"""Offline checks for honest, paired efficiency reporting; no model calls."""

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / ".agents/skills/pulmu/scripts/benchmark-report.py"
spec = importlib.util.spec_from_file_location("benchmark_report", SCRIPT)
reporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reporter)


def run_row(policy="baseline", sample=1, **overrides):
    row = dict(
        case="api", sample=sample, fixture="api-v1", policy=policy,
        checks_passed=True, review_passed=True, defects=0, retries=0,
        human_correction_seconds=0, usage_complete=True,
        input_tokens=1000, cached_input_tokens=700, output_tokens=200,
        elapsed_seconds=20,
    )
    row.update(overrides)
    return row


class BenchmarkReportTest(unittest.TestCase):
    def setUp(self):
        self.baseline = {("api", n): run_row(sample=n) for n in range(1, 4)}
        self.candidate = {
            ("api", n): run_row("candidate", n, input_tokens=800, output_tokens=100, elapsed_seconds=10)
            for n in range(1, 4)
        }

    def write_rows(self, path, rows):
        path.write_text("\n".join(json.dumps(row) for row in rows) + "\n")

    def test_cli_pairs_runs_and_does_not_double_count_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            before, after = Path(directory) / "before.jsonl", Path(directory) / "after.jsonl"
            self.write_rows(before, self.baseline.values())
            self.write_rows(after, self.candidate.values())
            result = subprocess.run([sys.executable, str(SCRIPT), str(before), str(after)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["status"], "observed-improvement")
        self.assertEqual(data["baseline"]["total_tokens"], 3600)
        self.assertEqual(data["baseline"]["uncached_input_tokens"], 900)
        self.assertEqual(data["token_reduction_percent"], 25)
        self.assertEqual(data["cases"][0]["elapsed_reduction_percent"], 50)

    def test_failures_and_defects_cannot_qualify_as_savings(self):
        for field, value in (("checks_passed", False), ("review_passed", False), ("defects", 1)):
            with self.subTest(field=field):
                candidate = copy.deepcopy(self.candidate)
                candidate[("api", 1)][field] = value
                result = reporter.compare(self.baseline, candidate)
                self.assertEqual(result["status"], "not-established")
                self.assertIn("quality-not-established", result["reasons"])
                self.assertEqual(result["candidate"]["total_tokens"], 2700)

    def test_failed_baseline_also_requires_quality_evidence(self):
        self.baseline[("api", 1)]["checks_passed"] = False
        self.assertIn("quality-not-established", reporter.compare(self.baseline, self.candidate)["reasons"])

    def test_missing_usage_is_not_zero(self):
        self.candidate[("api", 1)].update(usage_complete=False, input_tokens=None)
        result = reporter.compare(self.baseline, self.candidate)
        self.assertIn("incomplete-usage", result["reasons"])
        self.assertIsNone(result["candidate"]["total_tokens"])
        self.assertIsNone(result["token_reduction_percent"])

    def test_single_sample_cannot_establish_improvement(self):
        result = reporter.compare({("api", 1): self.baseline[("api", 1)]}, {("api", 1): self.candidate[("api", 1)]})
        self.assertIn("insufficient-samples", result["reasons"])

    def test_rework_and_time_regressions_block_qualification(self):
        for field, value, reason in (
            ("retries", 1, "rework-regression"),
            ("human_correction_seconds", 30, "rework-regression"),
            ("elapsed_seconds", 30, "elapsed-regression"),
        ):
            with self.subTest(field=field):
                candidate = copy.deepcopy(self.candidate)
                for row in candidate.values():
                    row[field] = value
                self.assertIn(reason, reporter.compare(self.baseline, candidate)["reasons"])

    def test_one_regressing_case_cannot_hide_in_aggregate(self):
        for n in range(1, 4):
            self.baseline[("ui", n)] = run_row(sample=n, case="ui")
            self.candidate[("ui", n)] = run_row("candidate", n, case="ui", input_tokens=1001)
        result = reporter.compare(self.baseline, self.candidate)
        self.assertGreater(result["token_reduction_percent"], 0)
        self.assertIn("tokens-not-reduced", result["reasons"])

    def test_median_cannot_hide_one_very_slow_run(self):
        self.candidate[("api", 3)]["elapsed_seconds"] = 600
        result = reporter.compare(self.baseline, self.candidate)
        self.assertEqual(result["status"], "not-established")
        self.assertIn("elapsed-tail-regression", result["reasons"])
        self.assertEqual(result["candidate"]["median_elapsed_seconds"], 10)
        self.assertEqual(result["candidate"]["total_elapsed_seconds"], 620)
        self.assertEqual(result["candidate"]["max_elapsed_seconds"], 600)
        self.assertEqual(result["cases"][0]["tail_regressions"][0]["sample"], 3)

    def test_tail_guard_allows_noise_and_threshold_equality(self):
        for elapsed in (21, 25):
            self.candidate[("api", 3)]["elapsed_seconds"] = elapsed
            self.assertEqual(reporter.compare(self.baseline, self.candidate)["status"], "observed-improvement")
        self.candidate[("api", 3)]["elapsed_seconds"] = 25.01
        self.assertIn("elapsed-tail-regression", reporter.compare(self.baseline, self.candidate)["reasons"])

    def test_tail_guard_handles_zero_baseline_and_explicit_thresholds(self):
        self.baseline[("api", 3)]["elapsed_seconds"] = 0
        self.candidate[("api", 3)]["elapsed_seconds"] = 5
        self.assertNotIn("elapsed-tail-regression", reporter.compare(self.baseline, self.candidate)["reasons"])
        self.candidate[("api", 3)]["elapsed_seconds"] = 6
        self.assertIn("elapsed-tail-regression", reporter.compare(self.baseline, self.candidate)["reasons"])
        result = reporter.compare(self.baseline, self.candidate, tail_seconds=6, tail_percent=10)
        self.assertEqual(result["tail_guard"]["seconds"], 6)
        self.assertNotIn("elapsed-tail-regression", result["reasons"])
        for value in (-1, float("nan"), float("inf")):
            with self.assertRaises(ValueError):
                reporter.compare(self.baseline, self.candidate, tail_seconds=value)

    def test_relative_tail_allowance_and_override(self):
        self.baseline[("api", 3)]["elapsed_seconds"] = 100
        for percent, boundary in ((25, 125), (10, 110)):
            self.candidate[("api", 3)]["elapsed_seconds"] = boundary
            self.assertNotIn("elapsed-tail-regression", reporter.compare(self.baseline, self.candidate, tail_percent=percent)["reasons"])
            self.candidate[("api", 3)]["elapsed_seconds"] = boundary + 0.01
            self.assertIn("elapsed-tail-regression", reporter.compare(self.baseline, self.candidate, tail_percent=percent)["reasons"])

    def test_zero_denominator_is_undefined(self):
        self.assertIsNone(reporter.reduction(0, 0))
        self.assertIsNone(reporter.reduction(0, 1))

    def test_mismatched_pairs_and_fixtures_are_rejected(self):
        candidate = copy.deepcopy(self.candidate)
        del candidate[("api", 3)]
        with self.assertRaisesRegex(ValueError, "same case/sample"):
            reporter.compare(self.baseline, candidate)
        self.candidate[("api", 1)]["fixture"] = "another-task"
        with self.assertRaisesRegex(ValueError, "same fixture"):
            reporter.compare(self.baseline, self.candidate)

    def test_rejects_invalid_measurements(self):
        invalid = [
            dict(input_tokens=-1), dict(input_tokens=True), dict(sample=0),
            dict(elapsed_seconds=float("nan")), dict(elapsed_seconds=float("inf")),
            dict(output_tokens=None), dict(cached_input_tokens=1001),
            dict(review_passed="true"), dict(defects=0.5), dict(policy=" "),
            dict(human_correction_seconds=-1), dict(raw_log="unrequested data"),
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "runs.jsonl"
            for change in invalid:
                with self.subTest(change=change):
                    self.write_rows(path, [run_row(**change)])
                    with self.assertRaises(ValueError):
                        reporter.read_runs(path)

    def test_rejects_duplicate_pairs_mixed_policies_and_empty_input(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "runs.jsonl"
            for rows in ([], [run_row(), run_row()], [run_row(), run_row("other", 2)]):
                with self.subTest(rows=rows):
                    self.write_rows(path, rows)
                    with self.assertRaises(ValueError):
                        reporter.read_runs(path)

    def test_unknown_usage_can_be_explicitly_null(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "runs.jsonl"
            self.write_rows(path, [run_row(usage_complete=False, input_tokens=None, cached_input_tokens=None, output_tokens=None)])
            self.assertFalse(reporter.read_runs(path)[("api", 1)]["usage_complete"])

    def test_cli_invalid_input_exits_two_without_a_report(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.jsonl"
            path.write_text("{}\n")
            result = subprocess.run([sys.executable, str(SCRIPT), str(path), str(path)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()

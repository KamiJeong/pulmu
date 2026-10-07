#!/usr/bin/env python3
"""Compare paired, sanitized run measurements. Never calls a model or writes state."""

import argparse
import json
import math
import statistics
import sys
from pathlib import Path


FIELDS = {
    "case", "sample", "fixture", "policy", "checks_passed", "review_passed",
    "defects", "retries", "human_correction_seconds", "usage_complete",
    "input_tokens", "cached_input_tokens", "output_tokens", "elapsed_seconds",
}
TOKEN_FIELDS = ("input_tokens", "cached_input_tokens", "output_tokens")


def number(value, field, integer=False):
    if type(value) not in ((int,) if integer else (int, float)):
        raise ValueError(f"{field} must be a nonnegative {'integer' if integer else 'number'}")
    if value < 0 or not math.isfinite(value):
        raise ValueError(f"{field} must be finite and nonnegative")


def read_runs(path):
    rows = {}
    policies = set()
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
            if not isinstance(row, dict) or set(row) != FIELDS:
                raise ValueError("row must contain exactly the documented measurement fields")
            for field in ("case", "fixture", "policy"):
                if not isinstance(row[field], str) or not row[field].strip():
                    raise ValueError(f"{field} must be a nonempty string")
            for field in ("checks_passed", "review_passed", "usage_complete"):
                if type(row[field]) is not bool:
                    raise ValueError(f"{field} must be a boolean")
            for field in ("sample", "defects", "retries"):
                number(row[field], field, integer=True)
            if row["sample"] < 1:
                raise ValueError("sample must be at least 1")
            for field in ("elapsed_seconds", "human_correction_seconds"):
                number(row[field], field)
            for field in TOKEN_FIELDS:
                if row[field] is not None or row["usage_complete"]:
                    number(row[field], field, integer=True)
            if row["input_tokens"] is not None and row["cached_input_tokens"] is not None:
                if row["cached_input_tokens"] > row["input_tokens"]:
                    raise ValueError("cached_input_tokens cannot exceed input_tokens")
            key = (row["case"], row["sample"])
            if key in rows:
                raise ValueError("duplicate case/sample pair")
            rows[key] = row
            policies.add(row["policy"])
        except (ValueError, TypeError, OverflowError) as exc:
            raise ValueError(f"{path.name}:{line_number}: {exc}") from exc
    if not rows or len(policies) != 1:
        raise ValueError(f"{path.name}: expected nonempty measurements from exactly one policy")
    return rows


def accepted(row):
    return row["checks_passed"] and row["review_passed"] and row["defects"] == 0


def aggregate(rows):
    complete = all(row["usage_complete"] for row in rows)
    result = {
        "runs": len(rows),
        "accepted_runs": sum(accepted(row) for row in rows),
        "defects": sum(row["defects"] for row in rows),
        "retries": sum(row["retries"] for row in rows),
        "human_correction_seconds": sum(row["human_correction_seconds"] for row in rows),
        "median_elapsed_seconds": statistics.median(row["elapsed_seconds"] for row in rows),
        "total_elapsed_seconds": sum(row["elapsed_seconds"] for row in rows),
        "max_elapsed_seconds": max(row["elapsed_seconds"] for row in rows),
        "usage_complete": complete,
    }
    for field in TOKEN_FIELDS:
        result[field] = sum(row[field] for row in rows) if complete else None
    # Cached input is a subset of input; reasoning is already part of output.
    result["total_tokens"] = result["input_tokens"] + result["output_tokens"] if complete else None
    result["uncached_input_tokens"] = (
        result["input_tokens"] - result["cached_input_tokens"] if complete else None
    )
    return result


def reduction(before, after):
    if before is None or after is None or before == 0:
        return None
    return round(100 * (before - after) / before, 2)


def compare(baseline, candidate, tail_seconds=5, tail_percent=25):
    number(tail_seconds, "tail_seconds")
    number(tail_percent, "tail_percent")
    if baseline.keys() != candidate.keys():
        raise ValueError("baseline and candidate must contain the same case/sample pairs")
    for key in baseline:
        if baseline[key]["fixture"] != candidate[key]["fixture"]:
            raise ValueError("paired runs must use the same fixture identity")
    if next(iter(baseline.values()))["policy"] == next(iter(candidate.values()))["policy"]:
        raise ValueError("baseline and candidate must identify different policies")

    cases = []
    for case in sorted({key[0] for key in baseline}):
        keys = sorted(key for key in baseline if key[0] == case)
        before = aggregate([baseline[key] for key in keys])
        after = aggregate([candidate[key] for key in keys])
        tail_regressions = []
        for key in keys:
            baseline_time = baseline[key]["elapsed_seconds"]
            candidate_time = candidate[key]["elapsed_seconds"]
            allowance = max(tail_seconds, baseline_time * tail_percent / 100)
            if candidate_time - baseline_time > allowance:
                tail_regressions.append({
                    "sample": key[1], "baseline_seconds": baseline_time,
                    "candidate_seconds": candidate_time,
                    "delta_seconds": candidate_time - baseline_time,
                    "allowed_delta_seconds": allowance,
                })
        cases.append({
            "case": case, "baseline": before, "candidate": after,
            "tail_regressions": tail_regressions,
            "token_reduction_percent": reduction(before["total_tokens"], after["total_tokens"]),
            "elapsed_reduction_percent": reduction(before["median_elapsed_seconds"], after["median_elapsed_seconds"]),
        })

    reasons = []
    for case in cases:
        before, after = case["baseline"], case["candidate"]
        if before["accepted_runs"] != before["runs"] or after["accepted_runs"] != after["runs"]:
            reasons.append("quality-not-established")
        if before["runs"] < 3:
            reasons.append("insufficient-samples")
        if not before["usage_complete"] or not after["usage_complete"]:
            reasons.append("incomplete-usage")
        if before["total_tokens"] is not None and after["total_tokens"] is not None:
            if after["total_tokens"] >= before["total_tokens"]:
                reasons.append("tokens-not-reduced")
        if after["median_elapsed_seconds"] > before["median_elapsed_seconds"]:
            reasons.append("elapsed-regression")
        if case["tail_regressions"]:
            reasons.append("elapsed-tail-regression")
        if after["retries"] > before["retries"] or after["human_correction_seconds"] > before["human_correction_seconds"]:
            reasons.append("rework-regression")

    before, after = aggregate(list(baseline.values())), aggregate(list(candidate.values()))
    return {
        "baseline_policy": next(iter(baseline.values()))["policy"],
        "candidate_policy": next(iter(candidate.values()))["policy"],
        "status": "observed-improvement" if not reasons else "not-established",
        "reasons": sorted(set(reasons)),
        "tail_guard": {"seconds": tail_seconds, "percent": tail_percent, "rule": "delta > max(seconds, baseline * percent / 100)"},
        "baseline": before, "candidate": after,
        "token_reduction_percent": reduction(before["total_tokens"], after["total_tokens"]),
        "cases": cases,
        "limitation": "Descriptive paired measurements, not statistical proof or a future performance guarantee. Token counts are not monetary cost.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--tail-seconds", type=float, default=5, help="absolute paired slowdown allowance (default: 5)")
    parser.add_argument("--tail-percent", type=float, default=25, help="relative paired slowdown allowance (default: 25)")
    args = parser.parse_args()
    try:
        report = compare(read_runs(args.baseline), read_runs(args.candidate), args.tail_seconds, args.tail_percent)
        output = json.dumps(report, indent=2, allow_nan=False)
    except (OSError, ValueError, OverflowError) as exc:
        print(f"benchmark-report: {exc}", file=sys.stderr)
        return 2
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

ok() { PASS=$((PASS+1)); printf '✓ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '✗ %s\n' "$1"; }
run_test() {
  local name="$1"; shift
  if "$@"; then ok "$name"; else bad "$name"; fi
}

syntax_test() {
  while IFS= read -r -d '' f; do bash -n "$f" || return 1; done < <(find "$ROOT" -name '*.sh' -print0)
}

github_repository_contract_test() {
  local workflow="$ROOT/.github/workflows/ci.yml" required
  [[ -f "$workflow" ]] || return 1
  grep -Fq 'actions/checkout@v7' "$workflow" || return 1
  grep -Fq 'actions/setup-node@v7' "$workflow" || return 1
  grep -Fq 'actions/setup-python@v7' "$workflow" || return 1
  grep -Fq -- '- ubuntu-latest' "$workflow" || return 1
  grep -Fq -- '- macos-14' "$workflow" || return 1
  grep -Fq 'run: /bin/bash ./tests/test.sh' "$workflow" || return 1
  for required in \
    CONTRIBUTING.md \
    SECURITY.md \
    CHANGELOG.md \
    .github/PULL_REQUEST_TEMPLATE.md \
    .github/ISSUE_TEMPLATE/bug_report.yml \
    .github/ISSUE_TEMPLATE/feature_request.yml \
    .github/ISSUE_TEMPLATE/config.yml; do
    [[ -f "$ROOT/$required" ]] || return 1
  done
  grep -Fq 'gh auth status' "$ROOT/README.md" || return 1
  grep -Fq 'PULMU_DELIVERY=github' "$ROOT/README.md" || return 1
  grep -Fq 'Fork and upstream limitation' "$ROOT/README.md" || return 1
  grep -Fq 'security/advisories/new' "$ROOT/SECURITY.md" || return 1
}

landing_page_contract_test() {
  local page="$ROOT/index.html" version install_command
  version="$(tr -d '[:space:]' < "$ROOT/.agents/skills/pulmu/VERSION")"
  install_command='git clone https://github.com/KamiJeong/pulmu.git &amp;&amp; cd pulmu'

  grep -Fq '<link rel="canonical" href="https://kamijeong.github.io/pulmu/">' "$page" || return 1
  grep -Fq '<link rel="icon" href="data:image/svg+xml,' "$page" || return 1
  grep -Fq '<meta name="theme-color" content="#151513">' "$page" || return 1
  for metadata in \
    'property="og:title"' \
    'property="og:description"' \
    'property="og:type" content="website"' \
    'property="og:url" content="https://kamijeong.github.io/pulmu/"' \
    'property="og:site_name" content="Pulmu"' \
    'property="og:image" content="https://kamijeong.github.io/pulmu/assets/pulmu-joseon-forge.png"' \
    'property="og:image:alt"' \
    'name="twitter:card" content="summary_large_image"' \
    'name="twitter:image" content="https://kamijeong.github.io/pulmu/assets/pulmu-joseon-forge.png"'; do
    grep -Fq "$metadata" "$page" || return 1
  done

  grep -Fq 'class="nav-section-link" href="#how-it-works"' "$page" || return 1
  grep -Fq 'class="nav-cta nav-repository" href="https://github.com/KamiJeong/pulmu"' "$page" || return 1
  grep -Fq 'class="nav-cta nav-install" href="#install"' "$page" || return 1
  grep -Fq '.nav-section-link {' "$page" || return 1

  grep -Fq 'id="install" aria-labelledby="install-title"' "$page" || return 1
  grep -Fq "$install_command" "$page" || return 1
  [[ "$(grep -Fc 'data-copy-target=' "$page")" -eq 2 ]] || return 1
  grep -Fq 'data-copy-target="#hero-command" data-copy-status="#copy-status"' "$page" || return 1
  grep -Fq 'data-copy-target="#install-command" data-copy-status="#install-copy-status"' "$page" || return 1
  grep -Fq 'id="copy-status" role="status" aria-live="polite"' "$page" || return 1
  grep -Fq 'id="install-copy-status" role="status" aria-live="polite"' "$page" || return 1

  grep -Fq "href=\"https://github.com/KamiJeong/pulmu/releases/tag/v${version}\">v${version}</a>" "$page" || return 1
  grep -Fq 'CI passing · Linux + macOS' "$page" || return 1
  grep -Fq '>MIT License</a>' "$page" || return 1
  grep -Fq 'class="result-action result-action-primary" href="#install">Install Pulmu</a>' "$page" || return 1
  grep -Fq 'href="https://github.com/KamiJeong/pulmu#quick-start">Read the setup guide</a>' "$page" || return 1
  grep -Fq 'class="footer-nav" aria-label="Repository"' "$page" || return 1
  for url in \
    'https://github.com/KamiJeong/pulmu"' \
    'https://github.com/KamiJeong/pulmu#readme"' \
    'https://github.com/KamiJeong/pulmu/releases"' \
    'https://github.com/KamiJeong/pulmu/security"'; do
    grep -Fq "href=\"$url" "$page" || return 1
  done
}

example_test() {
  (cd "$ROOT/examples/task-store" && npm test >/dev/null)
}

quench_test() {
  local d status=0
  d="$(mktemp -d)"
  cp -R "$ROOT/examples/task-store/." "$d/"
  (cd "$d" && git init -b main >/dev/null && git config user.name Test && git config user.email test@example.invalid && git add . && git commit -m init >/dev/null && bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type test --slug quench-pass 'Run Quench pass fixture' >/dev/null && finalize_metadata test quick low testing false false false && quench_for_run >/dev/null) || status=$?
  rm -rf "$d"
  return "$status"
}

quench_failure_test() {
  local d status
  d="$(mktemp -d)"
  mkdir -p "$d"
  printf '{"scripts":{"test":"touch .git/quench-ran && exit 17"}}\n' > "$d/package.json"
  if (
    cd "$d"
    git init -b main >/dev/null
    git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type test --slug quench-fail 'Run Quench failure fixture' >/dev/null
    finalize_metadata test quick low testing false false false
    quench_for_run >"$d/.git/quench-output" 2>&1
  ); then
    status=0
  else
    status=$?
  fi
  [[ -f "$d/.git/quench-ran" ]] || status=0
  grep -Fq '✗ npm run test (failed, exit 17)' "$d/.git/quench-output" || status=0
  grep -Fq 'PULMU_QUENCH_CHECK_EXIT=npm run test:17' "$d"/.git/pulmu-quench.* 2>/dev/null || status=0
  [[ ! -e "$d/.git/pulmu-metadata/quench_fingerprint" ]] || status=0
  rm -rf "$d"
  [[ "$status" -eq 17 ]]
}

quench_discovery_test() {
  local tmp shell_repo python_repo combined_repo fakebin scripts status
  tmp="$(mktemp -d)"
  shell_repo="$tmp/shell-repo"
  python_repo="$tmp/python-repo"
  combined_repo="$tmp/combined-repo"
  fakebin="$tmp/bin"
  scripts="$ROOT/.agents/skills/pulmu/scripts"
  status=0
  mkdir -p "$shell_repo/tests" "$python_repo/tests" "$combined_repo/tests" "$fakebin"
  printf '#!/usr/bin/env bash\nprintf "shell test ran\\n" > "$QUENCH_SHELL_MARKER"\n' > "$shell_repo/tests/test.sh"
  chmod +x "$shell_repo/tests/test.sh"
  printf '#!/usr/bin/env bash\nprintf "pytest ran\\n" > "$QUENCH_PYTEST_MARKER"\n' > "$fakebin/pytest"
  chmod +x "$fakebin/pytest"
  printf 'def test_example():\n    assert True\n' > "$python_repo/tests/test_example.py"
  printf '#!/usr/bin/env bash\nprintf "combined shell test ran\\n" > "$QUENCH_SHELL_MARKER"\n' > "$combined_repo/tests/test.sh"
  chmod +x "$combined_repo/tests/test.sh"
  printf 'def test_combined():\n    assert True\n' > "$combined_repo/tests/test_combined.py"

  (
    cd "$shell_repo"
    git init -b main >/dev/null
    git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    bash "$scripts/ignite.sh" --type test --slug shell-discovery 'Discover shell tests' >/dev/null
    finalize_metadata test quick low testing false false false
    PATH="$fakebin:$PATH" \
      QUENCH_SHELL_MARKER="$tmp/shell-ran" \
      QUENCH_PYTEST_MARKER="$tmp/pytest-ran-for-shell" \
      quench_for_run > "$tmp/shell-output"
    [[ -f "$tmp/shell-ran" && ! -e "$tmp/pytest-ran-for-shell" ]] || exit 1
    grep -Fq '• bash ./tests/test.sh' "$tmp/shell-output" || exit 1
    grep -Fq 'PULMU_QUENCH_CHECKS=1' "$tmp/shell-output" || exit 1
  ) || status=$?

  if [[ "$status" -eq 0 ]]; then
    (
      cd "$python_repo"
      git init -b main >/dev/null
      git config user.name Test; git config user.email test@example.invalid
      git add . && git commit -m init >/dev/null
      bash "$scripts/ignite.sh" --type test --slug python-discovery 'Discover Python tests' >/dev/null
      finalize_metadata test quick low testing false false false
      PATH="$fakebin:$PATH" \
        QUENCH_PYTEST_MARKER="$tmp/pytest-ran-for-python" \
        quench_for_run > "$tmp/python-output"
      [[ -f "$tmp/pytest-ran-for-python" ]] || exit 1
      grep -Fq '• pytest -q' "$tmp/python-output" || exit 1
      grep -Fq 'PULMU_QUENCH_CHECKS=1' "$tmp/python-output" || exit 1
    ) || status=$?
  fi

  if [[ "$status" -eq 0 ]]; then
    (
      cd "$combined_repo"
      git init -b main >/dev/null
      git config user.name Test; git config user.email test@example.invalid
      git add . && git commit -m init >/dev/null
      bash "$scripts/ignite.sh" --type test --slug combined-discovery 'Discover combined tests' >/dev/null
      finalize_metadata test quick low testing false false false
      PATH="$fakebin:$PATH" \
        QUENCH_SHELL_MARKER="$tmp/shell-ran-for-combined" \
        QUENCH_PYTEST_MARKER="$tmp/pytest-ran-for-combined" \
        quench_for_run > "$tmp/combined-output"
      [[ -f "$tmp/shell-ran-for-combined" && -f "$tmp/pytest-ran-for-combined" ]] || exit 1
      grep -Fq '• bash ./tests/test.sh' "$tmp/combined-output" || exit 1
      grep -Fq '• pytest -q' "$tmp/combined-output" || exit 1
      grep -Fq 'PULMU_QUENCH_CHECKS=2' "$tmp/combined-output" || exit 1
    ) || status=$?
  fi

  rm -rf "$tmp"
  return "$status"
}

quench_plan_gate_test() {
  local tmp status
  tmp="$(mktemp -d)"; status=0
  (
    for scenario in pass missing timeout; do
      repo="$tmp/$scenario"; mkdir -p "$repo/nested"; cd "$repo"
      git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
      printf 'fixture\n' > README.md; git add . && git commit -m init >/dev/null
      bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type test --slug "plan-$scenario" "Exercise $scenario verification plan" >/dev/null
      PULMU_TEST_SKIP_PLAN=1 finalize_metadata test quick low testing false false false
      run_id="$(cat .git/pulmu-metadata/run_id)"
      if [[ "$scenario" == pass ]]; then
        if bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage hammer --expect-run-id "$run_id" >/dev/null 2>&1; then exit 1; fi
        metadata_for_run verification --check nested 'printf ran > "$PLAN_MARKER"' >/dev/null
      elif [[ "$scenario" == missing ]]; then
        metadata_for_run verification --check . 'pulmu-command-that-does-not-exist' >/dev/null
      else
        metadata_for_run verification --check . 'trap "" TERM; sleep 30 & wait' >/dev/null
      fi
      bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage hammer --expect-run-id "$run_id" >/dev/null
      bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage quench --expect-run-id "$run_id" >/dev/null
      if [[ "$scenario" == pass ]]; then
        PLAN_MARKER="$tmp/plan-ran" bash "$ROOT/.agents/skills/pulmu/scripts/quench.sh" --expect-run-id "$run_id" >/dev/null
        [[ -f "$tmp/plan-ran" && -s .git/pulmu-metadata/quench_fingerprint ]] || exit 1
      else
        if PULMU_QUENCH_TIMEOUT_SECONDS=1 bash "$ROOT/.agents/skills/pulmu/scripts/quench.sh" --expect-run-id "$run_id" >/dev/null 2>&1; then exit 1; fi
        [[ ! -e .git/pulmu-metadata/quench_fingerprint ]] || exit 1
      fi
    done
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

quench_stale_publication_test() {
  local tmp repo status run_id pid a_status=0 count
  tmp="$(mktemp -d)"; repo="$tmp/repo"; status=0
  mkdir -p "$repo"
  (
    cd "$repo"
    git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    printf 'fixture\n' > README.md; git add . && git commit -m init >/dev/null
    out="$(bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type test --slug stale-quench 'Guard stale Quench publication')"
    run_id="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$out")"
    PULMU_TEST_SKIP_PLAN=1 finalize_metadata test quick low testing false false false
    metadata_for_run verification --check . 'if [[ -n "${STALE_RELEASE:-}" ]]; then printf started > "$STALE_STARTED"; while [[ ! -e "$STALE_RELEASE" ]]; do sleep 0.05; done; printf "RESULT_OLD\n"; else printf "RESULT_SUCCESSOR\n"; fi' >/dev/null
    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage hammer --expect-run-id "$run_id" >/dev/null
    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage quench --expect-run-id "$run_id" >/dev/null
    STALE_STARTED="$tmp/started" STALE_RELEASE="$tmp/release" \
      bash "$ROOT/.agents/skills/pulmu/scripts/quench.sh" --expect-run-id "$run_id" >"$tmp/a.out" 2>"$tmp/a.err" &
    pid=$!
    count=0; while [[ ! -e "$tmp/started" && "$count" -lt 100 ]]; do sleep 0.05; count=$((count + 1)); done
    [[ -e "$tmp/started" ]] || exit 1
    bash "$ROOT/.agents/skills/pulmu/scripts/quench.sh" --expect-run-id "$run_id" >/dev/null
    successor_fingerprint="$(cat .git/pulmu-metadata/quench_fingerprint)"
    printf 'release\n' > "$tmp/release"
    if wait "$pid"; then a_status=0; else a_status=$?; fi
    [[ "$a_status" -ne 0 && "$(cat .git/pulmu-metadata/quench_fingerprint)" == "$successor_fingerprint" ]] || exit 1
    grep -Fxq 'RESULT_SUCCESSOR' .git/pulmu-quench.log || exit 1
    ! grep -Fxq 'RESULT_OLD' .git/pulmu-quench.log || exit 1
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

installer_test() {
  local h status agent_count
  h="$(mktemp -d)"
  HOME="$h" bash "$ROOT/install.sh" >/dev/null
  agent_count="$(find "$h/.codex/agents" -maxdepth 1 -name 'pulmu-*.toml' -type f | wc -l)"
  if [[ -f "$h/.agents/skills/pulmu/SKILL.md" && -f "$h/.agents/skills/pulmu/VERSION" && -f "$h/.agents/skills/pulmu/agents/openai.yaml" && -f "$h/.codex/agents/pulmu-smith.toml" && -x "$h/.agents/skills/pulmu/scripts/ship.sh" && -x "$h/.agents/skills/pulmu/scripts/run-context.sh" && -f "$h/.agents/skills/pulmu/scripts/run-context.py" && "$agent_count" -eq 12 ]] &&
    grep -q 'display_name: "Pulmu Workflows"' "$h/.agents/skills/pulmu/agents/openai.yaml"; then
    status=0
  else
    status=1
  fi
  rm -rf "$h"
  return "$status"
}

uninstaller_test() {
  local h status
  h="$(mktemp -d)"
  HOME="$h" bash "$ROOT/install.sh" >/dev/null
  HOME="$h" bash "$ROOT/uninstall.sh" >/dev/null
  if [[ ! -e "$h/.agents/skills/pulmu" ]] &&
    ! find "$h/.codex/agents" -maxdepth 1 -name 'pulmu-*.toml' -type f | grep -q .; then
    status=0
  else
    status=1
  fi
  rm -rf "$h"
  return "$status"
}

local_installation_test() {
  local tmp target status before output agent_count
  tmp="$(mktemp -d)"; target="$tmp/project with spaces"; status=0
  (
    mkdir -p "$target/.codex/agents" "$target/.agents/skills/other"
    printf 'model = "keep-my-model"\n' > "$target/.codex/config.toml"
    printf 'other agent\n' > "$target/.codex/agents/other.toml"
    printf 'other skill\n' > "$target/.agents/skills/other/SKILL.md"
    before="$(git hash-object "$target/.codex/config.toml")"
    # Exercise logical vs physical paths on every OS (macOS temp roots may be links).
    ln -s "$target" "$tmp/project-alias"
    target="$tmp/project-alias"
    output="$(bash "$ROOT/install.sh" --local "$target")" || exit 1
    target="$(cd "$target" && pwd -P)" || exit 1
    grep -Fq "Installation scope: local ($target)" <<<"$output" || exit 1
    [[ -x "$target/.agents/skills/pulmu/scripts/ship.sh" ]] || exit 1
    agent_count="$(find "$target/.codex/agents" -name 'pulmu-*.toml' -type f | wc -l)"
    [[ "$agent_count" -eq 12 ]] || exit 1
    [[ "$(git hash-object "$target/.codex/config.toml")" == "$before" ]] || exit 1
    # Updating replaces only the installed Pulmu copy, including stale resources.
    printf 'old installed file\n' > "$target/.agents/skills/pulmu/obsolete.txt"
    bash "$ROOT/install.sh" --local "$target" >/dev/null || exit 1
    [[ ! -e "$target/.agents/skills/pulmu/obsolete.txt" && -f "$ROOT/.agents/skills/pulmu/SKILL.md" ]] || exit 1
    # A failure after replacing some agents restores the complete prior installation.
    printf 'previous skill\n' > "$target/.agents/skills/pulmu/obsolete.txt"
    printf 'previous architect\n' > "$target/.codex/agents/pulmu-architect.toml"
    printf 'previous smith\n' > "$target/.codex/agents/pulmu-smith.toml"
    mkdir -p "$tmp/bin"
    cat > "$tmp/bin/mv" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == *"/.pulmu-install."*"/agents/pulmu-smith.toml" ]]; then
  exit 1
fi
exec "$PULMU_TEST_REAL_MV" "$@"
SH
    chmod +x "$tmp/bin/mv"
    if PULMU_TEST_REAL_MV="$(command -v mv)" PATH="$tmp/bin:$PATH" bash "$ROOT/install.sh" --local "$target" >/dev/null 2>&1; then exit 1; fi
    grep -qx 'previous skill' "$target/.agents/skills/pulmu/obsolete.txt" || exit 1
    grep -qx 'previous architect' "$target/.codex/agents/pulmu-architect.toml" || exit 1
    grep -qx 'previous smith' "$target/.codex/agents/pulmu-smith.toml" || exit 1
    [[ -z "$(find "$target" -maxdepth 1 -name '.pulmu-install.*' -print)" ]] || exit 1
    bash "$ROOT/uninstall.sh" --local "$target" >/dev/null || exit 1
    [[ ! -e "$target/.agents/skills/pulmu" && ! -e "$target/.codex/agents/pulmu-smith.toml" ]] || exit 1
    [[ -f "$target/.agents/skills/other/SKILL.md" && -f "$target/.codex/agents/other.toml" ]] || exit 1
    [[ "$(git hash-object "$target/.codex/config.toml")" == "$before" ]] || exit 1
    bash "$ROOT/uninstall.sh" --local "$target" >/dev/null || exit 1
    if bash "$ROOT/install.sh" --local >/dev/null 2>&1; then exit 1; fi
    if bash "$ROOT/uninstall.sh" --local "$tmp/missing" >/dev/null 2>&1; then exit 1; fi
    if bash "$ROOT/install.sh" --global --local "$target" >/dev/null 2>&1; then exit 1; fi
    # Local paths cannot escape to other config directories through symlinks.
    mkdir -p "$tmp/linked" "$tmp/outside/agents"
    printf 'preserve external file\n' > "$tmp/outside/agents/pulmu-smith.toml"
    ln -s "$tmp/outside" "$tmp/linked/.codex"
    if bash "$ROOT/install.sh" --local "$tmp/linked" >/dev/null 2>&1; then exit 1; fi
    if bash "$ROOT/uninstall.sh" --local "$tmp/linked" >/dev/null 2>&1; then exit 1; fi
    grep -q 'preserve external file' "$tmp/outside/agents/pulmu-smith.toml" || exit 1
    [[ ! -e "$tmp/linked/.agents" ]] || exit 1
    # The source checkout already embeds Pulmu and must never delete itself.
    before="$(git hash-object "$ROOT/.agents/skills/pulmu/SKILL.md")"
    bash "$ROOT/install.sh" --local "$ROOT" >/dev/null || exit 1
    if bash "$ROOT/uninstall.sh" --local "$ROOT" >/dev/null 2>&1; then exit 1; fi
    if bash "$ROOT/install.sh" --local "$ROOT/.agents/skills/pulmu" >/dev/null 2>&1; then exit 1; fi
    [[ "$(git hash-object "$ROOT/.agents/skills/pulmu/SKILL.md")" == "$before" ]] || exit 1
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

demo_packaging_test() {
  local tmp target status agent_count
  tmp="$(mktemp -d)"
  target="$tmp/demo"
  bash "$ROOT/scripts/create-demo-repo.sh" "$target" >/dev/null
  agent_count="$(find "$target/.codex/agents" -maxdepth 1 -name 'pulmu-*.toml' -type f | wc -l)"
  if [[ -f "$target/.agents/skills/pulmu/SKILL.md" && -f "$target/.agents/skills/pulmu/scripts/run-context.py" && -f "$target/.agents/skills/pulmu/references/run-context.md" && -f "$target/.codex/config.toml" && -f "$target/.codex/agents/pulmu-smith.toml" && "$agent_count" -eq 12 ]]; then
    status=0
  else
    status=1
  fi
  rm -rf "$tmp"
  return "$status"
}

agent_contract_test() {
  python3 - "$ROOT" <<'PY'
import pathlib
import sys
import tomllib

root = pathlib.Path(sys.argv[1])
agent_dir = root / ".codex" / "agents"
expected = {
    "pulmu-explorer.toml": ("pulmu_explorer", "gpt-5.6-terra", "medium", "read-only"),
    "pulmu-test-scout.toml": ("pulmu_test_scout", "gpt-5.6-luna", "medium", "read-only"),
    "pulmu-risk-scout.toml": ("pulmu_risk_scout", "gpt-5.6-terra", "high", "read-only"),
    "pulmu-architect.toml": ("pulmu_architect", "gpt-5.6-sol", "high", "read-only"),
    "pulmu-designer.toml": ("pulmu_designer", "gpt-5.6-sol", "high", "read-only"),
    "pulmu-smith.toml": ("pulmu_smith", "gpt-5.6-sol", "high", "workspace-write"),
    "pulmu-failure-analyst.toml": ("pulmu_failure_analyst", "gpt-5.6-terra", "high", "read-only"),
    "pulmu-reviewer.toml": ("pulmu_reviewer", "gpt-5.6-terra", "high", "read-only"),
    "pulmu-test-reviewer.toml": ("pulmu_test_reviewer", "gpt-5.6-terra", "medium", "read-only"),
    "pulmu-security-reviewer.toml": ("pulmu_security_reviewer", "gpt-5.6-sol", "high", "read-only"),
    "pulmu-compat-reviewer.toml": ("pulmu_compat_reviewer", "gpt-5.6-terra", "high", "read-only"),
    "pulmu-design-reviewer.toml": ("pulmu_design_reviewer", "gpt-5.6-sol", "medium", "read-only"),
}

actual_files = {path.name for path in agent_dir.glob("pulmu-*.toml")}
assert actual_files == set(expected), (actual_files, set(expected))

agents = {}
required = {"name", "description", "model", "model_reasoning_effort", "sandbox_mode", "developer_instructions"}
for filename, contract in expected.items():
    data = tomllib.loads((agent_dir / filename).read_text())
    assert required <= data.keys(), (filename, required - data.keys())
    actual = (data["name"], data["model"], data["model_reasoning_effort"], data["sandbox_mode"])
    assert actual == contract, (filename, actual, contract)
    agents[data["name"]] = data
    if data["name"] != "pulmu_smith":
        assert "Do not modify files" in data["developer_instructions"], filename

writers = [name for name, data in agents.items() if data["sandbox_mode"] == "workspace-write"]
assert writers == ["pulmu_smith"], writers
smith_rules = agents["pulmu_smith"]["developer_instructions"].lower()
for forbidden in ("git commit", "push", "pull request", "force-push"):
    assert forbidden in smith_rules, forbidden

contract_text = "\n".join([
    (root / ".agents" / "skills" / "pulmu" / "SKILL.md").read_text(),
    (root / ".agents" / "skills" / "pulmu" / "references" / "agent-orchestration.md").read_text(),
])
for agent_name in agents:
    assert f"`{agent_name}`" in contract_text, agent_name

config = tomllib.loads((root / ".codex" / "config.toml").read_text())
assert config["agents"]["max_concurrent_threads_per_session"] >= 6
PY
}

skill_contract_test() {
  local skill stage design review delivery scripts readme plan_block progress_block actual_plan expected_plan actual_readme_plan expected_plain
  skill="$ROOT/.agents/skills/pulmu/SKILL.md"
  stage="$ROOT/.agents/skills/pulmu/references/stage-contract.md"
  design="$ROOT/.agents/skills/pulmu/references/design-pass.md"
  review="$ROOT/.agents/skills/pulmu/references/review-contract.md"
  delivery="$ROOT/.agents/skills/pulmu/references/delivery-policy.md"
  scripts="$ROOT/.agents/skills/pulmu/scripts"
  readme="$ROOT/README.md"

  grep -Fq "Codex's \`update_plan\` tool" "$skill" || return 1
  [[ "$(grep -Fc '🔥 Pulmu — Starting the forge workflow' "$skill")" -eq 1 ]] || return 1
  grep -Fq 'The banner is neither a plan item nor an eighth stage.' "$stage" || return 1
  grep -Fq 'references/design-pass.md' "$skill" || return 1
  grep -Fq 'Perform a brief read-only necessity assessment before creating a branch' "$skill" || return 1
  grep -Fq 'Tiny low-risk work may use zero subagents.' "$skill" || return 1
  grep -Fq 'Designate exactly one task-file writer' "$skill" || return 1
  grep -Fq '`pulmu_self_review`' "$skill" || return 1
  grep -Fq 'references/design-selection.md' "$skill" || return 1

  plan_block="$(sed -n '/## Native task-progress contract/,/## Terminal contract/p' "$stage")"
  actual_plan="$(grep '^- `.*—' <<<"$plan_block")"
  expected_plan="$(printf '%s\n' \
    '- `🔥 Ignite — Prepare`' \
    '- `🔎 Inspect — Explore`' \
    '- `📐 Shape — Design`' \
    '- `🔨 Hammer — Implement`' \
    '- `🌊 Quench — Verify`' \
    '- `🪨 Hone — Review`' \
    '- `📦 Ship — Deliver`')"
  expected_plain="$(printf '%s\n' \
    '🔥 Ignite — Prepare' \
    '🔎 Inspect — Explore' \
    '📐 Shape — Design' \
    '🔨 Hammer — Implement' \
    '🌊 Quench — Verify' \
    '🪨 Hone — Review' \
    '📦 Ship — Deliver')"
  [[ "$actual_plan" == "$expected_plan" ]] || return 1
  actual_readme_plan="$(sed -n '/The step text is stable/,/The native plan status/p' "$readme" | grep -E '^(🔥|🔎|📐|🔨|🌊|🪨|📦)')"
  [[ "$actual_readme_plan" == "$expected_plain" ]] || return 1
  ! grep -Eqi '^- `.*\b(active|pending|completed)\b.*`$' <<<"$actual_plan" || return 1
  ! grep -q '^- `.*Pattern' <<<"$plan_block" || return 1
  grep -Fq 'Do not repeat the full plan in normal assistant messages' "$stage" || return 1

  progress_block="$(sed -n '/## Terminal contract/,/## Retry paths/p' "$stage")"
  [[ "$(grep -Ec '^(🔥 Ignite|🔎 Inspect|📐 Shape|🔨 Hammer|🌊 Quench|🪨 Hone|📦 Ship)$' <<<"$progress_block")" -eq 7 ]] || return 1
  ! grep -Eq '^(🔥 Ignite|🔎 Inspect|📐 Shape|🔨 Hammer|🌊 Quench|🪨 Hone|📦 Ship) —' <<<"$progress_block" || return 1

  grep -Fq 'Decide from Inspect evidence rather than keywords alone.' "$design" || return 1
  grep -Fq 'Do not run this design review for tasks where Pattern was skipped.' "$review" || return 1
  grep -Fq 'Pulmu does not impose Git Flow.' "$delivery" || return 1
  grep -Fq 'Finalize task and execution metadata once after Shape.' "$skill" || return 1
  grep -Fq 'schemaVersion": 2' "$ROOT/.agents/skills/pulmu/references/run-context.md" || return 1
  grep -Fq 'scripts/run-context.sh set-stage' "$stage" || return 1
  [[ -f "$ROOT/.agents/skills/pulmu/references/run-context.md" ]] || return 1
  grep -Fq 'a real pull-request URL' "$stage" || return 1
  ! grep -REq 'declare[[:space:]]+-A|mapfile|sort[[:space:]]+-z|\$\{[^}]+\^\}' "$scripts" || return 1
}

task_mapping_test() {
  local common type prefix label
  common="$ROOT/.agents/skills/pulmu/scripts/common.sh"
  # shellcheck source=/dev/null
  source "$common"
  while IFS='|' read -r type prefix label; do
    [[ "$(pulmu_task_type_prefix "$type")" == "$prefix" ]] || return 1
    [[ "$(pulmu_task_type_label "$type")" == "$label" ]] || return 1
    [[ "pulmu/$prefix/example" =~ ^pulmu/$prefix/ ]] || return 1
  done <<'EOF'
feature|feat|type: feature
bugfix|fix|type: bug
refactor|refactor|type: refactor
docs|docs|type: docs
test|test|type: test
chore|chore|type: chore
EOF
}

base_selection_paths_test() {
  local tmp common status
  tmp="$(mktemp -d)"; common="$ROOT/.agents/skills/pulmu/scripts/common.sh"; status=0
  (
    mkdir -p "$tmp/convention"; cd "$tmp/convention"
    git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    printf 'base\n' > file.txt; git add . && git commit -m init >/dev/null
    git switch -c release >/dev/null
    source "$common"
    [[ "$(pulmu_base_branch)" == release ]] || exit 1
  ) || status=$?
  if [[ "$status" -eq 0 ]]; then
    (
      git init --bare "$tmp/remote.git" >/dev/null
      mkdir -p "$tmp/remote-default"; cd "$tmp/remote-default"
      git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
      printf 'base\n' > file.txt; git add . && git commit -m init >/dev/null
      git branch trunk; git remote add origin "$tmp/remote.git"; git push origin main trunk >/dev/null
      git remote set-head origin trunk
      git switch -c pulmu/existing >/dev/null
      source "$common"
      [[ "$(pulmu_base_branch)" == pulmu/existing ]] || exit 1
      git switch --detach >/dev/null
      [[ "$(pulmu_base_branch)" == trunk ]] || exit 1
    ) || status=$?
  fi
  if [[ "$status" -eq 0 ]]; then
    (
      mkdir -p "$tmp/main-fallback"; cd "$tmp/main-fallback"
      git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
      printf 'base\n' > file.txt; git add . && git commit -m init >/dev/null; git switch --detach >/dev/null
      source "$common"; [[ "$(pulmu_base_branch)" == main ]] || exit 1
    ) || status=$?
  fi
  if [[ "$status" -eq 0 ]]; then
    (
      mkdir -p "$tmp/develop-fallback"; cd "$tmp/develop-fallback"
      git init -b develop >/dev/null; git config user.name Test; git config user.email test@example.invalid
      printf 'base\n' > file.txt; git add . && git commit -m init >/dev/null; git switch --detach >/dev/null
      source "$common"; [[ "$(pulmu_base_branch)" == develop ]] || exit 1
    ) || status=$?
  fi
  rm -rf "$tmp"; return "$status"
}

finalize_metadata() {
  local run_id; local -a args checks
  run_id="$(cat .git/pulmu-metadata/run_id 2>/dev/null || true)"
  if [[ -z "$run_id" ]]; then
    run_id="$(bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" detect 2>/dev/null | sed -n 's/^PULMU_RUN_ID=//p' || true)"
  fi
  if [[ -n "$run_id" ]]; then
    current_stage="$(python3 -c 'import json; print(json.load(open(".git/pulmu/run.json"))["stage"]["current"])')"
    if [[ "$current_stage" == "ignite" ]]; then
      bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage inspect --expect-run-id "$run_id" >/dev/null || return 1
      current_stage="inspect"
    fi
    if [[ "$current_stage" == "inspect" ]]; then
      bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage shape --expect-run-id "$run_id" >/dev/null || return 1
    fi
  fi
  args=(finalize --type "${1:-feature}" --forge "${2:-standard}" --risk "${3:-low}" \
    --areas "${4:-backend}" --pattern "${5:-false}" \
    --security-review "${6:-false}" --compatibility-review "${7:-false}" \
  )
  [[ -n "${8:-}" ]] && args+=(--execution "$8")
  [[ -n "${9:-}" ]] && args+=(--writer "$9")
  [[ -n "${10:-}" ]] && args+=(--review-mode "${10}")
  [[ -n "${11:-}" ]] && args+=(--test-review "${11}")
  [[ -n "$run_id" ]] && args+=(--expect-run-id "$run_id")
  bash "$ROOT/.agents/skills/pulmu/scripts/metadata.sh" "${args[@]}" >/dev/null || return 1
  [[ "${PULMU_TEST_SKIP_PLAN:-0}" == 1 ]] && return 0
  checks=()
  if [[ -f package.json ]] && python3 -c 'import json; raise SystemExit(0 if "test" in json.load(open("package.json")).get("scripts", {}) else 1)' 2>/dev/null; then
    checks+=(--check . 'npm run test')
  fi
  [[ -f tests/test.sh ]] && checks+=(--check . 'bash ./tests/test.sh')
  if find . -path './.git' -prune -o -type f \( -name 'test_*.py' -o -name '*_test.py' \) -print -quit | grep -q .; then
    checks+=(--check . 'pytest -q')
  fi
  [[ "${#checks[@]}" -gt 0 ]] || checks+=(--check . 'git diff --check')
  metadata_for_run verification "${checks[@]}" >/dev/null
}

metadata_for_run() {
  local command="$1" run_id; shift
  run_id="$(cat .git/pulmu-metadata/run_id)"
  bash "$ROOT/.agents/skills/pulmu/scripts/metadata.sh" "$command" "$@" --expect-run-id "$run_id"
}

ship_for_run() {
  local run_id
  run_id="$(cat .git/pulmu-metadata/run_id)"
  bash "$ROOT/.agents/skills/pulmu/scripts/ship.sh" --expect-run-id "$run_id" "$@"
}

quench_for_run() {
  local run_id current_stage
  run_id="$(cat .git/pulmu-metadata/run_id)"
  current_stage="$(python3 -c 'import json; print(json.load(open(".git/pulmu/run.json"))["stage"]["current"])')"
  if [[ "$current_stage" == "shape" ]]; then
    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage hammer --expect-run-id "$run_id" >/dev/null || return 1
  fi
  bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage quench --expect-run-id "$run_id" >/dev/null
  bash "$ROOT/.agents/skills/pulmu/scripts/quench.sh" --expect-run-id "$run_id"
}

record_review_results() {
  local run_id role forge pattern security compatibility candidate review_mode test_review
  run_id="$(cat .git/pulmu-metadata/run_id)"
  forge="$(cat .git/pulmu-metadata/forge)"; pattern="$(cat .git/pulmu-metadata/pattern)"
  security="$(cat .git/pulmu-metadata/security_review)"; compatibility="$(cat .git/pulmu-metadata/compatibility_review)"
  review_mode="$(cat .git/pulmu-metadata/review_mode 2>/dev/null || printf 'independent\n')"
  test_review="$(cat .git/pulmu-metadata/test_review 2>/dev/null || { [[ "$forge" == "standard" || "$forge" == "full" ]] && printf 'true\n' || printf 'false\n'; })"
  candidate="$(cat .git/pulmu-metadata/quench_fingerprint)"
  if [[ "$review_mode" == "self" ]]; then roles=(pulmu_self_review); else roles=(pulmu_reviewer); fi
  [[ "$review_mode" == "independent" && "$test_review" == "true" ]] && roles+=(pulmu_test_reviewer)
  [[ "$review_mode" == "independent" && "$security" == "true" ]] && roles+=(pulmu_security_reviewer)
  [[ "$review_mode" == "independent" && "$compatibility" == "true" ]] && roles+=(pulmu_compat_reviewer)
  [[ "$review_mode" == "independent" && "$pattern" == "true" ]] && roles+=(pulmu_design_reviewer)
  for role in "${roles[@]}"; do
    bash "$ROOT/.agents/skills/pulmu/scripts/metadata.sh" review-attempt --role "$role" --candidate "$candidate" \
      --expect-run-id "$run_id" >/dev/null || return 1
    bash "$ROOT/.agents/skills/pulmu/scripts/metadata.sh" review --role "$role" --candidate "$candidate" --completion complete \
      --severity none --findings 'No blocking findings in fixture review.' --evidence 'Exact fixture candidate inspected.' --limitations none \
      --expect-run-id "$run_id" >/dev/null || return 1
  done
}

record_reviewed_delivery() {
  local title="$1" summary="$2" run_id
  run_id="$(cat .git/pulmu-metadata/run_id)"
  quench_for_run >/dev/null
  bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage hone --expect-run-id "$run_id" >/dev/null
  record_review_results
  bash "$ROOT/.agents/skills/pulmu/scripts/metadata.sh" hone --result pass --expect-run-id "$run_id" >/dev/null
  bash "$ROOT/.agents/skills/pulmu/scripts/metadata.sh" delivery \
    --title "$title" --summary "$summary" --change 'Updates the task-store fixture behavior and coverage' \
    --risk-reason 'Delivery mechanics are exercised with an isolated fixture' \
    --review-focus 'Git delivery metadata and repository safety' --expect-run-id "$run_id" >/dev/null
}

metadata_policy_test() {
  local tmp repo status
  tmp="$(mktemp -d)"; repo="$tmp/repo"; status=0
  mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"
    git init -b main >/dev/null
    git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    git branch develop
    printf 'Pulmu base branch: develop\n' > AGENTS.md
    git add AGENTS.md && git commit -m 'docs: add repository policy' >/dev/null
    out="$(bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type bugfix --slug login-redirect 'Fix login redirect')"
    grep -q 'PULMU_BASE=develop' <<<"$out" || exit 1
    grep -q 'PULMU_BRANCH=fix/login-redirect' <<<"$out" || exit 1
    [[ "$(cat .git/pulmu-base)" == develop && "$(cat .git/pulmu-branch)" == fix/login-redirect ]] || exit 1
    first_run_id="$(cat .git/pulmu-metadata/run_id)"
    if bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug ignored 'A different prompt must not replace provenance' >/dev/null 2>&1; then exit 1; fi
    [[ "$(cat .git/pulmu-metadata/run_id)" == "$first_run_id" && "$(cat .git/pulmu-metadata/task)" == 'Fix login redirect' ]] || exit 1
    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" interrupt --message 'replace fixture task' --expect-run-id "$first_run_id" >/dev/null
    next_task=$'A different prompt\nwith a second line'
    resume_out="$(bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug ignored "$next_task")"
    grep -q 'PULMU_BASE=develop' <<<"$resume_out" || exit 1
    grep -q 'PULMU_BRANCH=feat/ignored' <<<"$resume_out" || exit 1
    [[ "$(cat .git/pulmu-base)" == develop && "$(cat .git/pulmu-metadata/base_branch)" == develop ]] || exit 1
    [[ "$(cat .git/pulmu-metadata/task)" == "$next_task" && "$(cat .git/pulmu-task)" == "$next_task" ]] || exit 1
    second_run_id="$(cat .git/pulmu-metadata/run_id)"
    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" interrupt --message 'test ambiguous provenance' --expect-run-id "$second_run_id" >/dev/null
    printf 'main\n' > .git/pulmu-base
    if bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" 'Ambiguous provenance' >/dev/null 2>&1; then exit 1; fi
    printf 'develop\n' > .git/pulmu-base
    third_out="$(bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug pattern-metadata 'Finalize Pattern metadata')"
    grep -q 'PULMU_BRANCH=feat/pattern-metadata' <<<"$third_out" || exit 1
    finalize_metadata feature full medium testing true false true
    [[ "$(cat .git/pulmu-metadata/areas)" == frontend,design,testing ]] || exit 1
    if finalize_metadata feature standard medium testing true false true >/dev/null 2>&1; then exit 1; fi
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

branch_naming_policy_test() {
  local tmp repo scripts status run_id output saved_branch saved_id before invalid
  tmp="$(mktemp -d)"; repo="$tmp/repo"; scripts="$ROOT/.agents/skills/pulmu/scripts"; status=0
  mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"; git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    # A human-created namespace lookalike is an ordinary branch, not a run.
    git switch -c pulmu/feat/manual >/dev/null
    printf 'human branch\n' > human.txt; git add human.txt; git commit -m 'docs: human work' >/dev/null
    output="$(bash "$scripts/ignite.sh" --type bugfix --slug first 'Fix first issue')"
    grep -qx 'PULMU_BRANCH=fix/first' <<<"$output" || exit 1
    grep -qx 'PULMU_BASE=pulmu/feat/manual' <<<"$output" || exit 1
    [[ -f human.txt ]] || exit 1
    run_id="$(cat .git/pulmu-metadata/run_id)"
    bash "$scripts/run-context.sh" interrupt --expect-run-id "$run_id" >/dev/null

    mkdir -p .pulmu; printf '[git]\nbranch_prefix = "pulmu"\nbase_branch = "main"\n' > .pulmu/config.toml
    git add .pulmu/config.toml; git commit -m 'chore: choose namespace' >/dev/null
    # A user/repository-provided complete name overrides the optional namespace.
    output="$(bash "$scripts/ignite.sh" --type feature --slug search --branch feature/PROJ-123-search 'Search customers')"
    grep -qx 'PULMU_BRANCH=feature/PROJ-123-search' <<<"$output" || exit 1
    grep -qx 'PULMU_BASE=pulmu/feat/manual' <<<"$output" || exit 1
    run_id="$(cat .git/pulmu-metadata/run_id)"
    bash "$scripts/run-context.sh" interrupt --expect-run-id "$run_id" >/dev/null

    mkdir -p .pulmu; printf '[git]\nbranch_prefix = "pulmu"\n' > .pulmu/config.toml
    git add .pulmu/config.toml; git commit -m 'chore: namespace next task' >/dev/null
    output="$(bash "$scripts/ignite.sh" --type feature --slug scoped 'Namespaced task')"
    grep -qx 'PULMU_BRANCH=pulmu/feat/scoped' <<<"$output" || exit 1
    run_id="$(cat .git/pulmu-metadata/run_id)"
    bash "$scripts/run-context.sh" interrupt --expect-run-id "$run_id" >/dev/null
    mkdir -p .pulmu; printf '[git]\nbranch_prefix = ""\n' > .pulmu/config.toml
    git add .pulmu/config.toml; git commit -m 'chore: disable namespace' >/dev/null
    output="$(bash "$scripts/ignite.sh" --type feature --slug unscoped 'Unnamespaced next task')"
    grep -qx 'PULMU_BRANCH=feat/unscoped' <<<"$output" || exit 1
    grep -qx 'PULMU_BASE=pulmu/feat/manual' <<<"$output" || exit 1
    git show-ref --verify --quiet refs/heads/pulmu/feat/scoped || exit 1
    run_id="$(cat .git/pulmu-metadata/run_id)"
    bash "$scripts/run-context.sh" interrupt --expect-run-id "$run_id" >/dev/null

    # Missing/conflicting identity must fail before state or branch mutation.
    before="$(git hash-object .git/pulmu/run.json)"; saved_branch="$(cat .git/pulmu-branch)"
    rm .git/pulmu-branch
    if bash "$scripts/ignite.sh" --slug broken 'Missing provenance' >/dev/null 2>&1; then exit 1; fi
    [[ "$(git hash-object .git/pulmu/run.json)" == "$before" ]] || exit 1
    printf '%s\n' "$saved_branch" > .git/pulmu-branch
    saved_id="$(cat .git/pulmu-metadata/run_id)"; printf 'different-run\n' > .git/pulmu-metadata/run_id
    if bash "$scripts/ignite.sh" --slug broken 'Conflicting run identity' >/dev/null 2>&1; then exit 1; fi
    printf '%s\n' "$saved_id" > .git/pulmu-metadata/run_id
    for invalid in HEAD '@{-1}' '../escape' '-option' 'bad//name'; do
      if bash "$scripts/ignite.sh" --branch "$invalid" --slug invalid 'Invalid literal branch' >/dev/null 2>&1; then exit 1; fi
      [[ "$(git hash-object .git/pulmu/run.json)" == "$before" && "$(git branch --show-current)" == "$saved_branch" ]] || exit 1
    done
    # Explicit names retain deterministic collision handling as well.
    git branch feature/PROJ-123-existing
    output="$(bash "$scripts/ignite.sh" --branch feature/PROJ-123-existing --slug existing 'Existing requested name')"
    grep -qx 'PULMU_BRANCH=feature/PROJ-123-existing-2' <<<"$output" || exit 1
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

config_and_collision_test() {
  local tmp repo bare status
  tmp="$(mktemp -d)"; repo="$tmp/repo"; bare="$tmp/remote.git"; status=0
  mkdir -p "$repo/.pulmu"; git init --bare "$bare" >/dev/null; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"
    git init -b main >/dev/null
    git config user.name Test; git config user.email test@example.invalid
    printf 'Pulmu base branch: develop\n' > AGENTS.md
    printf '[git]\nbase_branch = "main"\n' > .pulmu/config.toml
    git add . && git commit -m init >/dev/null
    git branch develop
    git remote add origin "$bare"; git push -u origin main >/dev/null
    git branch feat/search; git push origin feat/search >/dev/null; git branch -D feat/search >/dev/null
    out="$(bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug search 'Add search')"
    grep -q 'PULMU_BASE=main' <<<"$out" || exit 1
    grep -q 'PULMU_BRANCH=feat/search-2' <<<"$out" || exit 1
  ) || status=$?
  if [[ "$status" -eq 0 ]]; then
    rm -rf "$repo"; mkdir -p "$repo/.pulmu"; cp -R "$ROOT/examples/task-store/." "$repo/"
    (
      cd "$repo"; git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
      git add . && git commit -m init >/dev/null
      printf '[git]\nbase_branch = "does-not-exist"\n' > .pulmu/config.toml
      if bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" 'Invalid base' >/dev/null 2>&1; then exit 1; fi
      printf '[policy]\nforce_push = true\n' > .pulmu/config.toml
      if bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" 'Unsafe config' >/dev/null 2>&1; then exit 1; fi
      printf '[policy]\nauto_merge = true\n' > .pulmu/config.toml
      if bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" 'Unsafe merge config' >/dev/null 2>&1; then exit 1; fi
    ) || status=$?
  fi
  rm -rf "$tmp"; return "$status"
}

ship_evidence_gate_test() {
  local tmp repo before status old_hone hidden_blob
  tmp="$(mktemp -d)"; repo="$tmp/repo"; status=0
  mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"
    git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug evidence-gates 'Exercise evidence gates' >/dev/null
    finalize_metadata feature standard medium testing false false true
    printf '\n// evidence v1\n' >> src/task-store.js
    before="$(git rev-parse HEAD)"
    if metadata_for_run hone --result pass >/dev/null 2>&1; then exit 1; fi
    quench_for_run >/dev/null
    printf '// evidence v2\n' >> src/task-store.js
    if metadata_for_run hone --result pass >/dev/null 2>&1; then exit 1; fi
    quench_for_run >/dev/null
    if metadata_for_run delivery --title 'feat(testing): exercise evidence gates' --summary 'Exercises missing Hone.' --change 'Adds evidence fixture comments' >/dev/null 2>&1; then exit 1; fi
    metadata_for_run_id="$(cat .git/pulmu-metadata/run_id)"
    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage hone --expect-run-id "$metadata_for_run_id" >/dev/null
    record_review_results
    metadata_for_run hone --result pass >/dev/null
    old_hone="$(cat .git/pulmu-metadata/hone_fingerprint)"
    printf '// evidence v3\n' >> src/task-store.js
    printf '#!/usr/bin/env bash\nexit 0\n' > verify-helper; chmod +x verify-helper
    ln -s verify-helper verify-link
    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" increment-retry hone --expect-run-id "$metadata_for_run_id" >/dev/null
    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage quench --expect-run-id "$metadata_for_run_id" >/dev/null
    if bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage hone --expect-run-id "$metadata_for_run_id" >/dev/null 2>&1; then exit 1; fi
    quench_for_run >/dev/null
    printf '%s\n' "$old_hone" > .git/pulmu-metadata/hone_fingerprint
    if metadata_for_run delivery --title 'feat(testing): exercise evidence gates' --summary 'Exercises stale Hone.' --change 'Adds evidence fixture comments' >/dev/null 2>&1; then exit 1; fi
    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage hone --expect-run-id "$metadata_for_run_id" >/dev/null
    record_review_results
    metadata_for_run hone --result pass >/dev/null
    metadata_for_run delivery --title 'feat(testing): exercise evidence gates' --summary 'Exercises exact final-diff delivery.' --change 'Adds evidence fixture comments' >/dev/null
    cp src/task-store.js "$tmp/task-store-v3.js"
    printf '// evidence v4\n' >> src/task-store.js
    if ship_for_run --delivery local >/dev/null 2>&1; then exit 1; fi
    [[ "$(git rev-parse HEAD)" == "$before" && ! -f .git/pulmu-ship-commit ]] || exit 1
    cp "$tmp/task-store-v3.js" src/task-store.js
    printf 'private staged content\n' > hidden-user.txt
    git add hidden-user.txt
    hidden_blob="$(git rev-parse :hidden-user.txt)"
    rm hidden-user.txt
    if ship_for_run --delivery local >/dev/null 2>&1; then exit 1; fi
    [[ "$(git rev-parse :hidden-user.txt)" == "$hidden_blob" && "$(git rev-parse HEAD)" == "$before" ]] || exit 1
    git rm --cached hidden-user.txt >/dev/null
    mkdir -p .git/hooks
    printf '#!/usr/bin/env bash\nprintf "// hook mutation\\n" >> src/task-store.js\ngit add src/task-store.js\n' > .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    if ship_for_run --delivery local >/dev/null 2>&1; then exit 1; fi
    [[ ! -f .git/pulmu-ship-commit ]] || exit 1
    python3 - .git/pulmu/run.json <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["status"] == "running" and state["stage"]["current"] == "ship"
PY
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

review_receipt_gate_test() {
  local tmp repo status run_id candidate role
  tmp="$(mktemp -d)"; repo="$tmp/repo"; status=0
  mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"
    git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug review-receipts 'Gate Hone on exact reviewer receipts' >/dev/null
    finalize_metadata feature full low testing true true true
    printf '\n// review receipt fixture\n' >> src/task-store.js
    quench_for_run >/dev/null
    run_id="$(cat .git/pulmu-metadata/run_id)"
    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage hone --expect-run-id "$run_id" >/dev/null
    candidate="$(cat .git/pulmu-metadata/quench_fingerprint)"
    if metadata_for_run review-attempt --role pulmu_reviewer --candidate 0000000000000000000000000000000000000000 >/dev/null 2>&1; then exit 1; fi
    if metadata_for_run hone --result pass >/dev/null 2>&1; then exit 1; fi
    metadata_for_run review-attempt --role pulmu_reviewer --candidate "$candidate" >/dev/null
    metadata_for_run review --role pulmu_reviewer --candidate "$candidate" --completion complete --severity medium \
      --findings 'Blocking fixture finding.' --evidence 'src/task-store.js fixture' --limitations none >/dev/null
    if metadata_for_run hone --result pass >/dev/null 2>&1; then exit 1; fi
    if metadata_for_run review --role pulmu_reviewer --candidate "$candidate" --completion complete --severity none \
      --findings 'Attempted verdict replacement.' --evidence 'none' --limitations none >/dev/null 2>&1; then exit 1; fi

    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" increment-retry hone --expect-run-id "$run_id" >/dev/null
    quench_for_run >/dev/null
    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage hone --expect-run-id "$run_id" >/dev/null
    candidate="$(cat .git/pulmu-metadata/quench_fingerprint)"
    metadata_for_run review-attempt --role pulmu_test_reviewer --candidate "$candidate" >/dev/null
    if metadata_for_run review --role pulmu_test_reviewer --candidate "$candidate" --completion complete --severity invalid \
      --findings 'Malformed severity.' --evidence 'fixture' --limitations none >/dev/null 2>&1; then exit 1; fi
    metadata_for_run review-attempt --role pulmu_test_reviewer --candidate "$candidate" >/dev/null
    if metadata_for_run review-attempt --role pulmu_test_reviewer --candidate "$candidate" >/dev/null 2>&1; then exit 1; fi
    metadata_for_run review --role pulmu_test_reviewer --candidate "$candidate" --completion complete --severity none \
      --findings 'No test gaps.' --evidence 'Fixture plan passed.' --limitations none >/dev/null

    for role in pulmu_reviewer pulmu_security_reviewer pulmu_design_reviewer; do
      metadata_for_run review-attempt --role "$role" --candidate "$candidate" >/dev/null
      metadata_for_run review --role "$role" --candidate "$candidate" --completion complete --severity none \
        --findings 'No blocking findings.' --evidence 'Exact candidate inspected.' --limitations none >/dev/null
    done
    if metadata_for_run hone --result pass >/dev/null 2>&1; then exit 1; fi
    role=pulmu_compat_reviewer
    metadata_for_run review-attempt --role "$role" --candidate "$candidate" >/dev/null
    metadata_for_run review --role "$role" --candidate "$candidate" --completion complete --severity low \
      --findings 'Non-blocking compatibility note.' --evidence 'Public fixture contract unchanged.' --limitations none >/dev/null
    metadata_for_run hone --result pass >/dev/null
    [[ "$(cat .git/pulmu-metadata/hone_fingerprint)" == "$candidate" ]] || exit 1
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

ship_terminal_recovery_test() {
  local tmp repo status run_id commit parent before_count recovered_id
  tmp="$(mktemp -d)"; repo="$tmp/repo"; status=0
  mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"
    git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug ship-recovery 'Recover exact partial Ship' >/dev/null
    finalize_metadata feature standard low testing false false false
    printf '\n// partial Ship fixture\n' >> src/task-store.js
    record_reviewed_delivery 'feat(delivery): recover partial Ship' 'Recovers an exact reviewed commit without duplicating it.'
    run_id="$(cat .git/pulmu-metadata/run_id)"
    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage ship --expect-run-id "$run_id" >/dev/null
    git add -- src/task-store.js
    [[ "$(git write-tree)" == "$(cat .git/pulmu-metadata/candidate_tree)" ]] || exit 1
    git commit -m 'feat(delivery): recover partial Ship' >/dev/null
    commit="$(git rev-parse HEAD)"; parent="$(git rev-parse HEAD^)"; before_count="$(git rev-list --count main..HEAD)"
    [[ ! -e .git/pulmu-ship-commit ]] || exit 1
    mv .git/pulmu-metadata/hone_fingerprint .git/pulmu-metadata/hone_fingerprint.saved
    if ship_for_run --delivery local >/dev/null 2>&1; then exit 1; fi
    [[ "$(git rev-parse HEAD)" == "$commit" && "$(git rev-list --count main..HEAD)" == "$before_count" ]] || exit 1
    mv .git/pulmu-metadata/hone_fingerprint.saved .git/pulmu-metadata/hone_fingerprint
    cp .git/pulmu/run.json "$tmp/ship-stage.json"
    python3 - .git/pulmu/run.json <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1]); state = json.loads(path.read_text())
state["stage"] = {"current": "hone", "status": "in_progress"}
path.write_text(json.dumps(state))
PY
    if ship_for_run --delivery local >/dev/null 2>&1; then exit 1; fi
    [[ "$(git rev-parse HEAD)" == "$commit" && "$(git rev-list --count main..HEAD)" == "$before_count" ]] || exit 1
    cp "$tmp/ship-stage.json" .git/pulmu/run.json
    rm -f .git/pulmu-ship-commit
    bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" fail --code SHIP_PUSH_FAILED \
      --message 'simulated external delivery failure' --expect-run-id "$run_id" >/dev/null
    if bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" recover-ship --commit "$parent" --expect-run-id "$run_id" >/dev/null 2>&1; then exit 1; fi
    out="$(ship_for_run --delivery local)"
    grep -Fq "PULMU_COMMIT=$commit" <<<"$out" || exit 1
    [[ "$(git rev-list --count main..HEAD)" == "$before_count" && -f .git/pulmu-ship-commit ]] || exit 1
    python3 - .git/pulmu/run.json ".git/pulmu/runs/$run_id.json" ".git/pulmu/runs/$run_id-recovered.json" <<'PY'
import json, pathlib, sys
current = json.loads(pathlib.Path(sys.argv[1]).read_text())
failed = json.loads(pathlib.Path(sys.argv[2]).read_text())
recovered = json.loads(pathlib.Path(sys.argv[3]).read_text())
assert current["status"] == "completed" and recovered == current
assert failed["status"] == "failed" and failed["error"]["code"] == "SHIP_PUSH_FAILED"
PY
    next="$(bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type test --slug after-recovery 'Start a distinct task after recovery')"
    recovered_id="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$next")"
    [[ "$recovered_id" != "$run_id" && ! -e .git/pulmu-ship-commit ]] || exit 1
    [[ "$(cat .git/pulmu-metadata/task)" == 'Start a distinct task after recovery' ]] || exit 1
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

local_delivery_test() {
  local tmp repo status
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  status=0
  mkdir -p "$repo"
  cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"
    git init -b main >/dev/null
    git config user.name Test
    git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    ignite_out="$(bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug complete-id 'add complete id')"
    grep -q 'PULMU_DELIVERY=local' <<<"$ignite_out" || exit 1
    finalize_metadata feature standard low backend false false false
    if ship_for_run --title 'test: unavailable GitHub delivery' --delivery github >/dev/null 2>&1; then
      exit 1
    fi
    printf '\n// pulmu local change\n' >> src/task-store.js
    if ship_for_run --delivery local >/dev/null 2>&1; then exit 1; fi
    record_reviewed_delivery 'feat: exercise local Pulmu integration' 'Exercises reviewed local delivery with canonical metadata.'
    out="$(ship_for_run --delivery local)"
    grep -q 'PULMU_DELIVERY=local' <<<"$out" || exit 1
    grep -q 'PULMU_COMMIT=' <<<"$out" || exit 1
    ! grep -q 'PULMU_PR_URL=' <<<"$out" || exit 1
    python3 - .git/pulmu/run.json <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["status"] == "completed" and state["stage"] == {"current": "ship", "status": "completed"}
assert state["pr"] is None and state["completedAt"] and state["git"]["commit"]
PY
    [[ -z "$(git status --porcelain)" ]] || exit 1
  ) || status=$?
  rm -rf "$tmp"
  return "$status"
}

github_delivery_test() {
  local tmp bare repo fakebin ancestry_bare ancestry_repo risky_bare risky_repo pattern_bare pattern_repo status real_git
  tmp="$(mktemp -d)"
  bare="$tmp/remote.git"
  repo="$tmp/repo"
  fakebin="$tmp/bin"
  status=0
  mkdir -p "$repo" "$fakebin"
  git init --bare "$bare" >/dev/null
  cp -R "$ROOT/examples/task-store/." "$repo/"
  cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$GH_LOG"
if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then [[ "$*" == *"--hostname github.com"* ]]; exit; fi
if [[ "${1:-}" == "repo" && "${2:-}" == "view" ]]; then
  [[ "${3:-}" == "github.com/example/pulmu-demo" ]] || exit 9
  if [[ "$*" == *defaultBranchRef* ]]; then printf 'main\n'; else printf 'Example/Pulmu-Demo\n'; fi
  exit 0
fi
if [[ "${1:-}" == "label" && "${2:-}" == "list" ]]; then
  [[ "$*" == *"--repo github.com/example/pulmu-demo"* ]] || exit 9
  [[ "${GH_LABEL_FAIL:-0}" == 1 ]] && exit 3
  if [[ "${GH_EMPTY_LABELS:-0}" == 1 ]]; then
    :
  elif [[ "${GH_PATTERN_LABELS:-0}" == 1 ]]; then
    printf '%s\n' pulmu 'type: feature' 'forge: standard' 'risk: low' 'area: frontend' 'area: design'
  else
    printf '%s\n' pulmu 'type: feature' 'forge: full' 'risk: medium' 'area: infra'
  fi
  exit 0
fi
if [[ "${1:-}" == "label" && "${2:-}" == "create" ]]; then [[ "$*" == *"--repo github.com/example/pulmu-demo"* ]] || exit 9; [[ "${GH_LABEL_CREATE_FAIL:-0}" == 1 ]] && exit 5; exit 0; fi
if [[ "${1:-}" == "pr" && "${2:-}" == "list" ]]; then
  [[ "$*" == *"--repo github.com/example/pulmu-demo"* ]] || exit 9
  [[ "$*" == *"--base main"* ]] || exit 4
  case "${GH_PR_MODE:-wrong-base}" in
    existing) printf 'https://github.com/example/pulmu-demo/pull/1\n' ;;
    invalid) printf 'not-a-pull-request-url\n' ;;
    wrong-base) ;;
  esac
  exit 0
fi
if [[ "${1:-}" == "pr" && "${2:-}" == "create" ]]; then
  [[ "$*" == *"--repo github.com/example/pulmu-demo"* ]] || exit 9
  while [[ $# -gt 0 ]]; do if [[ "$1" == "--body-file" ]]; then cp "$2" "$GH_BODY_CAPTURE"; break; fi; shift; done
  printf '%s\n' "${GH_CREATE_OUTPUT:-https://github.com/example/pulmu-demo/pull/1}"; exit 0
fi
if [[ "${1:-}" == "pr" && "${2:-}" == "edit" ]]; then
  [[ "$*" == *"--repo github.com/example/pulmu-demo"* ]] || exit 9
  if [[ "$*" == *"--add-label"* && "${GH_LABEL_APPLY_FAIL:-0}" == 1 ]]; then exit 6; fi
  while [[ $# -gt 0 ]]; do if [[ "$1" == "--body-file" ]]; then cp "$2" "$GH_BODY_CAPTURE"; break; fi; shift; done
  exit 0
fi
printf 'unsupported fake gh args: %s\n' "$*" >&2
exit 2
EOF
  chmod +x "$fakebin/gh"
  real_git="$(command -v git)"
cat > "$fakebin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${PULMU_TEST_INJECT_COMMIT:-0}" == 1 && "${1:-}" == "commit" ]]; then
  "$PULMU_TEST_REAL_GIT" "$@"
  injected_parent="$("$PULMU_TEST_REAL_GIT" rev-parse HEAD)"
  injected_tree="$("$PULMU_TEST_REAL_GIT" rev-parse 'HEAD^{tree}')"
  injected_commit="$(printf 'unreviewed ancestry fixture\n' | "$PULMU_TEST_REAL_GIT" commit-tree "$injected_tree" -p "$injected_parent")"
  "$PULMU_TEST_REAL_GIT" update-ref HEAD "$injected_commit"
  exit 0
fi
if [[ "${1:-}" == "push" && "${2:-}" == "-u" && "${3:-}" == "origin" ]]; then
  exec "$PULMU_TEST_REAL_GIT" push -u "$PULMU_TEST_PUSH_TARGET" "${@:4}"
fi
exec "$PULMU_TEST_REAL_GIT" "$@"
EOF
  chmod +x "$fakebin/git"
  (
    cd "$repo"
    git init -b main >/dev/null
    git config user.name Test
    git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    git push "$bare" main >/dev/null
    git remote add origin https://github.com/example/pulmu-demo.git
    git remote set-head origin main >/dev/null 2>&1 || true
    export GH_LOG="$tmp/gh.log" GH_BODY_CAPTURE="$tmp/body.md"
    export PULMU_TEST_REAL_GIT="$real_git" PULMU_TEST_PUSH_TARGET="$bare"
    : > "$GH_LOG"
    ignite_out="$(PATH="$fakebin:$PATH" bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug delivery-policy 'add complete id')"
    grep -q 'PULMU_DELIVERY=github' <<<"$ignite_out" || exit 1
    finalize_metadata feature full medium infra,testing false false true
    printf '\n// pulmu integration change\n' >> src/task-store.js
    record_reviewed_delivery 'feat(delivery): propagate forge metadata' 'Propagates finalized forge decisions into Git and GitHub delivery.'
    printf 'Repository-specific rollout note.\n' > "$tmp/supplement.md"
    export GH_PR_MODE=wrong-base
    head_before_mismatch="$(git rev-parse HEAD)"
    git remote set-url --push origin "$bare"
    if PATH="$fakebin:$PATH" ship_for_run --body-file "$tmp/supplement.md" --delivery github >/dev/null 2>&1; then exit 1; fi
    [[ "$(git rev-parse HEAD)" == "$head_before_mismatch" && ! -f .git/pulmu-ship-commit ]] || exit 1
    git config --unset-all remote.origin.pushurl
    out="$(PATH="$fakebin:$PATH" ship_for_run --body-file "$tmp/supplement.md" --delivery github)"
    grep -q 'PULMU_DELIVERY=github' <<<"$out" || exit 1
    grep -q 'PULMU_PR_URL=https://github.com/example/pulmu-demo/pull/1' <<<"$out" || exit 1
    python3 - .git/pulmu/run.json <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["status"] == "completed" and state["stage"] == {"current": "ship", "status": "completed"}
assert state["pr"] == {"number": 1, "url": "https://github.com/example/pulmu-demo/pull/1"}
PY
    grep -q 'PULMU_LABELS_APPLIED=5' <<<"$out" || exit 1
    grep -q 'PULMU_LABELS_SKIPPED=area: testing' <<<"$out" || exit 1
    git --git-dir="$bare" show-ref --verify --quiet refs/heads/feat/delivery-policy || exit 1
    grep -Fq '## Pulmu Forge' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq '| 📐 Shape | Pattern skipped |' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq -- '- Forge: Full' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq -- '- Type: Feature' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq -- '- Areas: infra, testing' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq '## Summary' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq '## Changes' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq '## Verification' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq -- '- ✓ npm run test' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq '## Risk' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq 'Medium — Delivery mechanics are exercised with an isolated fixture' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq '## Review Focus' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq 'Repository-specific rollout note.' "$GH_BODY_CAPTURE" || exit 1
    ! grep -Fqi 'visual hierarchy' "$GH_BODY_CAPTURE" || exit 1
    ! grep -q '^label create ' "$GH_LOG" || exit 1
    ! grep -Fq 'area: design' "$GH_LOG" || exit 1
    ! grep -q '^pr create .*--draft' "$GH_LOG" || exit 1
    ! grep -Eq -- '--force|merge|reviewer|assignee' "$GH_LOG" || exit 1
    [[ "$(git rev-list --count main..HEAD)" -eq 1 ]] || exit 1
    export GH_PR_MODE=existing
    resume_out="$(PATH="$fakebin:$PATH" ship_for_run --body-file "$tmp/supplement.md" --delivery github)"
    grep -q 'PULMU_PR_URL=https://github.com/example/pulmu-demo/pull/1' <<<"$resume_out" || exit 1
    [[ "$(git rev-list --count main..HEAD)" -eq 1 && "$(grep -c '^pr create ' "$GH_LOG")" -eq 1 ]] || exit 1
    grep -q '^pr list --repo github.com/example/pulmu-demo --head feat/delivery-policy --base main ' "$GH_LOG" || exit 1
    grep -q '^pr edit https://github.com/example/pulmu-demo/pull/1 --repo github.com/example/pulmu-demo --title .*--body-file ' "$GH_LOG" || exit 1
    export GH_LABEL_APPLY_FAIL=1
    apply_failure_out="$(PATH="$fakebin:$PATH" ship_for_run --delivery github)"
    grep -q 'PULMU_LABELS_UNAPPLIED=pulmu,type: feature,forge: full,risk: medium,area: infra' <<<"$apply_failure_out" || exit 1
    grep -q 'PULMU_PR_URL=https://github.com/example/pulmu-demo/pull/1' <<<"$apply_failure_out" || exit 1
    unset GH_LABEL_APPLY_FAIL
    export GH_LABEL_FAIL=1
    label_failure_out="$(PATH="$fakebin:$PATH" ship_for_run --delivery github)"
    grep -q 'PULMU_LABEL_DISCOVERY=unavailable' <<<"$label_failure_out" || exit 1
    grep -q 'PULMU_LABELS_SKIPPED=pulmu,type: feature,forge: full,risk: medium,area: infra,area: testing' <<<"$label_failure_out" || exit 1
    grep -q 'PULMU_PR_URL=https://github.com/example/pulmu-demo/pull/1' <<<"$label_failure_out" || exit 1
    unset GH_LABEL_FAIL
    label_edit_count="$(grep -Fc -- '--add-label ' "$GH_LOG" || true)"
    export GH_EMPTY_LABELS=1
    empty_label_out="$(PATH="$fakebin:$PATH" ship_for_run --delivery github)"
    grep -q 'PULMU_LABELS_APPLIED=0' <<<"$empty_label_out" || exit 1
    grep -q 'PULMU_LABELS_SKIPPED=pulmu,type: feature,forge: full,risk: medium,area: infra,area: testing' <<<"$empty_label_out" || exit 1
    [[ "$(grep -Fc -- '--add-label ' "$GH_LOG" || true)" == "$label_edit_count" ]] || exit 1
    unset GH_EMPTY_LABELS
    export GH_PR_MODE=invalid
    if PATH="$fakebin:$PATH" ship_for_run --delivery github >/dev/null 2>&1; then exit 1; fi
    [[ "$(git rev-list --count main..HEAD)" -eq 1 && "$(grep -c '^pr create ' "$GH_LOG")" -eq 1 ]] || exit 1
  ) || status=$?
  if [[ "$status" -eq 0 ]]; then
    ancestry_bare="$tmp/ancestry-remote.git"; ancestry_repo="$tmp/ancestry-repo"
    mkdir -p "$ancestry_repo"; git init --bare "$ancestry_bare" >/dev/null; cp -R "$ROOT/examples/task-store/." "$ancestry_repo/"
    (
      cd "$ancestry_repo"
      git init -b main >/dev/null
      git config user.name Test; git config user.email test@example.invalid
      git add . && git commit -m init >/dev/null
      git push "$ancestry_bare" main >/dev/null; git remote add origin https://github.com/example/pulmu-demo.git
      export PULMU_TEST_REAL_GIT="$real_git" PULMU_TEST_PUSH_TARGET="$ancestry_bare"
      export PULMU_TEST_INJECT_COMMIT=1 GH_LOG="$tmp/ancestry-gh.log" GH_BODY_CAPTURE="$tmp/ancestry-body.md"
      : > "$GH_LOG"
      PATH="$fakebin:$PATH" bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug ancestry-guard 'Reject unreviewed commit ancestry' >/dev/null
      finalize_metadata feature standard low delivery false false false
      printf '\n// ancestry guard fixture\n' >> src/task-store.js
      record_reviewed_delivery 'feat(delivery): guard commit ancestry' 'Rejects a hook-created commit before external delivery.'
      if PATH="$fakebin:$PATH" ship_for_run --delivery github >/dev/null 2>&1; then exit 1; fi
      if git --git-dir="$ancestry_bare" show-ref --verify --quiet refs/heads/feat/ancestry-guard; then exit 1; fi
      [[ ! -s "$GH_LOG" || "$(grep -c '^pr ' "$GH_LOG" || true)" -eq 0 ]] || exit 1
    ) || status=$?
  fi
  if [[ "$status" -eq 0 ]]; then
    risky_bare="$tmp/risky-remote.git"; risky_repo="$tmp/risky-repo"
    mkdir -p "$risky_repo"; git init --bare "$risky_bare" >/dev/null; cp -R "$ROOT/examples/task-store/." "$risky_repo/"
    (
      cd "$risky_repo"
      git init -b main >/dev/null
      git config user.name Test; git config user.email test@example.invalid
      mkdir -p .pulmu
      printf '[github]\ncreate_missing_labels = true\n' > .pulmu/config.toml
      git add . && git commit -m init >/dev/null
      git push "$risky_bare" main >/dev/null; git remote add origin https://github.com/example/pulmu-demo.git
      export PULMU_TEST_REAL_GIT="$real_git" PULMU_TEST_PUSH_TARGET="$risky_bare"
      export GH_LOG="$tmp/risky-gh.log" GH_BODY_CAPTURE="$tmp/risky-body.md"
      : > "$GH_LOG"
      export GH_PR_MODE=wrong-base
      PATH="$fakebin:$PATH" bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug risky-delivery 'Add risky delivery' >/dev/null
      finalize_metadata feature full high infra false false true
      printf '\n// high-risk integration change\n' >> src/task-store.js
      record_reviewed_delivery 'feat(delivery): exercise high-risk draft policy' 'Exercises the configured high-risk Full Forge draft boundary.'
      export GH_CREATE_OUTPUT=not-a-pull-request-url
      if PATH="$fakebin:$PATH" ship_for_run --delivery github >/dev/null 2>&1; then exit 1; fi
      unset GH_CREATE_OUTPUT
      export GH_PR_MODE=existing
      export GH_LABEL_CREATE_FAIL=1
      create_failure_out="$(PATH="$fakebin:$PATH" ship_for_run --delivery github)"
      grep -q 'PULMU_LABELS_SKIPPED=risk: high' <<<"$create_failure_out" || exit 1
      grep -q 'PULMU_PR_URL=https://github.com/example/pulmu-demo/pull/1' <<<"$create_failure_out" || exit 1
      unset GH_LABEL_CREATE_FAIL
      grep -q '^pr create .*--draft' "$GH_LOG" || exit 1
      grep -q '^label create risk: high --repo github.com/example/pulmu-demo ' "$GH_LOG" || exit 1
      [[ "$(grep -c '^pr create ' "$GH_LOG")" -eq 1 && "$(git rev-list --count main..HEAD)" -eq 1 ]] || exit 1
    ) || status=$?
  fi
  if [[ "$status" -eq 0 ]]; then
    pattern_bare="$tmp/pattern-remote.git"; pattern_repo="$tmp/pattern-repo"
    mkdir -p "$pattern_repo"; git init --bare "$pattern_bare" >/dev/null; cp -R "$ROOT/examples/task-store/." "$pattern_repo/"
    (
      cd "$pattern_repo"
      git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
      git add . && git commit -m init >/dev/null
      git push "$pattern_bare" main >/dev/null; git remote add origin https://github.com/example/pulmu-demo.git
      export PULMU_TEST_REAL_GIT="$real_git" PULMU_TEST_PUSH_TARGET="$pattern_bare"
      export GH_LOG="$tmp/pattern-gh.log" GH_BODY_CAPTURE="$tmp/pattern-body.md" GH_PR_MODE=wrong-base GH_PATTERN_LABELS=1
      : > "$GH_LOG"
      PATH="$fakebin:$PATH" bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug responsive-search 'Add responsive search' >/dev/null
      finalize_metadata feature standard low testing true false false
      printf '\n// Pattern integration change\n' >> src/task-store.js
      quench_for_run >/dev/null
      run_id="$(cat .git/pulmu-metadata/run_id)"
      bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" set-stage hone --expect-run-id "$run_id" >/dev/null
      record_review_results
      metadata_for_run hone --result pass >/dev/null
      metadata_for_run delivery \
        --title 'feat(search): add responsive search behavior' \
        --summary 'Adds a responsive search experience with accessible interaction states.' \
        --change 'Adds the Pattern delivery fixture' \
        --review-focus 'visual hierarchy and responsive behavior' \
        --review-focus 'interaction states and accessibility' >/dev/null
      pattern_out="$(PATH="$fakebin:$PATH" ship_for_run --delivery github)"
      grep -q 'PULMU_LABELS_APPLIED=6' <<<"$pattern_out" || exit 1
      grep -Fq '| 📐 Shape | Pattern used |' "$GH_BODY_CAPTURE" || exit 1
      grep -Fq -- '- visual hierarchy and responsive behavior' "$GH_BODY_CAPTURE" || exit 1
      grep -Fq -- '- Areas: frontend, design, testing' "$GH_BODY_CAPTURE" || exit 1
      grep -Fq -- '--add-label area: frontend' "$GH_LOG" || exit 1
      grep -Fq -- '--add-label area: design' "$GH_LOG" || exit 1
    ) || status=$?
  fi
  rm -rf "$tmp"
  return "$status"
}

run_context_test() {
  local tmp repo scripts status run_id second_id third_id stale_output
  tmp="$(mktemp -d)"; repo="$tmp/repo"; scripts="$ROOT/.agents/skills/pulmu/scripts"; status=0
  mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"
    git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null

    ignite_out="$(bash "$scripts/ignite.sh" --type feature --slug persistent-state \
      'Add persistent state token=should-never-persist')"
    run_id="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$ignite_out")"
    [[ "$run_id" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{12}$ ]] || exit 1
    run_mode="$(python3 -c 'import os, sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777)[2:])' .git/pulmu/run.json)"
    [[ -f .git/pulmu/run.json && "$run_mode" == 600 ]] || exit 1
    python3 - .git/pulmu/run.json "$run_id" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["schemaVersion"] == 2 and state["workflow"] == "pulmu"
assert state["runId"] == sys.argv[2] and state["status"] == "running"
assert state["stage"] == {"current": "ignite", "status": "in_progress"}
assert state["git"]["baseBranch"] == "main"
assert state["git"]["branch"] == "feat/persistent-state"
assert "should-never-persist" not in state["task"]["prompt"]
assert state["forge"] is None and state["risk"] is None and state["areas"] == []
assert state["execution"] is None
assert state["completedAt"] is None and state["interruptedAt"] is None
PY
    cp .git/pulmu/run.json "$tmp/semantic-valid.json"
    for variant in running_stage failed_timestamp failed_error interrupted_timestamp completed_error; do
      cp "$tmp/semantic-valid.json" .git/pulmu/run.json
      python3 - .git/pulmu/run.json "$variant" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1]); state = json.loads(path.read_text()); variant = sys.argv[2]
if variant == "running_stage":
    state["stage"]["status"] = "completed"
elif variant == "failed_timestamp":
    state["status"] = "failed"; state["stage"]["status"] = "failed"
    state["error"] = {"code": "TEST_FAILED", "message": "semantic fixture"}
    state["completedAt"] = state["updatedAt"]
elif variant == "failed_error":
    state["status"] = "failed"; state["stage"]["status"] = "failed"
elif variant == "interrupted_timestamp":
    state["status"] = "interrupted"; state["stage"]["status"] = "interrupted"
elif variant == "completed_error":
    state["status"] = "completed"; state["stage"] = {"current": "ship", "status": "completed"}
    state["completedAt"] = state["updatedAt"]; state["git"]["commit"] = "aabbccd"
    state["error"] = {"code": "CONTRADICTORY", "message": "must fail"}
path.write_text(json.dumps(state))
PY
      if bash "$scripts/run-context.sh" show >/dev/null 2>&1; then exit 1; fi
    done
    cp "$tmp/semantic-valid.json" .git/pulmu/run.json
    [[ -z "$(git status --porcelain)" ]] || exit 1
    ! git ls-files --error-unmatch .git/pulmu/run.json >/dev/null 2>&1 || exit 1

    before="$(python3 -c 'import json; print(json.load(open(".git/pulmu/run.json"))["updatedAt"])')"
    bash "$scripts/run-context.sh" set-stage inspect --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" set-agents pulmu_explorer pulmu_test_scout --expect-run-id "$run_id" >/dev/null
    python3 - .git/pulmu/run.json "$before" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["stage"]["current"] == "inspect"
assert state["agents"]["active"] == ["pulmu_explorer", "pulmu_test_scout"]
assert state["updatedAt"] > sys.argv[2]
PY
    bash "$scripts/run-context.sh" set-agents --expect-run-id "$run_id" >/dev/null
    if bash "$scripts/run-context.sh" set-stage shape --expect-run-id '20000101T000000Z-000000000000' >/dev/null 2>&1; then exit 1; fi
    [[ "$(python3 -c 'import json; print(json.load(open(".git/pulmu/run.json"))["stage"]["current"])')" == inspect ]] || exit 1
    bash "$scripts/run-context.sh" set-stage shape --expect-run-id "$run_id" >/dev/null
    finalize_metadata feature full medium infra,testing false false true
    python3 - .git/pulmu/run.json <<'PY'
import json, pathlib
state = json.loads(pathlib.Path('.git/pulmu/run.json').read_text())
assert state["task"]["type"] == "feature"
assert state["forge"] == "full" and state["risk"] == "medium"
assert state["areas"] == ["infra", "testing"] and state["pattern"] is False
PY
    if bash "$scripts/run-context.sh" set-stage quench --expect-run-id "$run_id" >/dev/null 2>&1; then exit 1; fi
    bash "$scripts/run-context.sh" set-stage hammer --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" set-agents pulmu_smith --expect-run-id "$run_id" >/dev/null
    printf '\n// bounded retry fixture\n' >> src/task-store.js
    printf '\nCandidate scope fixture.\n' >> README.md
    bash "$scripts/run-context.sh" set-stage quench --expect-run-id "$run_id" >/dev/null
    root_tree="$(bash -c 'source "$1/common.sh"; pulmu_candidate_tree' _ "$scripts")"
    subdir_tree="$(cd src && bash -c 'source "$1/common.sh"; pulmu_candidate_tree' _ "$scripts")"
    [[ "$subdir_tree" == "$root_tree" ]] || exit 1
    printf 'subdirectory candidate publication\n' > "$tmp/subdir-quench.log"
    bash "$scripts/run-context.sh" quench-evidence begin --attempt subdir-scope --expect-run-id "$run_id" >/dev/null
    (
      cd src
      bash "$scripts/run-context.sh" quench-evidence pass \
        --branch feat/persistent-state --base main --base-head "$(git rev-parse main)" \
        --head "$(git rev-parse HEAD)" --tree "$root_tree" --fingerprint aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
        --log "$tmp/subdir-quench.log" --attempt subdir-scope --expect-run-id "$run_id" >/dev/null
    )
    for expected_retry in 1 2 3; do
      bash "$scripts/run-context.sh" increment-retry quench --expect-run-id "$run_id" >/dev/null
      [[ "$(python3 -c 'import json; print(json.load(open(".git/pulmu/run.json"))["retries"]["quench"])')" -eq "$expected_retry" ]] || exit 1
      bash "$scripts/run-context.sh" set-stage quench --expect-run-id "$run_id" >/dev/null
    done
    if bash "$scripts/run-context.sh" increment-retry quench --expect-run-id "$run_id" >/dev/null 2>&1; then exit 1; fi
    bash "$scripts/quench.sh" --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" set-stage hone --expect-run-id "$run_id" >/dev/null
    for expected_retry in 1 2; do
      bash "$scripts/run-context.sh" increment-retry hone --expect-run-id "$run_id" >/dev/null
      [[ ! -e .git/pulmu-metadata/quench_fingerprint ]] || exit 1
      bash "$scripts/run-context.sh" set-stage quench --expect-run-id "$run_id" >/dev/null
      if bash "$scripts/run-context.sh" set-stage hone --expect-run-id "$run_id" >/dev/null 2>&1; then exit 1; fi
      bash "$scripts/quench.sh" --expect-run-id "$run_id" >/dev/null
      bash "$scripts/run-context.sh" set-stage hone --expect-run-id "$run_id" >/dev/null
    done
    if bash "$scripts/run-context.sh" increment-retry hone --expect-run-id "$run_id" >/dev/null 2>&1; then exit 1; fi
    bash "$scripts/run-context.sh" set-agents --expect-run-id "$run_id" >/dev/null
    record_review_results
    metadata_for_run hone --result pass >/dev/null
    metadata_for_run delivery --title 'feat(state): enforce bounded lifecycle' \
      --summary 'Exercises deterministic stage admission and retry limits.' \
      --change 'Adds a bounded lifecycle fixture' >/dev/null
    python3 - .git/pulmu/run.json "$run_id" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["runId"] == sys.argv[2]
assert state["retries"] == {"quench": 3, "hone": 2}
assert state["stage"]["current"] == "hone"
PY
    if bash "$scripts/run-context.sh" complete --delivery local --commit "$(git rev-parse HEAD)" --expect-run-id "$run_id" >/dev/null 2>&1; then exit 1; fi
    ship_for_run --delivery local >/dev/null
    python3 - .git/pulmu/run.json "$run_id" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["runId"] == sys.argv[2] and state["status"] == "completed"
assert state["stage"] == {"current": "ship", "status": "completed"}
assert state["pr"] is None and state["completedAt"] and state["git"]["commit"]
assert state["interruptedAt"] is None and state["error"] is None
PY
    [[ -f ".git/pulmu/runs/$run_id.json" ]] || exit 1

    # A new init gets a new ID; another init cannot replace a live run.
    bash "$scripts/run-context.sh" init --task-type feature --task 'second run' --base main --branch feat/second > "$tmp/second.out"
    second_id="$(sed -n 's/^PULMU_RUN_ID=//p' "$tmp/second.out")"
    [[ "$second_id" != "$run_id" ]] || exit 1
    if bash "$scripts/run-context.sh" init --task-type feature --task 'third run' --base main --branch feat/third >/dev/null 2>"$tmp/third.err"; then exit 1; fi
    grep -Fq "Pulmu run $second_id is still running" "$tmp/third.err" || exit 1
    printf 'dirty fixture\n' > dirty.tmp
    dirty_output="$(bash "$scripts/ignite.sh" --type feature --slug blocked 'blocked by dirty tree' 2>&1 || true)"
    grep -Fq '⚠ Previous Pulmu run detected:' <<<"$dirty_output" || exit 1
    grep -Fq "${second_id}" <<<"$dirty_output" || exit 1
    grep -Fq 'at ignite on feat/second' <<<"$dirty_output" || exit 1
    grep -Fq '⚠ Existing run left unchanged because liveness cannot be determined safely' <<<"$dirty_output" || exit 1
    grep -Fq 'working tree is not clean' <<<"$dirty_output" || exit 1
    python3 - .git/pulmu/run.json "$second_id" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["runId"] == sys.argv[2] and state["status"] == "running"
assert state["stage"] == {"current": "ignite", "status": "in_progress"}
assert state["agents"]["active"] == []
assert not pathlib.Path(sys.argv[1]).with_name("runs").joinpath(sys.argv[2] + ".json").exists()
PY
    rm dirty.tmp

    # Normal mutation fails closed on corruption; init quarantines and recovers.
    printf '{broken json\n' > .git/pulmu/run.json
    if bash "$scripts/run-context.sh" set-stage inspect >/dev/null 2>&1; then exit 1; fi
    malformed="$(bash "$scripts/run-context.sh" detect 2>/dev/null || true)"
    grep -Fq 'PULMU_RUN_DETECTED=malformed' <<<"$malformed" || exit 1
    bash "$scripts/run-context.sh" init --task-type bugfix --task 'recover malformed state' \
      --base main --branch fix/recovery > "$tmp/recovered.out" 2> "$tmp/recovered.err"
    grep -Fq '⚠ Malformed Pulmu run quarantined:' "$tmp/recovered.err" || exit 1
    find .git/pulmu/runs -maxdepth 1 -name 'corrupt-*.json' -type f | grep -q . || exit 1

    # Failures are concise, terminal, archived, and redact credentials.
    recovered_id="$(sed -n 's/^PULMU_RUN_ID=//p' "$tmp/recovered.out")"
    bash "$scripts/run-context.sh" fail --code IGNITE_FAILED \
      --message 'Tests failed bearer abcdefghijklmnop and token=more-secret-data' \
      --expect-run-id "$recovered_id" >/dev/null
    python3 - .git/pulmu/run.json "$recovered_id" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
raw = pathlib.Path(sys.argv[1]).read_text()
assert state["status"] == "failed" and state["stage"] == {"current": "ignite", "status": "failed"}
assert state["error"]["code"] == "IGNITE_FAILED"
assert state["completedAt"] is None and state["interruptedAt"] is None
assert "abcdefghijklmnop" not in raw and "more-secret-data" not in raw
assert pathlib.Path(sys.argv[1]).with_name("runs").joinpath(sys.argv[2] + ".json").exists()
PY
    mv .git/pulmu/run.json .git/pulmu/safe-run.json
    ln -s safe-run.json .git/pulmu/run.json
    if bash "$scripts/run-context.sh" show >/dev/null 2>&1; then exit 1; fi
    rm .git/pulmu/run.json
    mv .git/pulmu/safe-run.json .git/pulmu/run.json
    bash "$scripts/pulmu-status.sh" | grep -Fq 'Status   failed' || exit 1
    [[ -z "$(git status --porcelain)" ]] || exit 1
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

legacy_run_context_migration_test() {
  local tmp repo scripts status
  tmp="$(mktemp -d)"; repo="$tmp/repo"; scripts="$ROOT/.agents/skills/pulmu/scripts"; status=0
  mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"; git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    git switch -c pulmu/feat/legacy-state >/dev/null
    printf 'main\n' > .git/pulmu-base
    printf 'pulmu/feat/legacy-state\n' > .git/pulmu-branch
    printf 'Migrate legacy Pulmu state\n' > .git/pulmu-task
    [[ ! -e .git/pulmu/run.json && ! -e .git/pulmu-metadata/status ]] || exit 1
    out="$(bash "$scripts/metadata.sh" finalize --type feature --forge standard --risk low \
      --areas infra --pattern false --security-review false --compatibility-review true)"
    run_id="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$out")"
    [[ -n "$run_id" && "$(cat .git/pulmu-metadata/run_id)" == "$run_id" ]] || exit 1
    python3 - .git/pulmu/run.json "$run_id" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["runId"] == sys.argv[2] and state["status"] == "running"
assert state["task"] == {"prompt": "Migrate legacy Pulmu state", "type": "feature"}
assert state["git"]["baseBranch"] == "main" and state["git"]["branch"] == "pulmu/feat/legacy-state"
assert state["forge"] == "standard" and state["areas"] == ["infra"]
PY
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

legacy_terminal_context_test() {
  local tmp repo scripts status old_id before after
  tmp="$(mktemp -d)"; repo="$tmp/repo"; scripts="$ROOT/.agents/skills/pulmu/scripts"; status=0
  mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"; git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    ignite="$(bash "$scripts/ignite.sh" --type feature --slug legacy-terminal 'Migrate terminal legacy state')"
    old_id="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$ignite")"
    finalize_metadata feature standard low infra false false true
    printf '\n// terminal fixture\n' >> src/task-store.js
    record_reviewed_delivery 'feat(state): preserve terminal provenance' 'Preserves terminal run identity during legacy handling.'
    ship_for_run --delivery local >/dev/null
    before="$(git hash-object .git/pulmu/run.json)"
    rm .git/pulmu-metadata/run_id
    if bash "$scripts/metadata.sh" finalize --type feature --forge standard --risk low \
      --areas infra --pattern false --security-review false --compatibility-review true >/dev/null 2>&1; then exit 1; fi
    after="$(git hash-object .git/pulmu/run.json)"
    [[ "$before" == "$after" && ! -e .git/pulmu-metadata/run_id ]] || exit 1
    [[ -f ".git/pulmu/runs/$old_id.json" ]] || exit 1
    python3 - .git/pulmu/run.json "$old_id" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["runId"] == sys.argv[2] and state["status"] == "completed"
assert state["stage"] == {"current": "ship", "status": "completed"}
assert state["task"] == {"prompt": "Migrate terminal legacy state", "type": "feature"}
assert state["git"]["baseBranch"] == "main" and state["git"]["branch"] == "feat/legacy-terminal"
assert state["forge"] == "standard" and state["risk"] == "low" and state["areas"] == ["infra"]
assert state["git"]["commit"] and state["pr"] is None and state["error"] is None
PY
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

stale_run_guard_test() {
  local tmp repo scripts status run_a run_b before after head_before
  tmp="$(mktemp -d)"; repo="$tmp/repo"; scripts="$ROOT/.agents/skills/pulmu/scripts"; status=0
  mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"; git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    ignite="$(bash "$scripts/ignite.sh" --type feature --slug stale-guard 'Guard stale processes')"
    run_a="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$ignite")"
    finalize_metadata feature standard medium infra false false true
    printf '\n// stale guard fixture\n' >> src/task-store.js
    record_reviewed_delivery 'feat(state): guard stale run delivery' 'Rejects delayed operations from an older Pulmu run.'
    head_before="$(git rev-parse HEAD)"
    bash "$scripts/run-context.sh" interrupt --message 'replace run A with run B' --expect-run-id "$run_a" >/dev/null
    second="$(bash "$scripts/run-context.sh" init --task-type feature --task 'new run B' \
      --base main --branch feat/stale-guard 2>/dev/null)"
    run_b="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$second")"
    [[ "$run_a" != "$run_b" ]] || exit 1
    stale_quench_fingerprint="$(cat .git/pulmu-metadata/quench_fingerprint)"
    stale_quench_log="$(git hash-object .git/pulmu-quench.log)"
    if bash "$scripts/quench.sh" --expect-run-id "$run_a" >/dev/null 2>&1; then exit 1; fi
    [[ "$(cat .git/pulmu-metadata/quench_fingerprint)" == "$stale_quench_fingerprint" ]] || exit 1
    [[ "$(git hash-object .git/pulmu-quench.log)" == "$stale_quench_log" ]] || exit 1
    before="$(git hash-object .git/pulmu/run.json)"
    if bash "$scripts/metadata.sh" finalize --type feature --forge standard --risk medium \
      --areas infra --pattern false --security-review false --compatibility-review true \
      --expect-run-id "$run_a" >/dev/null 2>&1; then exit 1; fi
    if bash "$scripts/ship.sh" --delivery local --expect-run-id "$run_a" >/dev/null 2>&1; then exit 1; fi
    after="$(git hash-object .git/pulmu/run.json)"
    [[ "$before" == "$after" && "$(git rev-parse HEAD)" == "$head_before" ]] || exit 1
    python3 - .git/pulmu/run.json "$run_b" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["runId"] == sys.argv[2] and state["status"] == "running"
assert state["stage"] == {"current": "ignite", "status": "in_progress"}
PY
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

python_preflight_test() {
  local tmp repo fakebin scripts status
  tmp="$(mktemp -d)"; repo="$tmp/repo"; fakebin="$tmp/bin"; scripts="$ROOT/.agents/skills/pulmu/scripts"; status=0
  mkdir -p "$repo" "$fakebin"; cp -R "$ROOT/examples/task-store/." "$repo/"
  printf '#!/usr/bin/env bash\nexit 127\n' > "$fakebin/python3"; chmod +x "$fakebin/python3"
  (
    cd "$repo"; git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    if PATH="$fakebin:$PATH" bash "$scripts/ignite.sh" 'Python preflight' > "$tmp/out" 2>&1; then exit 1; fi
    grep -Fq 'Python 3.10+ is required for Pulmu Run Context' "$tmp/out" || exit 1
    [[ "$(git branch --show-current)" == main && ! -e .git/pulmu/run.json ]] || exit 1
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

adaptive_execution_policy_test() {
  local tmp scripts status
  tmp="$(mktemp -d)"; scripts="$ROOT/.agents/skills/pulmu/scripts"; status=0
  (
    repo="$tmp/direct"; mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"; cd "$repo"
    git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    bash "$scripts/ignite.sh" --type bugfix --slug direct-policy 'Exercise direct adaptive execution' >/dev/null
    finalize_metadata bugfix quick low testing false false false direct orchestrator self false
    python3 - .git/pulmu/run.json <<'PY'
import json, pathlib
state = json.loads(pathlib.Path('.git/pulmu/run.json').read_text())
assert state['schemaVersion'] == 2
assert state['execution'] == {
    'mode': 'direct', 'writer': 'orchestrator', 'review': 'self',
    'testReview': False, 'securityReview': False, 'compatibilityReview': False,
}
PY
    run_id="$(cat .git/pulmu-metadata/run_id)"
    bash "$scripts/run-context.sh" set-stage hammer --expect-run-id "$run_id" >/dev/null
    if bash "$scripts/run-context.sh" set-agents pulmu_smith --expect-run-id "$run_id" >/dev/null 2>&1; then exit 1; fi
    printf '\n// direct fixture\n' >> src/task-store.js
    quench_for_run >/dev/null
    bash "$scripts/run-context.sh" set-stage hone --expect-run-id "$run_id" >/dev/null
    candidate="$(cat .git/pulmu-metadata/quench_fingerprint)"
    if metadata_for_run review-attempt --role pulmu_reviewer --candidate "$candidate" >/dev/null 2>&1; then exit 1; fi
    metadata_for_run review-attempt --role pulmu_self_review --candidate "$candidate" >/dev/null
    metadata_for_run review --role pulmu_self_review --candidate "$candidate" --completion complete --severity none \
      --findings 'Direct self-review found no blocking issue.' --evidence 'Exact candidate and passing check inspected.' --limitations 'Not independent.' >/dev/null
    metadata_for_run hone --result pass >/dev/null
    metadata_for_run delivery --title 'fix: verify direct adaptive execution' \
      --summary 'Exercises a low-risk direct run with explicit self-review.' \
      --change 'Adds the direct execution fixture' >/dev/null
    out="$(ship_for_run --delivery local)"
    grep -Fq 'PULMU_EXECUTION=direct' <<<"$out" || exit 1
    grep -Fq 'PULMU_WRITER=orchestrator' <<<"$out" || exit 1
    grep -Fq 'PULMU_REVIEW=self' <<<"$out" || exit 1
    python3 -c 'import json; state=json.load(open(".git/pulmu/run.json")); assert state["status"] == "completed" and state["git"]["commit"]'

    for scenario in medium_self full_self reviewed_smith direct_test delegated_self; do
      repo="$tmp/$scenario"; mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"; cd "$repo"
      git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
      git add . && git commit -m init >/dev/null
      slug="${scenario//_/-}"
      bash "$scripts/ignite.sh" --type feature --slug "$slug" "Reject $scenario policy" >/dev/null
      run_id="$(cat .git/pulmu-metadata/run_id)"
      bash "$scripts/run-context.sh" set-stage inspect --expect-run-id "$run_id" >/dev/null
      bash "$scripts/run-context.sh" set-stage shape --expect-run-id "$run_id" >/dev/null
      args=(--type feature --forge quick --risk low --areas backend --pattern false --security-review false --compatibility-review false)
      case "$scenario" in
        medium_self) args+=(--risk medium --execution direct --writer orchestrator --review-mode self --test-review false) ;;
        full_self) args+=(--forge full --execution direct --writer orchestrator --review-mode self --test-review false) ;;
        reviewed_smith) args+=(--execution reviewed --writer pulmu_smith --review-mode independent --test-review false) ;;
        direct_test) args+=(--execution direct --writer orchestrator --review-mode self --test-review true) ;;
        delegated_self) args+=(--execution delegated --writer orchestrator --review-mode self --test-review false) ;;
      esac
      if bash "$scripts/metadata.sh" finalize "${args[@]}" --expect-run-id "$run_id" >/dev/null 2>&1; then exit 1; fi
      python3 -c 'import json; state=json.load(open(".git/pulmu/run.json")); assert state["execution"] is None and state["stage"]["current"] == "shape"'
      [[ "$(cat .git/pulmu-metadata/status)" == provisional ]] || exit 1
    done
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

replan_policy_test() {
  local tmp repo scripts status run_id
  tmp="$(mktemp -d)"; repo="$tmp/repo"; scripts="$ROOT/.agents/skills/pulmu/scripts"; status=0
  mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"; git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    bash "$scripts/ignite.sh" --type feature --slug replan-policy 'Preserve work during adaptive replan' >/dev/null
    finalize_metadata feature standard low backend false false false reviewed orchestrator independent true
    run_id="$(cat .git/pulmu-metadata/run_id)"
    printf '\n// preserved replan fixture\n' >> src/task-store.js
    quench_for_run >/dev/null
    bash "$scripts/run-context.sh" increment-retry quench --expect-run-id "$run_id" >/dev/null
    quench_for_run >/dev/null
    bash "$scripts/run-context.sh" set-stage hone --expect-run-id "$run_id" >/dev/null
    record_review_results
    metadata_for_run hone --result pass >/dev/null
    [[ -f .git/pulmu-metadata/hone_fingerprint && -f .git/pulmu-reviews/pulmu_reviewer.json ]] || exit 1
    bash "$scripts/run-context.sh" replan --reason 'A public compatibility constraint was discovered' --expect-run-id "$run_id" >/dev/null
    grep -Fq 'preserved replan fixture' src/task-store.js || exit 1
    python3 - .git/pulmu/run.json "$run_id" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state['runId'] == sys.argv[2] and state['stage'] == {'current': 'shape', 'status': 'in_progress'}
assert state['forge'] is None and state['risk'] is None and state['execution'] is None
assert state['retries'] == {'quench': 1, 'hone': 0} and state['agents']['active'] == []
PY
    [[ "$(cat .git/pulmu-metadata/status)" == provisional ]] || exit 1
    [[ ! -e .git/pulmu-metadata/verification-plan && ! -e .git/pulmu-metadata/quench_fingerprint && ! -e .git/pulmu-metadata/hone_fingerprint ]] || exit 1
    if find .git/pulmu-reviews -type f -print -quit 2>/dev/null | grep -q .; then exit 1; fi
    if bash "$scripts/run-context.sh" set-stage hammer --expect-run-id "$run_id" >/dev/null 2>&1; then exit 1; fi
    finalize_metadata feature full high backend false false true delegated pulmu_smith independent true
    [[ "$(cat .git/pulmu-metadata/compatibility_review)" == true ]] || exit 1
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

schema_v1_execution_migration_test() {
  local tmp repo scripts status run_id
  tmp="$(mktemp -d)"; repo="$tmp/repo"; scripts="$ROOT/.agents/skills/pulmu/scripts"; status=0
  mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"; git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    bash "$scripts/ignite.sh" --type feature --slug v1-migration 'Migrate strict v1 execution policy' >/dev/null
    run_id="$(cat .git/pulmu-metadata/run_id)"
    finalize_metadata feature standard low backend false false true
    python3 - .git/pulmu/run.json <<'PY'
import json, pathlib
path = pathlib.Path('.git/pulmu/run.json'); state = json.loads(path.read_text())
state['schemaVersion'] = 1; state.pop('execution'); path.write_text(json.dumps(state))
PY
    rm .git/pulmu-metadata/execution_mode .git/pulmu-metadata/writer .git/pulmu-metadata/review_mode .git/pulmu-metadata/test_review
    bash "$scripts/run-context.sh" set-stage hammer --expect-run-id "$run_id" >/dev/null
    python3 - <<'PY'
import json
state=json.load(open('.git/pulmu/run.json'))
assert state['schemaVersion'] == 2
assert state['execution'] == {
    'mode': 'delegated', 'writer': 'pulmu_smith', 'review': 'independent',
    'testReview': True, 'securityReview': False, 'compatibilityReview': True,
}
PY
    printf '\n// migrated v1 fixture\n' >> src/task-store.js
    quench_for_run >/dev/null
    bash "$scripts/run-context.sh" set-stage hone --expect-run-id "$run_id" >/dev/null
    record_review_results
    metadata_for_run hone --result pass >/dev/null
    [[ -f .git/pulmu-reviews/pulmu_reviewer.json && -f .git/pulmu-reviews/pulmu_test_reviewer.json && -f .git/pulmu-reviews/pulmu_compat_reviewer.json ]] || exit 1
    python3 - .git/pulmu/run.json <<'PY'
import json, pathlib
path = pathlib.Path('.git/pulmu/run.json'); state = json.loads(path.read_text())
state['schemaVersion'] = 1; state['unexpected'] = True; state.pop('execution'); path.write_text(json.dumps(state))
PY
    if bash "$scripts/run-context.sh" show >/dev/null 2>&1; then exit 1; fi
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

run_context_worktree_test() {
  local tmp repo linked scripts status
  tmp="$(mktemp -d)"; repo="$tmp/repo"; linked="$tmp/linked"; scripts="$ROOT/.agents/skills/pulmu/scripts"; status=0
  mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"; git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null; git branch linked
    git worktree add "$linked" linked >/dev/null
    cd "$linked"
    bash "$scripts/run-context.sh" init --task-type test --task 'linked worktree state' --base main --branch linked >/dev/null
    resolved="$(git rev-parse --path-format=absolute --git-dir)"
    [[ -f "$resolved/pulmu/run.json" && ! -e "$repo/.git/pulmu/run.json" ]] || exit 1
    [[ -z "$(git status --porcelain)" ]] || exit 1
  ) || status=$?
  rm -rf "$tmp"; return "$status"
}

run_test 'shell scripts parse' syntax_test
run_test 'GitHub CI covers Linux and macOS Bash' github_repository_contract_test
run_test 'landing page preserves adoption and repository contracts' landing_page_contract_test
run_test 'demo baseline tests pass' example_test
run_test 'Quench discovers and runs npm test' quench_test
run_test 'Quench propagates a failed verification command' quench_failure_test
run_test 'Quench distinguishes shell and Python test discovery' quench_discovery_test
run_test 'Quench requires and consumes a bounded verification plan' quench_plan_gate_test
run_test 'stale Quench cannot publish over a successor attempt' quench_stale_publication_test
run_test 'installer lays out skill and agents' installer_test
run_test 'uninstaller removes skill and all Pulmu agents' uninstaller_test
run_test 'project-local install and removal preserve unrelated configuration' local_installation_test
run_test 'demo repository packages all Pulmu agents' demo_packaging_test
run_test 'agent TOMLs preserve routing and single-writer contracts' agent_contract_test
run_test 'skill preserves seven stages with conditional Pattern' skill_contract_test
run_test 'all task types map to branch, commit, and label dimensions' task_mapping_test
run_test 'base selection covers convention, remote default, main, and develop' base_selection_paths_test
run_test 'metadata finalization propagates Pattern and remains immutable' metadata_policy_test
run_test 'config rejects unsafe policy and branch collisions are deterministic' config_and_collision_test
run_test 'Ship rejects missing, stale, and mutated verification evidence' ship_evidence_gate_test
run_test 'Hone requires exact bounded reviewer receipts' review_receipt_gate_test
run_test 'Ship recovers only the exact same-run reviewed commit' ship_terminal_recovery_test
run_test 'local Git repository completes without GitHub' local_delivery_test
run_test 'GitHub delivery propagates metadata, body, and existing labels' github_delivery_test
run_test 'Run Context covers lifecycle, retries, safety, concurrency, and observability' run_context_test
run_test 'Run Context resolves linked-worktree Git metadata safely' run_context_worktree_test
run_test 'legacy active branches bootstrap Run Context before metadata finalization' legacy_run_context_migration_test
run_test 'legacy metadata cannot replace a terminal Run Context' legacy_terminal_context_test
run_test 'stale metadata and Ship processes cannot mutate a newer run' stale_run_guard_test
run_test 'Ignite reports the Python Run Context runtime requirement clearly' python_preflight_test
run_test 'branch names use optional namespaces and recorded provenance' branch_naming_policy_test
run_test 'adaptive execution binds writer and review assurance' adaptive_execution_policy_test
run_test 'explicit replan preserves work and invalidates stale evidence' replan_policy_test
run_test 'schema v1 migrates only through the strict legacy shape' schema_v1_execution_migration_test

printf '\nPulmu tests: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]

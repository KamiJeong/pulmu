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

example_test() {
  (cd "$ROOT/examples/task-store" && npm test >/dev/null)
}

quench_test() {
  local d
  d="$(mktemp -d)"
  cp -R "$ROOT/examples/task-store/." "$d/"
  (cd "$d" && git init -b main >/dev/null && git config user.name Test && git config user.email test@example.invalid && git add . && git commit -m init >/dev/null && bash "$ROOT/.agents/skills/pulmu/scripts/quench.sh" >/dev/null)
  rm -rf "$d"
}

installer_test() {
  local h status agent_count
  h="$(mktemp -d)"
  HOME="$h" bash "$ROOT/install.sh" >/dev/null
  agent_count="$(find "$h/.codex/agents" -maxdepth 1 -name 'pulmu-*.toml' -type f | wc -l)"
  if [[ -f "$h/.agents/skills/pulmu/SKILL.md" && -f "$h/.agents/skills/pulmu/agents/openai.yaml" && -f "$h/.codex/agents/pulmu-smith.toml" && -x "$h/.agents/skills/pulmu/scripts/ship.sh" && "$agent_count" -eq 12 ]] &&
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

demo_packaging_test() {
  local tmp target status agent_count
  tmp="$(mktemp -d)"
  target="$tmp/demo"
  bash "$ROOT/scripts/create-demo-repo.sh" "$target" >/dev/null
  agent_count="$(find "$target/.codex/agents" -maxdepth 1 -name 'pulmu-*.toml' -type f | wc -l)"
  if [[ -f "$target/.agents/skills/pulmu/SKILL.md" && -f "$target/.codex/config.toml" && -f "$target/.codex/agents/pulmu-smith.toml" && "$agent_count" -eq 12 ]]; then
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
  local skill stage design review plan_block actual_plan expected_plan
  skill="$ROOT/.agents/skills/pulmu/SKILL.md"
  stage="$ROOT/.agents/skills/pulmu/references/stage-contract.md"
  design="$ROOT/.agents/skills/pulmu/references/design-pass.md"
  review="$ROOT/.agents/skills/pulmu/references/review-contract.md"

  grep -Fq "Codex's \`update_plan\` tool" "$skill" || return 1
  [[ "$(grep -Fc '🔥 Pulmu — Starting the forge workflow' "$skill")" -eq 1 ]] || return 1
  grep -Fq 'The banner is neither a plan item nor an eighth stage.' "$stage" || return 1
  grep -Fq '`references/design-pass.md`' "$skill" || return 1
  grep -Fq 'never an eighth top-level stage' "$skill" || return 1
  grep -Fq 'Pattern determines the intended experience; neither the Designer nor the Orchestrator implements or edits task files.' "$skill" || return 1
  grep -Fq 'it does not edit application/source/test files.' "$skill" || return 1
  grep -Fq 'Quick: `pulmu_reviewer`, plus `pulmu_design_reviewer` when Pattern ran' "$skill" || return 1
  grep -Fq 'Standard: `pulmu_reviewer` and `pulmu_test_reviewer`, plus `pulmu_design_reviewer` when Pattern ran' "$skill" || return 1

  plan_block="$(sed -n '/## Native task-progress contract/,/## Terminal contract/p' "$stage")"
  actual_plan="$(grep '^- `.*—' <<<"$plan_block")"
  expected_plan="$(printf '%s\n' \
    '- `🔥 Ignite  — initialize task, validate environment, and understand goal`' \
    '- `🔎 Inspect — inspect repository, conventions, tests, and relevant code`' \
    '- `📐 Shape   — design the implementation approach and determine scope`' \
    '- `🔨 Hammer  — implement the required changes`' \
    '- `🌊 Quench  — run tests, lint, typecheck, build, and other validation`' \
    '- `🪨 Hone    — review the implementation and fix important findings`' \
    '- `📦 Ship    — finalize the selected delivery`')"
  [[ "$actual_plan" == "$expected_plan" ]] || return 1
  ! grep -q '^- `.*Pattern' <<<"$plan_block" || return 1

  grep -Fq 'Decide from Inspect evidence rather than keywords alone.' "$design" || return 1
  grep -Fq 'Do not run this design review for tasks where Pattern was skipped.' "$review" || return 1
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
    ignite_out="$(bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" 'add complete id')"
    grep -q 'PULMU_DELIVERY=local' <<<"$ignite_out" || exit 1
    if bash "$ROOT/.agents/skills/pulmu/scripts/ship.sh" --title 'test: unavailable GitHub delivery' --delivery github >/dev/null 2>&1; then
      exit 1
    fi
    printf '\n// pulmu local change\n' >> src/task-store.js
    out="$(bash "$ROOT/.agents/skills/pulmu/scripts/ship.sh" --title 'test: local pulmu integration')"
    grep -q 'PULMU_DELIVERY=local' <<<"$out" || exit 1
    grep -q 'PULMU_COMMIT=' <<<"$out" || exit 1
    ! grep -q 'PULMU_PR_URL=' <<<"$out" || exit 1
    [[ -z "$(git status --porcelain)" ]] || exit 1
  ) || status=$?
  rm -rf "$tmp"
  return "$status"
}

github_delivery_test() {
  local tmp bare repo fakebin body status
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
if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then exit 0; fi
if [[ "${1:-}" == "repo" && "${2:-}" == "view" ]]; then printf '{"nameWithOwner":"example/pulmu-demo"}\n'; exit 0; fi
if [[ "${1:-}" == "pr" && "${2:-}" == "create" ]]; then printf 'https://github.com/example/pulmu-demo/pull/1\n'; exit 0; fi
printf 'unsupported fake gh args: %s\n' "$*" >&2
exit 2
EOF
  chmod +x "$fakebin/gh"
  (
    cd "$repo"
    git init -b main >/dev/null
    git config user.name Test
    git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    git remote add origin "$bare"
    git push -u origin main >/dev/null
    git remote set-head origin main >/dev/null 2>&1 || true
    ignite_out="$(PATH="$fakebin:$PATH" bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" 'add complete id')"
    grep -q 'PULMU_DELIVERY=github' <<<"$ignite_out" || exit 1
    printf '\n// pulmu integration change\n' >> src/task-store.js
    bash "$ROOT/.agents/skills/pulmu/scripts/quench.sh" >/dev/null
    body="$tmp/body.md"
    printf '# test\n' > "$body"
    out="$(PATH="$fakebin:$PATH" bash "$ROOT/.agents/skills/pulmu/scripts/ship.sh" --title 'test: pulmu integration' --body-file "$body" --delivery github)"
    grep -q 'PULMU_DELIVERY=github' <<<"$out" || exit 1
    grep -q 'PULMU_PR_URL=https://github.com/example/pulmu-demo/pull/1' <<<"$out" || exit 1
    git --git-dir="$bare" show-ref --verify --quiet refs/heads/pulmu/add-complete-id || exit 1
  ) || status=$?
  rm -rf "$tmp"
  return "$status"
}

run_test 'shell scripts parse' syntax_test
run_test 'demo baseline tests pass' example_test
run_test 'Quench discovers and runs npm test' quench_test
run_test 'installer lays out skill and agents' installer_test
run_test 'uninstaller removes skill and all Pulmu agents' uninstaller_test
run_test 'demo repository packages all Pulmu agents' demo_packaging_test
run_test 'agent TOMLs preserve routing and single-writer contracts' agent_contract_test
run_test 'skill preserves seven stages with conditional Pattern' skill_contract_test
run_test 'local Git repository completes without GitHub' local_delivery_test
run_test 'GitHub delivery pushes and creates a PR' github_delivery_test

printf '\nPulmu tests: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]

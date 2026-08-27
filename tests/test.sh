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
  local skill stage design review delivery scripts readme plan_block progress_block actual_plan expected_plan actual_skill_plan actual_readme_plan expected_plain
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
  grep -Fq '`references/design-pass.md`' "$skill" || return 1
  grep -Fq 'never an eighth top-level stage' "$skill" || return 1
  grep -Fq 'Pattern determines the intended experience; neither the Designer nor the Orchestrator implements or edits task files.' "$skill" || return 1
  grep -Fq 'it does not edit application/source/test files.' "$skill" || return 1
  grep -Fq 'Quick: `pulmu_reviewer`, plus `pulmu_design_reviewer` when Pattern ran' "$skill" || return 1
  grep -Fq 'Standard: `pulmu_reviewer` and `pulmu_test_reviewer`, plus `pulmu_design_reviewer` when Pattern ran' "$skill" || return 1

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
  actual_skill_plan="$(sed -n '/Immediately after Pulmu starts, call/,/Keep these strings unchanged/p' "$skill" | grep -E '^(🔥|🔎|📐|🔨|🌊|🪨|📦)')"
  [[ "$actual_skill_plan" == "$expected_plain" ]] || return 1
  actual_readme_plan="$(sed -n '/The step text is stable/,/The native plan status/p' "$readme" | grep -E '^(🔥|🔎|📐|🔨|🌊|🪨|📦)')"
  [[ "$actual_readme_plan" == "$expected_plain" ]] || return 1
  ! grep -Eqi '^- `.*\b(active|pending|completed)\b.*`$' <<<"$actual_plan" || return 1
  ! grep -q '^- `.*Pattern' <<<"$plan_block" || return 1
  grep -Fq 'Do not repeat the full plan in normal assistant messages' "$skill" || return 1
  grep -Fq 'Do not repeat the full plan in normal assistant messages' "$stage" || return 1

  progress_block="$(sed -n '/## Terminal contract/,/## Retry paths/p' "$stage")"
  [[ "$(grep -Ec '^(🔥 Ignite|🔎 Inspect|📐 Shape|🔨 Hammer|🌊 Quench|🪨 Hone|📦 Ship)$' <<<"$progress_block")" -eq 7 ]] || return 1
  ! grep -Eq '^(🔥 Ignite|🔎 Inspect|📐 Shape|🔨 Hammer|🌊 Quench|🪨 Hone|📦 Ship) —' <<<"$progress_block" || return 1

  grep -Fq 'Decide from Inspect evidence rather than keywords alone.' "$design" || return 1
  grep -Fq 'Do not run this design review for tasks where Pattern was skipped.' "$review" || return 1
  grep -Fq 'Pulmu does not impose Git Flow.' "$delivery" || return 1
  grep -Fq 'Finalize task metadata once after Shape.' "$skill" || return 1
  grep -Fq 'update_plan shows the forge to humans. Run Context exposes the forge to machines.' "$skill" || return 1
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
      [[ "$(pulmu_base_branch)" == trunk && "$(pulmu_base_branch)" != pulmu/existing ]] || exit 1
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
  local run_id; local -a args
  run_id="$(cat .git/pulmu-metadata/run_id 2>/dev/null || true)"
  if [[ -z "$run_id" ]]; then
    run_id="$(bash "$ROOT/.agents/skills/pulmu/scripts/run-context.sh" detect 2>/dev/null | sed -n 's/^PULMU_RUN_ID=//p' || true)"
  fi
  args=(finalize --type "${1:-feature}" --forge "${2:-standard}" --risk "${3:-low}" \
    --areas "${4:-backend}" --pattern "${5:-false}" \
    --security-review "${6:-false}" --compatibility-review "${7:-false}" \
  )
  [[ -n "$run_id" ]] && args+=(--expect-run-id "$run_id")
  bash "$ROOT/.agents/skills/pulmu/scripts/metadata.sh" "${args[@]}" >/dev/null
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

record_reviewed_delivery() {
  local title="$1" summary="$2" run_id
  run_id="$(cat .git/pulmu-metadata/run_id)"
  bash "$ROOT/.agents/skills/pulmu/scripts/quench.sh" >/dev/null
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
    grep -q 'PULMU_BRANCH=pulmu/fix/login-redirect' <<<"$out" || exit 1
    [[ "$(cat .git/pulmu-base)" == develop && "$(cat .git/pulmu-branch)" == pulmu/fix/login-redirect ]] || exit 1
    resume_out="$(bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug ignored 'A different prompt must not replace provenance')"
    grep -q 'PULMU_BASE=develop' <<<"$resume_out" || exit 1
    [[ "$(cat .git/pulmu-base)" == develop && "$(cat .git/pulmu-metadata/base_branch)" == develop ]] || exit 1
    printf 'main\n' > .git/pulmu-base
    if bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" 'Ambiguous provenance' >/dev/null 2>&1; then exit 1; fi
    printf 'develop\n' > .git/pulmu-base
    rm -rf .git/pulmu-metadata
    finalize_metadata bugfix full medium testing true false true
    [[ "$(cat .git/pulmu-metadata/areas)" == frontend,design,testing ]] || exit 1
    if finalize_metadata feature full medium testing true false true >/dev/null 2>&1; then exit 1; fi
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
    git branch pulmu/feat/search; git push origin pulmu/feat/search >/dev/null; git branch -D pulmu/feat/search >/dev/null
    out="$(bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug search 'Add search')"
    grep -q 'PULMU_BASE=main' <<<"$out" || exit 1
    grep -q 'PULMU_BRANCH=pulmu/feat/search-2' <<<"$out" || exit 1
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
  local tmp repo before status old_hone
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
    bash "$ROOT/.agents/skills/pulmu/scripts/quench.sh" >/dev/null
    printf '// evidence v2\n' >> src/task-store.js
    if metadata_for_run hone --result pass >/dev/null 2>&1; then exit 1; fi
    bash "$ROOT/.agents/skills/pulmu/scripts/quench.sh" >/dev/null
    if metadata_for_run delivery --title 'feat(testing): exercise evidence gates' --summary 'Exercises missing Hone.' --change 'Adds evidence fixture comments' >/dev/null 2>&1; then exit 1; fi
    metadata_for_run hone --result pass >/dev/null
    old_hone="$(cat .git/pulmu-metadata/hone_fingerprint)"
    printf '// evidence v3\n' >> src/task-store.js
    bash "$ROOT/.agents/skills/pulmu/scripts/quench.sh" >/dev/null
    printf '%s\n' "$old_hone" > .git/pulmu-metadata/hone_fingerprint
    if metadata_for_run delivery --title 'feat(testing): exercise evidence gates' --summary 'Exercises stale Hone.' --change 'Adds evidence fixture comments' >/dev/null 2>&1; then exit 1; fi
    metadata_for_run hone --result pass >/dev/null
    metadata_for_run delivery --title 'feat(testing): exercise evidence gates' --summary 'Exercises exact final-diff delivery.' --change 'Adds evidence fixture comments' >/dev/null
    printf '// evidence v4\n' >> src/task-store.js
    if ship_for_run --delivery local >/dev/null 2>&1; then exit 1; fi
    [[ "$(git rev-parse HEAD)" == "$before" && ! -f .git/pulmu-ship-commit ]] || exit 1
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
  local tmp bare repo fakebin risky_bare risky_repo pattern_bare pattern_repo status
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
if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then exit 0; fi
if [[ "${1:-}" == "repo" && "${2:-}" == "view" ]]; then
  if [[ "$*" == *defaultBranchRef* ]]; then printf 'main\n'; else printf '{"nameWithOwner":"example/pulmu-demo"}\n'; fi
  exit 0
fi
if [[ "${1:-}" == "label" && "${2:-}" == "list" ]]; then
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
if [[ "${1:-}" == "label" && "${2:-}" == "create" ]]; then [[ "${GH_LABEL_CREATE_FAIL:-0}" == 1 ]] && exit 5; exit 0; fi
if [[ "${1:-}" == "pr" && "${2:-}" == "list" ]]; then
  [[ "$*" == *"--base main"* ]] || exit 4
  case "${GH_PR_MODE:-wrong-base}" in
    existing) printf 'https://github.com/example/pulmu-demo/pull/1\n' ;;
    invalid) printf 'not-a-pull-request-url\n' ;;
    wrong-base) ;;
  esac
  exit 0
fi
if [[ "${1:-}" == "pr" && "${2:-}" == "create" ]]; then
  while [[ $# -gt 0 ]]; do if [[ "$1" == "--body-file" ]]; then cp "$2" "$GH_BODY_CAPTURE"; break; fi; shift; done
  printf '%s\n' "${GH_CREATE_OUTPUT:-https://github.com/example/pulmu-demo/pull/1}"; exit 0
fi
if [[ "${1:-}" == "pr" && "${2:-}" == "edit" ]]; then
  if [[ "$*" == *"--add-label"* && "${GH_LABEL_APPLY_FAIL:-0}" == 1 ]]; then exit 6; fi
  while [[ $# -gt 0 ]]; do if [[ "$1" == "--body-file" ]]; then cp "$2" "$GH_BODY_CAPTURE"; break; fi; shift; done
  exit 0
fi
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
    export GH_LOG="$tmp/gh.log" GH_BODY_CAPTURE="$tmp/body.md"
    : > "$GH_LOG"
    ignite_out="$(PATH="$fakebin:$PATH" bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug delivery-policy 'add complete id')"
    grep -q 'PULMU_DELIVERY=github' <<<"$ignite_out" || exit 1
    finalize_metadata feature full medium infra,testing false false true
    printf '\n// pulmu integration change\n' >> src/task-store.js
    record_reviewed_delivery 'feat(delivery): propagate forge metadata' 'Propagates finalized forge decisions into Git and GitHub delivery.'
    printf 'Repository-specific rollout note.\n' > "$tmp/supplement.md"
    export GH_PR_MODE=wrong-base
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
    git --git-dir="$bare" show-ref --verify --quiet refs/heads/pulmu/feat/delivery-policy || exit 1
    grep -Fq '## Pulmu Forge' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq '| 📐 Shape | Pattern skipped |' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq -- '- Forge: Full' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq -- '- Type: Feature' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq -- '- Areas: infra, testing' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq '## Summary' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq '## Changes' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq '## Verification' "$GH_BODY_CAPTURE" || exit 1
    grep -Fq -- '- ✓ test' "$GH_BODY_CAPTURE" || exit 1
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
    grep -q '^pr list .*--head pulmu/feat/delivery-policy --base main ' "$GH_LOG" || exit 1
    grep -q '^pr edit https://github.com/example/pulmu-demo/pull/1 --title .*--body-file ' "$GH_LOG" || exit 1
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
    risky_bare="$tmp/risky-remote.git"; risky_repo="$tmp/risky-repo"
    mkdir -p "$risky_repo"; git init --bare "$risky_bare" >/dev/null; cp -R "$ROOT/examples/task-store/." "$risky_repo/"
    (
      cd "$risky_repo"
      git init -b main >/dev/null
      git config user.name Test; git config user.email test@example.invalid
      mkdir -p .pulmu
      printf '[github]\ncreate_missing_labels = true\n' > .pulmu/config.toml
      git add . && git commit -m init >/dev/null
      git remote add origin "$risky_bare"; git push -u origin main >/dev/null
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
      grep -q '^label create risk: high ' "$GH_LOG" || exit 1
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
      git remote add origin "$pattern_bare"; git push -u origin main >/dev/null
      export GH_LOG="$tmp/pattern-gh.log" GH_BODY_CAPTURE="$tmp/pattern-body.md" GH_PR_MODE=wrong-base GH_PATTERN_LABELS=1
      : > "$GH_LOG"
      PATH="$fakebin:$PATH" bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" --type feature --slug responsive-search 'Add responsive search' >/dev/null
      finalize_metadata feature standard low testing true false false
      printf '\n// Pattern integration change\n' >> src/task-store.js
      bash "$ROOT/.agents/skills/pulmu/scripts/quench.sh" >/dev/null
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
assert state["schemaVersion"] == 1 and state["workflow"] == "pulmu"
assert state["runId"] == sys.argv[2] and state["status"] == "running"
assert state["stage"] == {"current": "ignite", "status": "in_progress"}
assert state["git"]["baseBranch"] == "main"
assert state["git"]["branch"] == "pulmu/feat/persistent-state"
assert "should-never-persist" not in state["task"]["prompt"]
assert state["forge"] is None and state["risk"] is None and state["areas"] == []
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

    finalize_metadata feature full medium infra,testing false false true
    python3 - .git/pulmu/run.json <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["task"]["type"] == "feature"
assert state["forge"] == "full" and state["risk"] == "medium"
assert state["areas"] == ["infra", "testing"] and state["pattern"] is False
PY

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

    # Exercise both documented retry paths without creating a second run.
    bash "$scripts/run-context.sh" set-stage quench --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" increment-retry quench --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" set-stage hammer --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" set-agents pulmu_smith --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" set-stage quench --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" set-agents --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" set-stage hone --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" increment-retry hone --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" set-stage hammer --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" set-stage quench --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" set-stage hone --expect-run-id "$run_id" >/dev/null
    python3 - .git/pulmu/run.json "$run_id" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["runId"] == sys.argv[2]
assert state["retries"] == {"quench": 1, "hone": 1}
assert state["stage"]["current"] == "hone"
PY

    # Concurrent locked increments must not lose updates.
    for _ in $(seq 1 12); do
      bash "$scripts/run-context.sh" increment-retry quench --expect-run-id "$run_id" >/dev/null &
    done
    wait
    [[ "$(python3 -c 'import json; print(json.load(open(".git/pulmu/run.json"))["retries"]["quench"])')" -eq 13 ]] || exit 1

    bash "$scripts/run-context.sh" set-stage ship --expect-run-id "$run_id" >/dev/null
    bash "$scripts/run-context.sh" complete --delivery github --commit aabbccddeeff0011 \
      --pr-number 128 --pr-url https://github.com/example/repo/pull/128 --expect-run-id "$run_id" >/dev/null
    python3 - .git/pulmu/run.json "$run_id" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["runId"] == sys.argv[2] and state["status"] == "completed"
assert state["stage"] == {"current": "ship", "status": "completed"}
assert state["pr"] == {"number": 128, "url": "https://github.com/example/repo/pull/128"}
assert state["completedAt"] and state["git"]["commit"] == "aabbccddeeff0011"
assert state["interruptedAt"] is None and state["error"] is None
PY
    [[ -f ".git/pulmu/runs/$run_id.json" ]] || exit 1

    # A new init gets a new ID. A second init detects and archives that running run.
    bash "$scripts/run-context.sh" init --task-type feature --task 'second run' --base main --branch pulmu/feat/second > "$tmp/second.out"
    second_id="$(sed -n 's/^PULMU_RUN_ID=//p' "$tmp/second.out")"
    [[ "$second_id" != "$run_id" ]] || exit 1
    stale_output="$(bash "$scripts/run-context.sh" init --task-type feature --task 'third run' --base main --branch pulmu/feat/third 2>&1)"
    third_id="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$stale_output" | tail -n 1)"
    grep -Fq '⚠ Previous Pulmu run detected' <<<"$stale_output" || exit 1
    grep -Fq "Run: $second_id" <<<"$stale_output" || exit 1
    grep -Fq 'Stage: 🔥 Ignite' <<<"$stale_output" || exit 1
    grep -Fq 'Branch: pulmu/feat/second' <<<"$stale_output" || exit 1
    python3 - ".git/pulmu/runs/$second_id.json" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["status"] == "interrupted"
assert state["stage"]["status"] == "interrupted"
assert state["interruptedAt"] and state["agents"]["active"] == []
PY

    bash "$scripts/run-context.sh" set-stage hammer --expect-run-id "$third_id" >/dev/null
    bash "$scripts/run-context.sh" set-agents pulmu_smith --expect-run-id "$third_id" >/dev/null
    printf 'dirty fixture\n' > dirty.tmp
    dirty_output="$(bash "$scripts/ignite.sh" --type feature --slug blocked 'blocked by dirty tree' 2>&1 || true)"
    grep -Fq '⚠ Previous Pulmu run detected:' <<<"$dirty_output" || exit 1
    grep -Fq "${third_id}" <<<"$dirty_output" || exit 1
    grep -Fq 'at hammer on pulmu/feat/third' <<<"$dirty_output" || exit 1
    grep -Fq '⚠ Existing run left unchanged because liveness cannot be determined safely' <<<"$dirty_output" || exit 1
    grep -Fq 'working tree is not clean' <<<"$dirty_output" || exit 1
    python3 - .git/pulmu/run.json "$third_id" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["runId"] == sys.argv[2] and state["status"] == "running"
assert state["stage"] == {"current": "hammer", "status": "in_progress"}
assert state["agents"]["active"] == ["pulmu_smith"]
assert not pathlib.Path(sys.argv[1]).with_name("runs").joinpath(sys.argv[2] + ".json").exists()
PY
    rm dirty.tmp

    # Normal mutation fails closed on corruption; init quarantines and recovers.
    printf '{broken json\n' > .git/pulmu/run.json
    if bash "$scripts/run-context.sh" set-stage inspect >/dev/null 2>&1; then exit 1; fi
    malformed="$(bash "$scripts/run-context.sh" detect 2>/dev/null || true)"
    grep -Fq 'PULMU_RUN_DETECTED=malformed' <<<"$malformed" || exit 1
    bash "$scripts/run-context.sh" init --task-type bugfix --task 'recover malformed state' \
      --base main --branch pulmu/fix/recovery > "$tmp/recovered.out" 2> "$tmp/recovered.err"
    grep -Fq '⚠ Malformed Pulmu run quarantined:' "$tmp/recovered.err" || exit 1
    find .git/pulmu/runs -maxdepth 1 -name 'corrupt-*.json' -type f | grep -q . || exit 1

    # Failures are concise, terminal, archived, and redact credentials.
    recovered_id="$(sed -n 's/^PULMU_RUN_ID=//p' "$tmp/recovered.out")"
    bash "$scripts/run-context.sh" set-stage quench --expect-run-id "$recovered_id" >/dev/null
    bash "$scripts/run-context.sh" fail --code QUENCH_FAILED \
      --message 'Tests failed bearer abcdefghijklmnop and token=more-secret-data' \
      --expect-run-id "$recovered_id" >/dev/null
    python3 - .git/pulmu/run.json "$recovered_id" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
raw = pathlib.Path(sys.argv[1]).read_text()
assert state["status"] == "failed" and state["stage"] == {"current": "quench", "status": "failed"}
assert state["error"]["code"] == "QUENCH_FAILED"
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
  local tmp repo scripts status old_id new_id
  tmp="$(mktemp -d)"; repo="$tmp/repo"; scripts="$ROOT/.agents/skills/pulmu/scripts"; status=0
  mkdir -p "$repo"; cp -R "$ROOT/examples/task-store/." "$repo/"
  (
    cd "$repo"; git init -b main >/dev/null; git config user.name Test; git config user.email test@example.invalid
    git add . && git commit -m init >/dev/null
    ignite="$(bash "$scripts/ignite.sh" --type feature --slug legacy-terminal 'Migrate terminal legacy state')"
    old_id="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$ignite")"
    finalize_metadata feature standard low infra false false true
    bash "$scripts/run-context.sh" set-stage ship --expect-run-id "$old_id" >/dev/null
    bash "$scripts/run-context.sh" complete --delivery local --commit aabbccd --expect-run-id "$old_id" >/dev/null
    rm .git/pulmu-metadata/run_id
    out="$(bash "$scripts/metadata.sh" finalize --type feature --forge standard --risk low \
      --areas infra --pattern false --security-review false --compatibility-review true)"
    new_id="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$out")"
    [[ -n "$new_id" && "$new_id" != "$old_id" && "$(cat .git/pulmu-metadata/run_id)" == "$new_id" ]] || exit 1
    [[ -f ".git/pulmu/runs/$old_id.json" ]] || exit 1
    python3 - .git/pulmu/run.json "$new_id" <<'PY'
import json, pathlib, sys
state = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert state["runId"] == sys.argv[2] and state["status"] == "running"
assert state["stage"] == {"current": "ignite", "status": "in_progress"}
assert state["task"] == {"prompt": "Migrate terminal legacy state", "type": "feature"}
assert state["git"]["baseBranch"] == "main" and state["git"]["branch"] == "pulmu/feat/legacy-terminal"
assert state["forge"] == "standard" and state["risk"] == "low" and state["areas"] == ["infra"]
assert state["pr"] is None and state["error"] is None
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
    second="$(bash "$scripts/run-context.sh" init --task-type feature --task 'new run B' \
      --base main --branch pulmu/feat/stale-guard 2>/dev/null)"
    run_b="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$second")"
    [[ "$run_a" != "$run_b" ]] || exit 1
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
run_test 'demo baseline tests pass' example_test
run_test 'Quench discovers and runs npm test' quench_test
run_test 'installer lays out skill and agents' installer_test
run_test 'uninstaller removes skill and all Pulmu agents' uninstaller_test
run_test 'demo repository packages all Pulmu agents' demo_packaging_test
run_test 'agent TOMLs preserve routing and single-writer contracts' agent_contract_test
run_test 'skill preserves seven stages with conditional Pattern' skill_contract_test
run_test 'all task types map to branch, commit, and label dimensions' task_mapping_test
run_test 'base selection covers convention, remote default, main, and develop' base_selection_paths_test
run_test 'metadata finalization propagates Pattern and remains immutable' metadata_policy_test
run_test 'config rejects unsafe policy and branch collisions are deterministic' config_and_collision_test
run_test 'Ship rejects missing, stale, and mutated verification evidence' ship_evidence_gate_test
run_test 'local Git repository completes without GitHub' local_delivery_test
run_test 'GitHub delivery propagates metadata, body, and existing labels' github_delivery_test
run_test 'Run Context covers lifecycle, retries, safety, concurrency, and observability' run_context_test
run_test 'Run Context resolves linked-worktree Git metadata safely' run_context_worktree_test
run_test 'legacy active branches bootstrap Run Context before metadata finalization' legacy_run_context_migration_test
run_test 'legacy metadata replaces a terminal Run Context with a new running runId' legacy_terminal_context_test
run_test 'stale metadata and Ship processes cannot mutate a newer run' stale_run_guard_test
run_test 'Ignite reports the Python Run Context runtime requirement clearly' python_preflight_test

printf '\nPulmu tests: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]

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
  local h status
  h="$(mktemp -d)"
  HOME="$h" bash "$ROOT/install.sh" >/dev/null
  if [[ -f "$h/.agents/skills/pulmu/SKILL.md" && -f "$h/.agents/skills/pulmu/agents/openai.yaml" && -f "$h/.codex/agents/pulmu-explorer.toml" && -x "$h/.agents/skills/pulmu/scripts/ship.sh" ]] &&
    grep -q 'display_name: "Pulmu Workflows"' "$h/.agents/skills/pulmu/agents/openai.yaml"; then
    status=0
  else
    status=1
  fi
  rm -rf "$h"
  return "$status"
}

skill_contract_test() {
  local skill stage design review plan_block actual_plan expected_plan
  skill="$ROOT/.agents/skills/pulmu/SKILL.md"
  stage="$ROOT/.agents/skills/pulmu/references/stage-contract.md"
  design="$ROOT/.agents/skills/pulmu/references/design-pass.md"
  review="$ROOT/.agents/skills/pulmu/references/review-contract.md"

  grep -Fq "Codex's \`update_plan\` tool" "$skill" || return 1
  grep -Fq '`references/design-pass.md`' "$skill" || return 1
  grep -Fq 'never an eighth top-level stage' "$skill" || return 1
  grep -Fq 'Pattern determines the intended experience; it does not implement or edit source code.' "$skill" || return 1

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
run_test 'skill preserves seven stages with conditional Pattern' skill_contract_test
run_test 'local Git repository completes without GitHub' local_delivery_test
run_test 'GitHub delivery pushes and creates a PR' github_delivery_test

printf '\nPulmu tests: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]

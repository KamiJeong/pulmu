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
  local h
  h="$(mktemp -d)"
  HOME="$h" bash "$ROOT/install.sh" >/dev/null
  [[ -f "$h/.agents/skills/pulmu/SKILL.md" && -f "$h/.codex/agents/pulmu-explorer.toml" && -x "$h/.agents/skills/pulmu/scripts/ship.sh" ]]
  rm -rf "$h"
}

forge_integration_test() {
  local tmp bare repo fakebin body
  tmp="$(mktemp -d)"
  bare="$tmp/remote.git"
  repo="$tmp/repo"
  fakebin="$tmp/bin"
  mkdir -p "$repo" "$fakebin"
  git init --bare "$bare" >/dev/null
  cp -R "$ROOT/examples/task-store/." "$repo/"
  cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then exit 0; fi
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
    PATH="$fakebin:$PATH" bash "$ROOT/.agents/skills/pulmu/scripts/ignite.sh" 'add complete id' >/dev/null
    printf '\n// pulmu integration change\n' >> src/task-store.js
    bash "$ROOT/.agents/skills/pulmu/scripts/quench.sh" >/dev/null
    body="$tmp/body.md"
    printf '# test\n' > "$body"
    out="$(PATH="$fakebin:$PATH" bash "$ROOT/.agents/skills/pulmu/scripts/ship.sh" --title 'test: pulmu integration' --body-file "$body")"
    grep -q 'PULMU_PR_URL=https://github.com/example/pulmu-demo/pull/1' <<<"$out"
    git --git-dir="$bare" show-ref --verify --quiet refs/heads/pulmu/add-complete-id
  )
  rm -rf "$tmp"
}

run_test 'shell scripts parse' syntax_test
run_test 'demo baseline tests pass' example_test
run_test 'Quench discovers and runs npm test' quench_test
run_test 'installer lays out skill and agents' installer_test
run_test 'Ignite → branch → Quench → Ship integration' forge_integration_test

printf '\nPulmu tests: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]

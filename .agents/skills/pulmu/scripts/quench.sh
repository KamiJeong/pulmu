#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ROOT="$(pulmu_repo_root)"
cd "$ROOT"
GIT_DIR="$(pulmu_git_dir)"
LOG="$GIT_DIR/pulmu-quench.log"
rm -f "$(pulmu_metadata_dir)/quench_fingerprint" "$(pulmu_metadata_dir)/hone_fingerprint" "$(pulmu_metadata_dir)/delivery_fingerprint"
: > "$LOG"

run_check() {
  local label="$1"; shift
  printf '• %s\n' "$label" | tee -a "$LOG"
  if "$@" 2>&1 | tee -a "$LOG"; then
    printf '✓ %s\n' "$label" | tee -a "$LOG"
  else
    printf '✗ %s\n' "$label" | tee -a "$LOG" >&2
    return 1
  fi
}

json_has_script() {
  local script="$1"
  if command -v node >/dev/null 2>&1; then
    node -e 'const p=require("./package.json"); process.exit(p.scripts && p.scripts[process.argv[1]] ? 0 : 1)' "$script" >/dev/null 2>&1
  else
    grep -Eq '"'"$script"'"[[:space:]]*:' package.json
  fi
}

has_python_tests() {
  [[ -f pyproject.toml || -f pytest.ini ]] && return 0
  [[ -d tests ]] || return 1
  find tests -type f \( -name 'test_*.py' -o -name '*_test.py' \) -print -quit | grep -q .
}

checks=0

if [[ -f package.json ]]; then
  runner="npm"
  [[ -f bun.lock || -f bun.lockb ]] && command -v bun >/dev/null 2>&1 && runner="bun"
  [[ -f pnpm-lock.yaml ]] && command -v pnpm >/dev/null 2>&1 && runner="pnpm"
  [[ -f yarn.lock ]] && command -v yarn >/dev/null 2>&1 && runner="yarn"

  for script in lint typecheck check test build; do
    if json_has_script "$script"; then
      checks=$((checks+1))
      if [[ "$runner" == "npm" ]]; then
        run_check "$script" npm run "$script"
      else
        run_check "$script" "$runner" run "$script"
      fi
    fi
  done
fi

if [[ -f tests/test.sh ]]; then
  checks=$((checks+1))
  run_check "tests/test.sh" bash ./tests/test.sh
fi

if has_python_tests; then
  if command -v pytest >/dev/null 2>&1; then
    checks=$((checks+1))
    run_check "pytest" pytest -q
  elif command -v python3 >/dev/null 2>&1 && python3 -m pytest --version >/dev/null 2>&1; then
    checks=$((checks+1))
    run_check "pytest" python3 -m pytest -q
  fi
fi

if [[ -f Cargo.toml ]] && command -v cargo >/dev/null 2>&1; then
  checks=$((checks+1))
  run_check "cargo test" cargo test
fi

if [[ -f go.mod ]] && command -v go >/dev/null 2>&1; then
  checks=$((checks+1))
  run_check "go test" go test ./...
fi

if [[ "$checks" -eq 0 ]]; then
  printf '⚠ no supported automated verification command was discovered\n' | tee -a "$LOG"
fi

printf 'PULMU_QUENCH_CHECKS=%s\n' "$checks" | tee -a "$LOG"
if [[ "$(pulmu_metadata_read status 2>/dev/null || true)" == "final" ]]; then
  pulmu_metadata_write quench_fingerprint "$(pulmu_changed_fingerprint)"
  printf 'PULMU_QUENCH=PASS\n' | tee -a "$LOG"
fi
printf 'PULMU_QUENCH_LOG=%s\n' "$LOG"

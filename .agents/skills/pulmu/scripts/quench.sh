#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

EXPECT_RUN_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --expect-run-id) EXPECT_RUN_ID="${2:-}"; shift 2 ;;
    *) pulmu_die "unknown Quench option: $1" ;;
  esac
done

[[ -n "$EXPECT_RUN_ID" ]] || pulmu_die "Quench requires --expect-run-id from Ignite"
pulmu_require_python
ROOT="$(pulmu_repo_root)"; cd "$ROOT"
GIT_DIR="$(pulmu_git_dir)"; METADATA_DIR="$(pulmu_metadata_dir)"
[[ "$(pulmu_metadata_read status 2>/dev/null || true)" == "final" ]] || pulmu_die "Quench requires finalized Pulmu task metadata"
[[ "$(pulmu_metadata_read run_id 2>/dev/null || true)" == "$EXPECT_RUN_ID" ]] || pulmu_die "Quench metadata runId changed; refusing stale operation"
BRANCH="$(git branch --show-current)"; BASE="$(pulmu_metadata_read base_branch)"
[[ "$BRANCH" == "$(pulmu_metadata_read branch)" ]] || pulmu_die "Quench branch does not match finalized metadata"
HEAD_COMMIT="$(git rev-parse HEAD)"; BASE_HEAD="$(git rev-parse "$BASE")"; CANDIDATE_TREE="$(pulmu_candidate_tree)"
CANDIDATE_ID="$(pulmu_candidate_identity "$EXPECT_RUN_ID" "$BRANCH" "$BASE" "$BASE_HEAD" "$HEAD_COMMIT" "$CANDIDATE_TREE")"
LOG="$(mktemp "$GIT_DIR/pulmu-quench.$$.XXXXXX")"
ATTEMPT="${LOG##*.}-$EXPECT_RUN_ID"
: > "$LOG"
quench_cleanup() {
  local status=$?
  if [[ "$status" -eq 0 ]]; then rm -f "$LOG"; else printf 'PULMU_QUENCH_LOG=%s\n' "$LOG" >&2; fi
  return "$status"
}
trap quench_cleanup EXIT
trap 'exit 130' HUP INT TERM

pulmu_run_context quench-evidence begin --attempt "$ATTEMPT" --expect-run-id "$EXPECT_RUN_ID" >/dev/null

run_check() {
  local label="$1" cwd="$2" command="$3" timeout="${PULMU_QUENCH_TIMEOUT_SECONDS:-900}" status
  [[ "$timeout" =~ ^[1-9][0-9]{0,4}$ ]] || pulmu_die "PULMU_QUENCH_TIMEOUT_SECONDS must be 1-99999"
  printf '• %s\n' "$label" | tee -a "$LOG"
  if python3 - "$ROOT/$cwd" "$timeout" "$command" 2>&1 <<'PY' | tee -a "$LOG"
import os
import signal
import subprocess
import sys
import time

cwd, timeout, command = sys.argv[1], int(sys.argv[2]), sys.argv[3]
environment = os.environ.copy()
environment.setdefault("CI", "true")
process = subprocess.Popen(["/bin/bash", "-c", command], cwd=cwd, env=environment, start_new_session=True)
def interrupted(_signum, _frame):
    raise KeyboardInterrupt
signal.signal(signal.SIGTERM, interrupted)
signal.signal(signal.SIGHUP, interrupted)
signal.signal(signal.SIGINT, interrupted)
def stop_group():
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=2)
    except subprocess.TimeoutExpired:
        pass
    time.sleep(0.1)
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()
try:
    returncode = process.wait(timeout=timeout)
except subprocess.TimeoutExpired:
    stop_group()
    print(f"verification timed out after {timeout}s", file=sys.stderr)
    raise SystemExit(124)
except BaseException:
    stop_group()
    raise
stop_group()
raise SystemExit(returncode)
PY
  then
    printf '✓ %s\n' "$label" | tee -a "$LOG"
    printf 'PULMU_QUENCH_CHECK_EXIT=%s:0\n' "$label" >> "$LOG"
  else
    status="${PIPESTATUS[0]}"
    case "$status" in
      124) reason="timeout" ;;
      126|127) reason="unavailable prerequisite" ;;
      *) reason="failed" ;;
    esac
    printf '✗ %s (%s, exit %s)\n' "$label" "$reason" "$status" | tee -a "$LOG" >&2
    printf 'PULMU_QUENCH_CHECK_EXIT=%s:%s\n' "$label" "$status" >> "$LOG"
    return "$status"
  fi
}

declare -a LABELS=() CWDS=() COMMANDS=()
add_check() { LABELS+=("$1"); CWDS+=("$2"); COMMANDS+=("$3"); }

PLAN="$METADATA_DIR/verification-plan"
[[ -f "$PLAN" ]] || pulmu_die "Shape did not record a verification plan"
while IFS=$'\t' read -r label cwd command || [[ -n "$label$cwd$command" ]]; do
  [[ -n "$label" && -n "$cwd" && -n "$command" ]] || pulmu_die "verification plan is malformed"
  [[ "$cwd" != /* ]] || pulmu_die "verification plan working directory is invalid: $cwd"
  root_real="$(cd "$ROOT" && pwd -P)"; dir_real="$(cd "$ROOT/$cwd" 2>/dev/null && pwd -P || true)"
  [[ -n "$dir_real" && ( "$dir_real" == "$root_real" || "$dir_real" == "$root_real/"* ) ]] || pulmu_die "verification plan working directory is invalid: $cwd"
  add_check "$label" "$cwd" "$command"
done < "$PLAN"

[[ "${#COMMANDS[@]}" -gt 0 ]] || pulmu_die "no automated verification command was selected or discovered"
for index in "${!COMMANDS[@]}"; do
  run_check "${LABELS[$index]}" "${CWDS[$index]}" "${COMMANDS[$index]}"
  [[ "$(git branch --show-current)" == "$BRANCH" && "$(git rev-parse HEAD)" == "$HEAD_COMMIT" && \
      "$(git rev-parse "$BASE")" == "$BASE_HEAD" && "$(pulmu_candidate_tree)" == "$CANDIDATE_TREE" ]] ||
    pulmu_die "candidate changed during ${LABELS[$index]}; verification commands must not modify task content"
done

[[ "$(git branch --show-current)" == "$BRANCH" ]] || pulmu_die "branch changed while Quench was running"
[[ "$(git rev-parse HEAD)" == "$HEAD_COMMIT" ]] || pulmu_die "HEAD changed while Quench was running"
[[ "$(git rev-parse "$BASE")" == "$BASE_HEAD" ]] || pulmu_die "base changed while Quench was running"
[[ "$(pulmu_candidate_tree)" == "$CANDIDATE_TREE" ]] || pulmu_die "candidate changed while Quench was running; verify again"

printf 'PULMU_QUENCH_CHECKS=%s\n' "${#COMMANDS[@]}" | tee -a "$LOG"
printf 'PULMU_QUENCH=PASS\n' >> "$LOG"
pulmu_run_context quench-evidence pass \
  --branch "$BRANCH" --base "$BASE" --base-head "$BASE_HEAD" --head "$HEAD_COMMIT" \
  --tree "$CANDIDATE_TREE" --fingerprint "$CANDIDATE_ID" --log "$LOG" \
  --attempt "$ATTEMPT" \
  --expect-run-id "$EXPECT_RUN_ID" >/dev/null
printf 'PULMU_QUENCH=PASS\n'
printf 'PULMU_QUENCH_LOG=%s\n' "$GIT_DIR/pulmu-quench.log"

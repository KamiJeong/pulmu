#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

TYPE="${PULMU_TASK_TYPE:-feature}"
SLUG_OVERRIDE=""
BRANCH_OVERRIDE=""
while [[ $# -gt 1 ]]; do
  case "$1" in
    --type) TYPE="${2:-}"; shift 2 ;;
    --slug) SLUG_OVERRIDE="${2:-}"; shift 2 ;;
    --branch) BRANCH_OVERRIDE="${2:-}"; [[ -n "$BRANCH_OVERRIDE" ]] || pulmu_die "--branch requires a name"; shift 2 ;;
    *) pulmu_die "unknown ignite option: $1" ;;
  esac
done
TASK="${1:-}"
[[ -n "$TASK" ]] || pulmu_die "usage: ignite.sh [--type <type>] [--slug <slug>] [--branch <name>] '<task>'"
pulmu_task_type_valid "$TYPE" || pulmu_die "Ignite task type must be feature, bugfix, refactor, docs, test, or chore"

pulmu_require git
pulmu_require_python
python3 - "$TASK" <<'PY' || pulmu_die "Ignite task must contain 1-2000 characters"
import sys
task = sys.argv[1]
raise SystemExit(0 if 0 < len(task) <= 2000 and "\x00" not in task else 1)
PY
ROOT="$(pulmu_repo_root)"
cd "$ROOT"
pulmu_load_config "$ROOT"

# Detection is deliberately non-mutating for run.json. Initialization happens
# only after repository provenance and the Pulmu branch are known.
RUN_DETECT_OUTPUT="$(pulmu_run_context detect 2>/dev/null || true)"

if [[ -n "$(git status --porcelain)" ]]; then
  if grep -q '^PULMU_RUN_DETECTED=true$' <<<"$RUN_DETECT_OUTPUT" && grep -q '^PULMU_RUN_STATUS=running$' <<<"$RUN_DETECT_OUTPUT"; then
    DETECTED_RUN_ID="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$RUN_DETECT_OUTPUT")"
    printf '⚠ Previous Pulmu run detected: %s at %s on %s\n' \
      "$DETECTED_RUN_ID" \
      "$(sed -n 's/^PULMU_RUN_STAGE=//p' <<<"$RUN_DETECT_OUTPUT")" \
      "$(sed -n 's/^PULMU_RUN_BRANCH=//p' <<<"$RUN_DETECT_OUTPUT")" >&2
    printf '⚠ Existing run left unchanged because liveness cannot be determined safely\n' >&2
  elif grep -q '^PULMU_RUN_DETECTED=malformed$' <<<"$RUN_DETECT_OUTPUT"; then
    printf '⚠ Existing Pulmu Run Context is malformed; it was not changed\n' >&2
  fi
  pulmu_die "working tree is not clean; commit/stash your existing work before starting Pulmu"
fi

if grep -q '^PULMU_RUN_DETECTED=true$' <<<"$RUN_DETECT_OUTPUT" && grep -q '^PULMU_RUN_STATUS=running$' <<<"$RUN_DETECT_OUTPUT"; then
  DETECTED_RUN_ID="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$RUN_DETECT_OUTPUT")"
  pulmu_die "Pulmu run $DETECTED_RUN_ID is still running; continue or explicitly interrupt it before starting another task"
fi

if [[ -z "$(git config user.name || true)" || -z "$(git config user.email || true)" ]]; then
  pulmu_die "git user.name/user.email are not configured"
fi

CURRENT="$(git branch --show-current)"
GIT_DIR="$(pulmu_git_dir)"
METADATA_DIR="$(pulmu_metadata_dir)"
ORIGIN="$(pulmu_origin_url)"
DELIVERY="local"
if [[ "$PULMU_GITHUB_CREATE_PR" == "true" ]] && pulmu_github_ready; then
  DELIVERY="github"
fi

BASE="$(pulmu_base_branch)"

SLUG="${SLUG_OVERRIDE:-$(pulmu_slug "$TASK")}"
[[ "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || pulmu_die "Ignite slug must be lowercase kebab-case"
PREFIX="$(pulmu_task_type_prefix "$TYPE")"
BRANCH_NAME="${PULMU_GIT_BRANCH_PREFIX:+$PULMU_GIT_BRANCH_PREFIX/}$PREFIX/$SLUG"
if [[ -n "$BRANCH_OVERRIDE" ]]; then BRANCH_NAME="$BRANCH_OVERRIDE"; fi
# --branch accepts checkout shorthands; validate a literal heads ref instead.
[[ "$BRANCH_NAME" != -* ]] && git check-ref-format "refs/heads/$BRANCH_NAME" >/dev/null 2>&1 &&
  git check-ref-format --branch "$BRANCH_NAME" >/dev/null 2>&1 ||
  pulmu_die "invalid work branch name: $BRANCH_NAME"
BRANCH="$(pulmu_unique_branch "$BRANCH_NAME")"

RUN_CONTEXT_OUTPUT="$(pulmu_run_context init \
  --task-type "$TYPE" --task "$TASK" --base "$BASE" --branch "$BRANCH")"
RUN_ID="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$RUN_CONTEXT_OUTPUT")"
[[ -n "$RUN_ID" ]] || pulmu_die "Run Context initialization did not return a runId"

if ! git switch -c "$BRANCH" "$BASE" >/dev/null; then
  pulmu_run_context fail --code IGNITE_BRANCH_FAILED --message "could not create the prepared Pulmu branch" --expect-run-id "$RUN_ID" >/dev/null || true
  pulmu_die "could not create Pulmu branch: $BRANCH"
fi
printf '%s\n' "$BASE" > "$GIT_DIR/pulmu-base"
printf '%s\n' "$BRANCH" > "$GIT_DIR/pulmu-branch"
printf '%s\n' "$TASK" > "$GIT_DIR/pulmu-task"
mkdir -p "$METADATA_DIR"
rm -f "$METADATA_DIR"/* "$GIT_DIR/pulmu-ship-commit" "$GIT_DIR/pulmu-quench.log"
rm -rf "$GIT_DIR/pulmu-reviews"
pulmu_metadata_write version 1
pulmu_metadata_write status provisional
pulmu_metadata_write task "$TASK"
pulmu_metadata_write task_type "$TYPE"
pulmu_metadata_write base_branch "$BASE"
pulmu_metadata_write branch "$BRANCH"
pulmu_metadata_write slug "$SLUG"
pulmu_metadata_write run_id "$RUN_ID"

printf 'PULMU_REPO=%s\n' "$ROOT"
printf 'PULMU_BASE=%s\n' "$BASE"
printf 'PULMU_BRANCH=%s\n' "$BRANCH"
printf 'PULMU_TYPE=%s\n' "$TYPE"
printf 'PULMU_SLUG=%s\n' "$SLUG"
printf 'PULMU_ORIGIN=%s\n' "$ORIGIN"
printf 'PULMU_DELIVERY=%s\n' "$DELIVERY"
printf '%s\n' "$RUN_CONTEXT_OUTPUT"

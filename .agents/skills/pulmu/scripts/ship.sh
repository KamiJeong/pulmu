#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

TITLE=""
BODY_FILE=""
DRAFT=0
BASE_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="${2:-}"; shift 2 ;;
    --body-file) BODY_FILE="${2:-}"; shift 2 ;;
    --base) BASE_OVERRIDE="${2:-}"; shift 2 ;;
    --draft) DRAFT=1; shift ;;
    *) pulmu_die "unknown ship option: $1" ;;
  esac
done

[[ -n "$TITLE" ]] || pulmu_die "ship.sh requires --title"
pulmu_require git
pulmu_require gh
ROOT="$(pulmu_repo_root)"
cd "$ROOT"
gh auth status >/dev/null 2>&1 || pulmu_die "GitHub CLI is not authenticated"

BRANCH="$(git branch --show-current)"
[[ "$BRANCH" == pulmu/* ]] || pulmu_die "Ship requires a pulmu/* branch; current branch: $BRANCH"
BASE="$BASE_OVERRIDE"
[[ -n "$BASE" ]] || BASE="$(cat .git/pulmu-base 2>/dev/null || true)"
[[ -n "$BASE" ]] || BASE="$(pulmu_base_branch)"

if [[ -z "$(git status --porcelain)" ]]; then
  pulmu_die "there are no changes to ship"
fi

git add -A
if git diff --cached --quiet; then
  pulmu_die "there are no staged changes to commit"
fi

git commit -m "$TITLE"
git push -u origin "$BRANCH"

cleanup_body=0
if [[ -z "$BODY_FILE" ]]; then
  BODY_FILE="$ROOT/.git/pulmu-pr-body.md"
  cleanup_body=1
  TASK="$(cat .git/pulmu-task 2>/dev/null || true)"
  {
    printf '## Purpose\n\n%s\n\n' "${TASK:-Pulmu task}"
    printf '## Forge\n\n'
    printf -- '- 🔥 Ignite — branch prepared\n'
    printf -- '- 🔎 Inspect — repository mapped\n'
    printf -- '- 📐 Shape — implementation planned\n'
    printf -- '- 🔨 Hammer — change implemented\n'
    printf -- '- 🌊 Quench — verification completed\n'
    printf -- '- 🪨 Hone — independent review completed\n'
    printf -- '- 📦 Ship — commit and PR created\n\n'
    printf '## Verification\n\n```text\n'
    if [[ -f .git/pulmu-quench.log ]]; then tail -n 80 .git/pulmu-quench.log; else printf 'No Quench log available.\n'; fi
    printf '\n```\n'
  } > "$BODY_FILE"
fi

args=(pr create --base "$BASE" --head "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE")
[[ "$DRAFT" -eq 1 ]] && args+=(--draft)
PR_URL="$(gh "${args[@]}")"
printf 'PULMU_COMMIT=%s\n' "$(git rev-parse HEAD)"
printf 'PULMU_BRANCH=%s\n' "$BRANCH"
printf 'PULMU_BASE=%s\n' "$BASE"
printf 'PULMU_PR_URL=%s\n' "$PR_URL"

[[ "$cleanup_body" -eq 1 ]] || true

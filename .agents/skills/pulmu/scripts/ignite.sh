#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

TASK="${1:-}"
[[ -n "$TASK" ]] || pulmu_die "usage: ignite.sh '<task>'"

pulmu_require git
ROOT="$(pulmu_repo_root)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  pulmu_die "working tree is not clean; commit/stash your existing work before starting Pulmu"
fi

if [[ -z "$(git config user.name || true)" || -z "$(git config user.email || true)" ]]; then
  pulmu_die "git user.name/user.email are not configured"
fi

BASE="$(pulmu_base_branch)"
CURRENT="$(git branch --show-current)"
SLUG="$(pulmu_slug "$TASK")"
BRANCH="pulmu/$SLUG"
ORIGIN="$(pulmu_origin_url)"
DELIVERY="local"
if pulmu_github_ready; then
  DELIVERY="github"
fi

if [[ "$CURRENT" == pulmu/* ]]; then
  BRANCH="$CURRENT"
else
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    BRANCH="$BRANCH-$(date +%H%M%S)"
  fi
  git switch -c "$BRANCH" >/dev/null
fi

printf '%s\n' "$BASE" > .git/pulmu-base
printf '%s\n' "$BRANCH" > .git/pulmu-branch
printf '%s\n' "$TASK" > .git/pulmu-task

printf 'PULMU_REPO=%s\n' "$ROOT"
printf 'PULMU_BASE=%s\n' "$BASE"
printf 'PULMU_BRANCH=%s\n' "$BRANCH"
printf 'PULMU_ORIGIN=%s\n' "$ORIGIN"
printf 'PULMU_DELIVERY=%s\n' "$DELIVERY"

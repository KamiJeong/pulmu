#!/usr/bin/env bash
set -euo pipefail

pulmu_die() {
  printf '✗ %s\n' "$*" >&2
  exit 1
}

pulmu_require() {
  command -v "$1" >/dev/null 2>&1 || pulmu_die "required command not found: $1"
}

pulmu_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pulmu_die "not inside a Git repository"
}

pulmu_base_branch() {
  local head base
  head="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$head" ]]; then
    printf '%s\n' "${head#refs/remotes/origin/}"
    return
  fi
  for base in main master develop; do
    if git show-ref --verify --quiet "refs/heads/$base" || git show-ref --verify --quiet "refs/remotes/origin/$base"; then
      printf '%s\n' "$base"
      return
    fi
  done
  git branch --show-current
}

pulmu_slug() {
  local task="$1" slug hash
  slug="$(printf '%s' "$task" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[[:space:]]+/-/g; s/[^[:alnum:]_.-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' \
    | cut -c1-48)"
  if [[ -z "$slug" || "$slug" == "-" ]]; then
    if command -v sha256sum >/dev/null 2>&1; then
      hash="$(printf '%s' "$task" | sha256sum | cut -c1-10)"
    else
      hash="$(date +%Y%m%d%H%M%S)"
    fi
    slug="task-$hash"
  fi
  printf '%s\n' "$slug"
}

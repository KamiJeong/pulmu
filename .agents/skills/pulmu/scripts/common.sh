#!/usr/bin/env bash
set -euo pipefail

pulmu_die() { printf '✗ %s\n' "$*" >&2; exit 1; }
pulmu_require() { command -v "$1" >/dev/null 2>&1 || pulmu_die "required command not found: $1"; }
pulmu_require_python() {
  command -v python3 >/dev/null 2>&1 || pulmu_die "Python 3.10+ is required for Pulmu Run Context"
  python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1 ||
    pulmu_die "Python 3.10+ is required for Pulmu Run Context"
}
pulmu_repo_root() { git rev-parse --show-toplevel 2>/dev/null || pulmu_die "not inside a Git repository"; }

pulmu_git_dir() {
  local root git_dir
  root="$(pulmu_repo_root)"
  git_dir="$(git rev-parse --git-dir)"
  [[ "$git_dir" == /* ]] || git_dir="$root/$git_dir"
  printf '%s\n' "$git_dir"
}

pulmu_origin_url() { git remote get-url origin 2>/dev/null || true; }

pulmu_github_ready() {
  [[ -n "$(pulmu_origin_url)" ]] || return 1
  command -v gh >/dev/null 2>&1 || return 1
  gh auth status >/dev/null 2>&1 || return 1
  gh repo view --json nameWithOwner >/dev/null 2>&1
}

pulmu_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

pulmu_config_defaults() {
  PULMU_GIT_BRANCH_PREFIX="pulmu"
  PULMU_GIT_CONVENTIONAL_COMMITS="true"
  PULMU_GIT_BASE_BRANCH=""
  PULMU_GITHUB_CREATE_PR="true"
  PULMU_GITHUB_APPLY_LABELS="true"
  PULMU_GITHUB_CREATE_MISSING_LABELS="false"
  PULMU_GITHUB_FULL_FORGE_DRAFT="true"
  PULMU_POLICY_AUTO_MERGE="false"
  PULMU_POLICY_FORCE_PUSH="false"
}

pulmu_config_assign() {
  local section="$1" key="$2" value="$3" file="$4" line_no="$5"
  case "$section.$key" in
    git.branch_prefix)
      [[ "$value" =~ ^[a-z0-9][a-z0-9-]*$ ]] || pulmu_die "$file:$line_no invalid branch_prefix"
      PULMU_GIT_BRANCH_PREFIX="$value"
      ;;
    git.base_branch)
      git check-ref-format --branch "$value" >/dev/null 2>&1 || pulmu_die "$file:$line_no invalid base_branch"
      PULMU_GIT_BASE_BRANCH="$value"
      ;;
    git.conventional_commits) PULMU_GIT_CONVENTIONAL_COMMITS="$value" ;;
    github.create_pr) PULMU_GITHUB_CREATE_PR="$value" ;;
    github.apply_labels) PULMU_GITHUB_APPLY_LABELS="$value" ;;
    github.create_missing_labels) PULMU_GITHUB_CREATE_MISSING_LABELS="$value" ;;
    github.full_forge_draft) PULMU_GITHUB_FULL_FORGE_DRAFT="$value" ;;
    policy.auto_merge) PULMU_POLICY_AUTO_MERGE="$value" ;;
    policy.force_push) PULMU_POLICY_FORCE_PUSH="$value" ;;
    *) pulmu_die "$file:$line_no unsupported Pulmu config key: $section.$key" ;;
  esac
}

# Parse only the documented scalar TOML subset. The file is never sourced or eval'd.
pulmu_load_config() {
  local root="${1:-$(pulmu_repo_root)}" file section="" line raw key value line_no=0
  pulmu_config_defaults
  file="$root/.pulmu/config.toml"
  [[ -f "$file" ]] || return 0
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line_no=$((line_no + 1))
    line="$(pulmu_trim "$raw")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    if [[ "$line" =~ ^\[([a-z]+)\]$ ]]; then
      section="${BASH_REMATCH[1]}"
      case "$section" in git|github|policy) ;; *) pulmu_die "$file:$line_no unsupported section: $section" ;; esac
      continue
    fi
    [[ -n "$section" ]] || pulmu_die "$file:$line_no key outside a section"
    if [[ "$line" =~ ^([a-z_]+)[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*(#.*)?$ ]]; then
      key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"
    elif [[ "$line" =~ ^([a-z_]+)[[:space:]]*=[[:space:]]*\"([A-Za-z0-9._/-]+)\"[[:space:]]*(#.*)?$ ]]; then
      key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"
    else
      pulmu_die "$file:$line_no unsupported value; use a documented boolean or simple quoted string"
    fi
    pulmu_config_assign "$section" "$key" "$value" "$file" "$line_no"
  done < "$file"
  [[ "$PULMU_POLICY_AUTO_MERGE" == "false" ]] || pulmu_die "policy.auto_merge=true is not supported; Pulmu never auto-merges"
  [[ "$PULMU_POLICY_FORCE_PUSH" == "false" ]] || pulmu_die "policy.force_push=true is not supported; Pulmu never force-pushes"
}

pulmu_ref_exists() {
  local branch="$1"
  git show-ref --verify --quiet "refs/heads/$branch" || git show-ref --verify --quiet "refs/remotes/origin/$branch"
}

pulmu_instruction_base_branch() {
  local root="$1" file candidate
  while IFS= read -r file; do
    candidate="$(sed -nE 's/^[[:space:]]*(Pulmu[[:space:]]+)?(base|default)[[:space:]]+branch[[:space:]]*:[[:space:]]*`?([A-Za-z0-9._\/-]+)`?.*$/\3/ip' "$file" | head -n 1)"
    if [[ -n "$candidate" ]] && git check-ref-format --branch "$candidate" >/dev/null 2>&1 && pulmu_ref_exists "$candidate"; then
      printf '%s\n' "$candidate"; return 0
    fi
  done < <(find "$root" -name AGENTS.md -type f -not -path '*/.git/*' -print 2>/dev/null | LC_ALL=C sort)
  return 1
}

pulmu_github_default_branch() {
  local branch head
  if command -v gh >/dev/null 2>&1; then
    branch="$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || true)"
    if [[ -n "$branch" && "$branch" != "null" ]] && pulmu_ref_exists "$branch"; then printf '%s\n' "$branch"; return 0; fi
  fi
  head="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$head" ]]; then printf '%s\n' "${head#refs/remotes/origin/}"; return 0; fi
  return 1
}

pulmu_base_branch() {
  local root current candidate base
  root="$(pulmu_repo_root)"
  pulmu_load_config "$root"
  if [[ -n "$PULMU_GIT_BASE_BRANCH" ]]; then
    pulmu_ref_exists "$PULMU_GIT_BASE_BRANCH" || pulmu_die "configured base branch does not exist: $PULMU_GIT_BASE_BRANCH"
    printf '%s\n' "$PULMU_GIT_BASE_BRANCH"; return
  fi
  candidate="$(pulmu_instruction_base_branch "$root" || true)"
  if [[ -n "$candidate" ]]; then printf '%s\n' "$candidate"; return; fi
  current="$(git branch --show-current)"
  if [[ -n "$current" && "$current" != "$PULMU_GIT_BRANCH_PREFIX/"* ]]; then printf '%s\n' "$current"; return; fi
  candidate="$(pulmu_github_default_branch || true)"
  if [[ -n "$candidate" ]]; then printf '%s\n' "$candidate"; return; fi
  for base in main develop; do
    if pulmu_ref_exists "$base"; then printf '%s\n' "$base"; return; fi
  done
  pulmu_die "could not determine a safe existing base branch"
}

pulmu_task_type_valid() { case "$1" in feature|bugfix|refactor|docs|test|chore) return 0 ;; *) return 1 ;; esac; }
pulmu_task_type_prefix() {
  case "$1" in feature) printf 'feat\n' ;; bugfix) printf 'fix\n' ;; refactor|docs|test|chore) printf '%s\n' "$1" ;; *) pulmu_die "unsupported task type: $1" ;; esac
}
pulmu_task_type_label() {
  case "$1" in bugfix) printf 'type: bug\n' ;; feature|refactor|docs|test|chore) printf 'type: %s\n' "$1" ;; *) pulmu_die "unsupported task type: $1" ;; esac
}

pulmu_display_enum() {
  case "$1" in
    quick) printf 'Quick\n' ;; standard) printf 'Standard\n' ;; full) printf 'Full\n' ;;
    low) printf 'Low\n' ;; medium) printf 'Medium\n' ;; high) printf 'High\n' ;;
    feature) printf 'Feature\n' ;; bugfix) printf 'Bugfix\n' ;; refactor) printf 'Refactor\n' ;;
    docs) printf 'Docs\n' ;; test) printf 'Test\n' ;; chore) printf 'Chore\n' ;;
    *) printf '%s\n' "$1" ;;
  esac
}

pulmu_slug() {
  local task="$1" slug hash
  slug="$(printf '%s' "$task" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^[:alnum:]]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' | cut -c1-40)"
  slug="${slug%-}"
  if [[ -z "$slug" || "$slug" == "-" ]]; then
    if command -v sha256sum >/dev/null 2>&1; then hash="$(printf '%s' "$task" | sha256sum | cut -c1-10)"; else hash="$(printf '%s' "$task" | git hash-object --stdin | cut -c1-10)"; fi
    slug="task-$hash"
  fi
  printf '%s\n' "$slug"
}

pulmu_branch_available() {
  local branch="$1"
  git show-ref --verify --quiet "refs/heads/$branch" && return 1
  git show-ref --verify --quiet "refs/remotes/origin/$branch" && return 1
  if [[ -n "$(pulmu_origin_url)" ]] && git ls-remote --exit-code --heads origin "refs/heads/$branch" >/dev/null 2>&1; then return 1; fi
  return 0
}

pulmu_unique_branch() {
  local candidate="$1" numbered number=2
  if pulmu_branch_available "$candidate"; then printf '%s\n' "$candidate"; return; fi
  while :; do
    numbered="$candidate-$number"
    if pulmu_branch_available "$numbered"; then printf '%s\n' "$numbered"; return; fi
    number=$((number + 1))
  done
}

pulmu_metadata_dir() { printf '%s/pulmu-metadata\n' "$(pulmu_git_dir)"; }
pulmu_metadata_key_valid() {
  case "$1" in version|status|run_id|task|task_type|forge|risk|areas|pattern|security_review|compatibility_review|base_branch|branch|slug|title|summary|risk_reason|quench_fingerprint|hone_fingerprint|delivery_fingerprint) return 0 ;; *) return 1 ;; esac
}
pulmu_metadata_write() {
  local key="$1" value="$2" dir tmp
  pulmu_metadata_key_valid "$key" || pulmu_die "invalid metadata key: $key"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || pulmu_die "metadata value for $key must be one line"
  dir="$(pulmu_metadata_dir)"; mkdir -p "$dir"; tmp="$dir/.$key.$$"
  printf '%s\n' "$value" > "$tmp"; mv "$tmp" "$dir/$key"
}
pulmu_metadata_read() {
  local key="$1" dir reply
  pulmu_metadata_key_valid "$key" || pulmu_die "invalid metadata key: $key"
  dir="$(pulmu_metadata_dir)"; [[ -f "$dir/$key" ]] || return 1
  IFS= read -r reply < "$dir/$key" || true; printf '%s\n' "$reply"
}

pulmu_changed_paths() {
  # Git emits each list deterministically; tracked and untracked sets cannot overlap.
  { git diff --name-only -z HEAD; git ls-files --others --exclude-standard -z; }
}
pulmu_changed_fingerprint() {
  local path
  {
    git diff --binary HEAD
    while IFS= read -r -d '' path; do printf 'untracked:%s:' "$path"; git hash-object -- "$path"; done < <(git ls-files --others --exclude-standard -z)
  } | git hash-object --stdin
}
pulmu_evidence_matches() {
  local key="$1" expected actual
  expected="$(pulmu_metadata_read "$key" 2>/dev/null || true)"; [[ -n "$expected" ]] || return 1
  actual="$(pulmu_changed_fingerprint)"; [[ "$expected" == "$actual" ]]
}

pulmu_run_context() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  bash "$script_dir/run-context.sh" "$@"
}

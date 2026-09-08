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

pulmu_github_repo_from_url() {
  local url="$1" host path
  case "$url" in
    git@*:*/*) host="${url#git@}"; host="${host%%:*}"; path="${url#*:}" ;;
    ssh://git@*/*) host="${url#ssh://git@}"; host="${host%%/*}"; path="${url#ssh://git@*/}" ;;
    https://*/*|http://*/*) host="${url#*://}"; host="${host%%/*}"; path="${url#*://*/}" ;;
    *) return 1 ;;
  esac
  path="${path%/}"; path="${path%.git}"
  [[ "$host" =~ ^[A-Za-z0-9.-]+$ && "$path" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]] || return 1
  printf '%s/%s\n' "$host" "$path"
}

pulmu_github_ready() {
  local repo host
  repo="$(pulmu_github_repo)" || return 1
  if [[ "$repo" == */*/* ]]; then host="${repo%%/*}"; else host="github.com"; fi
  command -v gh >/dev/null 2>&1 || return 1
  gh auth status --hostname "$host" >/dev/null 2>&1 || return 1
  gh repo view "$repo" --json nameWithOwner >/dev/null 2>&1
}

pulmu_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

pulmu_config_defaults() {
  PULMU_GIT_BRANCH_PREFIX=""
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
  [[ -n "$value" || "$section.$key" == "git.branch_prefix" ]] || pulmu_die "$file:$line_no empty value is only supported for branch_prefix"
  case "$section.$key" in
    git.branch_prefix)
      [[ -z "$value" || "$value" =~ ^[a-z0-9][a-z0-9-]*$ ]] || pulmu_die "$file:$line_no invalid branch_prefix"
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
    elif [[ "$line" =~ ^([a-z_]+)[[:space:]]*=[[:space:]]*\"([A-Za-z0-9._/-]*)\"[[:space:]]*(#.*)?$ ]]; then
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
  local branch head repo
  repo="$(pulmu_github_repo 2>/dev/null || true)"
  if command -v gh >/dev/null 2>&1 && [[ -n "$repo" ]]; then
    branch="$(gh repo view "$repo" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || true)"
    if [[ -n "$branch" && "$branch" != "null" ]] && pulmu_ref_exists "$branch"; then printf '%s\n' "$branch"; return 0; fi
  fi
  head="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$head" ]]; then printf '%s\n' "${head#refs/remotes/origin/}"; return 0; fi
  return 1
}

# Return 0 with a verified recorded base, 1 for an unrecorded branch, or 2
# for conflicting provenance. Naming conventions never establish ownership.
pulmu_recorded_base() {
  local current git_dir mirror_branch mirror_base canonical_branch canonical_base canonical_id
  local state_json state_record state_branch="" state_base="" state_id="" state_valid="false"
  current="$(git branch --show-current)"; [[ -n "$current" ]] || return 1
  git_dir="$(pulmu_git_dir)"
  mirror_branch="$(sed -n '1p' "$git_dir/pulmu-branch" 2>/dev/null || true)"
  mirror_base="$(sed -n '1p' "$git_dir/pulmu-base" 2>/dev/null || true)"
  canonical_branch="$(pulmu_metadata_read branch 2>/dev/null || true)"
  canonical_base="$(pulmu_metadata_read base_branch 2>/dev/null || true)"
  canonical_id="$(pulmu_metadata_read run_id 2>/dev/null || true)"
  if state_json="$(pulmu_run_context show 2>/dev/null)"; then
    state_record="$(python3 -c 'import json,sys; s=json.load(sys.stdin); print(s["git"]["branch"] or ""); print(s["git"]["baseBranch"] or ""); print(s["runId"])' <<<"$state_json")" || return 2
    state_branch="$(sed -n '1p' <<<"$state_record")"
    state_base="$(sed -n '2p' <<<"$state_record")"
    state_id="$(sed -n '3p' <<<"$state_record")"
    state_valid="true"
  fi
  [[ "$mirror_branch" == "$current" || "$canonical_branch" == "$current" || "$state_branch" == "$current" ]] || return 1
  if [[ "$mirror_branch" != "$current" || -z "$mirror_base" ]] ||
     { [[ -n "$canonical_branch" || -n "$canonical_base" || -n "$canonical_id" ]] && [[ "$canonical_branch" != "$current" || "$canonical_base" != "$mirror_base" ]]; } ||
     { [[ "$state_valid" == "true" ]] && [[ "$state_branch" != "$current" || "$state_base" != "$mirror_base" || ( -n "$canonical_id" && "$canonical_id" != "$state_id" ) ]]; } ||
     { [[ "$state_valid" == "false" ]] && [[ -e "$git_dir/pulmu/run.json" || -n "$canonical_id" ]]; }; then
    printf '✗ recorded branch has missing or conflicting Pulmu provenance\n' >&2
    return 2
  fi
  if ! pulmu_ref_exists "$mirror_base"; then
    printf '✗ recorded Pulmu base branch does not exist: %s\n' "$mirror_base" >&2
    return 2
  fi
  printf '%s\n' "$mirror_base"
}

pulmu_base_branch() {
  local root current candidate base recorded="" status
  root="$(pulmu_repo_root)"
  pulmu_load_config "$root"
  if recorded="$(pulmu_recorded_base)"; then :; else
    status=$?; [[ "$status" -eq 1 ]] || return "$status"
  fi
  if [[ -n "$recorded" ]]; then printf '%s\n' "$recorded"; return; fi
  if [[ -n "$PULMU_GIT_BASE_BRANCH" ]]; then
    pulmu_ref_exists "$PULMU_GIT_BASE_BRANCH" || pulmu_die "configured base branch does not exist: $PULMU_GIT_BASE_BRANCH"
    printf '%s\n' "$PULMU_GIT_BASE_BRANCH"; return
  fi
  candidate="$(pulmu_instruction_base_branch "$root" || true)"
  if [[ -n "$candidate" ]]; then printf '%s\n' "$candidate"; return; fi
  current="$(git branch --show-current)"
  if [[ -n "$current" ]]; then printf '%s\n' "$current"; return; fi
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
  case "$1" in version|status|run_id|task|task_type|forge|risk|areas|pattern|execution_mode|writer|review_mode|test_review|security_review|compatibility_review|base_branch|branch|slug|title|summary|risk_reason|candidate_tree|candidate_head|candidate_branch|candidate_base|candidate_base_head|quench_fingerprint|hone_fingerprint|delivery_fingerprint|github_repo) return 0 ;; *) return 1 ;; esac
}
pulmu_metadata_write() {
  local key="$1" value="$2" dir tmp
  pulmu_metadata_key_valid "$key" || pulmu_die "invalid metadata key: $key"
  if [[ "$key" != "task" ]]; then
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || pulmu_die "metadata value for $key must be one line"
  fi
  dir="$(pulmu_metadata_dir)"; mkdir -p "$dir"; tmp="$dir/.$key.$$"
  printf '%s\n' "$value" > "$tmp"; mv "$tmp" "$dir/$key"
}
pulmu_metadata_read() {
  local key="$1" dir reply
  pulmu_metadata_key_valid "$key" || pulmu_die "invalid metadata key: $key"
  dir="$(pulmu_metadata_dir)"; [[ -f "$dir/$key" ]] || return 1
  if [[ "$key" == "task" ]]; then cat "$dir/$key"; else IFS= read -r reply < "$dir/$key" || true; printf '%s\n' "$reply"; fi
}

pulmu_changed_paths() {
  # Git emits each list deterministically; tracked and untracked sets cannot overlap.
  { git diff --name-only -z HEAD; git ls-files --others --exclude-standard -z; }
}
pulmu_candidate_tree() (
  local index tree
  if [[ -f .gitmodules ]]; then
    git submodule foreach --quiet --recursive 'test -z "$(git status --porcelain --untracked-files=all)"' ||
      pulmu_die "candidate contains dirty or untracked submodule content"
  fi
  index="$(mktemp "$(pulmu_git_dir)/pulmu-candidate-index.XXXXXX")"
  rm -f "$index"
  trap 'rm -f "$index"' EXIT HUP INT TERM
  if GIT_INDEX_FILE="$index" git read-tree HEAD && GIT_INDEX_FILE="$index" git add -A -- :/; then
    tree="$(GIT_INDEX_FILE="$index" git write-tree)"
  else
    return 1
  fi
  printf '%s\n' "$tree"
)
pulmu_candidate_identity() {
  local run_id="$1" branch="$2" base="$3" base_head="$4" head="$5" tree="$6"
  printf 'run=%s\nbranch=%s\nbase=%s\nbase_head=%s\nhead=%s\ntree=%s\n' "$run_id" "$branch" "$base" "$base_head" "$head" "$tree" | git hash-object --stdin
}
pulmu_changed_fingerprint() {
  local run_id branch base base_head head tree
  run_id="$(pulmu_metadata_read run_id 2>/dev/null || true)"
  branch="$(git branch --show-current)"
  base="$(pulmu_metadata_read base_branch 2>/dev/null || true)"
  base_head="$(git rev-parse "$base")"
  head="$(git rev-parse HEAD)"
  tree="$(pulmu_candidate_tree)"
  pulmu_candidate_identity "$run_id" "$branch" "$base" "$base_head" "$head" "$tree"
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

pulmu_github_repo() {
  local fetch_url push_url fetch_repo push_repo fetch_key push_key
  fetch_url="$(git remote get-url --all origin 2>/dev/null)" || return 1
  push_url="$(git remote get-url --push --all origin 2>/dev/null)" || return 1
  [[ -n "$fetch_url" && "$fetch_url" != *$'\n'* && -n "$push_url" && "$push_url" != *$'\n'* ]] || return 1
  fetch_repo="$(pulmu_github_repo_from_url "$fetch_url")" || return 1
  push_repo="$(pulmu_github_repo_from_url "$push_url")" || return 1
  fetch_key="$(printf '%s' "$fetch_repo" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
  push_key="$(printf '%s' "$push_repo" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
  [[ "$fetch_key" == "$push_key" ]] || return 1
  printf '%s\n' "$fetch_repo"
}

pulmu_github_pr_url_matches() {
  local url="$1" repo="$2" prefix number url_key prefix_key
  prefix="https://$repo/pull/"
  url_key="$(printf '%s' "$url" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
  prefix_key="$(printf '%s' "$prefix" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
  [[ "$url_key" == "$prefix_key"* ]] || return 1
  number="${url#"$prefix"}"
  if [[ "$number" == "$url" ]]; then number="${url_key#"$prefix_key"}"; fi
  [[ "$number" =~ ^[1-9][0-9]*$ ]]
}

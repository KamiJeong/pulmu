#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() { pulmu_die "usage: metadata.sh finalize|hone|delivery [options]"; }
ROOT="$(pulmu_repo_root)"; cd "$ROOT"
COMMAND="${1:-}"; [[ -n "$COMMAND" ]] || usage; shift
pulmu_load_config "$ROOT"

pulmu_metadata_guard() {
  local expected="$1" stored detected current status
  stored="$(pulmu_metadata_read run_id 2>/dev/null || true)"
  [[ -n "$expected" ]] || pulmu_die "metadata operation requires --expect-run-id from Ignite"
  [[ -n "$stored" ]] || pulmu_die "Pulmu metadata has no runId; finalize legacy metadata first"
  [[ "$stored" == "$expected" ]] || pulmu_die "metadata runId changed; refusing stale operation"
  detected="$(pulmu_run_context detect 2>/dev/null || true)"
  current="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$detected")"
  status="$(sed -n 's/^PULMU_RUN_STATUS=//p' <<<"$detected")"
  [[ "$current" == "$expected" ]] || pulmu_die "Run Context runId changed; refusing stale metadata operation"
  [[ "$status" == "running" ]] || pulmu_die "Run Context is not running; refusing metadata operation"
}

pulmu_bootstrap_context() {
  local task="$1" type="$2" base="$3" branch="$4" expected="$5" detected output current status state_json
  detected="$(pulmu_run_context detect 2>/dev/null || true)"
  case "$detected" in
    *'PULMU_RUN_DETECTED=true'*)
      current="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$detected")"
      status="$(sed -n 's/^PULMU_RUN_STATUS=//p' <<<"$detected")"
      if [[ "$status" == "running" ]]; then
        state_json="$(pulmu_run_context show)"
        python3 -c 'import json, sys
state = json.load(sys.stdin)
expected = {"prompt": sys.argv[1], "type": sys.argv[2], "base": sys.argv[3], "branch": sys.argv[4]}
actual = {"prompt": state["task"]["prompt"], "type": state["task"]["type"], "base": state["git"]["baseBranch"], "branch": state["git"]["branch"]}
raise SystemExit(0 if actual == expected else 1)' "$task" "$type" "$base" "$branch" <<<"$state_json" ||
          pulmu_die "legacy metadata conflicts with the active running Run Context"
      else
        [[ -z "$expected" ]] || pulmu_die "terminal Run Context cannot satisfy the expected legacy runId"
        output="$(pulmu_run_context init --task-type "$type" --task "$task" --base "$base" --branch "$branch")"
        current="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$output")"
      fi
      ;;
    *'PULMU_RUN_DETECTED=false'*)
      output="$(pulmu_run_context init --task-type "$type" --task "$task" --base "$base" --branch "$branch")"
      current="$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$output")"
      ;;
    *) pulmu_die "legacy metadata cannot bootstrap from malformed Run Context" ;;
  esac
  [[ -n "$current" ]] || pulmu_die "legacy Run Context bootstrap did not return a runId"
  [[ -z "$expected" || "$expected" == "$current" ]] || pulmu_die "Run Context runId changed; refusing stale legacy migration"
  pulmu_metadata_write run_id "$current"
  printf '%s\n' "$current"
}

case "$COMMAND" in
  finalize)
    TYPE=""; FORGE=""; RISK=""; AREAS=""; PATTERN=""; SECURITY=""; COMPAT=""; EXPECT_RUN_ID=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --type) TYPE="${2:-}"; shift 2 ;; --forge) FORGE="${2:-}"; shift 2 ;; --risk) RISK="${2:-}"; shift 2 ;;
        --areas) AREAS="${2:-}"; shift 2 ;; --pattern) PATTERN="${2:-}"; shift 2 ;;
        --security-review) SECURITY="${2:-}"; shift 2 ;; --compatibility-review) COMPAT="${2:-}"; shift 2 ;;
        --expect-run-id) EXPECT_RUN_ID="${2:-}"; shift 2 ;;
        *) pulmu_die "unknown metadata finalize option: $1" ;;
      esac
    done
    pulmu_task_type_valid "$TYPE" || pulmu_die "metadata --type must be feature, bugfix, refactor, docs, test, or chore"
    case "$FORGE" in quick|standard|full) ;; *) pulmu_die "metadata --forge must be quick, standard, or full" ;; esac
    case "$RISK" in low|medium|high) ;; *) pulmu_die "metadata --risk must be low, medium, or high" ;; esac
    for boolean in "$PATTERN" "$SECURITY" "$COMPAT"; do [[ "$boolean" == "true" || "$boolean" == "false" ]] || pulmu_die "metadata review and Pattern flags must be true or false"; done
    declare -a selected=()
    IFS=',' read -r -a requested <<< "$AREAS"
    if [[ "$PATTERN" == "true" ]]; then
      if [[ "${#requested[@]}" -gt 0 ]]; then requested=(frontend design "${requested[@]}"); else requested=(frontend design); fi
    fi
    if [[ "${#requested[@]}" -gt 0 ]]; then
      for area in "${requested[@]}"; do
        area="$(pulmu_trim "$area")"; [[ -n "$area" ]] || continue
        [[ "$area" =~ ^[a-z][a-z0-9-]*$ ]] || pulmu_die "invalid metadata area: $area"
        duplicate="false"
        if [[ "${#selected[@]}" -gt 0 ]]; then
          for existing_area in "${selected[@]}"; do [[ "$existing_area" == "$area" ]] && duplicate="true"; done
        fi
        [[ "$duplicate" == "true" ]] || selected+=("$area")
      done
    fi
    [[ "${#selected[@]}" -gt 0 ]] || pulmu_die "metadata requires at least one area"
    [[ "${#selected[@]}" -le 3 ]] || pulmu_die "metadata supports at most three relevant areas"
    AREAS="$(IFS=,; printf '%s' "${selected[*]}")"
    existing_status="$(pulmu_metadata_read status 2>/dev/null || true)"
    if [[ -z "$existing_status" ]]; then
      # Upgrade an active branch prepared by an older Ignite while preserving its mirrors.
      git_dir="$(pulmu_git_dir)"; branch="$(git branch --show-current)"
      legacy_branch="$(sed -n '1p' "$git_dir/pulmu-branch" 2>/dev/null || true)"
      legacy_base="$(sed -n '1p' "$git_dir/pulmu-base" 2>/dev/null || true)"
      legacy_task="$(sed -n '1p' "$git_dir/pulmu-task" 2>/dev/null || true)"
      [[ -n "$legacy_base" && "$legacy_branch" == "$branch" && "$branch" == "$PULMU_GIT_BRANCH_PREFIX/"* ]] || pulmu_die "Ignite metadata is missing; run ignite.sh first"
      pulmu_ref_exists "$legacy_base" || pulmu_die "recorded legacy base branch does not exist: $legacy_base"
      EXPECT_RUN_ID="$(pulmu_bootstrap_context "$legacy_task" "$TYPE" "$legacy_base" "$branch" "$EXPECT_RUN_ID")"
      pulmu_metadata_write version 1; pulmu_metadata_write status provisional; pulmu_metadata_write task "$legacy_task"
      pulmu_metadata_write run_id "$EXPECT_RUN_ID"; pulmu_metadata_write task_type "$TYPE"; pulmu_metadata_write base_branch "$legacy_base"; pulmu_metadata_write branch "$branch"; pulmu_metadata_write slug "${branch##*/}"
      existing_status="provisional"
    elif [[ -z "$(pulmu_metadata_read run_id 2>/dev/null || true)" ]]; then
      EXPECT_RUN_ID="$(pulmu_bootstrap_context \
        "$(pulmu_metadata_read task)" "$(pulmu_metadata_read task_type)" \
        "$(pulmu_metadata_read base_branch)" "$(pulmu_metadata_read branch)" "$EXPECT_RUN_ID")"
    fi
    pulmu_metadata_guard "$EXPECT_RUN_ID"
    git_dir="$(pulmu_git_dir)"
    mirror_base="$(sed -n '1p' "$git_dir/pulmu-base" 2>/dev/null || true)"
    mirror_branch="$(sed -n '1p' "$git_dir/pulmu-branch" 2>/dev/null || true)"
    [[ -n "$mirror_base" && "$mirror_base" == "$(pulmu_metadata_read base_branch 2>/dev/null || true)" ]] || pulmu_die "canonical base branch conflicts with .git/pulmu-base"
    [[ -n "$mirror_branch" && "$mirror_branch" == "$(pulmu_metadata_read branch 2>/dev/null || true)" ]] || pulmu_die "canonical branch conflicts with .git/pulmu-branch"
    pulmu_ref_exists "$mirror_base" || pulmu_die "recorded Pulmu base branch does not exist: $mirror_base"
    if [[ "$existing_status" == "final" ]]; then
      [[ "$(pulmu_metadata_read task_type)" == "$TYPE" && "$(pulmu_metadata_read forge)" == "$FORGE" && "$(pulmu_metadata_read risk)" == "$RISK" && "$(pulmu_metadata_read areas)" == "$AREAS" && "$(pulmu_metadata_read pattern)" == "$PATTERN" && "$(pulmu_metadata_read security_review)" == "$SECURITY" && "$(pulmu_metadata_read compatibility_review)" == "$COMPAT" ]] || pulmu_die "Pulmu task metadata is already finalized and cannot be re-inferred"
      pulmu_run_context sync-metadata \
        --type "$TYPE" --forge "$FORGE" --risk "$RISK" --areas "$AREAS" --pattern "$PATTERN" \
        --base "$(pulmu_metadata_read base_branch)" --branch "$(pulmu_metadata_read branch)" \
        --expect-run-id "$EXPECT_RUN_ID" >/dev/null
      printf 'PULMU_METADATA_STATUS=final\nPULMU_RUN_ID=%s\n' "$EXPECT_RUN_ID"; exit 0
    fi
    [[ "$existing_status" == "provisional" ]] || pulmu_die "Ignite metadata is missing; run ignite.sh first"
    [[ "$(pulmu_metadata_read task_type)" == "$TYPE" ]] || pulmu_die "final task type must match the type used for branch naming during Ignite"
    branch="$(git branch --show-current)"; [[ "$(pulmu_metadata_read branch)" == "$branch" ]] || pulmu_die "metadata branch does not match the current branch"
    pulmu_metadata_write task_type "$TYPE"; pulmu_metadata_write forge "$FORGE"; pulmu_metadata_write risk "$RISK"; pulmu_metadata_write areas "$AREAS"
    pulmu_metadata_write pattern "$PATTERN"; pulmu_metadata_write security_review "$SECURITY"; pulmu_metadata_write compatibility_review "$COMPAT"; pulmu_metadata_write status final
    pulmu_run_context sync-metadata \
      --type "$TYPE" --forge "$FORGE" --risk "$RISK" --areas "$AREAS" --pattern "$PATTERN" \
      --base "$(pulmu_metadata_read base_branch)" --branch "$(pulmu_metadata_read branch)" \
      --expect-run-id "$EXPECT_RUN_ID" >/dev/null
    printf 'PULMU_METADATA_STATUS=final\nPULMU_RUN_ID=%s\nPULMU_TYPE=%s\nPULMU_FORGE=%s\nPULMU_RISK=%s\nPULMU_AREAS=%s\nPULMU_PATTERN=%s\n' "$EXPECT_RUN_ID" "$TYPE" "$FORGE" "$RISK" "$AREAS" "$PATTERN"
    ;;
  hone)
    RESULT=""; EXPECT_RUN_ID=""
    while [[ $# -gt 0 ]]; do case "$1" in --result) RESULT="${2:-}"; shift 2 ;; --expect-run-id) EXPECT_RUN_ID="${2:-}"; shift 2 ;; *) pulmu_die "unknown metadata hone option: $1" ;; esac; done
    pulmu_metadata_guard "$EXPECT_RUN_ID"
    [[ "$RESULT" == "pass" ]] || pulmu_die "Hone evidence must be an explicit pass"
    [[ "$(pulmu_metadata_read status 2>/dev/null || true)" == "final" ]] || pulmu_die "task metadata must be finalized before Hone evidence"
    pulmu_evidence_matches quench_fingerprint || pulmu_die "Hone diff does not match the passing Quench diff"
    pulmu_metadata_write hone_fingerprint "$(pulmu_changed_fingerprint)"; printf 'PULMU_HONE=PASS\n'
    ;;
  delivery)
    TITLE=""; SUMMARY=""; RISK_REASON=""; EXPECT_RUN_ID=""; declare -a CHANGES=() FOCUS=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --title) TITLE="${2:-}"; shift 2 ;; --summary) SUMMARY="${2:-}"; shift 2 ;; --change) CHANGES+=("${2:-}"); shift 2 ;;
        --review-focus) FOCUS+=("${2:-}"); shift 2 ;; --risk-reason) RISK_REASON="${2:-}"; shift 2 ;;
        --expect-run-id) EXPECT_RUN_ID="${2:-}"; shift 2 ;; *) pulmu_die "unknown metadata delivery option: $1" ;;
      esac
    done
    pulmu_metadata_guard "$EXPECT_RUN_ID"
    [[ "$(pulmu_metadata_read status 2>/dev/null || true)" == "final" ]] || pulmu_die "task metadata must be finalized before delivery metadata"
    pulmu_evidence_matches quench_fingerprint || pulmu_die "delivery diff does not match the passing Quench diff"
    pulmu_evidence_matches hone_fingerprint || pulmu_die "delivery diff does not match the non-blocking Hone diff"
    [[ -n "$TITLE" && -n "$SUMMARY" && "${#CHANGES[@]}" -gt 0 ]] || pulmu_die "delivery metadata requires --title, --summary, and at least one --change"
    [[ "$TITLE" != *$'\n'* && "$SUMMARY" != *$'\n'* ]] || pulmu_die "delivery title and summary must each be one line"
    if [[ "$PULMU_GIT_CONVENTIONAL_COMMITS" == "true" ]]; then
      expected="$(pulmu_task_type_prefix "$(pulmu_metadata_read task_type)")"
      [[ "$TITLE" =~ ^${expected}(\([a-z0-9._/-]+\))?:[[:space:]][^[:space:]].*$ ]] || pulmu_die "delivery title must be a meaningful Conventional Commit matching task type $expected"
    fi
    dir="$(pulmu_metadata_dir)"; pulmu_metadata_write title "$TITLE"; pulmu_metadata_write summary "$SUMMARY"; pulmu_metadata_write risk_reason "$RISK_REASON"
    : > "$dir/changes"
    for item in "${CHANGES[@]}"; do [[ -n "$item" && "$item" != *$'\n'* ]] || pulmu_die "each change must be one non-empty line"; printf '%s\n' "$item" >> "$dir/changes"; done
    : > "$dir/review-focus"
    if [[ "${#FOCUS[@]}" -gt 0 ]]; then
      for item in "${FOCUS[@]}"; do [[ -n "$item" && "$item" != *$'\n'* ]] || pulmu_die "each review focus must be one non-empty line"; printf '%s\n' "$item" >> "$dir/review-focus"; done
    fi
    pulmu_changed_paths > "$dir/paths.z"; [[ -s "$dir/paths.z" ]] || pulmu_die "there are no changed paths to deliver"
    pulmu_metadata_write delivery_fingerprint "$(pulmu_changed_fingerprint)"
    printf 'PULMU_DELIVERY_METADATA=ready\nPULMU_TITLE=%s\n' "$TITLE"
    ;;
  *) usage ;;
esac

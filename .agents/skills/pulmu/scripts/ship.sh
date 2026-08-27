#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

TITLE_OVERRIDE=""
BODY_FILE=""
DRAFT=0
BASE_OVERRIDE=""
DELIVERY="auto"
EXPECT_RUN_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE_OVERRIDE="${2:-}"; shift 2 ;;
    --body-file) BODY_FILE="${2:-}"; shift 2 ;;
    --base) BASE_OVERRIDE="${2:-}"; shift 2 ;;
    --delivery) DELIVERY="${2:-}"; shift 2 ;;
    --expect-run-id) EXPECT_RUN_ID="${2:-}"; shift 2 ;;
    --draft) DRAFT=1; shift ;;
    *) pulmu_die "unknown ship option: $1" ;;
  esac
done

case "$DELIVERY" in auto|local|github) ;; *) pulmu_die "ship.sh --delivery must be auto, local, or github" ;; esac
pulmu_require git
ROOT="$(pulmu_repo_root)"; cd "$ROOT"
pulmu_load_config "$ROOT"
GIT_DIR="$(pulmu_git_dir)"
METADATA_DIR="$(pulmu_metadata_dir)"

[[ -n "$EXPECT_RUN_ID" ]] || pulmu_die "Ship requires --expect-run-id from Ignite"
[[ "$(pulmu_metadata_read run_id 2>/dev/null || true)" == "$EXPECT_RUN_ID" ]] || pulmu_die "Ship metadata runId changed; refusing stale operation"
RUN_DETECT_OUTPUT="$(pulmu_run_context detect 2>/dev/null || true)"
[[ "$(sed -n 's/^PULMU_RUN_ID=//p' <<<"$RUN_DETECT_OUTPUT")" == "$EXPECT_RUN_ID" ]] || pulmu_die "Run Context runId changed; refusing stale Ship operation"
[[ "$(pulmu_metadata_read status 2>/dev/null || true)" == "final" ]] || pulmu_die "Ship requires finalized Pulmu task metadata"
BRANCH="$(git branch --show-current)"
[[ "$BRANCH" == "$(pulmu_metadata_read branch)" ]] || pulmu_die "Ship branch does not match finalized metadata: $BRANCH"
[[ "$(sed -n '1p' "$GIT_DIR/pulmu-branch" 2>/dev/null || true)" == "$BRANCH" ]] || pulmu_die "Ship branch conflicts with .git/pulmu-branch provenance"
BASE="${BASE_OVERRIDE:-$(pulmu_metadata_read base_branch 2>/dev/null || true)}"
[[ -n "$BASE" ]] || BASE="$(pulmu_base_branch)"
[[ "$(sed -n '1p' "$GIT_DIR/pulmu-base" 2>/dev/null || true)" == "$BASE" ]] || pulmu_die "Ship base conflicts with .git/pulmu-base provenance"
pulmu_ref_exists "$BASE" || pulmu_die "Ship base branch does not exist: $BASE"
if [[ -n "$BASE_OVERRIDE" && "$BASE_OVERRIDE" != "$(pulmu_metadata_read base_branch)" ]]; then
  pulmu_die "Ship --base cannot override finalized base-branch metadata"
fi
TITLE="$(pulmu_metadata_read title 2>/dev/null || true)"
[[ -n "$TITLE" ]] || pulmu_die "Ship requires generated delivery metadata; run metadata.sh delivery"
if [[ -n "$TITLE_OVERRIDE" && "$TITLE_OVERRIDE" != "$TITLE" ]]; then
  pulmu_die "Ship title must match the generated delivery metadata"
fi
[[ -f "$METADATA_DIR/changes" && -f "$METADATA_DIR/paths.z" ]] || pulmu_die "Ship delivery metadata is incomplete"
pulmu_run_context set-stage ship --expect-run-id "$EXPECT_RUN_ID" >/dev/null
SUPPLEMENTAL_BODY_FILE="$BODY_FILE"
if [[ -n "$SUPPLEMENTAL_BODY_FILE" ]]; then
  [[ -f "$SUPPLEMENTAL_BODY_FILE" ]] || pulmu_die "supplemental PR body file does not exist: $SUPPLEMENTAL_BODY_FILE"
  SUPPLEMENT_COPY="$GIT_DIR/pulmu-pr-supplement.md"
  cp "$SUPPLEMENTAL_BODY_FILE" "$SUPPLEMENT_COPY"
fi

if [[ "$DELIVERY" == "auto" ]]; then
  if [[ "$PULMU_GITHUB_CREATE_PR" == "true" ]] && pulmu_github_ready; then DELIVERY="github"; else DELIVERY="local"; fi
elif [[ "$DELIVERY" == "github" ]]; then
  [[ "$PULMU_GITHUB_CREATE_PR" == "true" ]] || pulmu_die "GitHub PR delivery is disabled by .pulmu/config.toml"
  [[ -n "$(pulmu_origin_url)" ]] || pulmu_die "GitHub delivery requires an origin remote"
  pulmu_require gh
  gh auth status >/dev/null 2>&1 || pulmu_die "GitHub delivery requires an authenticated GitHub CLI; run: gh auth login"
  gh repo view --json nameWithOwner >/dev/null 2>&1 || pulmu_die "origin is not an accessible GitHub repository"
fi

SHIP_STATE="$GIT_DIR/pulmu-ship-commit"
RESUME=0
if [[ -f "$SHIP_STATE" ]]; then
  IFS= read -r STORED_COMMIT < "$SHIP_STATE" || true
  if [[ -n "$STORED_COMMIT" && "$(git rev-parse HEAD)" == "$STORED_COMMIT" && -z "$(git status --porcelain)" ]]; then
    RESUME=1
  fi
fi

if [[ "$RESUME" -eq 0 ]]; then
  pulmu_evidence_matches quench_fingerprint || pulmu_die "Ship requires Quench PASS evidence for the exact final diff"
  pulmu_evidence_matches hone_fingerprint || pulmu_die "Ship requires non-blocking Hone evidence for the exact final diff"
  pulmu_evidence_matches delivery_fingerprint || pulmu_die "working tree changed after delivery metadata was generated"
  PATHS=()
  while IFS= read -r -d '' path; do PATHS+=("$path"); done < "$METADATA_DIR/paths.z"
  [[ "${#PATHS[@]}" -gt 0 ]] || pulmu_die "there are no expected paths to ship"
  git add -- "${PATHS[@]}"
  git diff --cached --quiet && pulmu_die "there are no staged changes to commit"
  git commit -m "$TITLE"
  COMMIT="$(git rev-parse HEAD)"
  printf '%s\n' "$COMMIT" > "$SHIP_STATE"
else
  COMMIT="$STORED_COMMIT"
fi

printf 'PULMU_COMMIT=%s\n' "$COMMIT"
printf 'PULMU_BRANCH=%s\n' "$BRANCH"
printf 'PULMU_BASE=%s\n' "$BASE"
printf 'PULMU_DELIVERY=%s\n' "$DELIVERY"

if [[ "$DELIVERY" == "local" ]]; then
  pulmu_run_context complete --delivery local --commit "$COMMIT" --expect-run-id "$EXPECT_RUN_ID" >/dev/null
  exit 0
fi

# A normal upstream push is the only push mode. Pulmu never invokes force options.
git push -u origin "$BRANCH"

DESIRED_LABELS=(); AVAILABLE_LABELS=(); MISSING_LABELS=(); UNAPPLIED_LABELS=()
DESIRED_LABELS=("pulmu" "$(pulmu_task_type_label "$(pulmu_metadata_read task_type)")" "forge: $(pulmu_metadata_read forge)" "risk: $(pulmu_metadata_read risk)")
IFS=',' read -r -a AREAS <<< "$(pulmu_metadata_read areas)"
for area in "${AREAS[@]:0:3}"; do DESIRED_LABELS+=("area: $area"); done

if [[ "$PULMU_GITHUB_APPLY_LABELS" == "true" ]]; then
  LABEL_FILE="$GIT_DIR/pulmu-existing-labels"
  if gh label list --limit 1000 --json name --jq '.[].name' > "$LABEL_FILE"; then
    LABEL_DISCOVERY="available"
    for label in "${DESIRED_LABELS[@]}"; do
      if grep -Fqx -- "$label" "$LABEL_FILE"; then
        AVAILABLE_LABELS+=("$label")
      elif [[ "$PULMU_GITHUB_CREATE_MISSING_LABELS" == "true" ]]; then
        case "$label" in
          pulmu) color="BFD4F2" ;; type:*) color="0E8A16" ;; forge:*) color="5319E7" ;; risk:*) color="D93F0B" ;; area:*) color="1D76DB" ;; *) color="EDEDED" ;;
        esac
        if gh label create "$label" --color "$color" --description "Managed by Pulmu delivery policy"; then
          AVAILABLE_LABELS+=("$label")
        else
          MISSING_LABELS+=("$label")
        fi
      else
        MISSING_LABELS+=("$label")
      fi
    done
  else
    LABEL_DISCOVERY="unavailable"
    MISSING_LABELS=("${DESIRED_LABELS[@]}")
  fi
else
  LABEL_DISCOVERY="disabled"
  MISSING_LABELS=("${DESIRED_LABELS[@]}")
fi

BODY_FILE="$GIT_DIR/pulmu-pr-body.md"
if [[ "$DELIVERY" == "github" ]]; then
  SUMMARY="$(pulmu_metadata_read summary)"
  RISK="$(pulmu_metadata_read risk)"
  RISK_REASON="$(pulmu_metadata_read risk_reason 2>/dev/null || true)"
  FORGE="$(pulmu_metadata_read forge)"
  PATTERN="$(pulmu_metadata_read pattern)"
  {
    printf '## Summary\n\n%s\n\n' "$SUMMARY"
    printf '## Changes\n\n'
    while IFS= read -r item; do printf -- '- %s\n' "$item"; done < "$METADATA_DIR/changes"
    printf '\n## Pulmu Forge\n\n| Stage | Result |\n| --- | --- |\n'
    printf '| 🔥 Ignite | %s Forge |\n' "$(pulmu_display_enum "$FORGE")"
    printf '| 🔎 Inspect | Complete |\n'
    if [[ "$PATTERN" == "true" ]]; then printf '| 📐 Shape | Pattern used |\n'; else printf '| 📐 Shape | Pattern skipped |\n'; fi
    printf '| 🔨 Hammer | Complete |\n| 🌊 Quench | PASS |\n| 🪨 Hone | PASS |\n| 📦 Ship | Ready |\n'
    printf '\n## Verification\n\n'
    if [[ -f "$GIT_DIR/pulmu-quench.log" ]] && grep -q '^✓ ' "$GIT_DIR/pulmu-quench.log"; then
      while IFS= read -r item; do printf -- '- %s\n' "$item"; done < <(grep '^✓ ' "$GIT_DIR/pulmu-quench.log")
    else
      printf -- '- ⚠ No supported automated check was discovered\n'
    fi
    printf '\n## Risk\n\n%s' "$(pulmu_display_enum "$RISK")"
    [[ -n "$RISK_REASON" ]] && printf ' — %s' "$RISK_REASON"
    printf '\n\n## Review Focus\n\n'
    if [[ -s "$METADATA_DIR/review-focus" ]]; then
      while IFS= read -r item; do printf -- '- %s\n' "$item"; done < "$METADATA_DIR/review-focus"
    else
      printf -- '- Correctness and regression risk in the changed paths\n'
    fi
    printf '\n## Pulmu Metadata\n\n- Forge: %s\n- Type: %s\n- Areas: %s\n' "$(pulmu_display_enum "$FORGE")" "$(pulmu_display_enum "$(pulmu_metadata_read task_type)")" "$(pulmu_metadata_read areas | sed 's/,/, /g')"
    if [[ -n "$SUPPLEMENTAL_BODY_FILE" ]]; then
      printf '\n## Additional Context\n\n'
      sed -n '1,200p' "$SUPPLEMENT_COPY"
      printf '\n'
    fi
  } > "$BODY_FILE"
fi
[[ -f "$BODY_FILE" ]] || pulmu_die "PR body file does not exist: $BODY_FILE"

if ! PR_URL="$(gh pr list --head "$BRANCH" --base "$BASE" --state open --json url --jq '.[0].url' 2>/dev/null)"; then
  pulmu_die "could not determine whether a pull request already exists for $BRANCH -> $BASE"
fi
if [[ -z "$PR_URL" || "$PR_URL" == "null" ]]; then
  args=(pr create --base "$BASE" --head "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE")
  FORGE="$(pulmu_metadata_read forge)"; RISK="$(pulmu_metadata_read risk)"
  if [[ "$DRAFT" -eq 1 || ( "$FORGE" == "full" && "$RISK" == "high" && "$PULMU_GITHUB_FULL_FORGE_DRAFT" == "true" ) ]]; then args+=(--draft); fi
  PR_OUTPUT="$(gh "${args[@]}")"
  PR_URL="$(printf '%s\n' "$PR_OUTPUT" | grep -Eo 'https://[^[:space:]]+/pull/[0-9]+' | tail -n 1 || true)"
else
  [[ "$PR_URL" =~ ^https://[^[:space:]]+/pull/[0-9]+$ ]] || pulmu_die "GitHub returned an invalid existing pull-request URL"
  gh pr edit "$PR_URL" --title "$TITLE" --body-file "$BODY_FILE" >/dev/null
fi
[[ "$PR_URL" =~ ^https://[^[:space:]]+/pull/[0-9]+$ ]] || pulmu_die "GitHub delivery did not return a real pull-request URL"
PR_NUMBER="${PR_URL##*/}"

APPLIED=0
if [[ "${#AVAILABLE_LABELS[@]}" -gt 0 ]]; then
  for label in "${AVAILABLE_LABELS[@]}"; do
    if gh pr edit "$PR_URL" --add-label "$label" >/dev/null; then
      APPLIED=$((APPLIED + 1))
    else
      UNAPPLIED_LABELS+=("$label")
    fi
  done
fi
printf 'PULMU_LABELS_APPLIED=%s\n' "$APPLIED"
printf 'PULMU_LABEL_DISCOVERY=%s\n' "$LABEL_DISCOVERY"
if [[ "${#MISSING_LABELS[@]}" -gt 0 ]]; then printf 'PULMU_LABELS_SKIPPED=%s\n' "$(IFS=,; printf '%s' "${MISSING_LABELS[*]}")"; fi
if [[ "${#UNAPPLIED_LABELS[@]}" -gt 0 ]]; then printf 'PULMU_LABELS_UNAPPLIED=%s\n' "$(IFS=,; printf '%s' "${UNAPPLIED_LABELS[*]}")"; fi
printf 'PULMU_PR_URL=%s\n' "$PR_URL"
pulmu_run_context complete --delivery github --commit "$COMMIT" --pr-number "$PR_NUMBER" --pr-url "$PR_URL" --expect-run-id "$EXPECT_RUN_ID" >/dev/null

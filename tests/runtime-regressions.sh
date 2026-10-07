#!/usr/bin/env bash
# Sourced by test.sh; each fixture has its own fail-fast process and temp root.

installer_rollback_test() {
  local tmp mode target result backup
  tmp="$(fixture_tempdir)"
  mkdir -p "$tmp/bin"
  export PULMU_TEST_REAL_MV="$(command -v mv)"
  cat > "$tmp/bin/mv" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "$2" in
  */previous-agents/pulmu-architect.toml)
    [[ "$PULMU_TEST_INSTALL_FAILURE" != backup ]] || exit 19
    "$PULMU_TEST_REAL_MV" "$@"
    if [[ "$PULMU_TEST_INSTALL_FAILURE" == signal ]]; then kill -TERM "$PPID"; fi
    exit 0
    ;;
esac
case "$1" in
  */agents/pulmu-architect.toml)
    [[ "$PULMU_TEST_INSTALL_FAILURE" != replacement && "$PULMU_TEST_INSTALL_FAILURE" != restore ]] || exit 23
    ;;
  */previous-agents/pulmu-architect.toml)
    [[ "$PULMU_TEST_INSTALL_FAILURE" != restore ]] || exit 29
    ;;
esac
exec "$PULMU_TEST_REAL_MV" "$@"
SH
  chmod +x "$tmp/bin/mv"
  for mode in signal backup replacement restore; do
    target="$tmp/$mode"
    mkdir -p "$target/.agents/skills/pulmu" "$target/.codex/agents"
    printf 'old skill\n' > "$target/.agents/skills/pulmu/custom"
    printf 'old agent\n' > "$target/.codex/agents/pulmu-architect.toml"
    printf 'other agent\n' > "$target/.codex/agents/custom.toml"
    if PATH="$tmp/bin:$PATH" PULMU_TEST_INSTALL_FAILURE="$mode" bash "$ROOT/install.sh" --local "$target" >"$tmp/$mode.log" 2>&1; then
      return 1
    else
      result=$?
    fi
    [[ "$(cat "$target/.agents/skills/pulmu/custom")" == 'old skill' ]]
    [[ "$(cat "$target/.codex/agents/custom.toml")" == 'other agent' ]]
    if [[ "$mode" == restore ]]; then
      backup="$(find "$target" -path '*/previous-agents/pulmu-architect.toml')"
      [[ -n "$backup" && "$(cat "$backup")" == 'old agent' ]]
      grep -Fq 'backups retained' "$tmp/$mode.log"
    else
      [[ "$(cat "$target/.codex/agents/pulmu-architect.toml")" == 'old agent' ]]
      [[ -z "$(find "$target" -name '.pulmu-install.*')" ]]
    fi
    if [[ "$mode" == signal ]]; then [[ "$result" -eq 143 ]]; fi
  done
}

remote_base_test() {
  local tmp mode scripts origin
  tmp="$(fixture_tempdir)"; scripts="$ROOT/.agents/skills/pulmu/scripts"
  for mode in configured detached local-preferred; do
    (
      mkdir -p "$tmp/$mode"; cd "$tmp/$mode"
      git init -b work >/dev/null
      git config user.name Test; git config user.email test@example.invalid
      mkdir .pulmu
      if [[ "$mode" != detached ]]; then printf '[git]\nbase_branch = "main"\n' > .pulmu/config.toml; fi
      printf 'base\n' > file.txt
      git add .; git commit -m init >/dev/null
      origin="$(git rev-parse HEAD)"
      git update-ref refs/remotes/origin/main "$origin"
      git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
      if [[ "$mode" == local-preferred ]]; then
        printf 'local base\n' >> file.txt
        git add .; git commit -m 'local base' >/dev/null
        git branch main
      fi
      if [[ "$mode" == detached ]]; then git switch --detach >/dev/null; fi
      bash "$scripts/ignite.sh" --type test --slug remote-base 'Use available base ref' >/dev/null
      [[ "$(cat .git/pulmu-base)" == main ]]
      finalize_metadata test quick low testing false false false
      printf 'task\n' >> file.txt
      record_reviewed_delivery 'test: verify remote base' 'Verify remote-only base handling.'
      if [[ "$mode" == local-preferred ]]; then
        [[ "$(cat .git/pulmu-metadata/candidate_base_head)" == "$(git rev-parse refs/heads/main)" ]]
        [[ "$(cat .git/pulmu-metadata/candidate_base_head)" != "$origin" ]]
      else
        [[ "$(cat .git/pulmu-metadata/candidate_base_head)" == "$origin" ]]
      fi
      ship_for_run --delivery local > "$tmp/$mode.out"
      grep -Fxq 'PULMU_BASE=main' "$tmp/$mode.out"
      [[ -z "$(git status --porcelain)" ]]
    )
  done
}

ship_hook_reverification_test() {
  local tmp mode scripts run_id origin hook_head index_before original_state merge
  tmp="$(fixture_tempdir)"; scripts="$ROOT/.agents/skills/pulmu/scripts"
  for mode in clean worktree failed-commit extra merge; do
    (
      mkdir -p "$tmp/$mode"; cd "$tmp/$mode"
      git init -b main >/dev/null
      git config user.name Test; git config user.email test@example.invalid
      printf 'base\n' > file.txt
      git add .; git commit -m init >/dev/null
      bash "$scripts/ignite.sh" --type test --slug hook-reverify 'Recover hook changes' >/dev/null
      finalize_metadata test standard medium testing false false true
      metadata_for_run verification --check . 'test ! -e .git/verification-fails' >/dev/null
      run_id="$(cat .git/pulmu-metadata/run_id)"; origin="$(git rev-parse HEAD)"
      printf 'task\n' >> file.txt
      record_reviewed_delivery 'test: recover hook mutation' 'Recover a changed commit candidate.'
      case "$mode" in
        worktree) printf '#!/usr/bin/env bash\nprintf "hook\\n" >> file.txt\n' > .git/hooks/post-commit; chmod +x .git/hooks/post-commit ;;
        failed-commit) printf '#!/usr/bin/env bash\nprintf "hook\\n" >> file.txt\ngit add file.txt\nexit 17\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit ;;
        *) printf '#!/usr/bin/env bash\nprintf "hook\\n" >> file.txt\ngit add file.txt\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit ;;
      esac
      if ship_for_run --delivery local >"$tmp/$mode.log" 2>&1; then exit 1; fi
      grep -Fq reverify-ship "$tmp/$mode.log"
      hook_head="$(git rev-parse HEAD)"
      rm -f .git/hooks/pre-commit .git/hooks/post-commit
      if [[ "$mode" == clean ]]; then
        python3 -B "$ROOT/tests/test_reverify_interruption.py" "$scripts" >/dev/null
      fi
      if [[ "$mode" == extra || "$mode" == merge ]]; then
        if [[ "$mode" == extra ]]; then
          git commit --allow-empty -m extra >/dev/null
        else
          merge="$(printf 'merge\n' | git commit-tree 'HEAD^{tree}' -p "$hook_head" -p "$origin")"
          git update-ref "refs/heads/$(git branch --show-current)" "$merge"
        fi
        original_state="$(git hash-object .git/pulmu/run.json)"
        if bash "$scripts/run-context.sh" reverify-ship --commit "$(git rev-parse HEAD)" --expect-run-id "$run_id" >/dev/null 2>&1; then exit 1; fi
        [[ "$(git hash-object .git/pulmu/run.json)" == "$original_state" && ! -e .git/pulmu/ship-reverify.json ]]
        exit 0
      fi
      if [[ "$mode" == worktree ]]; then
        bash "$scripts/run-context.sh" fail --code SHIP_HOOK_CHANGED --message 'Hook changed the working tree' --expect-run-id "$run_id" >/dev/null
      elif [[ "$mode" == failed-commit ]]; then
        [[ "$hook_head" == "$origin" ]]
        bash "$scripts/run-context.sh" interrupt --message 'Commit failed' --expect-run-id "$run_id" >/dev/null
      fi
      if bash "$scripts/run-context.sh" reverify-ship --commit "$hook_head" --expect-run-id stale >/dev/null 2>&1; then exit 1; fi
      index_before="$(git write-tree)"
      bash "$scripts/run-context.sh" reverify-ship --commit "$hook_head" --expect-run-id "$run_id" >/dev/null
      [[ "$(git rev-parse HEAD)" == "$hook_head" && "$(git write-tree)" == "$index_before" ]]
      [[ ! -e .git/pulmu-metadata/quench_fingerprint && ! -e .git/pulmu-metadata/hone_fingerprint && ! -e .git/pulmu-metadata/delivery_fingerprint ]]
      [[ -z "$(find .git/pulmu-reviews -name '*.json')" ]]
      grep -Fq hook file.txt
      # Failed commits keep their staged content; only the fixture explicitly unstages it.
      if [[ "$mode" == failed-commit ]]; then git restore --staged -- file.txt; fi
      if ship_for_run --delivery local >/dev/null 2>&1; then exit 1; fi
      touch .git/verification-fails
      if quench_for_run >/dev/null 2>&1; then exit 1; fi
      [[ ! -e .git/pulmu-metadata/quench_fingerprint ]]
      rm .git/verification-fails
      quench_for_run >/dev/null
      [[ "$(cat .git/pulmu-metadata/candidate_review_head)" == "$origin" ]]
      git diff "$origin" "$(cat .git/pulmu-metadata/candidate_tree)" > "$tmp/$mode.diff"
      grep -Fxq '+task' "$tmp/$mode.diff"; grep -Fxq '+hook' "$tmp/$mode.diff"
      bash "$scripts/run-context.sh" set-stage hone --expect-run-id "$run_id" >/dev/null
      if metadata_for_run hone --result pass >/dev/null 2>&1; then exit 1; fi
      record_review_results
      metadata_for_run hone --result pass >/dev/null
      metadata_for_run delivery --title 'test: recover hook mutation' --summary 'Reverified full hook diff.' --change 'Includes task and hook edits' >/dev/null
      ship_for_run --delivery local >/dev/null
      if [[ "$mode" == clean ]]; then [[ "$(git rev-parse HEAD)" == "$hook_head" ]]; fi
      if [[ "$mode" == worktree ]]; then [[ "$(git rev-parse HEAD^)" == "$hook_head" ]]; fi
      [[ -z "$(git status --porcelain)" ]]
      python3 - <<'PY'
import json
state = json.load(open('.git/pulmu/run.json'))
assert state['status'] == 'completed'
assert state['retries'] == {'quench': 0, 'hone': 0}
PY
    )
  done
}

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$ROOT/scripts/install-common.sh"
pulmu_install_scope install "$@"

if [[ "$INSTALL_SCOPE" == local && "$INSTALL_TARGET" == "$(cd "$ROOT" && pwd -P)" ]]; then
  printf '✓ This checkout already contains the project-local Pulmu skill and agents.\n'
  exit 0
fi
case "$INSTALL_TARGET/" in
  "$ROOT/.agents/skills/pulmu/"*|"$ROOT/.codex/agents/"*)
    printf '✗ installation target must not be inside the source skill or agents\n' >&2
    exit 1
    ;;
esac

mkdir -p "$(dirname "$SKILL_DST")" "$AGENT_DST"
[[ ! -e "$SKILL_DST" || -d "$SKILL_DST" ]] || { printf '✗ skill destination is not a directory\n' >&2; exit 1; }
WORK_DIR="$(mktemp -d "$INSTALL_TARGET/.pulmu-install.XXXXXX")"
COMPLETE=false; SKILL_ATTEMPTED=false
REPLACED_AGENTS=()
cleanup_install() {
  local status=$? name rollback_failed=false
  trap - EXIT
  if [[ "$COMPLETE" == false ]]; then
    if [[ "$SKILL_ATTEMPTED" == true ]]; then rm -rf "$SKILL_DST" || rollback_failed=true; fi
    if [[ -e "$WORK_DIR/previous-skill" || -L "$WORK_DIR/previous-skill" ]]; then
      mv "$WORK_DIR/previous-skill" "$SKILL_DST" || rollback_failed=true
    fi
    if [[ ${#REPLACED_AGENTS[@]} -gt 0 ]]; then
      for name in "${REPLACED_AGENTS[@]}"; do
        rm -f "$AGENT_DST/$name" || rollback_failed=true
        if [[ -e "$WORK_DIR/previous-agents/$name" || -L "$WORK_DIR/previous-agents/$name" ]]; then
          mv "$WORK_DIR/previous-agents/$name" "$AGENT_DST/$name" || rollback_failed=true
        fi
      done
    fi
  fi
  if [[ "$rollback_failed" == true ]]; then
    printf '✗ could not fully restore installation; backups retained at %s\n' "$WORK_DIR" >&2
    exit 1
  fi
  rm -rf "$WORK_DIR"
  exit "$status"
}
trap cleanup_install EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$WORK_DIR/skill" "$WORK_DIR/agents" "$WORK_DIR/previous-agents"
cp -R "$ROOT/.agents/skills/pulmu/." "$WORK_DIR/skill/"
cp "$ROOT/.codex/agents/"pulmu-*.toml "$WORK_DIR/agents/"
chmod +x "$WORK_DIR/skill/scripts/"*.sh
for agent in "$WORK_DIR/agents/"*.toml; do
  name="${agent##*/}"
  [[ ! -e "$AGENT_DST/$name" || -f "$AGENT_DST/$name" ]] || { printf '✗ agent destination is not a file: %s\n' "$name" >&2; exit 1; }
done
if [[ -e "$SKILL_DST" || -L "$SKILL_DST" ]]; then mv "$SKILL_DST" "$WORK_DIR/previous-skill"; fi
SKILL_ATTEMPTED=true
mv "$WORK_DIR/skill" "$SKILL_DST"
for agent in "$WORK_DIR/agents/"*.toml; do
  name="${agent##*/}"
  if [[ -e "$AGENT_DST/$name" || -L "$AGENT_DST/$name" ]]; then
    mv "$AGENT_DST/$name" "$WORK_DIR/previous-agents/$name"
  fi
  REPLACED_AGENTS+=("$name")
  mv "$agent" "$AGENT_DST/$name"
done
COMPLETE=true

printf '✓ Installation scope: %s (%s)\n' "$INSTALL_SCOPE" "$INSTALL_TARGET"
printf '✓ Installed Pulmu skill: %s\n' "$SKILL_DST"
printf '✓ Installed Pulmu agents: %s\n' "$AGENT_DST"
printf '\nRestart Codex if needed, then run: $pulmu "<task>"\n'
if [[ "$INSTALL_SCOPE" == local ]]; then
  printf 'Launch Codex in the target project. Commit the installed files for team use, or exclude these new files locally before Ignite.\n'
fi

#!/usr/bin/env bash
# Shared scope parsing for installation and removal. No writes during parsing.
pulmu_install_scope() {
  local action="$1"; shift
  INSTALL_SCOPE="global"
  INSTALL_TARGET="$HOME"
  case "${1:-}" in
    "") [[ $# -eq 0 ]] || return 1 ;;
    --global) [[ $# -eq 1 ]] || { printf '✗ --global accepts no target\n' >&2; return 1; } ;;
    --local)
      [[ $# -eq 2 && -n "$2" && -d "$2" ]] || {
        printf '✗ usage: %s.sh --local <existing-project-directory>\n' "$action" >&2; return 1;
      }
      INSTALL_SCOPE="local"
      INSTALL_TARGET="$(cd "$2" && pwd -P)" || return 1
      [[ "$INSTALL_TARGET" != / && "$INSTALL_TARGET" != "$(cd "$HOME" && pwd -P)" ]] || {
        printf '✗ --local requires a project directory, not / or the user home\n' >&2; return 1;
      }
      ;;
    --help|-h)
      printf 'Usage: %s.sh [--global | --local <existing-project-directory>]\n' "$action"
      printf 'No arguments: current-user installation. --local: only the selected project.\n'
      exit 0
      ;;
    *) printf '✗ unknown option: %s\n' "$1" >&2; return 1 ;;
  esac
  SKILL_DST="$INSTALL_TARGET/.agents/skills/pulmu"
  AGENT_DST="$INSTALL_TARGET/.codex/agents"
  if [[ "$INSTALL_SCOPE" == local ]]; then
    local relative agent
    # A project-local operation must not traverse links into user/global files.
    for relative in .agents .agents/skills .agents/skills/pulmu .codex .codex/agents; do
      [[ ! -L "$INSTALL_TARGET/$relative" ]] || {
        printf '✗ local destination is a symlink: %s\n' "$INSTALL_TARGET/$relative" >&2; return 1;
      }
    done
    for agent in "$AGENT_DST"/pulmu-*.toml; do
      [[ ! -L "$agent" ]] || { printf '✗ local agent is a symlink: %s\n' "$agent" >&2; return 1; }
    done
  fi
}

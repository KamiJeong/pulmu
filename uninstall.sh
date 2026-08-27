#!/usr/bin/env bash
set -euo pipefail
rm -rf "${HOME}/.agents/skills/pulmu"
rm -f "${HOME}/.codex/agents/pulmu-explorer.toml" "${HOME}/.codex/agents/pulmu-reviewer.toml"
printf '✓ Pulmu removed from user skill/agent directories.\n'

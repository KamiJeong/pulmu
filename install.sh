#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DST="${HOME}/.agents/skills/pulmu"
AGENT_DST="${HOME}/.codex/agents"

mkdir -p "$(dirname "$SKILL_DST")" "$AGENT_DST"
rm -rf "$SKILL_DST"
cp -R "$ROOT/.agents/skills/pulmu" "$SKILL_DST"
cp "$ROOT/.codex/agents/"pulmu-*.toml "$AGENT_DST/"
chmod +x "$SKILL_DST/scripts/"*.sh

printf '✓ Installed Pulmu skill: %s\n' "$SKILL_DST"
printf '✓ Installed Pulmu agents: %s\n' "$AGENT_DST"
printf '\nRestart Codex if needed, then run: $pulmu "<task>"\n'

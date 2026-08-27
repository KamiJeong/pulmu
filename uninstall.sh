#!/usr/bin/env bash
set -euo pipefail
rm -rf "${HOME}/.agents/skills/pulmu"
agent_files=(
  pulmu-explorer.toml
  pulmu-test-scout.toml
  pulmu-risk-scout.toml
  pulmu-architect.toml
  pulmu-designer.toml
  pulmu-smith.toml
  pulmu-failure-analyst.toml
  pulmu-reviewer.toml
  pulmu-test-reviewer.toml
  pulmu-security-reviewer.toml
  pulmu-compat-reviewer.toml
  pulmu-design-reviewer.toml
)
for agent_file in "${agent_files[@]}"; do
  rm -f "${HOME}/.codex/agents/${agent_file}"
done
printf '✓ Pulmu removed from user skill/agent directories.\n'

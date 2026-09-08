#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$ROOT/scripts/install-common.sh"
pulmu_install_scope uninstall "$@"
if [[ "$INSTALL_SCOPE" == local && "$INSTALL_TARGET" == "$(cd "$ROOT" && pwd -P)" ]]; then
  printf '✗ refusing to remove the source checkout; it already embeds Pulmu\n' >&2
  exit 1
fi
rm -rf "$SKILL_DST"
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
  rm -f "$AGENT_DST/${agent_file}"
done
printf '✓ Pulmu removed from %s skill/agent directories: %s\n' "$INSTALL_SCOPE" "$INSTALL_TARGET"

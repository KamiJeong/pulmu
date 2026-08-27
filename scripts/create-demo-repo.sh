#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-/tmp/pulmu-demo}"
MODE="${2:-}"
REPO_NAME="${3:-pulmu-demo}"

if [[ -e "$TARGET" ]]; then
  printf '✗ target already exists: %s\n' "$TARGET" >&2
  exit 1
fi

mkdir -p "$TARGET"
cp -R "$ROOT/examples/task-store/." "$TARGET/"
mkdir -p "$TARGET/.agents/skills" "$TARGET/.codex/agents"
cp -R "$ROOT/.agents/skills/pulmu" "$TARGET/.agents/skills/pulmu"
cp "$ROOT/.codex/agents/"pulmu-*.toml "$TARGET/.codex/agents/"
cp "$ROOT/.codex/config.toml" "$TARGET/.codex/config.toml"

cd "$TARGET"
git init -b main >/dev/null
git add -A
git -c user.name="Pulmu Demo" -c user.email="pulmu-demo@example.invalid" commit -m "chore: initialize Pulmu demo" >/dev/null

if [[ "$MODE" == "--github" ]]; then
  command -v gh >/dev/null 2>&1 || { printf '✗ gh is required for --github\n' >&2; exit 1; }
  gh auth status >/dev/null 2>&1 || { printf '✗ run gh auth login first\n' >&2; exit 1; }
  gh repo create "$REPO_NAME" --private --source=. --remote=origin --push
fi

printf '✓ Pulmu demo ready: %s\n' "$TARGET"
printf '  cd %s\n  codex\n  $pulmu "Add complete(id) to TaskStore and include tests"\n' "$TARGET"

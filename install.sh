#!/usr/bin/env bash
# Install the /flow skill into Claude Code.
#   bash install.sh global              -> ~/.claude/skills/flow   (every project)
#   bash install.sh project [dir]       -> <dir|cwd>/.claude/skills/flow
# Windows: run under Git Bash. Re-running overwrites the installed copy (dev source untouched).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/skill/flow"
MODE="${1:-global}"

case "$MODE" in
  global)  DEST="${HOME}/.claude/skills/flow" ;;
  project) DEST="${2:-$PWD}/.claude/skills/flow" ;;
  -h|--help) echo "usage: bash install.sh [global|project] [project-dir]"; exit 0 ;;
  *) echo "usage: bash install.sh [global|project] [project-dir]"; exit 1 ;;
esac

[ -f "$SRC/SKILL.md" ] || { echo "FAIL: skill source not found at $SRC"; exit 1; }
mkdir -p "$DEST"
# clean stale runtime artifacts but keep the destination dir
rm -rf "$DEST"/_templates "$DEST"/law "$DEST"/references "$DEST"/runner "$DEST"/harness "$DEST"/playbooks 2>/dev/null || true
cp -r "$SRC/." "$DEST/"
chmod +x "$DEST/runner/flow.sh" 2>/dev/null || true

echo "installed /flow -> $DEST"
echo "doctor:"
command -v bash >/dev/null 2>&1 && echo "  bash:   ok (required)" || echo "  bash:   MISSING - required for the gate runner"
if (command -v python || command -v python3) >/dev/null 2>&1; then
  echo "  python: ok  (durable harness layer enabled)"
else
  echo "  python: none (engine still works; durable layer auto-disabled)"
fi
command -v cargo >/dev/null 2>&1 && echo "  cargo:  ok  (optional Rust harness power-path available)" || true
echo
echo "Done. In a project, type '/flow' (or '/flow next' to start a build)."

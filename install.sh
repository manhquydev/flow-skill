#!/usr/bin/env bash
# Install the /flow skill into Claude Code.
#   bash install.sh global              -> ~/.claude/skills/flow   (every project)
#   bash install.sh project [dir]       -> <dir|cwd>/.claude/skills/flow
# Windows: run under Git Bash. Re-running overwrites the installed copy (dev source untouched).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/skills/flow"
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
echo
# run the real cross-platform doctor from the freshly installed runner
bash "$DEST/runner/flow.sh" doctor || true
echo
echo "Done. In a project, type '/flow' (or '/flow next' to start a build)."

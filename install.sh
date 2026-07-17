#!/usr/bin/env bash
# Install the flow skill into every AI-harness skills dir on this machine.
#   bash install.sh global                       -> ~/.claude/skills/flow (always)
#                                                   + ~/.codex/skills/flow  (if ~/.codex/skills exists)
#                                                   + ~/.agents/skills/flow (if ~/.agents/skills exists)
#                                                   + Antigravity homes     (if ~/.gemini exists):
#                                                       ~/.gemini/antigravity-cli/skills/flow (CLI)
#                                                       ~/.gemini/config/skills/flow          (IDE)
#   bash install.sh global claude|codex|agents|antigravity -> only that one harness
#   bash install.sh project [dir]                -> <dir|cwd>/.claude/skills/flow
# Re-run after any update to re-sync every harness (the repo is the single source of truth).
# Windows: run under Git Bash. Claude Code invokes it as /flow; Codex CLI as $flow.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/skills/flow"
MODE="${1:-global}"

[ -f "$SRC/SKILL.md" ] || { echo "FAIL: skill source not found at $SRC"; exit 1; }

install_to() {
  dest="$1"
  mkdir -p "$dest"
  # clean stale runtime artifacts but keep the destination dir
  rm -rf "$dest"/_templates "$dest"/law "$dest"/references "$dest"/runner "$dest"/harness "$dest"/playbooks 2>/dev/null || true
  cp -r "$SRC/." "$dest/"
  chmod +x "$dest/runner/flow.sh" 2>/dev/null || true
  echo "installed flow -> $dest"
  LAST="$dest"
}

usage() { echo "usage: bash install.sh [global [claude|codex|agents|antigravity|all] | project [dir]]"; }

# v0.23 A0 fix — the reported symptom: a user installs to a non-Claude agent, opens it, types
# /flow, and sees nothing, because a freshly-installed skill isn't discovered until the agent
# reloads. The old static Done line only told Claude+Codex users what to do; track which
# targets actually got installed so every one of them gets its own restart/reload hint.
INSTALLED=""
done_line() {
  out="Done."
  for t in $INSTALLED; do
    case "$t" in
      claude)      out="$out Claude Code: type /flow |" ;;
      codex)       out="$out Codex CLI: type \$flow (restart Codex once to load a new skill) |" ;;
      antigravity) out="$out Antigravity: restart/reload the IDE (or restart agy) to load the new skill, then type /flow |" ;;
      agents)      out="$out Agents home (~/.agents/skills/): restart/reload your tool if it does not auto-detect new skills |" ;;
    esac
  done
  echo "${out% |}"
}

LAST=""
case "$MODE" in
  global)
    TARGET="${2:-all}"
    # claude: the primary harness, always installed (created if missing)
    if [ "$TARGET" = "all" ] || [ "$TARGET" = "claude" ]; then
      install_to "${HOME}/.claude/skills/flow"
      INSTALLED="$INSTALLED claude"
    fi
    # codex: install when explicitly targeted, or when the harness is already set up
    if [ "$TARGET" = "codex" ] || { [ "$TARGET" = "all" ] && [ -d "${HOME}/.codex/skills" ]; }; then
      install_to "${HOME}/.codex/skills/flow"
      INSTALLED="$INSTALLED codex"
    fi
    # agents: same rule
    if [ "$TARGET" = "agents" ] || { [ "$TARGET" = "all" ] && [ -d "${HOME}/.agents/skills" ]; }; then
      install_to "${HOME}/.agents/skills/flow"
      INSTALLED="$INSTALLED agents"
    fi
    # antigravity (Gemini): same SKILL.md bundle; two global homes (CLI + IDE) under ~/.gemini
    if [ "$TARGET" = "antigravity" ] || { [ "$TARGET" = "all" ] && [ -d "${HOME}/.gemini" ]; }; then
      install_to "${HOME}/.gemini/antigravity-cli/skills/flow"   # agy CLI global
      install_to "${HOME}/.gemini/config/skills/flow"            # Antigravity IDE global
      INSTALLED="$INSTALLED antigravity"
    fi
    [ -n "$LAST" ] || { echo "FAIL: unknown target '$TARGET'"; usage; exit 1; }
    ;;
  project)
    install_to "${2:-$PWD}/.claude/skills/flow"
    INSTALLED="claude"
    ;;
  -h|--help) usage; exit 0 ;;
  *) usage; exit 1 ;;
esac

echo
# run the real cross-platform doctor from a freshly installed runner
bash "$LAST/runner/flow.sh" doctor || true
echo
done_line

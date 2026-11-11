#!/usr/bin/env bash
# Install the flow skill into every AI-harness skills dir on this machine.
#   bash install.sh global                       -> ~/.claude/skills/flow (always)
#                                                   + ~/.codex/skills/flow  (if ~/.codex/skills exists)
#                                                   + ~/.agents/skills/flow (if ~/.agents/skills exists)
#                                                   + Antigravity homes     (if ~/.gemini exists):
#                                                       ~/.gemini/antigravity-cli/skills/flow (CLI)
#                                                       ~/.gemini/config/skills/flow          (IDE)
#                                                   + OMP home              (if ~/.omp/agent/skills exists):
#                                                       ~/.omp/agent/skills/flow
#                                                   + WidelCode home        (if ~/.widelai/skills exists):
#                                                       ~/.widelai/skills/flow
#                                                       + generated rules -> ~/.widelai/rules/flowskill.md
#                                                       + pointer line in ~/.widelai/AGENTS.md
#   bash install.sh global claude|codex|agents|antigravity|omp|cursor|widelai -> only that one harness
#   bash install.sh project [dir]                -> <dir|cwd>/.claude/skills/flow
#
# Safe transactional installation:
#   - Fresh installs are staged and promoted atomically without destructive pre-deletion.
#     When Python 3 is available, an ownership receipt (manifest-hashes.json) is generated.
#     Without Python, fresh installs proceed with POSIX staging and emit an advisory.
#   - In-place updates of existing destinations REQUIRE Python 3 (stdlib only helper) to
#     enforce strict ownership, preserve user custom files, prune retired files, detect
#     conflicts, and execute transactional swap with rollback. If Python 3 is absent on an
#     existing destination, the update fails loudly and the original tree is left untouched.
#
# Re-run after any update to re-sync every harness (the repo is the single source of truth).
# Windows: run under Git Bash. Claude Code invokes it as /flow; Codex CLI as $flow.
set -eu

export PYTHONDONTWRITEBYTECODE=1

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/skills/flow"
MODE="${1:-global}"

[ -f "$SRC/SKILL.md" ] || { echo "FAIL: skill source not found at $SRC"; exit 1; }
[ -d "$SRC" ] || { echo "FAIL: skill source directory missing at $SRC"; exit 1; }

HELPER="$SRC/runner/installer_helper.py"

select_py() {
  PY=""
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
      if "$candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
        PY="$candidate"
        return 0
      fi
    fi
  done
}

validate_path_no_symlinks() {
  target="$1"
  label="$2"
  [ -n "$target" ] || { echo "FAIL: $label path is empty"; exit 1; }

  # Reject dotdot relative traversals strictly in raw input
  case "$target" in
    *"/../"*|*"../"*|*"/.."|"..")
      echo "FAIL: $label path containing '..' relative traversal refused: $target"
      exit 1
      ;;
  esac

  # If relative, validate cwd ancestry first
  if [ "${target#/}" = "$target" ]; then
    curr="$PWD"
    pcheck="$curr"
    while [ "$pcheck" != "/" ] && [ "$pcheck" != "." ]; do
      if [ -L "$pcheck" ]; then
        echo "FAIL: current directory component is a symlink: $pcheck"
        exit 1
      fi
      pcheck="$(dirname "$pcheck")"
    done
    prefix="$target"
  else
    curr=""
    prefix="${target#/}"
  fi

  # Walk segments component by component before any mkdir or resolution
  old_ifs="$IFS"
  IFS='/'
  set -f
  # shellcheck disable=SC2086
  set -- $prefix
  set +f
  IFS="$old_ifs"

  for seg in "$@"; do
    [ -z "$seg" ] || [ "$seg" = "." ] && continue
    curr="$curr/$seg"
    if [ -L "$curr" ]; then
      echo "FAIL: $label symlink component refused: $curr"
      exit 1
    fi
  done
}

check_source_tree() {
  validate_path_no_symlinks "$SRC" "source"
  if [ ! -d "$SRC" ] || [ -L "$SRC" ]; then
    echo "FAIL: source is not a real directory: $SRC"
    exit 1
  fi
  sl="$(find "$SRC" -type l -print)"
  if [ -n "$sl" ]; then
    echo "FAIL: source contains symlinks which are refused:"
    echo "$sl"
    exit 1
  fi
  spec="$(find "$SRC" ! -type d ! -type f)"
  if [ -n "$spec" ]; then
    echo "FAIL: source contains non-regular entries which are refused:"
    echo "$spec"
    exit 1
  fi
}

# Verify that an existing destination has files
is_nonempty_dir() {
  d="$1"
  if [ -d "$d" ] && [ ! -L "$d" ]; then
    contents="$(ls -A "$d" 2>/dev/null)" || return 1
    [ -n "$contents" ]
  else
    return 1
  fi
}

# POSIX-only fresh install staging when Python is not available
posix_fresh_install() {
  dest="$1"
  validate_path_no_symlinks "$dest" "destination"
  check_source_tree

  dparent="$(dirname "$dest")"
  validate_path_no_symlinks "$dparent" "destination parent"
  mkdir -p "$dparent"

  stage="$(mktemp -d "${dparent}/.flow-skill-stage-XXXXXX")"
  backup_slot=""

  cleanup_posix_fresh() {
    rm -rf "$stage"
    if [ -n "$backup_slot" ] && [ -d "$backup_slot" ] && [ ! -e "$dest" ]; then
      mv "$backup_slot" "$dest" 2>/dev/null || true
    fi
  }
  trap cleanup_posix_fresh EXIT INT TERM

  cp -R "$SRC/." "$stage/"
  chmod +x "$stage/runner/flow.sh" 2>/dev/null || true

  # Handle existing destination after stage is fully populated
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ -L "$dest" ]; then
      echo "FAIL: destination is a symlink: $dest"
      exit 1
    fi
    if [ ! -d "$dest" ]; then
      echo "FAIL: destination exists and is not a regular directory: $dest"
      exit 1
    fi
    content="$(ls -A "$dest")" || { echo "FAIL: cannot inspect destination: $dest"; exit 1; }
    if [ -n "$content" ]; then
      echo "FAIL: destination exists and is not empty: $dest"
      exit 1
    fi

    # Backup empty directory via rename rather than deleting it
    backup_slot="$(mktemp -d "${dparent}/.flow-skill-backup-XXXXXX")"
    rmdir "$backup_slot"
    mv "$dest" "$backup_slot"
  fi

  if ! mv "$stage" "$dest"; then
    echo "FAIL: promotion mv failed for $dest"
    exit 1
  fi

  # Promotion succeeded: remove backup of empty dir
  if [ -n "$backup_slot" ] && [ -d "$backup_slot" ]; then
    rmdir "$backup_slot" 2>/dev/null || true
    backup_slot=""
  fi
  trap - EXIT INT TERM

  echo "NOTE: Python 3 not found - installed without ownership receipt; future in-place updates will refuse unknown file collisions."
  echo "installed flow -> $dest"
  LAST="$dest"
}

# WidelCode extras (T1): place the generated rules file + AGENTS.md pointer line.
# Runs BEFORE install_to (fail fast): a rules-file conflict aborts before the
# skill tree is touched. A missing generated file (checkout without `npm run
# sync`) warns loudly and continues with the skill install only.
# Never overwrites user content: an existing rules file with differing bytes
# is a hard refusal; AGENTS.md is only appended to, never rewritten.
install_widelai_extras() {
  rules_src="$HERE/npm-wrapper/.widelai/rules/flowskill.md"
  rules_dest="${HOME}/.widelai/rules/flowskill.md"
  agents_file="${HOME}/.widelai/AGENTS.md"
  pointer="FlowSkill rules: see .widelai/rules/flowskill.md"
  if [ ! -f "$rules_src" ]; then
    echo "WARNING: generated WidelCode rules file missing at $rules_src (run 'npm run sync' inside npm-wrapper/); skill installed without rules file."
    return 0
  fi
  # Refuse symlinked destinations (and ancestors) before any write: the rest
  # of this installer rejects symlinks, and cp/>> would follow them.
  validate_path_no_symlinks "$rules_dest" "rules destination"
  validate_path_no_symlinks "$agents_file" "AGENTS.md"
  # An existing directory (or other non-regular entry) at either destination
  # must fail loudly: cp into a directory "succeeds" by nesting the file,
  # and appending to a directory is not a pointer line.
  if [ -e "$rules_dest" ] && [ ! -f "$rules_dest" ]; then
    echo "FAIL: $rules_dest exists and is not a regular file; refusing to overwrite."
    return 1
  fi
  if [ -e "$agents_file" ] && [ ! -f "$agents_file" ]; then
    echo "FAIL: $agents_file exists and is not a regular file; refusing to write."
    return 1
  fi
  if [ -f "$rules_dest" ] && ! cmp -s "$rules_src" "$rules_dest"; then
    echo "FAIL: $rules_dest exists with different content (user-edited?); refusing to overwrite. Resolve manually."
    return 1
  fi
  # This function runs in a `||` list (call site: `install_widelai_extras ||
  # exit 1`), which disables errexit inside it — so every required write
  # checks its own failure explicitly instead of relying on `set -e`.
  mkdir -p "$(dirname "$rules_dest")" || return 1
  cp "$rules_src" "$rules_dest" || return 1
  echo "installed WidelCode rules -> $rules_dest"
  if [ -f "$agents_file" ]; then
    # Strip CR so a CRLF pointer is recognized (no duplicate append).
    if tr -d '\r' < "$agents_file" | grep -Fxq "$pointer"; then
      :
    else
      # Preserve the last line: append a newline first if the file lacks one.
      if [ -s "$agents_file" ] && [ -n "$(tail -c 1 "$agents_file")" ]; then
        printf '\n' >> "$agents_file" || return 1
      fi
      printf '%s\n' "$pointer" >> "$agents_file" || return 1
    fi
  else
    mkdir -p "$(dirname "$agents_file")" || return 1
    printf '%s\n' "$pointer" > "$agents_file" || return 1
  fi
  echo "pointer line ensured in $agents_file"
}

install_to() {
  dest="$1"
  # Validate raw path before ANY directory creation or helper invocation
  validate_path_no_symlinks "$dest" "destination"

  select_py

  if is_nonempty_dir "$dest"; then
    # In-place update of an existing destination: REQUIRED Python 3 full transaction
    if [ -z "$PY" ]; then
      echo "FAIL: updating an existing flow install requires Python 3 (ownership-receipt transaction); destination left untouched: $dest"
      exit 1
    fi
    if [ ! -f "$HELPER" ]; then
      echo "FAIL: installer helper missing at $HELPER"
      exit 1
    fi

    # Run single-process upgrade transaction
    set +e
    out="$("$PY" "$HELPER" upgrade "$SRC" "$dest" 2>&1)"
    rc=$?
    set -e
    if [ $rc -ne 0 ]; then
      echo "FAIL: update failed for $dest (exit code $rc):"
      echo "$out"
      exit $rc
    fi
    echo "installed flow -> $dest"
    LAST="$dest"
  else
    # Fresh install (destination missing or empty)
    if [ -n "$PY" ] && [ -f "$HELPER" ]; then
      set +e
      out="$("$PY" "$HELPER" upgrade "$SRC" "$dest" 2>&1)"
      rc=$?
      set -e
      if [ $rc -ne 0 ]; then
        echo "FAIL: fresh install via helper failed for $dest (exit code $rc):"
        echo "$out"
        exit $rc
      fi
      echo "installed flow -> $dest"
      LAST="$dest"
    else
      posix_fresh_install "$dest"
    fi
  fi
}

usage() {
  echo "usage: bash install.sh [global [claude|codex|agents|antigravity|omp|cursor|widelai|all] | project [dir]]" >&2
}

INSTALLED=""
done_line() {
  out="Done."
  for t in $INSTALLED; do
    case "$t" in
      claude)      out="$out Claude Code: type /flow |" ;;
      codex)       out="$out Codex CLI: type \$flow (restart Codex once to load a new skill) |" ;;
      antigravity) out="$out Antigravity: restart/reload the IDE (or restart agy) to load the new skill, then type /flow |" ;;
      agents)      out="$out Agents home / Zed (~/.agents/skills/): restart your tool (or Zed Agent Panel) to auto-detect flow |" ;;
      omp)         out="$out OMP: restart/reload your agent to load the new skill, then invoke flow |" ;;
      cursor)      out="$out Cursor: restart/reload Cursor to load the new skill, then check the Agent panel for flow |" ;;
      widelai)     out="$out WidelCode: restart/reload WidelCode to load the new skill, then invoke flow |" ;;
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
    # agents: same rule; also autodetects ~/.config/zed
    if [ "$TARGET" = "agents" ] || { [ "$TARGET" = "all" ] && { [ -d "${HOME}/.agents/skills" ] || [ -d "${HOME}/.config/zed" ]; }; }; then
      install_to "${HOME}/.agents/skills/flow"
      INSTALLED="$INSTALLED agents"
    fi
    # antigravity (Gemini): same SKILL.md bundle; two global homes (CLI + IDE) under ~/.gemini
    if [ "$TARGET" = "antigravity" ] || { [ "$TARGET" = "all" ] && [ -d "${HOME}/.gemini" ]; }; then
      install_to "${HOME}/.gemini/antigravity-cli/skills/flow"   # agy CLI global
      INSTALLED="$INSTALLED antigravity"
      install_to "${HOME}/.gemini/config/skills/flow"            # Antigravity IDE global
    fi
    # omp: explicit target or autodetected only when ~/.omp/agent/skills exists (never bare ~/.omp)
    if [ "$TARGET" = "omp" ] || { [ "$TARGET" = "all" ] && [ -d "${HOME}/.omp/agent/skills" ]; }; then
      install_to "${HOME}/.omp/agent/skills/flow"
      INSTALLED="$INSTALLED omp"
    fi
    # cursor: install when explicitly targeted, or when ~/.cursor/skills exists
    if [ "$TARGET" = "cursor" ] || { [ "$TARGET" = "all" ] && [ -d "${HOME}/.cursor/skills" ]; }; then
      install_to "${HOME}/.cursor/skills/flow"
      INSTALLED="$INSTALLED cursor"
    fi
    # widelai: install when explicitly targeted, or when ~/.widelai/skills exists
    # (never bare ~/.widelai — it holds credentials.json for every WidelCode user)
    if [ "$TARGET" = "widelai" ] || { [ "$TARGET" = "all" ] && [ -d "${HOME}/.widelai/skills" ]; }; then
      # Skill placement first: a loud refusal (marker/directory collision) must
      # happen before any extras bytes are written.
      install_to "${HOME}/.widelai/skills/flow"
      install_widelai_extras || exit 1
      INSTALLED="$INSTALLED widelai"
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
if [ -n "$LAST" ] && [ -f "$LAST/runner/flow.sh" ]; then
  bash "$LAST/runner/flow.sh" doctor || true
fi
echo
done_line

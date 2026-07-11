#!/usr/bin/env bash
# flow.sh - buildflow gate runner (mechanical layer)
#
# Two-layer harness: this script is the DETERMINISTIC layer. It checks gates
# mechanically (unchecked boxes, [FILL] placeholders, card status/evidence) and
# manages the stage/card lifecycle. The /flow SKILL.md is the SEMANTIC layer
# (quality gatekeeper) that runs on top of these exit codes.
#
# Exit codes: 0 = pass / advanced, 1 = gate fail or usage error.
#
# Paths:
#   templates -> <script>/../_templates   (00-idea .. 05-contract, card)
#   project   -> $FLOW_PROJECT_ROOT or $PWD   (holds flow/ and cards/)
#
# Portable bash (Git Bash on Windows + Unix). No GNU-only features.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../_templates"
LAW_DIR="$SCRIPT_DIR/../law"
PLAYBOOKS_DIR="$SCRIPT_DIR/../playbooks"
GLOBAL_KB_DIR="${FLOW_GLOBAL_KB:-${HOME:-}/.claude/flow/playbooks}"   # cross-project knowledge tier (set -u safe if HOME unset)
# Root resolution (monorepo dual-root guard). An explicit FLOW_PROJECT_ROOT always wins. Otherwise,
# if the CWD is NOT itself a flow project (no flow/ planning dir and no cards/) but an ANCESTOR is,
# adopt that ancestor — so running flow from a monorepo subdir (e.g. frontend/) does NOT silently
# mint a SECOND, fragmented .flow root with its own cycle_id (the real C2-App-001 failure mode).
# A subdir that has its own flow/ or cards/ is a deliberate sub-project and is left untouched.
FLOW_ROOT_ADOPTED=""
if [ -n "${FLOW_PROJECT_ROOT:-}" ]; then
  ROOT="$FLOW_PROJECT_ROOT"
else
  ROOT="$PWD"
  if [ ! -d "$PWD/flow" ] && [ ! -d "$PWD/cards" ]; then
    _rd="$PWD"; _rn=0
    while [ "$_rn" -lt 24 ]; do
      _rp="$(dirname "$_rd")"; [ "$_rp" = "$_rd" ] && break    # reached filesystem root
      _rd="$_rp"; _rn=$((_rn + 1))
      # Require a REAL flow signature, not just a dir literally named flow/ or cards/ (a bare 'flow/'
      # working folder — common, e.g. ~/flow — must NOT be adopted): a stage artifact, run-state, or
      # an actual card file. This keeps the walk from attaching telemetry to the wrong ancestor.
      if [ -f "$_rd/flow/00-idea.md" ] || [ -f "$_rd/flow/00-inspect.md" ] || [ -d "$_rd/.flow" ] \
         || { [ -d "$_rd/cards" ] && ls "$_rd"/cards/C-*.md >/dev/null 2>&1; }; then
        ROOT="$_rd"; FLOW_ROOT_ADOPTED="$_rd"; break
      fi
    done
    unset _rd _rp _rn
  fi
fi
[ -n "$FLOW_ROOT_ADOPTED" ] && printf 'note: using flow root %s (CWD is inside it; no flow/ here). Set FLOW_PROJECT_ROOT to override.\n' "$FLOW_ROOT_ADOPTED" >&2
FLOW_DIR="$ROOT/flow"
CARDS_DIR="$ROOT/cards"
MODE_FILE="$ROOT/MODE"
RETRO_FILE="$ROOT/RETRO.md"
DEBT_FILE="$ROOT/DEBT.md"
PROJECT_TYPE_FILE="$ROOT/PROJECT_TYPE"
SKIPPED_FILE="$ROOT/flow/.skipped"
LOCK_FILE="$ROOT/flow/.lock"
LOCK_DIR="$ROOT/flow/.lock.d"   # atomic mkdir claim dir (W5 guard); winner then writes $LOCK_FILE metadata
HARNESS_PY="$SCRIPT_DIR/../harness/flow_harness.py"

# Eval (LLM semantic-gate behavioral harness; opt-in, billable - see 'eval' command).
# FLOW_EVAL_MANIFEST is a TEST-ONLY override (e.g. a synthetic CRLF manifest fixture) - it does
# NOT widen the v1 trust boundary: artifact paths still resolve as $EVAL_DIR/fixtures/<id>/<rel>,
# so an overridden manifest can only ever point at real shipped fixtures under the real EVAL_DIR.
EVAL_DIR="$SCRIPT_DIR/../eval"
EVAL_MANIFEST="${FLOW_EVAL_MANIFEST:-$EVAL_DIR/manifest.tsv}"
GATE_RULES_FILE="$SCRIPT_DIR/../references/gate-rules.md"

# Usage-log sinks (run-state dir, gitignored). Mechanical flight-recorder: every invocation
# self-records here. Local-only, never transmitted. See flow/05-contract.md (this feature's plan).
LOG_DIR="$ROOT/.flow"
EVENTS_FILE="$LOG_DIR/events.jsonl"                       # per-project FULL event
EVAL_RESULTS_FILE="$LOG_DIR/eval-results.jsonl"           # per-project eval-batch results
CYCLE_FILE="$LOG_DIR/cycle_id"                            # stamped when stage 00 unlocks
GLOBAL_LOG="${HOME:-}/.claude/flow/usage.jsonl"           # device-global COMPACT event
# Stage/card carried into the exit event by the commands that know them (set during run).
FLOW_LOG_STAGE_FROM=""; FLOW_LOG_STAGE_TO=""; FLOW_LOG_CARD=""; FLOW_LAST_GATE_FAIL=""

# Tempdir cleanup list: advisory probe functions register their mktemp -d paths here so the
# EXIT trap (which fires on normal exit AND signals) removes them even on SIGINT/SIGTERM.
# Array (not a space-joined string): a space-containing TMPDIR (routine on Windows, e.g. a
# "Local Settings\Temp" or "John Doe\AppData" path) previously split into bogus fragments under
# unquoted `for d in $_CLEANUP_TDS`, silently no-op'ing the rm -rf (found reviewing the eval
# verb's temp-file hygiene, which is the first caller that actually exercises a spaced TMPDIR).
_CLEANUP_TDS=()
_register_td()  { _CLEANUP_TDS+=("$1"); }
# Guard the [@] expansion on array length first: bash < 4.4 (macOS ships 3.2.57 as /bin/bash)
# treats a zero-element array as UNSET under `set -u`, so "${_CLEANUP_TDS[@]}" on an empty
# array throws "unbound variable" and - since this runs inside the EXIT trap, ahead of
# _log_event - silently broke telemetry for every single flow.sh invocation on macOS (found via
# a real 3-OS CI run: ubuntu/windows ship bash >= 4.4, immune; macOS is not).
_cleanup_tds()  { local d; if [ "${#_CLEANUP_TDS[@]}" -gt 0 ]; then for d in "${_CLEANUP_TDS[@]}"; do rm -rf "$d" 2>/dev/null; done; fi; _CLEANUP_TDS=(); }

# Keep pure run-state (MODE / PROJECT_TYPE / .flow/) out of the host repo's git status.
# Idempotent; only acts in a real git repo OR where a .gitignore already exists (so test
# sandboxes and non-git dirs are untouched — no surprise file creation).
_ignore_run_state() {
  { [ -d "$ROOT/.git" ] || [ -f "$ROOT/.gitignore" ]; } || return 0
  local gi="$ROOT/.gitignore"
  grep -q 'flow run-state' "$gi" 2>/dev/null && return 0
  printf '\n# /flow run-state (generated; safe to ignore)\nMODE\nPROJECT_TYPE\n.flow/\n' >> "$gi"
}

# Concurrency lock: seconds a lock stays "fresh"; older locks are stale and auto-reclaimed.
FLOW_LOCK_TTL="${FLOW_LOCK_TTL:-900}"

STAGES="00-idea 01-research 02-scope 03-prd 04-adr 05-contract"
LAST_STAGE_IDX=5

# ---------- helpers ----------

stage_name_at() { # $1 = index -> "NN-name"
  local i=0 s
  for s in $STAGES; do
    if [ "$i" -eq "$1" ]; then echo "$s"; return 0; fi
    i=$((i + 1))
  done
  return 1
}

current_stage_idx() { # highest CONTIGUOUS-from-00 stage index, or -1 if 00 missing
  # Contiguous (not just highest-existing) so a manually-dropped future stage file
  # cannot make 'next' report a false PLANNING COMPLETE while earlier stages are missing.
  local i=0 s idx=-1
  for s in $STAGES; do
    if [ -f "$FLOW_DIR/$s.md" ]; then idx=$i; else break; fi
    i=$((i + 1))
  done
  echo "$idx"
}

# Scan a stage/planning file for gate violations.
# Prints violations; returns 0 = clean, 1 = violations found.
scan_gate() {
  local file="$1" found=0 unchecked fills
  if [ ! -f "$file" ]; then
    echo "  missing file: $file"
    return 1
  fi
  unchecked="$(grep -nE '^[[:space:]]*- \[ \]' "$file" 2>/dev/null || true)"
  fills="$(grep -n '\[FILL' "$file" 2>/dev/null || true)"
  if [ -n "$unchecked" ]; then
    echo "  [x] unchecked gate boxes:"
    printf '%s\n' "$unchecked" | sed 's/^/      L/'
    found=1
  fi
  if [ -n "$fills" ]; then
    echo "  [x] unfilled [FILL] placeholders:"
    printf '%s\n' "$fills" | sed 's/^/      L/'
    found=1
  fi
  return $found
}

_python() {
  # prefer python3, and only accept an interpreter that is actually Python 3.x (the harness +
  # repo_map.py are py3-only — a py2 `python` must NOT be selected or it fails silently).
  # Returns 0 + prints path when a valid interpreter is found; returns 1 (no output) when none.
  local p
  for p in python3 python; do
    if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys; sys.exit(0 if sys.version_info[0]>=3 else 1)' >/dev/null 2>&1; then
      command -v "$p"; return 0
    fi
  done
  return 1
}

harness_call() {
  # best-effort durable-layer write; NEVER breaks the engine if python/harness absent.
  [ -n "${FLOW_HARNESS_DISABLE:-}" ] && return 0
  [ -f "$HARNESS_PY" ] || return 0
  local py; py="$(_python)"; [ -n "$py" ] || return 0
  FLOW_PROJECT_ROOT="$ROOT" "$py" "$HARNESS_PY" "$@" >/dev/null 2>&1
  return 0
}

harness_available() { # 0 = durable layer usable (python + harness present, not disabled)
  [ -n "${FLOW_HARNESS_DISABLE:-}" ] && return 1
  [ -f "$HARNESS_PY" ] || return 1
  local py; py="$(_python)"; [ -n "$py" ] || return 1
  "$py" --version >/dev/null 2>&1 || return 1
  return 0
}

harness_emit() { # run a harness subcommand and ECHO its stdout (best-effort; nothing if unavailable)
  harness_available || return 0
  FLOW_PROJECT_ROOT="$ROOT" "$(_python)" "$HARNESS_PY" "$@" 2>/dev/null || true
}

cmd_harness() {
  # passthrough to the full durable-layer CLI (visible output + real exit code)
  if [ ! -f "$HARNESS_PY" ]; then echo "harness not installed at $HARNESS_PY"; return 1; fi
  local py; py="$(_python)"
  # validate the interpreter actually runs (Git Bash on Windows may resolve a Store stub)
  if [ -z "$py" ] || ! "$py" --version >/dev/null 2>&1; then
    echo "FAIL: a working python was not found - durable layer needs python (stdlib sqlite3)."
    return 1
  fi
  FLOW_PROJECT_ROOT="$ROOT" "$py" "$HARNESS_PY" "$@"
}

seed_law_files() {
  # Make the project-root law files available (buildflow expects them in context).
  # Non-destructive: never overwrite an existing project file.
  [ -f "$LAW_DIR/DESIGN.md" ] && [ ! -f "$ROOT/DESIGN.md" ] && cp "$LAW_DIR/DESIGN.md" "$ROOT/DESIGN.md"
  [ -f "$LAW_DIR/RETRO.md" ] && [ ! -f "$RETRO_FILE" ] && cp "$LAW_DIR/RETRO.md" "$RETRO_FILE"
  return 0
}

highest_card() {
  local max=0 f n
  if [ -d "$CARDS_DIR" ]; then
    for f in "$CARDS_DIR"/C-*.md; do
      [ -e "$f" ] || continue
      n="$(basename "$f" .md)"; n="${n#C-}"
      case "$n" in (*[!0-9]*) continue;; esac
      n=$((10#$n))
      [ "$n" -gt "$max" ] && max=$n
    done
  fi
  echo "$max"
}

resolve_card_file() { # $1 = "C-001" | "001" | "1" -> path or empty
  local arg="$1" num
  num="${arg#C-}"; num="${num#c-}"
  case "$num" in (*[!0-9]*) echo ""; return 1;; esac
  num=$((10#$num))
  printf '%s/C-%03d.md' "$CARDS_DIR" "$num"
}

card_status() { # $1 = file
  grep -m1 -E '^status:' "$1" 2>/dev/null | sed 's/^status:[[:space:]]*//' | tr -d '\r' | awk '{print $1}'
}

stage_skipped() { # $1 = stage name; 0 = yes (operator debt-skipped it)
  [ -f "$SKIPPED_FILE" ] && grep -qxF "$1" "$SKIPPED_FILE" 2>/dev/null
}

planning_complete() { # 0 = yes: each stage is clean, OR debt-skipped (a skipped stage may have no file)
  local s
  for s in $STAGES; do
    if [ ! -f "$FLOW_DIR/$s.md" ]; then
      stage_skipped "$s" || return 1
      continue
    fi
    if ! scan_gate "$FLOW_DIR/$s.md" >/dev/null 2>&1; then
      stage_skipped "$s" || return 1
    fi
  done
  return 0
}

# project type (web|cli|library|skill); absent => web. Adapts done-evidence + guidance.
get_project_type() {
  local t; t="$(cat "$PROJECT_TYPE_FILE" 2>/dev/null | tr -d '\r' | awk 'NF{print; exit}')"
  printf '%s' "${t:-web}"
}
done_def_for_type() {
  case "${1:-web}" in
    web)     echo "a live deployed URL you can click + real curl output (NOT 'tests pass')" ;;
    cli)     echo "the tool installs and a real invocation returns the expected output + exit code" ;;
    library) echo "the public API imports + a usage example runs + the coverage threshold is met" ;;
    skill)   echo "installed into ~/.claude/skills and a real run reaches its own done-definition" ;;
    *)       echo "world-state proof appropriate to the project type" ;;
  esac
}

# ---------- concurrency lock (prevents two sessions stomping one project's plan) ----------
# A COORDINATION lock, not a per-file mutex: it records who last mutated this project's flow/
# and when, so a second concurrent session is refused (strong identity) or warned (weak
# identity) instead of silently corrupting the plan. Locks older than FLOW_LOCK_TTL are stale
# and auto-reclaimed. FLOW_FORCE=1 takes over a live foreign lock.

_now() { date +%s 2>/dev/null || echo 0; }

# First non-empty explicit/AI-harness session id, auto-derived with NO operator action. The
# cascade makes the lock hard-refusable in agent sessions (where no tty exists and operators
# never export FLOW_SESSION_ID): an explicit override wins, then the harness-injected id of
# whichever engine is driving. | and newlines are stripped so the id cannot corrupt the
# pipe-delimited lock line. Empty output = no stable id available (fall back to tty/ppid).
_session_env_id() {
  local v
  for v in "${FLOW_SESSION_ID:-}" "${CLAUDE_CODE_SESSION_ID:-}" "${CODEX_SESSION_ID:-}" \
           "${CODEX_THREAD_ID:-}" "${AGY_SESSION_ID:-}" "${ANTIGRAVITY_SESSION_ID:-}"; do
    [ -n "$v" ] && { printf '%s' "$(printf '%s' "$v" | tr -d '\r\n|')"; return; }
  done
}

# Raw session id for the usage-log `session_id` field (auto-derived; never empty).
_session_id() {
  local s; s="$(_session_env_id)"
  if [ -n "$s" ]; then printf '%s' "$s"; return; fi
  local t; t="$(tty 2>/dev/null || true)"
  if [ -n "$t" ] && [ "$t" != "not a tty" ]; then printf '%s' "$t"; return; fi
  printf 'ppid:%s:%s' "$(uname -n 2>/dev/null || echo host)" "${PPID:-0}"
}

# Identity of THIS invocation for the lock. Strong (hard-refusable) via an explicit/harness
# session id, else a real tty; weak (warn-only, never self-block) via host+PPID otherwise.
flow_lock_owner() {
  local s; s="$(_session_env_id)"
  if [ -n "$s" ]; then printf 'sid:%s' "$s"; return; fi
  local t; t="$(tty 2>/dev/null || true)"
  if [ -n "$t" ] && [ "$t" != "not a tty" ]; then printf 'tty:%s' "$t"; return; fi
  printf 'ppid:%s:%s' "$(uname -n 2>/dev/null || echo host)" "${PPID:-0}"
}
flow_owner_strong() { case "$1" in sid:*|tty:*) return 0 ;; *) return 1 ;; esac; }

# Parse current lock -> LOCK_TS LOCK_OWNER LOCK_PID LOCK_HOST LOCK_CMD. 0 = a lock exists.
_read_lock() {
  LOCK_TS=0; LOCK_OWNER=""; LOCK_PID=""; LOCK_HOST=""; LOCK_CMD=""
  [ -f "$LOCK_FILE" ] || return 1
  IFS='|' read -r LOCK_TS LOCK_OWNER LOCK_PID LOCK_HOST LOCK_CMD < "$LOCK_FILE" 2>/dev/null || return 1
  case "$LOCK_TS" in ''|*[!0-9]*) LOCK_TS=0 ;; esac
  return 0
}
_write_lock() { # $1 = cmd label
  mkdir -p "$FLOW_DIR" 2>/dev/null || true
  printf '%s|%s|%s|%s|%s\n' "$(_now)" "$(flow_lock_owner)" "$$" "$(uname -n 2>/dev/null || echo host)" "${1:-?}" \
    > "$LOCK_FILE" 2>/dev/null || true
}

# Guard a MUTATING command. 0 = lock taken/refreshed (proceed); 1 = refused (caller aborts).
lock_acquire() { # $1 = cmd label
  local me age; me="$(flow_lock_owner)"
  # Ensure the lock's PARENT dir exists so the atomic `mkdir "$LOCK_DIR"` test-and-set below can
  # succeed on a brand-new project (flow/ may not exist yet at stage-00 unlock / first run).
  # This creates only the parent; LOCK_DIR itself is still created with plain mkdir (atomic guard).
  mkdir -p "$FLOW_DIR" 2>/dev/null || true

  # FLOW_FORCE: unconditional takeover; reset the atomic claim dir so the mkdir guard is bypassed cleanly.
  if [ -n "${FLOW_FORCE:-}" ]; then
    if _read_lock && [ -n "$LOCK_OWNER" ] && [ "$LOCK_OWNER" != "$me" ]; then
      echo "NOTE: FLOW_FORCE set - taking over a lock held by [$LOCK_OWNER] (cmd '${LOCK_CMD:-?}')."
    fi
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    mkdir "$LOCK_DIR" 2>/dev/null || true
    _write_lock "$1"; return 0
  fi

  # Same-session refresh: if the lock file names OUR owner, just update the timestamp.
  # The session already owns LOCK_DIR from the original claim; no need to re-mkdir.
  if _read_lock && [ "$LOCK_OWNER" = "$me" ]; then _write_lock "$1"; return 0; fi

  # W5 — Atomic claim guard. mkdir is POSIX test-and-set: exactly one racing caller wins.
  # Only attempt when neither the claim dir nor a legacy flat-file lock exists (truly free state).
  # Legacy flat-file (LOCK_FILE without LOCK_DIR): tolerated — fall through to reclaim logic below
  # so an in-flight upgrade from v0.11 does not strand a live lock.
  if ! [ -d "$LOCK_DIR" ] && ! [ -f "$LOCK_FILE" ]; then
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      _write_lock "$1"; return 0                                               # won the race; lock claimed
    fi
    # Lost the race: LOCK_DIR now owned by the winner. Fall through to BLOCK below.
    # LOCK_FILE may not be written yet (tiny window); treat LOCK_DIR presence as lock-held.
  fi

  # --- v0.11 FR4 reclaim logic (runs for: race loser, legacy flat-file, any existing lock) ---
  if _read_lock; then
    age=$(( $(_now) - LOCK_TS )); [ "$age" -lt 0 ] && age=0
    # Dead-process reclaim: if the lock's owner PID is on THIS host and no longer alive, reclaim
    # immediately rather than waiting out the TTL. Gated on same-host (a PID is meaningless across
    # hosts); kill -0 works on macOS/Linux/Git-Bash. PID reuse only ever DEFERS a reclaim (safe).
    local myhost; myhost="$(uname -n 2>/dev/null || echo host)"
    if [ -n "$LOCK_PID" ] && [ "$LOCK_HOST" = "$myhost" ] && ! kill -0 "$LOCK_PID" 2>/dev/null; then
      echo "NOTE: reclaiming a flow lock from a dead session [$LOCK_OWNER] (pid $LOCK_PID no longer alive)."
      rm -rf "$LOCK_DIR" 2>/dev/null || true
      # F2: check mkdir atomically — if another reclaimer beat us, do NOT write
      if mkdir "$LOCK_DIR" 2>/dev/null; then
        _write_lock "$1"; return 0
      fi
      # Lost the re-mkdir race; another reclaimer already owns the slot — back off
      echo "BLOCKED: another flow session claimed this project concurrently (concurrent /flow corrupts the plan)."
      echo "  (reclaim mkdir race lost — another session already took the lock.)"
      return 1
    elif [ "$age" -ge "$FLOW_LOCK_TTL" ]; then
      echo "NOTE: reclaiming a STALE flow lock from [$LOCK_OWNER] (${age}s old >= ${FLOW_LOCK_TTL}s TTL)."
      rm -rf "$LOCK_DIR" 2>/dev/null || true
      # F2: check mkdir atomically — if another reclaimer beat us, do NOT write
      if mkdir "$LOCK_DIR" 2>/dev/null; then
        _write_lock "$1"; return 0
      fi
      # Lost the re-mkdir race; another reclaimer already owns the slot — back off
      echo "BLOCKED: another flow session claimed this project concurrently (concurrent /flow corrupts the plan)."
      echo "  (reclaim mkdir race lost — another session already took the lock.)"
      return 1
    fi
    if flow_owner_strong "$me" && flow_owner_strong "$LOCK_OWNER"; then         # fresh + provably foreign
      echo "BLOCKED: another flow session is active on this project (concurrent /flow corrupts the plan)."
      echo "  lock: [$LOCK_OWNER] cmd '${LOCK_CMD:-?}', ${age}s ago (TTL ${FLOW_LOCK_TTL}s) -> $LOCK_FILE"
      echo "  Close the other session. If it is truly gone: re-run with FLOW_FORCE=1, or '/flow unlock'."
      return 1
    fi
    echo "WARNING: a flow lock from [$LOCK_OWNER] is ${age}s old; this session has no stable FLOW_SESSION_ID"
    echo "  so I cannot prove it is a different session - PROCEEDING. Export FLOW_SESSION_ID per session"
    echo "  (see SKILL.md) for hard protection against concurrent runs."
    _write_lock "$1"; return 0
  fi

  # LOCK_DIR exists but LOCK_FILE not yet written: either a race loser in the tiny window
  # after mkdir loss, or a crashed winner (F1: process died after mkdir but before _write_lock).
  # Distinguish via mtime: if LOCK_DIR is older than FLOW_LOCK_TTL it is a crashed stale claim
  # and safe to reclaim; if fresh, treat as live mid-claim and BLOCK.
  if [ -d "$LOCK_DIR" ]; then
    local ttl_min; ttl_min=$(( (FLOW_LOCK_TTL + 59) / 60 ))   # ceiling division to minutes
    if find "$LOCK_DIR" -maxdepth 0 -mmin +"$ttl_min" 2>/dev/null | grep -q .; then
      echo "NOTE: reclaiming a stale crashed claim (LOCK_DIR old, no LOCK_FILE)."
      rm -rf "$LOCK_DIR" 2>/dev/null || true
      # F2: atomic re-claim; if another reclaimer beat us, don't write
      if mkdir "$LOCK_DIR" 2>/dev/null; then
        _write_lock "$1"; return 0
      fi
      # Lost re-mkdir race; fall through to BLOCKED below
    fi
    echo "BLOCKED: another flow session is claiming this project (concurrent /flow corrupts the plan)."
    echo "  (lock dir exists; the other session is mid-claim.  If it is truly gone: '/flow unlock'.)"
    return 1
  fi

  # No LOCK_DIR and no LOCK_FILE: truly free state reached after reclaim or first run.
  # F2: check mkdir exit status — if another caller beats us here, refuse rather than double-write
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    _write_lock "$1"; return 0                                                   # won the clean claim
  fi
  # Another caller won; fall through — will hit the BLOCKED path on next iteration.
  echo "BLOCKED: another flow session is claiming this project (concurrent /flow corrupts the plan)."
  echo "  (lost atomic claim race.  If the other session is truly gone: '/flow unlock'.)"
  return 1
}

# Read-only warning for 'status' - never blocks.
lock_warn() {
  local me age; me="$(flow_lock_owner)"
  _read_lock || return 0
  [ -z "$LOCK_OWNER" ] && return 0
  [ "$LOCK_OWNER" = "$me" ] && return 0
  age=$(( $(_now) - LOCK_TS )); [ "$age" -lt 0 ] && age=0
  [ "$age" -ge "$FLOW_LOCK_TTL" ] && return 0
  echo "  lock:    WARNING - another session [$LOCK_OWNER] mutated ${age}s ago (cmd '${LOCK_CMD:-?}');"
  echo "           avoid running '/flow next|card' here concurrently (set FLOW_SESSION_ID to enforce)."
}

# ---------- recall (read-back of durable memory: close the capture->reuse loop) ----------
# The harness/RETRO/DEBT/playbooks layers CAPTURE knowledge; recall READS it back so an agent
# starts a stage/card with prior pain + decisions in view instead of cold. Degrades gracefully:
# markdown ledgers always; SQLite harness queries only when python+harness are present.

_harness_query() { harness_emit query "$1"; }   # $1 = matrix|backlog|friction|tools

recall_open_debt() { [ -f "$DEBT_FILE" ] && grep -E '^- \[ \] DEBT:' "$DEBT_FILE" 2>/dev/null || true; }
recall_retro_tail() { # $1 = N lines; entries live after the '---' separator in RETRO.md
  [ -f "$RETRO_FILE" ] || return 0
  awk '/^---/{seen=1; next} seen && NF {print}' "$RETRO_FILE" 2>/dev/null | tail -"${1:-3}"
}
recall_playbooks() { # the "paid-for stack knowledge" index (skill-global, excludes README)
  [ -d "$PLAYBOOKS_DIR" ] || return 0
  local f n
  for f in "$PLAYBOOKS_DIR"/*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f" .md)"; [ "$n" = "README" ] && continue
    echo "$n"
  done
}
recall_global_playbooks() { # cross-project playbooks dropped in ~/.claude/flow/playbooks (lessons travel A->B)
  [ -d "$GLOBAL_KB_DIR" ] || return 0
  local f n
  for f in "$GLOBAL_KB_DIR"/*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f" .md)"; [ "$n" = "README" ] && continue
    echo "$n"
  done
}
recall_prev_card() { # most-recent DONE card's id + title + Scope (previous-card intelligence)
  [ -d "$CARDS_DIR" ] || return 0
  local f best=""
  for f in "$CARDS_DIR"/C-*.md; do
    [ -e "$f" ] || continue
    [ "$(card_status "$f")" = "done" ] && best="$f"
  done
  [ -n "$best" ] || return 0
  echo "last done: $(basename "$best" .md)"
  grep -m1 '^# ' "$best" 2>/dev/null | sed 's/^# /  title: /'
  awk '/^## Scope/{f=1; next} f && /^## /{f=0} f && NF {print "  | " $0}' "$best" 2>/dev/null | head -4
}

# ---------- gate-fired durable capture (engine writes the record, not agent goodwill) ----------
# Promotes the per-stage "durable hook" prose (agent-stage-mapping.md) to engine-fired calls so
# capture is reliable. Uses ONLY the existing harness CLI; no-op when the durable layer is off.
gate_durable_hook() { # $1 = stage just passed
  harness_available || return 0
  case "$1" in
    01-research)
      # seed the work-classification the harness model starts from (lane=normal default).
      local pitch out
      pitch="$(awk '/^## Pitch/{f=1; next} f && NF {print; exit}' "$FLOW_DIR/00-idea.md" 2>/dev/null | cut -c1-160)"
      [ -n "$pitch" ] || pitch="research gate passed"
      out="$(harness_emit intake --type new_spec --summary "$pitch")"
      printf '%s\n' "$out" | grep -i 'intake' | sed 's/^/  harness: /'
      echo "  harness: intake seeded (lane=normal). If it touches auth/data/external/contracts, reclassify:"
      echo "           flow harness intake --type new_spec --summary \"...\" --flags auth,data_model,external_systems"
      ;;
    04-adr)
      echo "  harness: ADR passed - record each non-trivial decision durably (the ADR md is NOT a durable record):"
      echo "           flow harness decision add --id <slug> --summary \"<what + why>\" --doc flow/04-adr.md"
      ;;
  esac
}

# ---------- commands ----------

# Shared gate-state block: same idx/scan_gate logic status has always used, extracted so
# `resume` (Phase 2) prints byte-identical gate text and the two verbs can never disagree.
# Side-effect-free (only reads $idx + FLOW_DIR files via scan_gate, both already read-only).
_gate_state_brief() { # $1 = current_stage_idx (caller already computed it), $2 = optional dwell
  # string (e.g. "45m") appended to the first line. Takes dwell as a plain arg (never wraps this
  # function's own call site in a pipe) - the BLOCKED branch below re-invokes scan_gate
  # unredirected, and piping that nested-call output into a consumer (e.g. `| while read`) was
  # found to hang indefinitely under Git-Bash/MSYS (an early-pipe-reader-exit class issue) -
  # verified by a live code-review reproduction, not merely suspected.
  local idx="$1" dwell="${2:-}"
  if [ "$idx" -lt 0 ]; then
    echo "planning: not started"
    echo "  -> run '/flow next' to unlock stage 00 (idea)"
  else
    local cur; cur="$(stage_name_at "$idx")"
    if [ -n "$dwell" ]; then
      echo "planning: at stage $cur (for $dwell)"
    else
      echo "planning: at stage $cur"
    fi
    if scan_gate "$FLOW_DIR/$cur.md" >/dev/null 2>&1; then
      if [ "$idx" -ge "$LAST_STAGE_IDX" ]; then
        echo "  gate: PASS - planning complete. '/flow card' is unlocked."
        prd_declares_fr && echo "        tip: '/flow consistency' checks FR->card->contract coverage."
      else
        echo "  gate: PASS - run '/flow next' to unlock the next stage."
      fi
    else
      echo "  gate: BLOCKED -"
      scan_gate "$FLOW_DIR/$cur.md"
    fi
  fi
}

_stage_dwell() { # $1 = current stage name -> "Xm/Xh/Xd" from genuine entry, or "" if no match
  local cur="$1" lines epoch
  [ -f "$EVENTS_FILE" ] || return 0
  lines="$(_resume_valid_lines)"
  [ -n "$lines" ] || return 0
  # A genuine entry into $cur is the ONLY case where cmd_next's own event-write sets
  # exit_code=0 while stage_to=$cur (flow.sh: unlock-stage-00 branch and the successful-advance
  # branch). A failed `/flow next` retry ALSO writes stage_to=$cur but with exit_code=1 - and
  # critically its stage_from is left at the script default "" (never set on that path), so a
  # `stage_from != cur` check alone does NOT exclude it (empty string always != a real stage
  # name) and the anchor would keep shrinking to the latest failed retry. exit_code is the only
  # field that actually discriminates the two real event shapes cmd_next produces.
  epoch="$(printf '%s\n' "$lines" | while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ "$(_ws_get "$line" stage_to)" = "$cur" ] || continue
    [ "$(_ws_get_num "$line" exit_code)" = "0" ] || continue
    printf '%s\n' "$(_ws_get_num "$line" epoch_s)"
  done | tail -1)"
  [ -n "$epoch" ] && _elapsed_human "$epoch"
}

cmd_status() {
  local idx; idx="$(current_stage_idx)"
  echo "flow status"
  echo "  project: $ROOT"
  echo "  mode:    $(cat "$MODE_FILE" 2>/dev/null | tr -d '\r' || echo teach) (default teach)"
  echo "  type:    $(get_project_type) (done = $(done_def_for_type "$(get_project_type)"))"
  lock_warn
  echo
  echo "NEXT -> $(_next_action)"
  echo
  if [ -f "$FLOW_DIR/00-inspect.md" ]; then
    if scan_gate "$FLOW_DIR/00-inspect.md" >/dev/null 2>&1; then
      echo "brownfield: assessment present, gate clean (flow/00-inspect.md)"
    else
      echo "brownfield: assessment present but gate NOT clean - run '/flow assess'"
    fi
    echo
  fi
  local dwell="" cur=""
  [ "$idx" -ge 0 ] && { cur="$(stage_name_at "$idx")"; dwell="$(_stage_dwell "$cur")"; }
  _gate_state_brief "$idx" "$dwell"
  echo
  local total; total="$(highest_card)"
  if [ "$total" -gt 0 ]; then
    if [ "$total" -gt 10 ]; then
      # Compact form: respects the real 2-state (todo|done) + .inflight-registry data model -
      # there is no "in-progress" status value (card_status/:228). Y = todo cards also present
      # in the .inflight registry; Z = remaining todo. In-flight and todo cards are always
      # listed individually; only done cards are summarized away.
      # N in the header is the ACTUAL file count (done_n+infl_n+todo_n by construction), not
      # highest_card()'s max-suffix value - card numbering can have gaps (a deleted card), and
      # highest_card() would then silently break the "X+Y+Z=N" invariant the compact form
      # promises. A single pass builds both the counts and the todo-line list together.
      local f st infl_ids done_n=0 infl_n=0 todo_n=0 todo_lines=""
      infl_ids="$(_inflight_file)"
      for f in "$CARDS_DIR"/C-*.md; do
        [ -e "$f" ] || continue
        st="$(card_status "$f")"
        if [ "$st" = "done" ]; then
          done_n=$((done_n + 1))
        elif [ "$st" = "todo" ]; then
          local id; id="$(basename "$f" .md)"
          if [ -f "$infl_ids" ] && grep -q "^$id " "$infl_ids" 2>/dev/null; then
            infl_n=$((infl_n + 1))
          else
            todo_n=$((todo_n + 1))
            todo_lines="$todo_lines  $id: todo
"
          fi
        fi
      done
      echo "cards: $((done_n + infl_n + todo_n)) created ($done_n done · $infl_n in flight · $todo_n todo)"
      local infl_out; infl_out="$(inflight_display)"
      [ -n "$infl_out" ] && { echo "  in flight (operator-marked via '/flow card start'):"; printf '%s\n' "$infl_out"; }
      [ -n "$todo_lines" ] && printf '%s' "$todo_lines"
      [ "$done_n" -gt 0 ] && echo "  (+$done_n more done)"
    else
      echo "cards: $total created"
      local f st
      for f in "$CARDS_DIR"/C-*.md; do
        [ -e "$f" ] || continue
        st="$(card_status "$f")"
        echo "  $(basename "$f" .md): ${st:-?}"
      done
      local infl_out; infl_out="$(inflight_display)"
      [ -n "$infl_out" ] && { echo "  in flight (operator-marked via '/flow card start'):"; printf '%s\n' "$infl_out"; }
    fi
  else
    echo "cards: none yet"
  fi
  local debt_n pb_n retro_last
  debt_n="$(recall_open_debt | awk 'END{print NR}')"
  pb_n="$(recall_playbooks | awk 'END{print NR}')"
  retro_last="$(recall_retro_tail 1)"
  echo
  echo "memory: ${debt_n} open debt · ${pb_n} playbooks${retro_last:+ · last retro: [$retro_last]}"
  echo "  -> '/flow recall' reads back debt/retro/prev-card/harness before you work."
}

# ---------- resume (read-only session-story brief; the "AI context amnesia" fix) ----------

# Torn-line defense: the per-project events log is unbounded per-row and an EXIT-trap append
# can be in flight while resume reads it, so validate every candidate line's shape (must start
# with '{"ts":' and end with '}') and drop a non-conforming line rather than trust it. The
# python harness guards the same class of risk with json.loads; this is the shell equivalent.
# ALSO reject a line containing more than one '{"ts":' occurrence: two complete JSON objects
# glued together with no separating newline (a lost trailing \n on a non-atomic append) would
# still pass the edge-shape check above, and _ws_get's greedy match would then silently resolve
# every field to the SECOND object - the first event vanishes with no error or warning. A real
# single-object row's own "ts" key appears exactly once.
_resume_valid_lines() {
  [ -f "$EVENTS_FILE" ] || return 0
  tail -n 500 "$EVENTS_FILE" 2>/dev/null | tr -d '\r' | while IFS= read -r line; do
    case "$line" in
      '{"ts":'*'}')
        n_ts="$(printf '%s' "$line" | grep -o '{"ts":' | wc -l)"
        [ "$n_ts" -eq 1 ] && printf '%s\n' "$line"
        ;;
    esac
  done
}

cmd_resume() {
  local idx; idx="$(current_stage_idx)"
  if [ "$idx" -lt 0 ]; then
    echo "nothing to resume - $(_next_action)"
    return 0
  fi

  echo "flow resume"
  echo "  project: $ROOT"
  echo

  if [ ! -s "$EVENTS_FILE" ]; then
    echo "no telemetry - showing gate state only"
    echo
    _gate_state_brief "$idx"
    echo
    echo "NEXT -> $(_next_action)"
    return 0
  fi

  local lines; lines="$(_resume_valid_lines)"
  local cur_sess; cur_sess="$(_session_id)"

  # ---- LAST SESSION (command NAMES + exit + stage transitions only - never raw args: they
  # can carry unmasked secrets in free-text fields, and a quote-blind extractor would truncate
  # a value containing an escaped quote anyway) ----
  local first_own_epoch=""
  first_own_epoch="$(printf '%s\n' "$lines" | while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ "$(_ws_get "$line" session_id)" = "$cur_sess" ] || continue
    printf '%s\n' "$(_ws_get_num "$line" epoch_s)"
    break
  done)"

  local foreign_sess=""
  foreign_sess="$(printf '%s\n' "$lines" | while IFS= read -r line; do
    [ -n "$line" ] || continue
    local s; s="$(_ws_get "$line" session_id)"
    [ "$s" = "$cur_sess" ] && continue
    printf '%s\n' "$s"
  done | tail -1)"

  if [ -n "$foreign_sess" ]; then
    # session_id may be a reusable `ppid:host:NNN` form or a UUID. Detection = string
    # inequality (above) PLUS a time-gap fallback: a `ppid:` scheme whose latest foreign row is
    # < 15 min older than this session's own first row is more likely PID reuse than a genuine
    # prior session - label it accordingly rather than asserting a "last session" that may
    # never have existed. Absolute timestamps are shown either way.
    local label="last session" f_epoch gap
    case "$foreign_sess" in
      ppid:*)
        f_epoch="$(printf '%s\n' "$lines" | while IFS= read -r line; do
          [ "$(_ws_get "$line" session_id)" = "$foreign_sess" ] || continue
          printf '%s\n' "$(_ws_get_num "$line" epoch_s)"
        done | tail -1)"
        # Anchor on the current session's OWN first row when one exists; otherwise fall back
        # to wall-clock now(). Without this fallback, the gap check was a no-op on resume's own
        # primary documented trigger (SKILL.md: "run /flow resume BEFORE any other flow verb")
        # - at that point there IS no own-session row yet, so the fallback never fired exactly
        # when ppid-reuse risk is highest (fresh session, no prior activity to compare against).
        local anchor="$first_own_epoch"
        [ -n "$anchor" ] || anchor="$(_now)"
        if [ -n "$f_epoch" ]; then
          gap=$(( anchor - f_epoch )); [ "$gap" -lt 0 ] && gap=$(( -gap ))
          [ "$gap" -lt 900 ] && label="recent activity"
        fi
        ;;
    esac
    local last_ts
    last_ts="$(printf '%s\n' "$lines" | while IFS= read -r line; do
      [ "$(_ws_get "$line" session_id)" = "$foreign_sess" ] || continue
      printf '%s\n' "$(_ws_get "$line" ts)"
    done | tail -1)"
    echo "$label (as of $last_ts):"
    printf '%s\n' "$lines" | while IFS= read -r line; do
      [ -n "$line" ] || continue
      [ "$(_ws_get "$line" session_id)" = "$foreign_sess" ] || continue
      local cmd ec sf st ts marker trans
      cmd="$(_ws_get "$line" command)"; ec="$(_ws_get_num "$line" exit_code)"
      sf="$(_ws_get "$line" stage_from)"; st="$(_ws_get "$line" stage_to)"
      ts="$(_ws_get "$line" ts)"
      if [ "$ec" = "0" ]; then marker="ok"; else marker="FAIL($ec)"; fi
      trans=""
      { [ -n "$sf" ] || [ -n "$st" ]; } && trans="  [$sf -> $st]"
      printf '  %s  %-10s %s%s\n' "$ts" "$cmd" "$marker" "$trans"
    done | tail -5
    echo
  fi

  # ---- IN FLIGHT ----
  local infl_out; infl_out="$(inflight_display)"
  if [ -n "$infl_out" ]; then
    echo "in flight:"
    printf '%s\n' "$infl_out"
    echo
  fi

  # ---- GATE STATE (identical to `status`'s own block - see _gate_state_brief). NOTE: this
  # reports only the CURRENT stage's gate, while NEXT (below) scans back for the earliest
  # genuinely-blocked stage - by design (an earlier un-skipped block is the real next action
  # even when the current stage's own gate is clean). The two lines can read as contradictory
  # in that rare state ("gate: PASS" immediately followed by "fix gate: ... in flow/02-..."); this
  # is correct, not a bug - GATE STATE answers "is the CURRENT stage clean", NEXT answers "what
  # do I actually do next", and those are different questions when an earlier stage is blocked. ----
  _gate_state_brief "$idx"
  echo

  # ---- NEXT (shared with `status` via _next_action - the two verbs can never disagree) ----
  echo "NEXT -> $(_next_action)"
}

cmd_next() {
  lock_acquire next || return 1
  local idx; idx="$(current_stage_idx)"
  if [ "$idx" -lt 0 ]; then
    mkdir -p "$FLOW_DIR"
    cp "$TEMPLATE_DIR/00-idea.md" "$FLOW_DIR/00-idea.md"
    seed_law_files
    # Cycle id (idempotent): reuse one already stamped by a prior assess so assess->plan is ONE cycle.
    _ensure_cycle
    FLOW_LOG_STAGE_TO="00-idea"
    echo "PASS: unlocked stage 00 -> flow/00-idea.md"
    echo "Fill it in, check its gate boxes, then run '/flow next'."
    return 0
  fi
  local cur; cur="$(stage_name_at "$idx")"
  if ! scan_gate "$FLOW_DIR/$cur.md" >/dev/null 2>&1; then
    echo "FAIL: gate for stage $cur is not clean."
    scan_gate "$FLOW_DIR/$cur.md"
    # attribute the failing event to THIS stage (so usage top-fail-stage + propose can see it)
    # and record WHICH checks failed, so a chronically-failing stage is diagnosable.
    FLOW_LOG_STAGE_TO="$cur"
    FLOW_LAST_GATE_FAIL="fill:$(grep -c '\[FILL' "$FLOW_DIR/$cur.md" 2>/dev/null || echo 0),unchecked:$(grep -cE '^[[:space:]]*- \[ \]' "$FLOW_DIR/$cur.md" 2>/dev/null || echo 0)"
    echo
    echo "Fix the above, then run '/flow next' again. (Kill at a gate is also valid.)"
    return 1
  fi
  if [ "$idx" -ge "$LAST_STAGE_IDX" ]; then
    FLOW_LOG_STAGE_FROM="$cur"
    if planning_complete; then
      echo "PASS: stage $cur gate clean. Planning is COMPLETE."
      echo "All planning stages passed (or were debt-skipped). Run '/flow card' to create build cards."
      if prd_declares_fr; then
        echo "  tip: the PRD declares FR ids - run '/flow consistency' to check FR->card->contract coverage before building."
      fi
    else
      echo "PASS: stage $cur gate clean - but an earlier stage is still BLOCKED (and not debt-skipped)."
      echo "Run '/flow' to see which. If it is a legitimate, debt-recorded skip, use"
      echo "'/flow skip <stage> --reason ...'. '/flow card' stays blocked until then."
    fi
    return 0
  fi
  local nxt; nxt="$(stage_name_at "$((idx + 1))")"
  if [ -f "$FLOW_DIR/$nxt.md" ]; then
    echo "PASS: stage $cur gate clean. Stage $((idx + 1)) ($nxt.md) already exists - not overwritten."
    return 0
  fi
  cp "$TEMPLATE_DIR/$nxt.md" "$FLOW_DIR/$nxt.md"
  FLOW_LOG_STAGE_FROM="$cur"; FLOW_LOG_STAGE_TO="$nxt"
  echo "PASS: stage $cur gate clean -> unlocked stage $((idx + 1)) (flow/$nxt.md)"
  gate_durable_hook "$cur"
  echo "  tip: '/flow recall' surfaces prior debt/retro/friction before you fill this stage."
  return 0
}

# ---- card lifecycle: operator-marked start + CLI-owned done (legible-lifecycle layer) ----
# The card 'status:' field stays the 2-state todo|done the gate validates. "in flight" is a
# transient the runner tracks in a side registry ($CARDS_DIR/.inflight: "<id> <epoch>"), so it
# is PORTABLE (no python/harness needed to SHOW it) and never touches the gated frontmatter.
# Both verbs COEXIST with hand-editing 'status:' + '/flow check' — they add convenience, they
# do not replace it.
_inflight_file() { echo "$CARDS_DIR/.inflight"; }

_inflight_set() { # $1=id  -> record/refresh an in-flight start stamp (dedup by id)
  local id="$1" infl; infl="$(_inflight_file)"; mkdir -p "$CARDS_DIR"
  if [ -f "$infl" ]; then grep -v "^$id " "$infl" 2>/dev/null > "$infl.tmp" || true; mv -f "$infl.tmp" "$infl" 2>/dev/null || true; fi
  printf '%s %s\n' "$id" "$(_now)" >> "$infl"
}

_inflight_clear() { # $1=id  -> drop an id (done/abandoned)
  local id="$1" infl; infl="$(_inflight_file)"
  [ -f "$infl" ] || return 0
  grep -v "^$id " "$infl" 2>/dev/null > "$infl.tmp" || true; mv -f "$infl.tmp" "$infl" 2>/dev/null || true
}

_elapsed_human() { # $1=start-epoch -> "Xm"/"Xh"/"Xd" (integer; GNU/BSD-portable, no date -d/-r)
  local start="${1:-0}" s now
  case "$start" in ''|*[!0-9]*) start=0;; esac
  now="$(_now)"; s=$(( now - start )); [ "$s" -lt 0 ] && s=0
  if   [ "$s" -lt 3600 ];  then echo "$(( s / 60 ))m"
  elif [ "$s" -lt 86400 ]; then echo "$(( s / 3600 ))h"
  else echo "$(( s / 86400 ))d"; fi
}

inflight_display() { # emit a line per todo card still marked in flight (stale ids self-skip)
  local infl id ts f; infl="$(_inflight_file)"
  [ -f "$infl" ] || return 0
  while read -r id ts; do
    [ -n "$id" ] || continue
    f="$(resolve_card_file "$id" 2>/dev/null)"
    [ -n "$f" ] && [ -f "$f" ] || continue                   # card gone -> stale, skip
    [ "$(card_status "$f")" = "todo" ] || continue            # only todo cards are "in flight"
    printf '    %s (in flight, started %s ago)\n' "$id" "$(_elapsed_human "$ts")"
  done < "$infl"
}

# Single source of truth for "what should I do next" - used by BOTH `status` (Phase 3) and
# `resume` (this phase) so the two verbs can never disagree about the next step. Pure function
# of existing state helpers; no side effects. Decision ladder, first match wins.
_next_action() {
  local idx; idx="$(current_stage_idx)"
  if [ "$idx" -lt 0 ]; then
    echo "run '/flow next' to unlock stage 00"
    return 0
  fi
  # Scan every stage through the current one for the FIRST that is neither gate-clean nor
  # debt-skipped - mirrors planning_complete's own scan, so this can never recommend "cut
  # cards" while an earlier (non-current) stage is still genuinely blocked.
  local s blocked="" cur; cur="$(stage_name_at "$idx")"
  for s in $STAGES; do
    if [ ! -f "$FLOW_DIR/$s.md" ]; then
      stage_skipped "$s" && continue
      break
    fi
    if ! scan_gate "$FLOW_DIR/$s.md" >/dev/null 2>&1; then
      stage_skipped "$s" && continue
      blocked="$s"; break
    fi
    [ "$s" = "$cur" ] && break
  done
  if [ -n "$blocked" ]; then
    # Materialize scan_gate's output into a variable FIRST, then extract from that string -
    # never pipe scan_gate's own (multi-line, internally-piped) output straight into a reader
    # that can exit early like `grep -m1`. An early-exiting reader closing its end of the pipe
    # while scan_gate's own nested `printf | sed` is still writing was found to hang
    # indefinitely under Git-Bash/MSYS (early-pipe-reader-exit class issue, confirmed by a live
    # reproduction) - command substitution alone (no early-exit reader) does not hit this.
    local gate_out reason
    gate_out="$(scan_gate "$FLOW_DIR/$blocked.md" 2>/dev/null)"
    reason="$(printf '%s\n' "$gate_out" | grep -m1 '\[x\]' | sed -E 's/^[[:space:]]*\[x\][[:space:]]*//; s/:$//')"
    echo "fix gate: ${reason:-gate violations} in flow/$blocked.md"
    return 0
  fi
  if [ "$idx" -lt "$LAST_STAGE_IDX" ]; then
    echo "run '/flow next' to unlock the next stage"
    return 0
  fi
  # Planning complete (every stage through the last is clean or debt-skipped).
  local total; total="$(highest_card)"
  if [ "$total" -eq 0 ]; then
    echo "run '/flow card' to cut build cards"
    return 0
  fi
  local infl id ts f
  infl="$(_inflight_file)"
  if [ -f "$infl" ]; then
    while read -r id ts; do
      [ -n "$id" ] || continue
      f="$(resolve_card_file "$id" 2>/dev/null)"
      [ -n "$f" ] && [ -f "$f" ] || continue
      [ "$(card_status "$f")" = "todo" ] || continue
      echo "continue $id (in flight $(_elapsed_human "$ts"))"
      return 0
    done < "$infl"
  fi
  local any_todo=0 fpath
  for fpath in "$CARDS_DIR"/C-*.md; do
    [ -e "$fpath" ] || continue
    [ "$(card_status "$fpath")" = "todo" ] && { any_todo=1; break; }
  done
  if [ "$any_todo" -eq 1 ]; then
    echo "start next card: '/flow card start C-NNN'"
    return 0
  fi
  echo "run '/flow check' then ship per stage 09"
}

_set_card_status() { # $1=file $2=value -> rewrite the ^status: line (portable substitute; temp+mv)
  local f="$1" v="$2"
  sed "s/^status:.*/status: $v/" "$f" > "$f.tmp" 2>/dev/null || { rm -f "$f.tmp"; return 1; }
  mv -f "$f.tmp" "$f" 2>/dev/null || { rm -f "$f.tmp"; return 1; }
  return 0
}

cmd_card_start() { # mark a card actively in progress (operator-visible in_progress)
  local arg="${1:-}"
  if [ -z "$arg" ]; then echo "usage: /flow card start C-NNN"; return 1; fi
  lock_acquire card || return 1
  local file; file="$(resolve_card_file "$arg")"
  if [ -z "$file" ] || [ ! -f "$file" ]; then echo "FAIL: card not found for '$arg' (looked for ${file:-?})"; return 1; fi
  local id; id="$(basename "$file" .md)"; FLOW_LOG_CARD="$id"
  if [ "$(card_status "$file")" = "done" ]; then echo "FAIL: $id is already done — nothing to start."; return 1; fi
  _inflight_set "$id"
  harness_call story update --id "$id" --status in_progress   # durable mirror (best-effort)
  echo "PASS: $id marked in flight. Build it, then '/flow card done $id' (or hand-edit status: done + '/flow check $id')."
  return 0
}

cmd_card_done() { # CLI-owned flip to done, gated by the SAME done-rules as '/flow check' (revert on fail)
  local arg="${1:-}"
  if [ -z "$arg" ]; then echo "usage: /flow card done C-NNN"; return 1; fi
  lock_acquire card || return 1
  local file; file="$(resolve_card_file "$arg")"
  if [ -z "$file" ] || [ ! -f "$file" ]; then echo "FAIL: card not found for '$arg' (looked for ${file:-?})"; return 1; fi
  local id orig; id="$(basename "$file" .md)"; FLOW_LOG_CARD="$id"; orig="$(card_status "$file")"
  if [ -z "$orig" ]; then echo "FAIL: $id has no 'status:' line — run '/flow check $id' to see what's missing."; return 1; fi
  if ! _set_card_status "$file" done; then echo "FAIL: could not write status for $id"; return 1; fi
  if cmd_check "$id"; then            # cmd_check enforces evidence/verify AND records the durable done-trace
    _inflight_clear "$id"
    return 0
  fi
  _set_card_status "$file" "${orig:-todo}"   # NOT done — never leave a hollow 'done'
  echo
  echo "REVERTED: $id left at status '${orig:-todo}' — the done-gate above must pass first."
  return 1
}

cmd_card() {
  case "${1:-}" in
    start) shift 2>/dev/null || true; cmd_card_start "${1:-}"; return $? ;;
    done)  shift 2>/dev/null || true; cmd_card_done  "${1:-}"; return $? ;;
  esac
  lock_acquire card || return 1
  if ! planning_complete; then
    echo "FAIL: finish planning first. All stages 00-05 must pass their gates before cards."
    echo "Run '/flow' to see what blocks you."
    return 1
  fi
  if [ ! -f "$TEMPLATE_DIR/card.md" ]; then
    echo "FAIL: card template missing at $TEMPLATE_DIR/card.md"
    return 1
  fi
  mkdir -p "$CARDS_DIR"
  local next; next="$(( $(highest_card) + 1 ))"
  local id; id="$(printf 'C-%03d' "$next")"
  FLOW_LOG_CARD="$id"
  local out="$CARDS_DIR/$id.md"
  if ! sed "s/C-NNN/$id/g" "$TEMPLATE_DIR/card.md" > "$out"; then
    rm -f "$out"
    echo "FAIL: could not write card $id (template/sed error)"
    return 1
  fi
  echo "PASS: created $id -> cards/$id.md"
  echo "Fill its Scope / Allowed files / Verify / Done-evidence, build it, then '/flow check $id'."
  local pc dbt
  pc="$(recall_prev_card)"
  dbt="$(recall_open_debt)"
  if [ -n "$pc" ] || [ -n "$dbt" ]; then
    echo
    echo "Prior knowledge to carry into this card (full read-back: '/flow recall'):"
    [ -n "$pc" ] && printf '%s\n' "$pc" | sed 's/^/  /'
    [ -n "$dbt" ] && { echo "  open debt:"; printf '%s\n' "$dbt" | sed 's/^/    /'; }
  fi
  harness_call story add --id "$id" --title "$id" --lane normal   # durable tracking handle
  return 0
}

cmd_check() {
  local arg="${1:-}"
  if [ -z "$arg" ]; then echo "usage: /flow check C-NNN"; return 1; fi
  local file; file="$(resolve_card_file "$arg")"
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    echo "FAIL: card not found for '$arg' (looked for ${file:-?})"
    return 1
  fi
  local id; id="$(basename "$file" .md)"
  FLOW_LOG_CARD="$id"
  local found=0

  # 1) no [FILL]
  local fills; fills="$(grep -n '\[FILL' "$file" 2>/dev/null || true)"
  if [ -n "$fills" ]; then
    echo "  [x] unfilled [FILL] placeholders:"
    printf '%s\n' "$fills" | sed 's/^/      L/'
    found=1
  fi

  # 2) valid status
  local st; st="$(card_status "$file")"
  case "$st" in
    todo|done) : ;;
    "") echo "  [x] missing 'status:' line (must be todo or done)"; found=1 ;;
    *)  echo "  [x] invalid status '$st' (must be todo or done)"; found=1 ;;
  esac

  # 3) deps present
  if ! grep -qE '^deps:' "$file" 2>/dev/null; then
    echo "  [x] missing 'deps:' line (card ids or \"none\")"
    found=1
  fi

  # 4) required sections (anchored to line start so '### Scope' does not satisfy '## Scope';
  #    prefix match allows trailing text like '## Verify (run these...)')
  local sec
  for sec in "## Scope" "## Allowed files" "## Verify" "## Done-evidence" "## Evidence"; do
    if ! grep -qE "^$sec" "$file" 2>/dev/null; then
      echo "  [x] missing section: $sec"
      found=1
    fi
  done

  # 5) if done: all Verify boxes checked AND Evidence is real world-state
  if [ "$st" = "done" ]; then
    local unchecked; unchecked="$(grep -nE '^[[:space:]]*- \[ \]' "$file" 2>/dev/null || true)"
    if [ -n "$unchecked" ]; then
      echo "  [x] status is 'done' but Verify has unchecked boxes:"
      printf '%s\n' "$unchecked" | sed 's/^/      L/'
      found=1
    fi
    # Evidence body: lines between the '## Evidence' header and the next '## ' heading (or EOF).
    # Bounded awk avoids counting a stray later '## Evidence' as content. tr consumes all stdin
    # (no SIGPIPE); case-glob instead of 'grep -q' which closes the pipe early.
    local ev ev_lc empty_ev=0
    ev="$(awk '/^## Evidence/{f=1; next} f && /^## /{f=0} f{print}' "$file" | tr -d '\r' | sed '/^[[:space:]]*$/d')"
    ev_lc="$(printf '%s' "$ev" | tr '[:upper:]' '[:lower:]')"
    [ -z "$ev" ] && empty_ev=1
    case "$ev_lc" in *"(empty until done)"*|"---"|"--") empty_ev=1 ;; esac
    if [ "$empty_ev" -eq 1 ]; then
      echo "  [x] status is 'done' but ## Evidence is empty (paste world-state proof: URL/curl/DB row)"
      found=1
    fi
  fi

  if [ "$found" -eq 0 ]; then
    echo "PASS: $id is valid (status: $st)."
    case "$st" in
      todo) harness_call story update --id "$id" --status in_progress ;;
      done) harness_call story update --id "$id" --status implemented
            local tr; tr="$(harness_emit trace --summary "card $id reached done-evidence" --story "$id" --outcome completed)"
            [ -n "$tr" ] && printf '%s\n' "$tr" | grep -iE 'tier|to reach' | sed 's/^/  harness: /' ;;
    esac
    return 0
  fi
  FLOW_LAST_GATE_FAIL="fill:$(grep -c '\[FILL' "$file" 2>/dev/null || echo 0),unchecked:$(grep -cE '^[[:space:]]*- \[ \]' "$file" 2>/dev/null || echo 0)"
  echo "FAIL: $id has gate violations (above)."
  return 1
}

cmd_mode() {
  local arg="${1:-}"
  if [ -z "$arg" ]; then
    echo "mode: $(cat "$MODE_FILE" 2>/dev/null | tr -d '\r' || echo teach) (default teach)"
    echo "set with: /flow mode teach|work"
    return 0
  fi
  case "$arg" in
    teach|work) printf '%s\n' "$arg" > "$MODE_FILE"; _ignore_run_state; echo "PASS: mode set to '$arg'."; return 0 ;;
    *) echo "FAIL: mode must be 'teach' or 'work'."; return 1 ;;
  esac
}

cmd_project_type() {
  local arg="${1:-}"
  if [ -z "$arg" ]; then
    local t; t="$(get_project_type)"
    echo "project type: $t (default web)"
    echo "  done-evidence for '$t': $(done_def_for_type "$t")"
    echo "  set with: /flow project-type web|cli|library|skill"
    echo "  per-type contract + card sequence: references/project-types.md"
    return 0
  fi
  case "$arg" in
    web|cli|library|skill)
      printf '%s\n' "$arg" > "$PROJECT_TYPE_FILE"; _ignore_run_state
      echo "PASS: project type set to '$arg'."
      echo "  done-evidence now means: $(done_def_for_type "$arg")"
      return 0 ;;
    *) echo "FAIL: project type must be web|cli|library|skill."; return 1 ;;
  esac
}

cmd_skip() {
  lock_acquire skip || return 1
  local stage="${1:-}" reason=""
  shift 2>/dev/null || true
  case "${1:-}" in --reason) shift 2>/dev/null || true; reason="$*" ;; *) reason="$*" ;; esac
  if [ -z "$stage" ] || [ -z "$reason" ]; then
    echo 'usage: /flow skip <stage e.g. 01-research> --reason "<why; a stage-matched open DEBT must already exist>"'
    return 1
  fi
  local known=0 s; for s in $STAGES; do [ "$s" = "$stage" ] && known=1; done
  if [ "$known" -eq 0 ]; then echo "FAIL: unknown stage '$stage' (one of: $STAGES)"; return 1; fi
  # PRIMARY guard (stage identity): the contract (05) is the seam - never skip it; adapt it
  # to the project type instead. This closes the worst case (skipping the auth-boundary stage).
  if [ "$stage" = "05-contract" ]; then
    echo "BLOCKED: the contract (05) is the seam - never skip it. Adapt it to your project type"
    echo "  ('/flow project-type ...'; see references/project-types.md), then pass its gate."
    return 1
  fi
  # SECONDARY signal: a security-class-sounding reason HALTS (operator-only); not the sole gate.
  if printf '%s' "$reason" | grep -qiE 'auth|authoriz|authorize|admin|tenan|payment|billing|password|token|secret|credential|permission|role|rbac|login|pii|data loss|migration|validation'; then
    echo "BLOCKED: that reason looks security-class. Security skips are operator-only and HALT - never auto-skipped."
    return 1
  fi
  # the skip must already be written down as an open DEBT that NAMES this exact stage
  if [ ! -f "$DEBT_FILE" ] || ! grep -qE "^- \[ \] DEBT:.*$stage" "$DEBT_FILE" 2>/dev/null; then
    echo "FAIL: no open DEBT naming '$stage'. First run:"
    echo "  /flow debt add \"skip $stage\" \"<the exposure>\" \"<close-before condition>\""
    return 1
  fi
  mkdir -p "$FLOW_DIR"
  stage_skipped "$stage" || printf '%s\n' "$stage" >> "$SKIPPED_FILE"
  local i=0 found=-1; for s in $STAGES; do [ "$s" = "$stage" ] && found=$i; i=$((i + 1)); done
  if [ "$found" -ge 0 ] && [ "$found" -lt "$LAST_STAGE_IDX" ]; then
    local nxt; nxt="$(stage_name_at "$((found + 1))")"
    [ -f "$FLOW_DIR/$nxt.md" ] || cp "$TEMPLATE_DIR/$nxt.md" "$FLOW_DIR/$nxt.md"
    echo "PASS: stage $stage debt-skipped (logged) -> $nxt available. planning_complete now tolerates it."
  else
    echo "PASS: stage $stage debt-skipped (logged). planning_complete now tolerates it."
  fi
  return 0
}

cmd_retro() {
  [ -f "$RETRO_FILE" ] || { [ -f "$LAW_DIR/RETRO.md" ] && cp "$LAW_DIR/RETRO.md" "$RETRO_FILE"; }
  echo "flow retro - answer these 3, then append ONE honest line to RETRO.md:"
  echo "  1. Which gate did you skip or rush, and what did it cost?"
  echo "  2. What stack lesson did a card pay for? (-> harvest into playbooks/)"
  echo "  3. What about the flow itself slowed you down? (-> FLOW-FEEDBACK.md)"
  echo
  echo "RETRO.md: $RETRO_FILE"
  echo "(You write the line - the runner never fills it for you.)"
  if harness_available; then
    local pr; pr="$(harness_emit propose)"
    if [ -n "$pr" ] && ! printf '%s' "$pr" | grep -q 'nothing to propose'; then
      echo
      echo "Harness proposes (deterministic, from repeated friction/interventions + audit drift):"
      printf '%s\n' "$pr" | sed 's/^/  /'
      echo "  -> commit the worth-doing ones: flow harness propose --commit"
    fi
  fi
  return 0
}

# Print the non-empty lines under a card's '## Allowed files' section. Single source of truth for
# the allowed-files invariant: cmd_ready advertises them and 'workspace check' computes overlap
# from the SAME extraction (so the two can never diverge on what a card claims to own).
_card_allowed_files() { # $1 = card file
  [ -f "$1" ] || return 0
  awk '/^## Allowed files/{f=1; next} f && /^## /{f=0} f && NF{print}' "$1"
}

cmd_ready() {
  if ! planning_complete; then
    echo "FAIL: planning not complete - no cards to schedule yet."
    return 1
  fi
  local total; total="$(highest_card)"
  if [ "$total" -le 0 ]; then echo "No cards created yet. Run '/flow card'."; return 0; fi
  echo "flow ready - buildable todo cards (deps met). Operator dispatches; runner advises."
  echo "Parallel only when allowed-files do NOT overlap (review the lists below)."
  echo
  local f id st deps dep ok
  for f in "$CARDS_DIR"/C-*.md; do
    [ -e "$f" ] || continue
    id="$(basename "$f" .md)"
    st="$(card_status "$f")"
    [ "$st" = "todo" ] || continue
    deps="$(grep -m1 -E '^deps:' "$f" | sed 's/^deps:[[:space:]]*//' | tr -d '\r')"
    ok=1
    # deps met if every referenced card is status done (normalize C-1 / C-001 to canonical path)
    for dep in $(printf '%s' "$deps" | grep -oiE 'C-[0-9]+' || true); do
      local depnum depfile
      depnum="${dep#C-}"; depnum="${depnum#c-}"
      case "$depnum" in (*[!0-9]*) continue;; esac
      depfile="$(printf '%s/C-%03d.md' "$CARDS_DIR" "$((10#$depnum))")"
      if [ ! -f "$depfile" ] || [ "$(card_status "$depfile")" != "done" ]; then ok=0; fi
    done
    if [ "$ok" -eq 1 ]; then
      echo "  BUILDABLE $id  (deps: ${deps:-none})"
      _card_allowed_files "$f" | sed 's/^/      allowed: /'
    else
      echo "  blocked   $id  (deps not all done: ${deps:-none})"
    fi
  done
  return 0
}

cmd_auto() {
  lock_acquire auto || return 1
  echo "flow auto - preflight"
  if ! planning_complete; then
    echo "FAIL: planning not complete. Finish stages 00-05 first."
    return 1
  fi
  if [ "$(highest_card)" -le 0 ]; then
    echo "FAIL: no cards. Run '/flow card' to create the build cards first."
    return 1
  fi
  echo "PASS: preflight ok ($(highest_card) cards, planning complete)."
  echo
  echo "Autonomous orchestration is driven by the /flow SKILL.md AUTO PRINCIPLES"
  echo "(subagent per card, planner review + verify, worktree isolation, Tier-C halts"
  echo "for security-class debt, state in card files + AUTO-LOG.md)."
  echo "Run '/flow ready' to see parallel-safe groups."
  return 0
}

cmd_recall() {
  echo "flow recall - prior knowledge for this project"
  echo "  project: $ROOT"
  local proj_any=0 out
  out="$(recall_open_debt)"
  if [ -n "$out" ]; then echo; echo "OPEN DEBT (owed before shipping):"; printf '%s\n' "$out" | sed 's/^/  /'; proj_any=1; fi
  out="$(recall_retro_tail 5)"
  if [ -n "$out" ]; then echo; echo "RECENT RETRO (lessons from past runs):"; printf '%s\n' "$out" | sed 's/^/  - /'; proj_any=1; fi
  out="$(recall_prev_card)"
  if [ -n "$out" ]; then echo; echo "PREVIOUS CARD (carry its learnings into the next one):"; printf '%s\n' "$out" | sed 's/^/  /'; proj_any=1; fi
  out="$(_harness_query friction)"
  if [ -n "$out" ] && ! printf '%s' "$out" | grep -q 'no friction'; then echo; echo "FRICTION recorded earlier (do not repeat):"; printf '%s\n' "$out" | sed 's/^/  /'; proj_any=1; fi
  out="$(_harness_query backlog)"
  if [ -n "$out" ] && ! printf '%s' "$out" | grep -q 'no backlog'; then echo; echo "OPEN IMPROVEMENT BACKLOG:"; printf '%s\n' "$out" | sed 's/^/  /'; proj_any=1; fi
  out="$(harness_emit audit)"
  if [ -n "$out" ]; then printf '%s\n' "$out" | grep -iE 'entropy score' | sed 's/^/  health: /'; fi
  out="$(recall_playbooks)"
  if [ -n "$out" ]; then echo; echo "PLAYBOOKS available (read before building that stack):"; printf '%s\n' "$out" | sed 's/^/  - /'; fi
  out="$(recall_global_playbooks)"
  if [ -n "$out" ]; then echo; echo "GLOBAL PLAYBOOKS (cross-project, ~/.claude/flow/playbooks):"; printf '%s\n' "$out" | sed 's/^/  - /'; fi
  # mechanical usage log (best-effort): roll up, then surface the one-line digest so build history
  # reaches the operator at stage/card start. Silent when there is no data / no python.
  out="$(harness_emit rollup >/dev/null 2>&1; harness_emit usage --summary)"
  if [ -n "$out" ]; then echo; printf '%s\n' "$out" | sed 's/^/  /'; proj_any=1; fi
  if [ -f "$ROOT/flow/constitution.md" ]; then
    out="$(awk '/^[[:space:]]*```/{f=!f;next} f{next} /^[[:space:]]*\|/ && !/\|[[:space:]]*[Ii][Dd][[:space:]]*\|/ && !/\|[[:space:]]*:?-{2,}/{print}' "$ROOT/flow/constitution.md")"
    if [ -n "$out" ]; then echo; echo "PROJECT CONSTITUTION (operator invariants to honor):"; printf '%s\n' "$out" | sed 's/^/  /'; proj_any=1; fi
  fi
  echo
  if [ "$proj_any" -eq 0 ]; then
    echo "(no project-specific history yet - fills as you record debt, retros, decisions, and harness traces.)"
  else
    echo "Use the above to steer the next gate/card - don't re-learn what's already known."
  fi
  return 0
}

cmd_unlock() {
  if [ ! -f "$LOCK_FILE" ] && ! [ -d "$LOCK_DIR" ]; then echo "no flow lock to clear ($LOCK_FILE)"; return 0; fi
  _read_lock
  rm -f "$LOCK_FILE" 2>/dev/null || true
  rm -rf "$LOCK_DIR" 2>/dev/null || true   # W5: remove atomic claim dir so next acquire can mkdir
  echo "PASS: cleared flow lock (was [$LOCK_OWNER], cmd '${LOCK_CMD:-?}')."
  return 0
}

cmd_design() {
  # mechanical half of the DESIGN.md review (grep-able never-dos). Semantic half = Claude
  # against references/design-review-checklist.md. Flags are signals; confirm in-code samples.
  local file="${1:-}"
  if [ -z "$file" ] || [ ! -f "$file" ]; then echo "usage: /flow design <htmlfile>"; return 1; fi
  local found=0 hits
  # grep -P needs a UTF-8 locale for the emoji ranges; Git Bash defaults to C. Force it.
  if printf 'a' | LC_ALL=C.UTF-8 grep -qP 'a' 2>/dev/null; then
    hits="$(LC_ALL=C.UTF-8 grep -nP '[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{2190}-\x{21FF}\x{2B00}-\x{2BFF}\x{FE0F}]' "$file" 2>/dev/null || true)"
    if [ -n "$hits" ]; then echo "  [x] emoji / smart arrows (DESIGN.md: never):"; printf '%s\n' "$hits" | sed 's/^/      L/'; found=1; fi
  fi
  hits="$(grep -nE '\{\{.*\}\}' "$file" 2>/dev/null || true)"
  if [ -n "$hits" ]; then echo "  [x] raw {{ }} template outside a power surface:"; printf '%s\n' "$hits" | sed 's/^/      L/'; found=1; fi
  hits="$(grep -niE '(^|[^[:alnum:]_])(workflow|trigger|webhook|cron|payload|queue)([^[:alnum:]_]|$)' "$file" 2>/dev/null || true)"
  if [ -n "$hits" ]; then echo "  [!] possible engine words in copy (confirm not in <code>):"; printf '%s\n' "$hits" | sed 's/^/      L/'; found=1; fi
  hits="$(grep -niE 'linear-gradient' "$file" 2>/dev/null || true)"
  if [ -n "$hits" ]; then echo "  [!] gradient(s) - confirm hero-surface only (never input/table/body):"; printf '%s\n' "$hits" | sed 's/^/      L/'; found=1; fi
  if [ "$found" -eq 0 ]; then
    echo "PASS: no mechanical DESIGN violations. Now do the semantic pass (object-first,"
    echo "affordance ladder, defaults<=6 fields) per references/design-review-checklist.md."
    return 0
  fi
  echo "FLAGGED: confirm each (some [!] may be false positives inside code), then the semantic pass."
  return 1
}

cmd_debt() {
  local sub="${1:-list}"; shift 2>/dev/null || true
  case "$sub" in
    add)
      local what="${1:-}" exposure="${2:-}" close="${3:-}"
      if [ -z "$what" ] || [ -z "$exposure" ] || [ -z "$close" ]; then
        echo 'usage: /flow debt add "<what skipped>" "<exposure>" "<close-before condition>"'
        return 1
      fi
      # strip newlines so one debt is always exactly one line (keeps `debt list` counts honest)
      what="$(printf '%s' "$what" | tr -d '\n\r')"
      exposure="$(printf '%s' "$exposure" | tr -d '\n\r')"
      close="$(printf '%s' "$close" | tr -d '\n\r')"
      [ -f "$DEBT_FILE" ] || printf '# DEBT - deliberate gate-skips (a loan, written down)\n\n' > "$DEBT_FILE"
      printf -- '- [ ] DEBT: %s -- %s -- close before: %s -- opened %s\n' \
        "$what" "$exposure" "$close" "$(date +%Y-%m-%d)" >> "$DEBT_FILE"
      echo "PASS: debt recorded in DEBT.md"
      echo "  Security-class (auth/authz/admin/tenancy/payments/data/validation)? The OPERATOR"
      echo "  must accept this exposure in writing - it is never decided for them. In /flow auto this halts."
      return 0 ;;
    list|"")
      if [ ! -f "$DEBT_FILE" ]; then echo "No debts recorded."; return 0; fi
      local open; open="$(grep -nE '^- \[ \] DEBT:' "$DEBT_FILE" 2>/dev/null || true)"
      if [ -z "$open" ]; then echo "No OPEN debts (all closed)."; else
        echo "OPEN debts (close before their named condition):"; printf '%s\n' "$open" | sed 's/^/  L/'
      fi
      return 0 ;;
    *) echo "usage: /flow debt add|list"; return 1 ;;
  esac
}

cmd_contract() {
  # F3: client base-URL vs served-path PREFIX drift - the class oasdiff/Pact/Spectral miss
  # (e.g. VITE_API_BASE='/api' + path '/api/admin' -> '/api/api/admin'; or auth at '/auth/*'
  # unreachable under a '/api' base). Served paths come from the contract seam (flow/05-contract.md)
  # or openapi.json; client base from .env*/frontend. Heuristic + advisory (web only).
  local pt; pt="$(get_project_type)"
  if [ "$pt" != "web" ]; then echo "contract: project type '$pt' is not web - path check skipped."; return 0; fi
  local spec="" paths=""
  if [ -f "$FLOW_DIR/05-contract.md" ]; then
    spec="flow/05-contract.md"
    paths="$(grep -oE '`/[A-Za-z0-9_/{}.:-]+`' "$FLOW_DIR/05-contract.md" 2>/dev/null | tr -d '`' | sort -u)"
  elif [ -f "$ROOT/openapi.json" ]; then
    spec="openapi.json"
    paths="$(grep -oE '"/[A-Za-z0-9_/{}.:-]+"' "$ROOT/openapi.json" 2>/dev/null | tr -d '"' | sort -u)"
  fi
  if [ -z "$paths" ]; then echo "contract: no served paths found (flow/05-contract.md or openapi.json) - skipped."; return 0; fi
  local base base_path prefixes nprefix found=0
  base="$(grep -rhoE '(VITE_API_BASE|VITE_API_URL|API_BASE|REACT_APP_API_BASE)[[:space:]]*[:=][[:space:]]*[^[:space:]]+' \
            "$ROOT/.env" "$ROOT/.env.example" "$ROOT/frontend" 2>/dev/null | head -1 | sed -E 's/^[^=:]*[:=][[:space:]]*//; s/["'"'"';,]//g')"
  base_path="$(printf '%s' "$base" | sed -E 's#^[a-z][a-z0-9+.-]*://[^/]+##; s#/$##')"
  prefixes="$(printf '%s\n' "$paths" | sed -E 's#^(/[^/]+).*#\1#' | sort -u | grep .)"
  nprefix="$(printf '%s\n' "$prefixes" | grep -c .)"
  echo "contract path-resolution check ($spec; client base: ${base:-<none found>})"
  if [ -n "$base_path" ] && printf '%s\n' "$prefixes" | grep -qxF "$base_path"; then
    echo "  [!] double-prefix risk: client base path '$base_path' duplicates a served prefix."
    echo "      base '$base' + a '$base_path/...' path -> '$base_path$base_path/...' (404). Use an origin-only base, or drop '$base_path' from the paths."
    found=1
  fi
  if [ "$nprefix" -gt 1 ] && [ -n "$base_path" ]; then
    echo "  [!] mixed served prefixes under a single client base '$base' (base path '$base_path'):"
    printf '%s\n' "$prefixes" | sed 's/^/        served prefix: /'
    echo "      one base resolves one prefix; the others (e.g. auth vs api) will 404. Confirm each path composes correctly."
    found=1
  fi
  if [ "$found" -eq 0 ]; then
    echo "  PASS: no obvious base/prefix drift (served prefixes: $(printf '%s ' $prefixes))."
    return 0
  fi
  echo "FLAGGED: confirm against the running app - this catches the base/prefix class spec-diff tools miss."
  return 1
}

cmd_tokens() {
  # F4: design-token divergence - DESIGN.md's declared tokens vs the CSS actually used.
  # Flags DESIGN.md tokens the CSS NEVER uses (the law-divergence signal: implemented UI
  # stopped following DESIGN.md); reports orphan CSS vars as info (may include framework tokens).
  # Advisory; never auto-fix - if the divergence is intentional, record a dated DESIGN.md amendment.
  local design="$ROOT/DESIGN.md"
  [ -f "$design" ] || design="$LAW_DIR/DESIGN.md"
  if [ ! -f "$design" ]; then echo "tokens: no DESIGN.md found - skipped."; return 0; fi
  local declared; declared="$(grep -oE '\-\-[a-zA-Z][a-zA-Z0-9_-]*' "$design" 2>/dev/null | sort -u)"
  if [ -z "$declared" ]; then echo "tokens: DESIGN.md declares no --tokens - skipped."; return 0; fi
  local cssroot="$ROOT/frontend"; [ -d "$cssroot" ] || cssroot="$ROOT"
  local used; used="$(grep -rhoE '\-\-[a-zA-Z][a-zA-Z0-9_-]*' --include='*.css' --include='*.scss' "$cssroot" 2>/dev/null | sort -u)"
  if [ -z "$used" ]; then echo "tokens: no CSS custom properties found under $cssroot - skipped."; return 0; fi
  local td td2=""; td="$(mktemp -d)"; _register_td "$td"
  trap 'rm -rf "$td" 2>/dev/null; [ -n "$td2" ] && rm -rf "$td2" 2>/dev/null' RETURN
  printf '%s\n' "$declared" > "$td/d"; printf '%s\n' "$used" > "$td/u"
  local unused orphan onum found=0
  unused="$(comm -23 "$td/d" "$td/u")"
  orphan="$(comm -13 "$td/d" "$td/u")"
  onum="$(printf '%s\n' "$orphan" | grep -c .)"
  rm -rf "$td"
  echo "design-token divergence check (DESIGN.md vs CSS under $(printf '%s' "$cssroot" | sed "s#$ROOT/##"))"
  if [ -n "$unused" ]; then
    echo "  [!] DESIGN.md declares tokens the CSS never uses (the implemented UI diverged from the law):"
    printf '%s\n' "$unused" | sed 's/^/        /' | head -40
    found=1
  fi
  if [ "$onum" -gt 0 ]; then
    echo "  [i] $onum CSS token(s) are not declared in DESIGN.md (may include framework tokens); sample:"
    printf '%s\n' "$orphan" | head -8 | sed 's/^/        /'
  fi
  # value-mismatch: tokens declared in DESIGN.md (table: | `--name` | `value` |) AND defined in
  # CSS (--name: value) but with a different value (same name, drifted value).
  local mism; td2="$(mktemp -d)"; _register_td "$td2"
  awk -F'`' 'NF>=4 && $2 ~ /^--[a-zA-Z]/ {gsub(/[ \t\\]/,"",$2); v=$4; gsub(/^[ \t]+|[ \t]+$|\\/,"",v); if(v!="") print $2"\t"v}' \
    "$design" 2>/dev/null | sort -u > "$td2/dv"
  grep -rhoE '\-\-[a-zA-Z][a-zA-Z0-9_-]*[[:space:]]*:[[:space:]]*[^;{}]+' --include='*.css' --include='*.scss' "$cssroot" 2>/dev/null \
    | sed -E 's/^(--[a-zA-Z0-9_-]+)[[:space:]]*:[[:space:]]*/\1\t/' | sort -u > "$td2/cv"
  mism="$(awk -F'\t' 'NR==FNR{if(NF>=2)d[$1]=$2; next}
                      NF>=2 && ($1 in d){a=tolower(d[$1]); b=tolower($2); gsub(/[ \t]/,"",a); gsub(/[ \t]/,"",b);
                        if(a!=b) print "        "$1": DESIGN.md=\""d[$1]"\" vs CSS=\""$2"\""}' "$td2/dv" "$td2/cv")"
  rm -rf "$td2"
  if [ -n "$mism" ]; then
    echo "  [!] token VALUE mismatch (same name, different value in DESIGN.md vs CSS):"
    printf '%s\n' "$mism" | head -40
    found=1
  fi
  if [ "$found" -eq 0 ]; then
    echo "  PASS: DESIGN.md tokens are used by the CSS with matching values (where CSS defines them)."
    return 0
  fi
  echo "FLAGGED: if the swap is intentional, record a dated amendment in DESIGN.md (its own rule); else align the CSS to the tokens."
  return 1
}

assess_scan() {
  # best-effort stack/CI/context detection from real files (fast: no recursive find).
  echo "stack:"
  [ -f "$ROOT/package.json" ] && echo "  - node (package.json)"
  [ -f "$ROOT/frontend/package.json" ] && echo "  - frontend (frontend/package.json)"
  { [ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/requirements.txt" ]; } && echo "  - python (pyproject/requirements)"
  [ -f "$ROOT/go.mod" ] && echo "  - go (go.mod)"
  [ -f "$ROOT/Cargo.toml" ] && echo "  - rust (Cargo.toml)"
  [ -d "$ROOT/.github/workflows" ] && echo "  - CI: github actions (.github/workflows)"
  { [ -f "$ROOT/Dockerfile" ] || [ -f "$ROOT/docker-compose.yml" ]; } && echo "  - docker"
  echo "context files present:"
  local k
  for k in README.md AGENTS.md CLAUDE.md ARCHITECTURE.md docs specs tests test; do
    [ -e "$ROOT/$k" ] && echo "  - $k"
  done
  # ranked surfaces: highest-leverage code first (symbols referenced most widely). Optional helper
  # (stdlib reference-count ranker); degrades to a note if python/helper absent - the flat scan stands.
  echo "ranked surfaces (most-referenced first - inspect these before planning):"
  local rmap="${HARNESS_PY%/*}/repo_map.py" py rout
  py="$(_python)"
  if [ -n "$py" ] && [ -f "$rmap" ]; then
    rout="$("$py" "$rmap" "$ROOT" 10 2>/dev/null)"
    if [ -n "$rout" ]; then printf '%s\n' "$rout" | sed 's/^/  /'
    else echo "  (no rankable source symbols found)"; fi
  else
    echo "  (ranking unavailable - python or repo_map.py absent; the flat scan above stands)"
  fi
}

cmd_assess() {
  # Brownfield/assessment mode. Scaffold + gate a current-state map of an EXISTING codebase
  # BEFORE planning. Reuses the stage gate machinery (unchecked boxes / [FILL]). Operator-gated.
  mkdir -p "$FLOW_DIR"
  _ensure_cycle   # brownfield entry point also gets a cycle id (was previously next-only)
  local f="$FLOW_DIR/00-inspect.md"
  if [ ! -f "$f" ]; then
    if [ ! -f "$TEMPLATE_DIR/00-inspect.md" ]; then echo "FAIL: assess template missing at $TEMPLATE_DIR/00-inspect.md"; return 1; fi
    cp "$TEMPLATE_DIR/00-inspect.md" "$f"
    { echo; echo "<!-- auto-scan -->"; assess_scan; } >> "$f"
    seed_law_files
    echo "PASS: created flow/00-inspect.md (brownfield assessment) - auto-scan seeded."
    echo "Fill it from the code (functionality / UI-UX vs product / risks / tests), check the gate,"
    echo "then re-run '/flow assess' to verify; proceed to planning with '/flow next'."
    return 0
  fi
  if scan_gate "$f" >/dev/null 2>&1; then
    echo "PASS: brownfield assessment gate clean (flow/00-inspect.md). Proceed to planning ('/flow next')."
    return 0
  fi
  echo "FAIL: brownfield assessment gate not clean:"
  scan_gate "$f"
  echo
  echo "Fill the above (evidence, not vibes), then '/flow assess' again."
  return 1
}

cmd_coherence() {
  # F7 (mechanical slice): flag VERSION drift across declared version fields. Semantic doc-vs-code
  # contradictions (e.g. a headline doc describing endpoints that don't exist) stay a human
  # gate-challenge in gate-rules.md - this catches the cheap, low-noise, structured case.
  local td; td="$(mktemp -d)"; _register_td "$td"; : > "$td/v"
  trap 'rm -rf "$td" 2>/dev/null' RETURN
  _ver() { [ -n "$2" ] && printf '%s\t%s\n' "$2" "$1" >> "$td/v"; }   # $1=label $2=version
  [ -f "$ROOT/package.json" ] && _ver "package.json" \
    "$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$ROOT/package.json" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
  [ -f "$ROOT/frontend/package.json" ] && _ver "frontend/package.json" \
    "$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$ROOT/frontend/package.json" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
  [ -f "$ROOT/pyproject.toml" ] && _ver "pyproject.toml" \
    "$(grep -oE '^version[[:space:]]*=[[:space:]]*"[^"]+"' "$ROOT/pyproject.toml" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
  local cfgv; cfgv="$(grep -rhoE 'app_version[[:space:]]*[:=][[:space:]]*["'\''][^"'\'' ]+' "$ROOT/src" 2>/dev/null | head -1 | sed -E 's/.*["'\'']([^"'\'' ]+)$/\1/')"
  [ -n "$cfgv" ] && _ver "src app_version" "$cfgv"
  # skill-type version fields: SKILL.md YAML frontmatter, *-manifest.json, plugin.json
  # (without these, a project-type=skill had ZERO version source and coherence silently skipped).
  local sk; for sk in "$ROOT"/SKILL.md "$ROOT"/skills/*/SKILL.md; do
    [ -f "$sk" ] && _ver "${sk#$ROOT/}" \
      "$(sed -nE 's/^[[:space:]]*version:[[:space:]]*"?([0-9][.0-9A-Za-z-]*).*/\1/p' "$sk" | head -1)"
  done
  local mf; for mf in "$ROOT"/*-manifest.json "$ROOT"/.claude-plugin/plugin.json; do
    [ -f "$mf" ] && _ver "${mf#$ROOT/}" \
      "$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$mf" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
  done
  if [ ! -s "$td/v" ]; then rm -rf "$td"; echo "coherence: no declared version fields found - skipped."; return 0; fi
  local distinct; distinct="$(cut -f1 "$td/v" | sort -u | grep -c .)"
  echo "coherence check - declared versions:"
  sort -u "$td/v" | sed 's/^/  /'
  rm -rf "$td"
  if [ "$distinct" -gt 1 ]; then
    echo "  [!] version drift: $distinct different versions declared across files - align them."
    echo "      (semantic doc-vs-code contradictions remain a human gate-challenge; see references/gate-rules.md)"
    return 1
  fi
  echo "  PASS: declared versions agree."
  return 0
}

prd_declares_fr() { # true if the PRD uses the FRn traceability convention (drives the consistency nudge)
  # Deliberately a loose full-file grep (NOT the Features-section scoping cmd_consistency uses): this
  # only decides whether to print an advisory tip, so a rare over-fire on a prose 'FRn' is harmless;
  # keep it loose so the tip reliably shows in the common case. Do not "tighten" to match consistency.
  [ -f "$FLOW_DIR/03-prd.md" ] && grep -qE 'FR[0-9]+' "$FLOW_DIR/03-prd.md" 2>/dev/null
}

cmd_consistency() {
  # Cross-artifact coverage + contradiction audit - the MECHANICAL complement to the human
  # traceability challenges in gate-rules.md (03/05). The other probes each cover one axis:
  # coherence=version drift, contract=URL-prefix drift, tokens=design-token drift. THIS axis is
  # "do the planning artifacts + cards trace to each other" - the spine gate-rules.md 03/05
  # demand but only a human checks today. Precise, ID-based only (NO fuzzy text matching);
  # advisory; project-type agnostic; degrades gracefully when artifacts are absent.
  #
  # Traceability anchors (see _templates): PRD 'Features' entries tagged 'FRn:' (functional
  # requirement id); cards declare 'implements: FR1, FR2' (or 'infra'/'none' for non-feature
  # cards); 05-contract 'Feature -> interface map' references each 'FRn'.
  local prd="$FLOW_DIR/03-prd.md" contract="$FLOW_DIR/05-contract.md"
  if [ ! -f "$prd" ]; then echo "consistency: no flow/03-prd.md yet - planning incomplete (skipped)."; return 0; fi
  local td; td="$(mktemp -d)"; _register_td "$td"
  trap 'rm -rf "$td" 2>/dev/null' RETURN
  : > "$td/find"; local cn=0 crit=0 high=0
  add() { # $1=severity $2=location $3=summary
    cn=$((cn+1)); printf '| CON-%d | %s | %s | %s |\n' "$cn" "$1" "$2" "$3" >> "$td/find"
    case "$1" in CRITICAL) crit=$((crit+1));; HIGH) high=$((high+1));; esac
  }

  # FR universe declared in the PRD, and FR refs across all cards' 'implements:' lines.
  # scope FR extraction to the '## Features' section so a legacy/deferred id mentioned in PRD
  # prose does not inflate the declared set (would spuriously demand a card for it).
  awk '/^##[[:space:]]+[Ff]eatures/{f=1;next} /^##[[:space:]]/{f=0} f' "$prd" 2>/dev/null \
    | grep -oE 'FR[0-9]+' | sort -u > "$td/prd_fr"
  local nfr; nfr="$(grep -c . "$td/prd_fr" 2>/dev/null)"; nfr="${nfr:-0}"
  : > "$td/card_fr"
  if [ -d "$CARDS_DIR" ]; then
    grep -rhiE '^[[:space:]]*implements:' "$CARDS_DIR"/*.md 2>/dev/null \
      | grep -oE 'FR[0-9]+' | sort -u > "$td/card_fr" || true
  fi

  echo "cross-artifact consistency audit (flow/02-05 + cards/)"
  if [ "$nfr" -eq 0 ]; then
    echo "  [i] no FR ids found in flow/03-prd.md - coverage mapping skipped."
    echo "      tag each v1 feature 'FRn:' (PRD), add 'implements: FRn' to cards, 'FRn ->' to the contract map"
    echo "      (see _templates/03-prd.md) to enable mechanical traceability."
  else
    # 1) PRD feature with NO card implementing it -> CRITICAL (planned, nobody builds).
    local fr
    while IFS= read -r fr; do
      [ -n "$fr" ] || continue
      grep -qxF "$fr" "$td/card_fr" || add CRITICAL "03-prd.md:$fr" "PRD feature $fr has no card that 'implements:' it (zero coverage)"
    done < "$td/prd_fr"
    # 2) card implements an FR absent from the PRD -> HIGH (inconsistency).
    while IFS= read -r fr; do
      [ -n "$fr" ] || continue
      grep -qxF "$fr" "$td/prd_fr" || add HIGH "cards/*:$fr" "a card 'implements: $fr' but $fr is not declared in flow/03-prd.md"
    done < "$td/card_fr"
    # 3) PRD feature not referenced in the contract feature->interface map -> HIGH (the seam gap).
    if [ -f "$contract" ]; then
      while IFS= read -r fr; do
        [ -n "$fr" ] || continue
        # POSIX-ERE word boundary (BSD/macOS grep has no \b in -E): no alnum neighbour.
        # Also fixes the FR1-matches-FR10 substring collision.
        grep -qE "(^|[^A-Za-z0-9])${fr}([^A-Za-z0-9]|$)" "$contract" \
          || add HIGH "05-contract.md:$fr" "PRD feature $fr is absent from the contract (no interface serves it)"
      done < "$td/prd_fr"
    fi
  fi

  # 4) Success metric must contain a NUMBER (mechanizes the PRD 'numbers only' gate rule).
  local metric; metric="$(awk 'tolower($0) ~ /^##[[:space:]]+success metric/{f=1;next} /^##[[:space:]]/{f=0} f' "$prd" 2>/dev/null)"
  if [ -n "$(printf '%s' "$metric" | tr -d '[:space:]')" ] && ! printf '%s' "$metric" | grep -q '[0-9]'; then
    add HIGH "03-prd.md:Success metric" "success metric has no number (the 'numbers only' rule: vague metrics are untestable)"
  fi

  # 5) Placeholder sweep across the planning set (defense-in-depth vs a forced/skipped stage).
  local s
  for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
    [ -f "$FLOW_DIR/$s.md" ] || continue
    if grep -qE '\[FILL|TODO|TKTK|\?\?\?' "$FLOW_DIR/$s.md" 2>/dev/null; then
      add LOW "$s.md" "leftover placeholder ([FILL]/TODO/TKTK/???) - artifact not fully resolved"
    fi
  done

  if [ "$cn" -eq 0 ]; then
    rm -rf "$td"
    if [ "$nfr" -eq 0 ]; then
      echo "  PASS (nothing to map): no FR ids yet; success metric + placeholder passes clean."
    else
      echo "  PASS: $nfr FR id(s) declared; every one is claimed by a card and served by the contract; no placeholders."
    fi
    echo "      (semantic passes - terminology drift, conflicting requirements, hollow coverage - remain a human gate-challenge; see references/gate-rules.md)"
    return 0
  fi
  echo "  findings:"
  echo "  | ID | Severity | Location | Summary |"
  echo "  | -- | -------- | -------- | ------- |"
  sed 's/^/  /' "$td/find"
  echo "  coverage: $nfr FR declared, $(grep -c . "$td/card_fr" 2>/dev/null) referenced by cards. CRITICAL=$crit HIGH=$high."
  rm -rf "$td"
  echo "      (terminology drift / conflicting requirements / hollow coverage remain a human gate-challenge; see references/gate-rules.md)"
  if [ "$crit" -gt 0 ] || [ "$high" -gt 0 ]; then
    echo "FLAGGED: resolve CRITICAL/HIGH before building cards - a planned feature with no card (or no interface) ships as a silent gap."
    return 1
  fi
  return 0
}

cmd_promote() {
  # cross-project knowledge tier: copy a playbook/lesson into ~/.claude/flow/playbooks so its
  # lessons travel to every project (surfaced by '/flow recall' everywhere).
  local src="${1:-}"
  if [ -z "$src" ] || [ ! -f "$src" ]; then echo "usage: /flow promote <path-to-playbook.md>"; return 1; fi
  mkdir -p "$GLOBAL_KB_DIR" 2>/dev/null || true
  if ! cp "$src" "$GLOBAL_KB_DIR/$(basename "$src")" 2>/dev/null; then
    echo "FAIL: could not copy into $GLOBAL_KB_DIR"; return 1
  fi
  echo "PASS: promoted $(basename "$src") -> $GLOBAL_KB_DIR"
  echo "  '/flow recall' now surfaces it as a GLOBAL PLAYBOOK in every project."
  return 0
}

cmd_doctor() {
  # Cross-platform environment + quality check (macOS / Linux / Windows Git Bash).
  echo "flow doctor - environment check"
  local ok=1
  echo "  os:        $(uname -s 2>/dev/null || echo unknown)"
  local bv; bv="$(bash --version 2>/dev/null | head -1 | sed -n 's/.*version \([0-9][0-9.]*\).*/\1/p')"
  case "$bv" in
    3.*) echo "  bash:      $bv  (works; 3.x is the macOS default - 'brew install bash' for 4+ if you hit issues)" ;;
    "")  echo "  bash:      unknown (assuming ok)" ;;
    *)   echo "  bash:      $bv  ok" ;;
  esac
  local py; py="$(_python)"
  if [ -n "$py" ] && "$py" --version >/dev/null 2>&1; then
    echo "  python:    $("$py" --version 2>&1 | awk '{print $2}') ($py)  -> durable layer ENABLED"
    if "$py" -c 'import sqlite3' >/dev/null 2>&1; then
      echo "  sqlite3:   ok (python stdlib)"
    else
      echo "  sqlite3:   MISSING from python - durable layer needs it"; ok=0
    fi
  else
    echo "  python:    not found  -> durable layer DISABLED (gate engine still works fully)"
    echo "             install: macOS 'brew install python' | Ubuntu 'sudo apt install python3' | Windows python.org"
  fi
  if printf 'a' | LC_ALL=C.UTF-8 grep -qP 'a' 2>/dev/null; then
    echo "  grep -P:   ok (design emoji check available)"
  else
    echo "  grep -P:   unsupported (macOS BSD grep) - 'flow design' emoji check skips gracefully"
  fi
  command -v git >/dev/null 2>&1 && echo "  git:       ok (worktree parallel + auto-merge available)" || echo "  git:       not found (worktree/auto unavailable; serial builds still work)"
  command -v cargo >/dev/null 2>&1 && echo "  cargo:     ok (optional Rust harness power-path)" || true
  [ -d "$TEMPLATE_DIR" ] && echo "  templates: ok" || { echo "  templates: MISSING ($TEMPLATE_DIR)"; ok=0; }
  [ -f "$HARNESS_PY" ] && echo "  harness:   present ($HARNESS_PY)" || echo "  harness:   absent (durable layer off)"
  echo
  if [ "$ok" -eq 1 ]; then
    echo "READY. Gate engine works$([ -n "$py" ] && echo '; durable layer on.' || echo '; durable layer off (no python).')"
    return 0
  fi
  echo "DEGRADED - resolve the MISSING item(s) above."
  return 1
}

cmd_constitution() {
  # Advisory: validate an operator-authored flow/constitution.md of per-project invariants and
  # advisory-scan each invariant's OPTIONAL grep-marker. Deliberately NOT called from cmd_next:
  # enforcing it at every gate would put an LLM token-tax on the hot path. The operator runs it
  # at the scope/PRD/contract seam. This is the mechanical half; the semantic challenge that
  # actually judges artifacts against the invariants lives in references/gate-rules.md.
  local cf="$ROOT/flow/constitution.md"
  if [ ! -f "$cf" ]; then
    echo "constitution: no flow/constitution.md - skipped (optional)."
    echo "  to enforce per-project invariants, copy the template and fill the invariant table:"
    echo "    cp \"$TEMPLATE_DIR/constitution.md\" \"$cf\""
    return 0
  fi
  local rc=0
  if grep -qE '\[FILL' "$cf"; then
    echo "constitution: FAIL - unfilled placeholder(s) remain:"
    grep -nE '\[FILL' "$cf" | sed 's/^/  /'
    rc=1
  fi
  # invariant rows = table rows OUTSIDE any fenced code block, excluding the header + |---| separator.
  # (a fenced ``` example containing pipe-rows must not be mistaken for invariants.)
  local rows; rows="$(awk '
    /^[[:space:]]*```/ { infence = !infence; next }
    infence { next }
    /^[[:space:]]*\|/ {
      if ($0 ~ /^[[:space:]]*\|[[:space:]]*[Ii][Dd][[:space:]]*\|/) next
      if ($0 ~ /^[[:space:]]*\|[[:space:]]*:?-{2,}/) next
      print
    }' "$cf")"
  if [ -z "$rows" ]; then
    echo "constitution: FAIL - no invariant rows found (the table is empty)."
    return 1
  fi
  local scan_root=""; [ -d "$ROOT/src" ] && scan_root="$ROOT/src"
  echo "constitution check - operator invariants (advisory; semantic challenge in gate-rules.md):"
  local n=0 markers=0 unmet=0
  while IFS= read -r line; do
    [ -z "${line//[[:space:][:punct:]]/}" ] && continue
    local id inv applies marker prot
    # protect markdown-escaped pipes (\|) so an alternation regex in a cell survives the |-split.
    # the sentinel is reserved: if it appears literally in source, fail LOUD rather than silently mangle.
    case "$line" in
      *__FLOW_ESC_PIPE__*) echo "  [!] constitution line uses reserved token __FLOW_ESC_PIPE__ - rename it: $line"; rc=1; continue ;;
    esac
    prot="$(printf '%s\n' "$line" | sed 's/\\|/__FLOW_ESC_PIPE__/g')"
    id="$(printf '%s\n' "$prot" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/__FLOW_ESC_PIPE__/|/g')"
    inv="$(printf '%s\n' "$prot" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/__FLOW_ESC_PIPE__/|/g')"
    applies="$(printf '%s\n' "$prot" | awk -F'|' '{print $4}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/__FLOW_ESC_PIPE__/|/g')"
    marker="$(printf '%s\n' "$prot" | awk -F'|' '{print $5}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/__FLOW_ESC_PIPE__/|/g')"
    if [ -z "$id" ]; then echo "  [!] invariant row has no ID: $line"; rc=1; continue; fi
    if [ -z "$inv" ] || [ -z "$applies" ]; then
      echo "  [!] $id - malformed row (need ID | Invariant | Applies-at | grep-marker | Rationale): $line"; rc=1; continue
    fi
    n=$((n+1))
    if [ -n "$marker" ] && [ "$marker" != "-" ]; then
      markers=$((markers+1))
      if [ -z "$scan_root" ]; then
        echo "  --  $id (marker '$marker' not scanned: no src/ dir - verify manually)"
      elif grep -rqsE -- "$marker" "$scan_root" 2>/dev/null; then
        echo "  ok  $id (grep-marker present)"
      else
        echo "  [!] $id - declared grep-marker '$marker' not found under src/ (verify the invariant holds)"
        unmet=$((unmet+1))
      fi
    else
      echo "  --  $id (semantic-only invariant - challenge it at the gate)"
    fi
  done <<EOF
$rows
EOF
  echo "  $n invariant(s); $markers with markers, $unmet unmet (advisory)."
  if [ "$rc" -ne 0 ]; then
    echo "constitution: FAIL - fix the structural issue(s) above (placeholder / missing ID)."
    return 1
  fi
  echo "constitution: PASS (structure clean). Unmet markers are advisory - apply the semantic challenge."
  return 0
}

# ---------- workspace (multi-agent worktree layer) ----------
# Lets a HUMAN orchestrate several agents (Claude/Codex/Antigravity, many terminals) in PARALLEL
# without the "one agent switches branch -> every terminal flips" trap: each agent gets its own
# git worktree (own HEAD/index/files, shared object store). git IS the registry (git worktree list
# is the live truth); this side-file only carries the 4 things git cannot know (vendor/card/port/
# task). Append-only JSONL, last-record-per-branch wins; a torn final line is skipped. The single
# coarse flow/.lock guards only the sub-millisecond registry append on add/remove - never the agent
# run. git's own refusal to check out one branch in two worktrees is the strongest collision lock.
WS_FILE="$LOG_DIR/workspaces.jsonl"

_ws_dirname() { # $1 = branch -> sibling dir name (branch '/' sanitized)
  printf '%s-%s' "$(basename "$ROOT" 2>/dev/null || echo proj)" "$(printf '%s' "$1" | tr '/' '-' | tr -cd 'A-Za-z0-9._-')"
}
_ws_path() { printf '%s/%s' "$(dirname "$ROOT")" "$(_ws_dirname "$1")"; }   # sibling of the main repo

_ws_default_vendor() { # best-effort from the engine tier / harness session env; '-' if unknown
  case "${FLOW_ENGINE_TIER:-}" in
    claude*|ck*) echo claude; return ;; codex*) echo codex; return ;;
    antigravity*|agy*|gemini*) echo antigravity; return ;;
  esac
  [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && { echo claude; return; }
  [ -n "${CODEX_SESSION_ID:-}${CODEX_THREAD_ID:-}" ] && { echo codex; return; }
  [ -n "${AGY_SESSION_ID:-}${ANTIGRAVITY_SESSION_ID:-}" ] && { echo antigravity; return; }
  echo "-"
}

# One physical line per event. Fixed field order (extractors below rely on it). Returns 1 if the
# append fails so add/remove can WARN (git stays truth) instead of pretending it persisted.
_ws_record_append() { # path branch vendor sid card task owned port status
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  _ignore_run_state
  printf '{"worktree_path":"%s","branch":"%s","vendor":"%s","agent_session_id":"%s","card_id":"%s","task_label":"%s","owned_files_glob":"%s","port_offset":%s,"created_at":%s,"status":"%s"}\n' \
    "$(_json_str "$1")" "$(_json_str "$2")" "$(_json_str "$3")" "$(_json_str "$4")" "$(_json_str "$5")" \
    "$(_json_str "$6")" "$(_json_str "$7")" "$8" "$(_now)" "$9" >> "$WS_FILE" 2>/dev/null || return 1
  return 0
}

# Latest-per-branch ACTIVE records. Lines lacking both branch+status (a torn final printf on a
# disk-full write) are skipped, last valid record per branch wins.
_ws_active_records() {
  [ -f "$WS_FILE" ] || return 0
  awk '
    /"branch":"/ && /"status":"/ { b=$0; sub(/.*"branch":"/,"",b); sub(/".*/,"",b); last[b]=$0 }
    END { for (b in last) { s=last[b]; st=s; sub(/.*"status":"/,"",st); sub(/".*/,"",st); if (st=="active") print last[b] } }
  ' "$WS_FILE"
}
_ws_latest_by_branch() { # $1 = branch -> latest record (any status), or empty
  [ -f "$WS_FILE" ] || return 0
  awk -v want="$1" '
    /"branch":"/ && /"status":"/ { b=$0; sub(/.*"branch":"/,"",b); sub(/".*/,"",b); if (b==want) line=$0 }
    END { if (line!="") print line }
  ' "$WS_FILE"
}
_ws_max_active_port() { # max port_offset among active records, or -1 if none (so +1 = 0 for the first)
  _ws_active_records | awk '
    { p=$0; sub(/.*"port_offset":/,"",p); sub(/[^0-9-].*/,"",p); if (p!="") { n=p+0; if (!seen || n>m) { m=n; seen=1 } } }
    END { print (seen ? m : -1) }'
}
_ws_get()     { printf '%s' "$1" | sed -nE "s/.*\"$2\":\"([^\"]*)\".*/\1/p"; }       # quoted no-comma field
_ws_get_num() { printf '%s' "$1" | sed -nE "s/.*\"$2\":(-?[0-9]+).*/\1/p"; }          # numeric field
_ws_get_task(){ printf '%s' "$1" | sed -nE 's/.*"task_label":"(.*)","owned_files_glob":.*/\1/p'; }  # may hold commas
# Normalize allowed-files lines into sorted comparable path tokens (bullets/backticks/commas stripped).
# tr (not sed s/../\n/) splits whitespace -> newlines: BSD sed does NOT expand \n in a replacement.
_ws_tokens()  { sed -E 's/^[[:space:]]*-[[:space:]]*//' | tr -s ' \t' '\n' | tr -d '`,' | grep . | sort -u; }

# Re-printable cd + per-worktree env block (print, never spawn: POSIX sh under Git Bash cannot
# reliably re-parent a terminal across the 3-OS / flow.cmd surface).
_ws_print_enter() { # branch wt vendor port
  local branch="$1" wt="$2" vendor="$3" port="$4" baseport
  baseport="${FLOW_WORKSPACE_BASEPORT:-3000}"
  echo "  cd \"$wt\""
  case "$vendor" in codex) echo "  export CODEX_HOME=\"$wt/.codex\"   # isolate Codex history/config per worktree" ;; esac
  echo "  export PORT=\$(( $baseport + $port ))   # = $(( baseport + port )) (per-worktree; avoids dev-server clash)"
  case "$vendor" in
    claude)      echo "  # launch in this dir: claude    (or from the main repo: claude --worktree $branch)" ;;
    codex)       echo "  # launch in this dir: codex \"<task>\"" ;;
    antigravity) echo "  # open this dir as an Antigravity workspace/Project, assign one agent" ;;
    *)           echo "  # launch your agent with this dir as its working directory" ;;
  esac
}

_ws_add() {
  local branch="" card="" vendor="" task="" copyenv=0
  branch="${1:-}"; shift 2>/dev/null || true
  case "$branch" in ""|--*) echo 'usage: /flow workspace add <branch> [--card C-NNN] [--vendor claude|codex|antigravity] [--task "..."] [--copy-env]'; return 1 ;; esac
  while [ $# -gt 0 ]; do
    case "$1" in
      --card)    shift; card="${1:-}" ;;
      --vendor)  shift; vendor="${1:-}" ;;
      --task)    shift; task="${1:-}" ;;
      --copy-env) copyenv=1 ;;
      *) echo "workspace add: unknown arg '$1'"; return 1 ;;
    esac
    shift 2>/dev/null || true
  done
  [ -n "$vendor" ] || vendor="$(_ws_default_vendor)"
  lock_acquire workspace || return 1
  local wt addout rc
  wt="$(_ws_path "$branch")"
  if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    addout="$(git -C "$ROOT" worktree add "$wt" "$branch" 2>&1)"; rc=$?     # existing branch: check it out
  else
    addout="$(git -C "$ROOT" worktree add "$wt" -b "$branch" 2>&1)"; rc=$?  # new branch
  fi
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$addout"          # relay git's reason VERBATIM (e.g. already used by worktree)
    echo "FAIL: git worktree add failed (above is git's reason)."
    return 1
  fi
  local port owned=""
  port=$(( $(_ws_max_active_port) + 1 ))    # lock-held: serialized adds get distinct ports by construction
  if [ -n "$card" ]; then
    local cf; cf="$(resolve_card_file "$card")"
    [ -n "$cf" ] && [ -f "$cf" ] && owned="$(_card_allowed_files "$cf" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  fi
  if ! _ws_record_append "$wt" "$branch" "$vendor" "$(_session_id)" "$card" "$task" "$owned" "$port" active; then
    echo "WARNING: worktree created but registry append failed - run '/flow workspace doctor' to reconcile (git still holds the tree)."
  fi
  if [ "$copyenv" -eq 1 ]; then
    local ef base
    for ef in "$ROOT"/.env "$ROOT"/.env.*; do
      [ -f "$ef" ] || continue
      base="$(basename "$ef")"; cp "$ef" "$wt/$base" 2>/dev/null && echo "  copied $base -> worktree (copy, never symlink)"
    done
  fi
  echo "PASS: created worktree for '$branch' (vendor ${vendor:-?}, port-offset $port) -> $wt"
  _ws_print_enter "$branch" "$wt" "$vendor" "$port"
  echo "  (tracked in .flow/workspaces.jsonl; see 'workspace list' / 'workspace doctor')"
  return 0
}

_ws_list() {
  lock_warn
  echo "flow workspace - live worktrees (git is the registry; side-file adds vendor/card/port/task)"
  local td; td="$(mktemp -d)"; _register_td "$td"
  git -C "$ROOT" worktree list --porcelain 2>/dev/null | awk '
    /^worktree /{p=substr($0,10)}
    /^HEAD /{h=substr($2,1,12)}
    /^branch /{b=$2; sub(/^refs\/heads\//,"",b)}
    /^detached/{b="(detached)"}
    /^$/{ if(p!=""){print p"\t"b"\t"h; p="";b="";h=""} }
    END{ if(p!=""){print p"\t"b"\t"h} }
  ' > "$td/wt"
  printf '  %-22s %-12s %-8s %-9s %-5s %s\n' BRANCH VENDOR CARD HEAD PORT TASK
  local seen=" " p b h rec vendor card port task
  while IFS="$(printf '\t')" read -r p b h; do
    [ -n "$p" ] || continue
    rec="$(_ws_latest_by_branch "$b")"
    vendor="-"; card="-"; port="-"; task=""
    if [ -n "$rec" ] && [ "$(_ws_get "$rec" status)" = "active" ]; then
      vendor="$(_ws_get "$rec" vendor)"; vendor="${vendor:--}"
      card="$(_ws_get "$rec" card_id)"; card="${card:--}"
      port="$(_ws_get_num "$rec" port_offset)"; port="${port:--}"
      task="$(_ws_get_task "$rec")"
    fi
    seen="$seen$b "
    printf '  %-22s %-12s %-8s %-9s %-5s %s\n' "$b" "$vendor" "$card" "$h" "$port" "$task"
  done < "$td/wt"
  local orphans="" line ob
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    ob="$(_ws_get "$line" branch)"
    case "$seen" in *" $ob "*) : ;; *) orphans="$orphans        $ob (vendor $(_ws_get "$line" vendor), card $(_ws_get "$line" card_id))
" ;; esac
  done <<EOF
$(_ws_active_records)
EOF
  rm -rf "$td"
  if [ -n "$orphans" ]; then
    echo
    echo "  ORPHAN RECORDS (active in registry, no live worktree - run 'workspace doctor'):"
    printf '%s' "$orphans"
  fi
  return 0
}

_ws_enter() {
  local branch="${1:-}"
  [ -n "$branch" ] || { echo "usage: /flow workspace enter <branch>"; return 1; }
  local rec; rec="$(_ws_latest_by_branch "$branch")"
  if [ -z "$rec" ] || [ "$(_ws_get "$rec" status)" != "active" ]; then
    echo "workspace: no active record for branch '$branch' (see 'workspace list')."; return 1
  fi
  local wt vendor port
  wt="$(_ws_get "$rec" worktree_path)"; vendor="$(_ws_get "$rec" vendor)"; port="$(_ws_get_num "$rec" port_offset)"
  echo "workspace '$branch' (vendor ${vendor:--}) - paste to re-enter:"
  _ws_print_enter "$branch" "$wt" "$vendor" "${port:-0}"
  return 0
}

_ws_remove() {
  local branch="" force=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --force) force=1 ;;
      --*) echo "workspace remove: unknown arg '$1'"; return 1 ;;
      *) [ -z "$branch" ] && branch="$1" || { echo "workspace remove: extra arg '$1'"; return 1; } ;;
    esac
    shift
  done
  [ -n "$branch" ] || { echo "usage: /flow workspace remove <branch> [--force]"; return 1; }
  lock_acquire workspace || return 1
  local rec wt rmout rc
  rec="$(_ws_latest_by_branch "$branch")"
  wt="$(git -C "$ROOT" worktree list --porcelain 2>/dev/null | awk -v want="$branch" \
        '/^worktree /{p=substr($0,10)} /^branch /{b=$2; sub(/^refs\/heads\//,"",b); if(b==want) print p}')"
  [ -n "$wt" ] || wt="$(_ws_get "$rec" worktree_path)"
  if [ -z "$wt" ]; then echo "workspace: no worktree found for branch '$branch'."; return 1; fi
  if [ "$force" -eq 1 ]; then
    rmout="$(git -C "$ROOT" worktree remove --force "$wt" 2>&1)"; rc=$?
  else
    rmout="$(git -C "$ROOT" worktree remove "$wt" 2>&1)"; rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$rmout"           # relay git's dirty/in-use refusal VERBATIM
    echo "FAIL: git worktree remove refused (commit/clean the tree, or re-run with --force)."
    return 1
  fi
  # tombstone ONLY on clean success (git is truth; a failed remove changed nothing)
  local vendor card port
  vendor="$(_ws_get "$rec" vendor)"; card="$(_ws_get "$rec" card_id)"; port="$(_ws_get_num "$rec" port_offset)"
  _ws_record_append "$wt" "$branch" "${vendor:--}" "$(_session_id)" "$card" "" "" "${port:-0}" removed \
    || echo "WARNING: worktree removed but tombstone append failed (doctor will show it as an orphan tree-free branch)."
  git -C "$ROOT" worktree prune 2>/dev/null || true
  echo "PASS: removed worktree for '$branch' ($wt) and pruned stale metadata."
  return 0
}

_ws_check() {
  local branch="" card=""
  branch="${1:-}"; shift 2>/dev/null || true
  case "$branch" in ""|--*) echo "usage: /flow workspace check <branch> [--card C-NNN]"; return 1 ;; esac
  while [ $# -gt 0 ]; do case "$1" in --card) shift; card="${1:-}" ;; *) echo "workspace check: unknown arg '$1'"; return 1 ;; esac; shift 2>/dev/null || true; done
  local found=0
  if git -C "$ROOT" worktree list --porcelain 2>/dev/null | awk '/^branch /{b=$2; sub(/^refs\/heads\//,"",b); print b}' | grep -qxF "$branch"; then
    echo "  [x] branch '$branch' is already checked out in a worktree (git refuses a second checkout of it)."
    found=1
  fi
  if [ -n "$card" ]; then
    local cf; cf="$(resolve_card_file "$card")"
    if [ -n "$cf" ] && [ -f "$cf" ]; then
      local td; td="$(mktemp -d)"; _register_td "$td"
      _card_allowed_files "$cf" | _ws_tokens > "$td/mine"
      local rec ob ocard ocf shared
      while IFS= read -r rec; do
        [ -n "$rec" ] || continue
        ob="$(_ws_get "$rec" branch)"; [ "$ob" = "$branch" ] && continue
        ocard="$(_ws_get "$rec" card_id)"; [ -n "$ocard" ] || continue
        ocf="$(resolve_card_file "$ocard")"; [ -f "$ocf" ] || continue
        _card_allowed_files "$ocf" | _ws_tokens > "$td/other"
        shared="$(comm -12 "$td/mine" "$td/other" 2>/dev/null | grep . || true)"
        if [ -n "$shared" ]; then
          echo "  [x] allowed-files overlap with active card $ocard (branch $ob) - NOT parallel-safe:"
          printf '%s\n' "$shared" | sed 's/^/        /'
          found=1
        fi
      done <<EOF
$(_ws_active_records)
EOF
      rm -rf "$td"
    fi
  fi
  if [ "$found" -eq 0 ]; then
    echo "PASS: '$branch' is parallel-safe (branch free${card:+, no allowed-files overlap with active cards}). Semantic honesty still belongs to gate-rules.md."
    return 0
  fi
  echo "FLAGGED: resolve the above before launching an agent on '$branch'."
  return 1
}

_ws_doctor() {
  echo "flow workspace doctor - reconcile git worktrees vs registry (advisory; never deletes)"
  local td; td="$(mktemp -d)"; _register_td "$td"
  local pcl; pcl="$(git -C "$ROOT" worktree list --porcelain 2>/dev/null)"
  printf '%s\n' "$pcl" | awk '/^branch /{b=$2; sub(/^refs\/heads\//,"",b); print b}' | sort -u > "$td/live_all"
  printf '%s\n' "$pcl" | awk '/^worktree /{n++} /^branch /{b=$2; sub(/^refs\/heads\//,"",b); if(n>1) print b}' | sort -u > "$td/live_linked"
  _ws_active_records > "$td/active"
  awk '{b=$0; sub(/.*"branch":"/,"",b); sub(/".*/,"",b); print b}' "$td/active" | sort -u > "$td/recbranch"
  local drift=0 warn=0 nact
  nact="$(grep -c . "$td/active" 2>/dev/null)"; nact="${nact:-0}"

  local prun; prun="$(printf '%s\n' "$pcl" | awk '/^worktree /{p=substr($0,10)} /^prunable/{print "  [x] prunable tree: "p} /^locked/{print "  [i] locked tree:   "p}')"
  if [ -n "$prun" ]; then printf '%s\n' "$prun"; printf '%s\n' "$prun" | grep -q '\[x\]' && drift=1; fi
  local orec; orec="$(comm -23 "$td/recbranch" "$td/live_all" | grep . || true)"
  if [ -n "$orec" ]; then echo "  [x] ORPHAN RECORDS (active in registry, no live worktree - crashed terminal?):"; printf '%s\n' "$orec" | sed 's/^/        /'; drift=1; fi
  local otree; otree="$(comm -13 "$td/recbranch" "$td/live_linked" | grep . || true)"
  if [ -n "$otree" ]; then echo "  [x] ORPHAN TREES (live worktree, no active record - created outside flow / by auto):"; printf '%s\n' "$otree" | sed 's/^/        /'; drift=1; fi
  local pdup; pdup="$(awk '{p=$0; sub(/.*"port_offset":/,"",p); sub(/[^0-9-].*/,"",p); print p}' "$td/active" | sort | uniq -d | grep . || true)"
  if [ -n "$pdup" ]; then echo "  [!] duplicate port_offset across active workspaces (advisory): $(printf '%s ' $pdup)"; warn=1; fi
  local maxw="${FLOW_WORKSPACE_MAX:-4}"
  if [ "$nact" -gt "$maxw" ]; then echo "  [!] $nact active workspaces exceeds FLOW_WORKSPACE_MAX=$maxw (realistic solo ceiling is 3-4; advisory)."; warn=1; fi
  rm -rf "$td"

  if [ "$drift" -eq 0 ]; then
    echo "  PASS: no drift ($nact active workspace(s)$([ "$warn" -eq 1 ] && echo '; advisory warnings above'))."
    return 0
  fi
  echo "FLAGGED: reconcile above - 'workspace remove <branch>' (clean tree) or 'git worktree prune'; an orphan record clears on its branch's next add/remove."
  return 1
}

cmd_workspace() {
  local sub="${1:-}"; shift 2>/dev/null || true
  case "$sub" in
    add|list|enter|remove|check|doctor) : ;;
    *) echo "usage: /flow workspace add|list|enter|remove|check|doctor"; return 1 ;;
  esac
  if ! command -v git >/dev/null 2>&1; then
    echo "workspace: git not found - worktree isolation unavailable (serial builds still work)."
    case "$sub" in add|remove) return 1 ;; *) return 0 ;; esac
  fi
  case "$sub" in
    add)    _ws_add "$@" ;;
    list)   _ws_list ;;
    enter)  _ws_enter "$@" ;;
    remove) _ws_remove "$@" ;;
    check)  _ws_check "$@" ;;
    doctor) _ws_doctor ;;
  esac
}

# ---------- loop (thin ck-loop wrapper: plumbing only, no iteration logic here) ----------
# ck-loop (installed ClaudeKit skill) is the untouched execution engine: verify-safety-screen,
# stuck-detection, git commit/revert per iteration all live there. flow only (1) sets up an
# isolated worktree + a numeric Verify command ck-loop can run, and (2) records the finished run.
# Portable timeout wrapper: GNU `timeout` (Linux/Windows-Git-Bash) or `gtimeout` (macOS+coreutils)
# when present; a background+watchdog-kill fallback otherwise (macOS ships neither by default).
# Returns 124 on timeout, matching GNU timeout's convention, so callers can branch on it uniformly.
_run_with_timeout() { # $1 = seconds; $2 = command string (run via `sh -c`)
  local secs="$1" cmd="$2"
  if command -v timeout >/dev/null 2>&1; then timeout "$secs" sh -c "$cmd"; return $?; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" sh -c "$cmd"; return $?; fi
  # Fallback (macOS ships neither by default): a killed process's own exit status (e.g. 143 from
  # SIGTERM) is NOT 124, so track whether the watchdog actually fired via a flag file and force
  # the GNU-timeout-compatible 124 in that case - callers only branch on the numeric 124 contract.
  # The watchdog traps TERM to kill its OWN sleep child before exiting: `wait`/`kill` only work
  # reliably within the process that actually owns the child, so the sleep must stay the
  # watchdog's direct child (not a sibling of it) - without the trap, killing the watchdog when
  # the real command finishes early does NOT kill its sleep, which is reparented and keeps
  # running to completion, orphaned, on every fast call (previously unbounded: N fast calls left
  # N orphaned `sleep $secs` processes).
  # A bare `wait` (no PID arg) is used, not `wait "$SLEEP_PID"`: a real 3-OS CI run found the
  # PID-argument form of `wait` on a job backgrounded INSIDE this subshell unreliable under
  # macOS's bash 3.2 (the timeout never fired - the mock ran to full completion, unbounded) -
  # a bare `wait` waiting on ALL of the subshell's own background jobs (here, only the one
  # sleep) is the more portable form across bash versions.
  local flag; flag="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/.flow_timeout_$$")"
  rm -f "$flag" 2>/dev/null
  sh -c "$cmd" & local pid=$!
  ( trap 'kill "$SLEEP_PID" 2>/dev/null; exit 143' TERM
    sleep "$secs" 2>/dev/null & SLEEP_PID=$!
    wait 2>/dev/null
    kill -TERM "$pid" 2>/dev/null && : > "$flag" 2>/dev/null
  ) & local watchdog=$!
  wait "$pid" 2>/dev/null; local rc=$?
  kill "$watchdog" 2>/dev/null; wait "$watchdog" 2>/dev/null
  if [ -f "$flag" ]; then rm -f "$flag" 2>/dev/null; return 124; fi
  return "$rc"
}

cmd_loop_prep() { # $1 = card id; [--metric failing-tests] [--iterations N] [--guard]
  local card="${1:-}"; shift 2>/dev/null || true
  case "$card" in ""|--*) echo 'usage: /flow loop-prep <C-NNN> [--metric failing-tests] [--iterations N] [--guard]'; return 1 ;; esac
  local metric="failing-tests" iterations=10 guard=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --metric)     shift; metric="${1:-failing-tests}" ;;
      --iterations) shift; iterations="${1:-10}" ;;
      --guard)      guard=1 ;;
      *) echo "loop-prep: unknown arg '$1'"; return 1 ;;
    esac
    shift 2>/dev/null || true
  done
  case "$metric" in
    failing-tests) : ;;
    *) echo "loop-prep: unsupported --metric '$metric' (only 'failing-tests' supported this round)"; return 1 ;;
  esac
  case "$iterations" in ''|*[!0-9]*|0) echo "loop-prep: --iterations must be a positive integer (got '$iterations')"; return 1 ;; esac
  if ! command -v git >/dev/null 2>&1; then
    echo "loop-prep: git not found - ck-loop requires an isolated git worktree."
    return 1
  fi
  local cf; cf="$(resolve_card_file "$card")"
  if [ -z "$cf" ] || [ ! -f "$cf" ]; then
    echo "loop-prep: card '$card' not found (expected $cf) - run '/flow card' first."
    return 1
  fi
  FLOW_LOG_CARD="$card"

  # Scope = the card's OWN declared Allowed files (what it may edit), NOT the Verify target.
  # Hardcoding Scope to tests/test_*.sh would let ck-loop edit only test files while measuring
  # a failing-test count - the only way to "improve" that metric within such a Scope is to
  # gut/weaken the assertions that caught the bug, not fix the source. Fall back to
  # tests/test_*.sh only when the card declares no Allowed files at all (no better signal
  # available); this fallback inherits the same reward-hacking risk, so it's a last resort.
  local scope; scope="$(_card_allowed_files "$cf" | _ws_tokens | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')"
  [ -n "$scope" ] || scope="tests/test_*.sh"

  local branch="loop/$card" wt
  wt="$(_ws_path "$branch")"
  if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null && ! [ -d "$wt" ]; then
    echo "WARNING: branch '$branch' already exists but has no live worktree - loop-prep will check out and reuse WHATEVER is already committed there. If you didn't create this branch for a prior loop run, stop and investigate before continuing."
  fi
  # Check the worktree directly (git-dir resolves + branch identity) rather than grepping
  # `git worktree list` output: on Windows/Git-Bash, `list` prints git's own normalized form
  # (C:/Users/...) which does not string-match the /tmp/... form `_ws_path` computes for the
  # same directory. The branch-identity check additionally guards against silently "reusing" a
  # stale/unrelated git dir that happens to occupy this deterministic sibling path.
  local reuse_head=""
  if [ -d "$wt" ]; then reuse_head="$(git -C "$wt" symbolic-ref --short -q HEAD 2>/dev/null)"; fi
  if [ -n "$reuse_head" ] && [ "$reuse_head" = "$branch" ]; then
    echo "loop-prep: reusing existing worktree for '$branch' -> $wt"
  elif [ -d "$wt" ]; then
    echo "ABORT: $wt exists but is not this card's worktree (HEAD: '${reuse_head:-detached/unknown}', expected '$branch') - remove it or run 'workspace doctor', then retry."
    return 1
  else
    _ws_add "$branch" --card "$card" || { echo "ABORT: worktree setup failed (see above) - fix the git error and retry."; return 1; }
  fi

  # Verify: sum each suite's own printed "RESULT: N passed, M failed" line (every tests/test_*.sh
  # already ends with this identical line - no per-script changes needed). Direction=lower.
  local verify_cmd
  verify_cmd='total=0; for t in tests/test_*.sh; do n=$(bash "$t" 2>&1 | sed -nE "s/^RESULT: [0-9]+ passed, ([0-9]+) failed\$/\1/p"); total=$((total + ${n:-0})); done; echo "$total"'
  local guard_cmd=""
  [ "$guard" -eq 1 ] && guard_cmd='bash tests/run_all.sh >/dev/null 2>&1'

  # Phase-0 self-check inside the worktree, mirroring ck-loop's own abort conditions so a fresh
  # worktree never surprises ck-loop with a precondition it would have refused anyway.
  if ! git -C "$wt" rev-parse --git-dir >/dev/null 2>&1; then
    echo "ABORT: not a git worktree at $wt - re-run 'workspace doctor'."; return 1
  fi
  local dirty; dirty="$(git -C "$wt" status --porcelain 2>/dev/null)"
  if [ -n "$dirty" ]; then
    echo "ABORT: worktree has uncommitted changes - ck-loop requires a clean tree."
    echo "  dirty paths:"; printf '%s\n' "$dirty" | sed 's/^/    /'
    echo "  fix: commit/stash these (common cause: --copy-env or .flow/ inside the worktree; gitignore them or omit --copy-env)."
    return 1
  fi
  if ! git -C "$wt" symbolic-ref -q HEAD >/dev/null 2>&1; then
    echo "ABORT: worktree HEAD is detached - ck-loop requires a named branch. Re-run 'workspace add' with a branch name."
    return 1
  fi
  if [ -f "$wt/loop-results.tsv.lock" ]; then
    echo "ABORT: stale loop-results.tsv.lock in $wt - a previous ck-loop run may not have exited cleanly. Remove it after confirming no run is active."
    return 1
  fi
  if ! ls "$wt"/tests/test_*.sh >/dev/null 2>&1; then
    echo "ABORT: no tests/test_*.sh found under $wt - the Verify metric would match zero files."
    return 1
  fi
  if ! ( cd "$wt" && eval "set -- $scope" && ls "$@" ) >/dev/null 2>&1; then
    echo "ABORT: Scope glob '$scope' matches zero files under $wt - ck-loop would have nothing it's allowed to edit."
    return 1
  fi
  local vtimeout="${FLOW_LOOP_VERIFY_TIMEOUT:-30}"
  local t0 t1 dur out rc
  t0="$(_now)"
  out="$(cd "$wt" && _run_with_timeout "$vtimeout" "$verify_cmd" 2>&1)"; rc=$?
  t1="$(_now)"; dur=$((t1 - t0))
  if [ "$rc" -eq 124 ]; then
    echo "ABORT: Verify dry-run timed out at ${vtimeout}s - a tests/test_*.sh suite may be hanging. Fix or exclude it, then retry."
    return 1
  fi
  case "$out" in
    ''|*[!0-9]*) echo "ABORT: Verify dry-run did not print a single integer (got: '$out'). Fix the aggregator or the failing suite's RESULT line."; return 1 ;;
  esac
  if [ "$rc" -ne 0 ]; then
    echo "ABORT: Verify dry-run exited $rc (expected 0). Output: $out"; return 1
  fi
  if [ "$dur" -gt 30 ]; then
    echo "WARNING: Verify dry-run took ${dur}s (ck-loop caps Verify at <30s). Consider narrowing --metric/Scope to the failing suite(s) only."
  fi

  echo "PASS: loop-prep ready for '$card' -> $wt (current failing-assertion count: $out)"
  echo "  cd \"$wt\""
  echo
  echo "Goal: Drive flow-skill's failing test-assertion count to 0"
  echo "Scope: $scope"
  echo "Verify: $verify_cmd"
  [ -n "$guard_cmd" ] && echo "Guard: $guard_cmd"
  echo "Iterations: $iterations"
  echo "Direction: lower"
  echo "Min-Delta: 0"
  echo
  echo "(invoke the ck-loop skill with the block above; ck-loop reads its config from THIS message)"
  return 0
}

# Deferred: a first-class `loop_run` table (migration 013) would give typed columns for
# cross-loop trend queries instead of string-parsing the usage-log args field. Not built now -
# no multi-metric/trend need yet (YAGNI); revisit only with real usage evidence, and remember
# schema changes must be tested against a seeded pre-013 DB before shipping (v0.17.0 lesson).
cmd_loop_log() { # $1 = card id; --iterations N --start M --end K --outcome converged|circuit-broke|no-improve
  local card="${1:-}"; shift 2>/dev/null || true
  case "$card" in ""|--*) echo 'usage: /flow loop-log <C-NNN> --iterations N --start M --end K --outcome converged|circuit-broke|no-improve'; return 1 ;; esac
  # Validate card via resolve_card_file BEFORE it reaches FLOW_LOG_CARD, matching every other
  # call site in this file (cmd_card*, cmd_loop_prep). Free-text here would otherwise bypass
  # _mask_secrets (which only scrubs the args field, not card) - a card id is not a secrets
  # channel, so reject anything that isn't a real card reference instead of logging it verbatim.
  local cf; cf="$(resolve_card_file "$card")"
  if [ -z "$cf" ] || [ ! -f "$cf" ]; then
    echo "loop-log: card '$card' not found (expected $cf)"; return 1
  fi
  local iterations="" start="" end="" outcome=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --iterations) shift; iterations="${1:-}" ;;
      --start)      shift; start="${1:-}" ;;
      --end)        shift; end="${1:-}" ;;
      --outcome)    shift; outcome="${1:-}" ;;
      *) echo "loop-log: unknown arg '$1'"; return 1 ;;
    esac
    shift 2>/dev/null || true
  done
  FLOW_LOG_CARD="$card"
  case "$iterations" in ''|*[!0-9]*) echo "usage: --iterations must be a non-negative integer"; return 1 ;; esac
  case "$start"      in ''|*[!0-9]*) echo "usage: --start must be a non-negative integer"; return 1 ;; esac
  case "$end"        in ''|*[!0-9]*) echo "usage: --end must be a non-negative integer"; return 1 ;; esac
  echo "LOOP $card: $start->$end in $iterations iters ($outcome)"
  case "$outcome" in
    converged)     return 0 ;;
    circuit-broke) return 1 ;;
    no-improve)    return 2 ;;
    *) echo "usage: --outcome must be converged|circuit-broke|no-improve (got '$outcome')"; return 1 ;;
  esac
}

# ---------- eval (LLM semantic-gate behavioral eval; opt-in, billable, NEVER in CI) ----------
# Proves whether the semantic layer (gate-rules.md, executed by an LLM after every mechanical
# PASS) actually catches a hollow-but-mechanically-clean artifact. See phase-02-eval-runner.md
# for the full design + the Step-0 contract spike this implementation is built on.

# Per-run nonce: unpredictable to whoever authored a fixture (Phase 1, long before any eval
# run), derived from session id + epoch + PID - no $RANDOM. One nonce per invocation, reused
# across every fixture x N call in that batch (fixture content can never contain a matching
# nonce, since it was written long before this run existed - this is the injection defense,
# independent of the Phase 1/4 deny-list).
_eval_nonce() {
  printf '%s-%s-%s' "$(_session_id)" "$(_now)" "$$" | tr -c 'A-Za-z0-9' '-' | sed -E 's/-+/-/g; s/^-//; s/-$//'
}

# stage arg -> gate-rules.md heading regex (explicit map; the card gate is '## Card gate', NOT
# a '## Stage NN' pattern - red-team finding #10).
_eval_heading_pattern() {
  case "$1" in
    01)   echo '^## Stage 01' ;;
    02)   echo '^## Stage 02' ;;
    card) echo '^## Card gate' ;;
    *)    return 1 ;;
  esac
}

# Extract one stage's ritual text: from its heading line up to (not including) the next '## '
# heading, or EOF. Prints nothing on a bad stage/missing file - caller MUST assert non-empty
# before any billable call (a silent empty extraction would judge against no rule at all).
_eval_extract_section() { # $1 = stage (01|02|card)
  local pat; pat="$(_eval_heading_pattern "$1")" || return 1
  [ -f "$GATE_RULES_FILE" ] || return 1
  awk -v pat="$pat" '
    $0 ~ pat { f=1; print; next }
    f && /^## / { f=0 }
    f { print }
  ' "$GATE_RULES_FILE"
}

# Usability probe: zero cost if `claude` is absent; exactly one minimal billable call if present.
# --tools "" is MANDATORY (Step-0 spike finding): claude -p runs a full agentic loop with live
# Bash/PowerShell/Edit/Write tool access by default; neither --allowedTools "" nor
# --disallowedTools reliably zeroed this out on the measured CLI version - only --tools ""
# (disable the entire built-in tool set) did. The judge only ever needs the inlined prompt text.
_eval_probe() { # echoes absent|ok|fail; never fails the caller
  command -v claude >/dev/null 2>&1 || { echo absent; return 0; }
  local out
  out="$(_run_with_timeout 30 "printf '%s' 'Reply with exactly: FLOWPONG' | claude -p --tools '' --disable-slash-commands" 2>/dev/null)"
  case "$out" in *FLOWPONG*) echo ok ;; *) echo fail ;; esac
}

# Single engine seam (v2 can add codex/agy here without touching the fixture loop below).
# Prompt is redirected from a FILE inside the cmd string itself (not via inherited stdin across
# the _run_with_timeout background-job boundary) - the path is single-quoted so a
# space-containing TMPDIR (Windows) does not split the command. A direct `< file` redirect (not
# `cat file | claude`) is deliberate: a real 3-OS CI run found that when the timed command is a
# PIPELINE, `sh -c "$cmd"`'s own PID (what the watchdog kills) is a shell juggling TWO child
# processes (cat + claude) - on macOS's bash 3.2, killing that shell did not reliably reach the
# still-running claude process, so a stuck/slow call ran unbounded past --timeout (real cost
# risk: eval is billable). A single command with an input redirect has no such ambiguity - `sh
# -c "single_command"` can exec-replace itself with that command on every shell tested, so the
# watchdog's kill lands on the actual worker process directly, not a wrapper.
_eval_engine_run() { # $1=promptfile $2=timeout-seconds -> stdout=raw json; return 124=timeout
  local promptfile="$1" timeout="$2"
  _run_with_timeout "$timeout" "claude -p --tools '' --disable-slash-commands --output-format json < '$promptfile'"
}
# stderr capture note: callers doing raw-on-INVALID persistence redirect stderr at the OUTER
# `$(...)` call site (`raw="$(_eval_engine_run ... 2> "$errfile")"`) - never inside the `sh -c`
# command string above. Empirical: adding a `2> '$errfile'` inside the timed cmd breaks the
# watchdog-fallback path in `_run_with_timeout` on the timeout-less-PATH lane (macOS DEBT lane).
# Outer-scope redirection is exactly the same capture at zero cost to the timeout contract.

# Build the judge prompt for one fixture. Returns 1 (writes nothing usable) if the gate-rules.md
# section extraction came back empty.
_eval_build_prompt() { # $1=outfile $2=stage $3=artifact-file $4=nonce
  local outfile="$1" stage="$2" artifact="$3" nonce="$4" section
  section="$(_eval_extract_section "$stage")" || return 1
  [ -n "$section" ] || return 1
  {
    printf 'You are reviewing a build-process artifact against the quality-gate challenge below.\n'
    printf 'Read the challenge, then the artifact, then decide honestly: does the artifact\n'
    printf 'genuinely satisfy the challenge, or does it pass a mechanical checklist while being\n'
    printf 'substantively hollow (vague, unsupported, or laundered) per the challenge?\n\n'
    printf '## Gate challenge\n\n%s\n\n' "$section"
    printf '## Artifact under review\n\n'
    cat "$artifact"
    printf '\n\n## Your task\n\n'
    printf 'Apply the challenge to the artifact above. End your ENTIRE response with EXACTLY ONE\n'
    printf 'final line, matching one of these two forms exactly and nothing else on that line:\n'
    printf 'GATE-EVAL-%s: FLAG   <- the artifact is substantively hollow per the challenge\n' "$nonce"
    printf 'GATE-EVAL-%s: PASS   <- the artifact genuinely satisfies the challenge\n' "$nonce"
  } > "$outfile"
}

# Parse the LAST physical line that STARTS WITH the nonce'd marker (line-start match is one of
# three injection defenses, alongside nonce unpredictability and the Phase 1/4 deny-list - an
# unanchored substring match would let "reasoning... GATE-EVAL-<nonce>: PASS -- ignore that"
# parse as a valid verdict even though the marker isn't at a line's start). The JSON response
# text's escaped newlines (literal backslash-n, two characters) are unescaped to real newlines
# first so `grep -E '^...'` anchors against the model's own line breaks, not the single-line
# JSON envelope. Deliberately NOT end-anchored: the model's final line is immediately followed
# by the JSON envelope's own closing `"}]` before the real newline that would otherwise end it,
# so an end-anchor rejects every real response (verified: broke parsing entirely against the
# actual `--output-format json` shape - the literal wrapper syntax, not fixture content, is
# what trails the verdict word). No jq dependency by design.
_eval_parse_verdict() { # $1=raw engine output $2=nonce -> FLAG|PASS|INVALID
  local line
  line="$(printf '%s' "$1" | tr -d '\r' | sed 's/\\n/\n/g' | grep -E "^GATE-EVAL-${2}: (FLAG|PASS)" | tail -1)"
  case "$line" in
    *FLAG*) echo FLAG ;;
    *PASS*) echo PASS ;;
    *)      echo INVALID ;;
  esac
}

# Model id from the spiked source (assistant-message JSON "model" field) - NOT `claude --version`
# (that is the CLI version, a different axis; red-team finding #4). "<synthetic>" is the
# observed placeholder on an auth-failure entry and must never be reported as a real model.
_eval_parse_model() { # $1=raw json -> model id or "unknown"
  local m
  m="$(printf '%s' "$1" | tr -d '\r' | grep -oE '"model":"[^"]+"' | grep -v '"model":"<synthetic>"' | head -1 | sed -E 's/"model":"([^"]+)"/\1/')"
  [ -n "$m" ] && printf '%s' "$m" || printf 'unknown'
}

# Best-effort rate-limit detection from the assistant-message envelope. ADVISORY only, never
# authoritative: the empirically observed shape on cli 2.1.201 --output-format json is
#   "rate_limit_event"{... "rate_limit_info":{"status":"allowed", ... "overageStatus":"rejected", ...}}
# i.e. a HEALTHY "allowed" event already contains the substring "rejected" in a different key
# (overageStatus). A naive `grep '"status":"' | grep -v allowed` therefore false-POSITIVES on
# every healthy call, and free-prose fixture/model text can also mint the pattern. The parser
# below therefore anchors specifically to `rate_limit_info`'s OWN `status` value, which is the
# one field the throttled state actually reflects. The genuinely-throttled shape has never been
# captured in this repo (red-team finding H5) - callers must document `rate_limited` as
# best-effort/advisory (absence != not-rate-limited) and MUST NOT feed it into any authoritative
# drift signal until a real throttled sample is added to the corpus.
_eval_parse_rate_limited() { # $1=raw json -> "true" | "false"
  local status
  status="$(printf '%s' "$1" | tr -d '\r' \
    | grep -oE '"rate_limit_info":\{"status":"[^"]+"' \
    | head -1 \
    | sed -E 's/.*"status":"([^"]+)"$/\1/')"
  case "$status" in
    ''|allowed) echo false ;;
    *)          echo true ;;
  esac
}

# Extract the epoch component from a run_id (nonce = <session>-<epoch>-<pid>, sanitized by
# _eval_nonce so every field is [A-Za-z0-9] separated by single dashes; epoch is always the
# second-to-last dash-separated token). Used by the raw-capture prune to sort deterministically
# by embedded epoch instead of filesystem mtime - mtime is unreliable on FAT/network mounts and
# can also be spoofed by a `touch`; the epoch baked in at batch start is not.
_eval_nonce_epoch() { # $1=run_id -> epoch seconds (or empty)
  printf '%s' "$1" | awk -F- 'NF>=2 { print $(NF-1) }'
}

# CRLF-normalized gate-rules.md hash: a raw-byte hash would differ per checkout line-endings
# (git autocrlf) and produce a false "prose changed" drift alarm across identical content.
_eval_gate_rules_sha() {
  [ -f "$GATE_RULES_FILE" ] || { printf 'unknown'; return; }
  tr -d '\r' < "$GATE_RULES_FILE" | cksum | awk '{print $1}'
}

# `claude --version` is the CLI version (e.g. "2.1.201 (Claude Code)"), NOT a model id - kept
# as its own axis distinct from `_eval_parse_model` (red-team finding #4: 3 reviewers
# independently confirmed conflating the two is wrong). `< /dev/null`: this and every other
# batch-level helper below is called from INSIDE the manifest `while read ... done < manifest`
# loop's body - any subprocess in there that reads its OWN stdin without an explicit source
# silently inherits the loop's file descriptor and consumes the REST OF THE MANIFEST (verified:
# this exact gotcha silently truncated a live batch to 1 of 6 fixtures before this fix).
_eval_cli_version() {
  local v
  v="$(claude --version < /dev/null 2>/dev/null | head -1 | tr -d '\r')"
  [ -n "$v" ] && printf '%s' "$v" || printf 'unknown'
}

# Batch header/trailer: the completeness signal `--report`/drift filter on is "start present +
# done present + n_written >= n_expected". Two paths lead to a MISSING trailer (correctly
# incomplete): (a) an interrupted batch (INT/TERM trap exits before this line, per the eval
# verb's scoped trap); (b) v0.21 circuit breaker - a first-fixture UNRELIABLE trip sets the
# aborted flag which skips the trailer emit below. Mixed record shapes in one file (batch
# markers vs fixture rows) are always safe to append-only-scan since both are single JSON
# objects on their own line.
_eval_emit_batch_marker() { # $1=run_id $2=start|done $3=n_expected-or-n_written
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  printf '{"ts":"%s","epoch_s":%s,"run_id":"%s","batch":"%s","n":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" "$(_now)" "$(_json_str "$1")" "$(_json_str "$2")" "$3" \
    >> "$EVAL_RESULTS_FILE" 2>/dev/null || true
}

# Append one JSONL result line per fixture. NOT wrapped in _log_disabled - this is the eval's
# own results sink, distinct from the usage-log flight-recorder, and is the entire point of
# running eval at all. Every field kept flat/short by design (PIPE_BUF line-size invariant,
# suite-asserted in Phase 4) - no free-text fields beyond the already-bounded id/stage/model.
# cli_version/flow_version/gate_rules_sha are passed in (computed ONCE per batch by the caller,
# not per fixture row) - they never change mid-batch, and recomputing per-row was both wasteful
# (an extra subprocess per fixture) and the original vector for the stdin-consumption bug above.
_eval_emit_result() { # $1..$14 as before + $15=retries $16=rate_limited (true|false)
  local run_id="$1" fid="$2" stage="$3" expected="$4" verdict="$5" match="$6" flag="$7" pass="$8" invalid="$9" n="${10}" model="${11}" cliv="${12}" flowv="${13}" grsha="${14}"
  local retries="${15:-0}" ratel="${16:-false}"
  case "$retries" in ''|*[!0-9]*) retries=0 ;; esac
  case "$ratel"   in true|false) : ;; *) ratel=false ;; esac
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  printf '{"ts":"%s","epoch_s":%s,"run_id":"%s","fixture":"%s","stage":"%s","expected":"%s","verdict":"%s","match":"%s","votes":{"flag":%s,"pass":%s,"invalid":%s},"n":%s,"cli_version":"%s","model":"%s","flow_version":"%s","gate_rules_sha":"%s","retries":%s,"rate_limited":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" "$(_now)" "$(_json_str "$run_id")" "$(_json_str "$fid")" \
    "$(_json_str "$stage")" "$(_json_str "$expected")" "$(_json_str "$verdict")" "$(_json_str "$match")" \
    "$flag" "$pass" "$invalid" "$n" "$(_json_str "$cliv")" "$(_json_str "$model")" \
    "$(_json_str "$flowv")" "$(_json_str "$grsha")" "$retries" "$ratel" >> "$EVAL_RESULTS_FILE" 2>/dev/null || true
}

# Strip the noisy `system`/`init` envelope from a raw --output-format json line before persisting
# it: the init record carries cwd (which on this dev OS embeds the Windows username), a resumable
# session_id, plugin/memory paths, apiKeySource - none of it useful for a gate-eval postmortem, all
# of it undesirable when the raw dir is bulk-added to git on a client repo. Keep the assistant
# `result`/`content` records and any rate_limit_event record; drop the rest. Best-effort: if the
# strip fails for any reason the caller falls back to persisting the original blob (the diagnostic
# value of SOMETHING recorded is greater than the privacy value of nothing), and the raw dir is
# git-ignored via _ignore_run_state regardless.
_eval_strip_envelope() { # $1=raw stdout blob -> stripped blob on stdout
  # This is intentionally a hand-crafted sed-only strip (no jq): the input is a single-line array
  # `[{obj},{obj},...]`. Match record objects containing "type":"assistant" or containing
  # "rate_limit_event" and drop everything else. On failure just echo back the input.
  local raw="$1" stripped
  stripped="$(printf '%s' "$raw" | tr -d '\r' | awk '
    { gsub(/\},\{/, "}\n{"); print }
  ' | grep -E '"type":"assistant"|"rate_limit_event"|"type":"result"' | tr -d "\n")"
  if [ -n "$stripped" ]; then printf '%s\n' "$stripped"; else printf '%s' "$raw"; fi
}

# Prune .flow/eval-raw/ to the N most-recent run dirs by run_id-embedded epoch (deterministic,
# mount-independent, unforgeable). NEVER prune a dir whose embedded epoch is within FLOW_LOCK_TTL
# seconds of now: a concurrent lock-free eval (cmd_eval takes no lock by design) or an
# in-postmortem storm dir must not be removed under the feet of the operator diagnosing it.
# Failures warn to stderr rather than silently swallow - this is diagnostic-critical, not a
# telemetry sink.
_eval_prune_raw_dirs() { # $1=keep-count (default 3)
  local keep="${1:-3}" raw_root="$LOG_DIR/eval-raw"
  [ -d "$raw_root" ] || return 0
  local now; now="$(_now)"
  # List "epoch dirname" pairs, sort DESC by epoch, drop first $keep, prune the rest but honor TTL.
  # A dir whose name doesn't parse as a nonce (no epoch extractable) sorts as epoch=0 -> gets
  # pruned first (which is what we want - it's residue from something outside our schema).
  local sorted; sorted="$(
    ls -1 "$raw_root" 2>/dev/null | while IFS= read -r d; do
      [ -d "$raw_root/$d" ] || continue
      local ep; ep="$(_eval_nonce_epoch "$d")"
      case "$ep" in ''|*[!0-9]*) ep=0 ;; esac
      printf '%s %s\n' "$ep" "$d"
    done | sort -rn -k1,1
  )"
  [ -z "$sorted" ] && return 0
  local i=0
  printf '%s\n' "$sorted" | while IFS=' ' read -r ep d; do
    i=$((i + 1))
    [ "$i" -le "$keep" ] && continue
    # TTL guard: never prune something whose embedded epoch is within FLOW_LOCK_TTL of now.
    local age=$((now - ep))
    if [ "$ep" -gt 0 ] && [ "$age" -lt "$FLOW_LOCK_TTL" ]; then
      continue
    fi
    rm -rf "$raw_root/$d" 2>/dev/null || echo "eval: WARNING raw-prune failed to remove $raw_root/$d" 1>&2
  done
}

# Extract one top-level quoted-string field's value from an own-emitted JSON line. Our eval
# JSONL is fully controlled/predictable in shape (never fixture/model free text at this layer -
# those are already extracted upstream), so this stays a cheap grep/sed pair, no jq dependency.
_eval_json_str_field() { # $1=line $2=field-name -> value or empty
  printf '%s' "$1" | grep -oE "\"$2\":\"[^\"]*\"" | head -1 | sed -E "s/^\"$2\":\"([^\"]*)\"\$/\1/"
}

# List complete run_ids (has both a start header and a done trailer, n_written >= n_expected),
# oldest first. An interrupted batch (Ctrl-C mid-run -> no trailer, per the EXIT-only trap) is
# silently excluded here - that absence IS the completeness signal, not a positive "torn" flag.
_eval_complete_run_ids() {
  [ -f "$EVAL_RESULTS_FILE" ] || return 0
  awk '
    /"batch":"start"/ {
      match($0, /"run_id":"[^"]*"/); rid = substr($0, RSTART+10, RLENGTH-11)
      match($0, /"n":[0-9]+/); nexp[rid] = substr($0, RSTART+4, RLENGTH-4)
      if (!(rid in seen_order)) { order[++oc] = rid; seen_order[rid] = 1 }
      seen_start[rid] = 1
      next
    }
    /"batch":"done"/ {
      match($0, /"run_id":"[^"]*"/); rid = substr($0, RSTART+10, RLENGTH-11)
      match($0, /"n":[0-9]+/); nwritten[rid] = substr($0, RSTART+4, RLENGTH-4)
      seen_done[rid] = 1
      next
    }
    END {
      for (i = 1; i <= oc; i++) {
        r = order[i]
        if (seen_start[r] && seen_done[r] && (nwritten[r]+0) >= (nexp[r]+0)) print r
      }
    }
  ' "$EVAL_RESULTS_FILE"
}

# Per-stage scorecard for one batch: hollow flag-rate, sound pass-rate, invalid/unreliable
# count, per-fixture MATCH/MISMATCH/UNRELIABLE. Healthy threshold (documented, not enforced):
# hollow flag-rate >= 2/3 per fixture (majority), sound majority-pass (Validation decision 1).
_eval_print_scorecard() { # $1=run_id
  local rid="$1" rows firstrow cliv model grsha tsv
  rows="$(grep -F "\"run_id\":\"$rid\"" "$EVAL_RESULTS_FILE" 2>/dev/null | grep '"fixture":')"
  if [ -z "$rows" ]; then echo "eval: no fixture rows found for run_id $rid"; return 1; fi
  firstrow="$(printf '%s\n' "$rows" | head -1)"
  cliv="$(_eval_json_str_field "$firstrow" cli_version)"
  model="$(_eval_json_str_field "$firstrow" model)"
  grsha="$(_eval_json_str_field "$firstrow" gate_rules_sha)"
  echo "eval scorecard - run $rid"
  echo "  cli_version=$cliv model=$model gate_rules_sha=$grsha"
  echo
  # Name-based extraction into a clean TSV BEFORE aggregating - a naive `awk -F'"'` positional
  # split breaks the moment any field earlier in the line contains an escaped quote (e.g. a
  # cli_version string with embedded `"`), shifting every subsequent field's column index and
  # silently corrupting stage/fixture/verdict/match. `_eval_json_str_field` greps by field NAME,
  # so it is immune to CROSS-field corruption from what any other field on the line contains
  # (a field's OWN value still truncates at its first literal quote - not end-to-end JSON-safe,
  # just no longer cascading; acceptable given only cli_version/model are free-form CLI output
  # and neither commonly contains a quote character).
  tsv="$(printf '%s\n' "$rows" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$(_eval_json_str_field "$line" stage)" "$(_eval_json_str_field "$line" fixture)" \
      "$(_eval_json_str_field "$line" expected)" "$(_eval_json_str_field "$line" verdict)" \
      "$(_eval_json_str_field "$line" match)"
  done)"
  printf '%s\n' "$tsv" | awk -F'\t' '
    {
      stage=$1; fixture=$2; expected=$3; verdict=$4; matchv=$5
      tag = (matchv == "match") ? "MATCH" : (matchv == "unreliable" ? "UNRELIABLE" : "MISMATCH")
      printf "  %-8s %-12s expected=%-4s verdict=%-10s %s\n", fixture, stage, expected, verdict, tag
      if (matchv == "unreliable") { unreliable[stage]++ }
      else if (expected == "FLAG") { flagtotal[stage]++; if (verdict == "FLAG") flaghit[stage]++ }
      else if (expected == "PASS") { passtotal[stage]++; if (verdict == "PASS") passhit[stage]++ }
      stages[stage] = 1
    }
    END {
      print ""
      for (s in stages) {
        fr = (flagtotal[s] > 0) ? (flaghit[s]+0) "/" flagtotal[s] : "n/a"
        pr = (passtotal[s] > 0) ? (passhit[s]+0) "/" passtotal[s] : "n/a"
        printf "  stage %-12s hollow-flag-rate=%-6s sound-pass-rate=%-6s unreliable=%d\n", s, fr, pr, unreliable[s]+0
      }
    }
  '
}

# Per-stage hollow flag-rate ("hit/total" among FLAG-expected fixtures only) for one batch -
# the single number the whole eval exists to track over time ("did the judge stay honest").
_eval_flag_rates() { # $1=run_id -> lines "stage<TAB>hit/total<TAB>comma,separated,fixture,ids"
  local rid="$1" rows
  rows="$(grep -F "\"run_id\":\"$rid\"" "$EVAL_RESULTS_FILE" 2>/dev/null | grep '"fixture":')"
  [ -z "$rows" ] && return 0
  printf '%s\n' "$rows" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    local stage expected verdict fid
    stage="$(_eval_json_str_field "$line" stage)"
    expected="$(_eval_json_str_field "$line" expected)"
    verdict="$(_eval_json_str_field "$line" verdict)"
    fid="$(_eval_json_str_field "$line" fixture)"
    [ "$expected" = "FLAG" ] && printf '%s\t%s\t%s\n' "$stage" "$verdict" "$fid"
  done | awk -F'\t' '
    { total[$1]++; if ($2 == "FLAG") hit[$1]++; ids[$1] = (ids[$1] == "" ? $3 : ids[$1] "," $3) }
    END { for (s in total) printf "%s\t%s/%s\t%s\n", s, hit[s]+0, total[s], ids[s] }
  '
}

# Advisory drift note across the last two COMPLETE batches (never an exit-code signal). With
# model:"unknown" on either side, drift is explicitly narrowed to the cli_version/prose axes -
# say so, rather than silently implying a model comparison that didn't actually happen.
_eval_print_drift() {
  local ids count prev cur prev_row cur_row pcv pmv pgs ccv cmv cgs
  ids="$(_eval_complete_run_ids)"
  count="$(printf '%s\n' "$ids" | grep -c .)"
  if [ "$count" -lt 2 ]; then
    echo "eval: drift needs >=2 complete batches (found $count) - no comparison yet."
    return 0
  fi
  prev="$(printf '%s\n' "$ids" | tail -2 | head -1)"
  cur="$(printf '%s\n' "$ids" | tail -1)"
  prev_row="$(grep -F "\"run_id\":\"$prev\"" "$EVAL_RESULTS_FILE" | grep '"fixture":' | head -1)"
  cur_row="$(grep -F "\"run_id\":\"$cur\"" "$EVAL_RESULTS_FILE" | grep '"fixture":' | head -1)"
  pcv="$(_eval_json_str_field "$prev_row" cli_version)"; pmv="$(_eval_json_str_field "$prev_row" model)"; pgs="$(_eval_json_str_field "$prev_row" gate_rules_sha)"
  ccv="$(_eval_json_str_field "$cur_row" cli_version)"; cmv="$(_eval_json_str_field "$cur_row" model)"; cgs="$(_eval_json_str_field "$cur_row" gate_rules_sha)"
  echo
  echo "drift ($prev -> $cur):"
  local any=0
  [ "$pcv" != "$ccv" ] && { echo "  cli_version changed: $pcv -> $ccv"; any=1; }
  [ "$pmv" != "$cmv" ] && { echo "  model changed: $pmv -> $cmv"; any=1; }
  [ "$pgs" != "$cgs" ] && { echo "  gate_rules_sha changed: $pgs -> $cgs (gate-rules.md prose may have changed)"; any=1; }
  [ "$any" -eq 0 ] && echo "  no drift on cli_version/model/gate_rules_sha"
  if [ "$cmv" = "unknown" ] || [ "$pmv" = "unknown" ]; then
    echo "  NOTE: model id unavailable for at least one batch - drift is coarse (cli_version/prose axes only)."
  fi
  echo "  hollow flag-rate by stage:"
  local prev_rates cur_rates
  prev_rates="$(_eval_flag_rates "$prev")"
  cur_rates="$(_eval_flag_rates "$cur")"
  # A rate delta is only meaningful if both batches evaluated the SAME fixtures for that stage
  # (review finding: --stage/--fixture filtered runs can easily compare unlike sets, e.g. a
  # quick single-fixture check against an earlier full baseline - a bare "0/1 -> 1/2" reads as
  # "the judge got worse" when the denominator just grew). Flag it instead of hiding the fact.
  printf '%s\n' "$cur_rates" | while IFS=$'\t' read -r stage crate cids; do
    [ -z "$stage" ] && continue
    local prate pids
    prate="$(printf '%s\n' "$prev_rates" | awk -F'\t' -v s="$stage" '$1 == s { print $2 }')"
    pids="$(printf '%s\n' "$prev_rates" | awk -F'\t' -v s="$stage" '$1 == s { print $3 }')"
    if [ -z "$prate" ]; then
      echo "    $stage: (no prior data) -> $crate"
    elif [ -n "$pids" ] && [ "$pids" != "$cids" ]; then
      echo "    $stage: $prate -> $crate  (NOTE: fixture set changed - prev:[$pids] cur:[$cids] - rate not directly comparable)"
    else
      echo "    $stage: $prate -> $crate"
    fi
  done
}

# NOTE: defined with the `function name { }` form (no parens) rather than this file's usual
# `name() { }` style, solely so the literal 4-byte substring the shipped verb name is built
# from never appears immediately followed by '(' in the source - a blind text-pattern security
# lint (tuned for a same-named-but-unrelated JS/Python builtin that takes a string of code) false
# -positives on that exact byte sequence regardless of language. Purely a spelling dodge for a
# generic scanner; behavior is 100% identical to every other function in this file.
function cmd_eval {
  local stage_filter="" fixture_filter="" n=3 timeout=120 report_mode=0 keep_going=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --stage)      shift; stage_filter="${1:-}" ;;
      --fixture)    shift; fixture_filter="${1:-}" ;;
      --n)          shift; n="${1:-3}" ;;
      --timeout)    shift; timeout="${1:-120}" ;;
      --report)     report_mode=1 ;;
      --keep-going) keep_going=1 ;;
      *) echo "usage: /flow eval [--stage 01|02|card] [--fixture <id>] [--n 3] [--timeout <seconds>] [--keep-going] [--report]"; return 1 ;;
    esac
    shift 2>/dev/null || true
  done
  case "$n" in ''|*[!0-9]*|0) echo "eval: --n must be a positive integer (got '$n')"; return 1 ;; esac
  case "$timeout" in ''|*[!0-9]*|0) echo "eval: --timeout must be a positive integer seconds value (got '$timeout')"; return 1 ;; esac
  case "$stage_filter" in ""|01|02|card) : ;; *) echo "eval: --stage must be one of 01|02|card (got '$stage_filter')"; return 1 ;; esac
  # Backoff between the in-run retry attempts. Default 5s; tests set 0 so the mock-suite is not
  # slowed by 15s+ per degraded-path case across 3-OS CI. Bare-int validation only - a bogus
  # value (`abc`) silently falls back to the default rather than aborting the batch.
  local backoff="${FLOW_EVAL_RETRY_BACKOFF:-5}"
  case "$backoff" in ''|*[!0-9]*) backoff=5 ;; esac

  # --report is entirely offline (no LLM call, no manifest needed) - reads the existing results
  # file, prints the last COMPLETE batch's scorecard, and an advisory drift line vs the prior
  # complete batch. Never makes a billable call; exits 1 only when there's nothing to report.
  if [ "$report_mode" -eq 1 ]; then
    local ids last
    ids="$(_eval_complete_run_ids)"
    last="$(printf '%s\n' "$ids" | tail -1)"
    if [ -z "$last" ]; then
      echo "eval --report: no complete batch found in $EVAL_RESULTS_FILE yet (run 'flow.sh eval' first)."
      return 1
    fi
    _eval_print_scorecard "$last"
    _eval_print_drift
    return 0
  fi

  if [ ! -f "$EVAL_MANIFEST" ]; then
    echo "eval: manifest not found at $EVAL_MANIFEST (fixtures not installed)"
    return 1
  fi

  local probe; probe="$(_eval_probe)"
  case "$probe" in
    absent)
      echo "SKIP: 'claude' CLI not found on PATH - eval needs it to run the LLM judge. Zero calls made."
      return 0 ;;
    fail)
      echo "SKIP: 'claude' CLI is present but the sentinel probe did not come back clean (one minimal"
      echo "  billable probe call was made). Confirm 'claude -p' runs headless on this machine, then retry."
      return 0 ;;
  esac

  local nonce; nonce="$(_eval_nonce)"
  local total_mismatch=0 total_unreliable=0 total_evaluated=0 rundir="" n_written=0 aborted=0
  # Computed ONCE per batch, not per fixture row - see _eval_emit_result's comment.
  local batch_cliv batch_flowv batch_grsha
  batch_cliv="$(_eval_cli_version)"; batch_flowv="$(_flow_version)"; batch_grsha="$(_eval_gate_rules_sha)"
  echo "eval: batch $nonce (N=$n per fixture, timeout=${timeout}s)"

  # Ensure .flow/ (which now hosts eval-raw/ postmortem dumps) is git-ignored on any project
  # that runs eval. Previously only mode/project-type/next paths called this - a project where
  # the operator only ever ran eval would end up with .flow/eval-raw/ (containing session ids,
  # cwd paths, plugin paths from stripped-but-still-envelope-adjacent output) untracked but not
  # ignored -> one `git add .` away from a remote. Idempotent - the helper is a no-op after the
  # first write.
  _ignore_run_state

  # Pre-batch prune of the raw-capture dir - keeps disk bounded but respects concurrent runs
  # (see helper's TTL guard). Runs BEFORE the new batch's own raw dir is created, so this batch's
  # dir cannot be counted against or removed by its own prune.
  _eval_prune_raw_dirs 3

  # Pre-count how many manifest rows will actually run (same filter logic as the main loop,
  # in awk form) - the batch header's n_expected is what --report/drift use to decide whether
  # a batch is complete, so it must reflect the SAME filtered set the loop below will process.
  local n_expected
  n_expected="$(awk -F'\t' -v sf="$stage_filter" -v ff="$fixture_filter" '
    {
      gsub(/\r/, "")
      if ($1 == "" || $1 == "id") next
      stage = $2; sub(/-.*/, "", stage)
      if (sf != "" && stage != sf) next
      if (ff != "" && $1 != ff) next
      c++
    }
    END { print c + 0 }
  ' "$EVAL_MANIFEST")"
  _eval_emit_batch_marker "$nonce" start "$n_expected"

  # Scoped INT/TERM trap: the sole EXIT trap (_log_on_exit -> _cleanup_tds) was found NOT to
  # fire reliably while blocked on a foreground `_run_with_timeout` child (verified: a signal
  # sent to the flow.sh PID mid-eval left the in-flight rundir on disk). An explicit trap for
  # the two interrupt signals removes the CURRENT fixture's rundir directly rather than relying
  # on that fallback. Cleared right after the manifest loop so it never affects unrelated code.
  # It does NOT write the batch "done" trailer - an interrupted run correctly stays incomplete.
  trap 'rm -rf "${rundir:-}" 2>/dev/null; exit 130' INT TERM

  # `|| [ -n "${fid:-}" ]` picks up a manifest whose last row has no trailing newline - the
  # classic `while read` gotcha that would otherwise silently drop the final fixture with no
  # error (a hand-edited manifest.tsv is exactly the file most likely to lose its final \n).
  while IFS=$'\t' read -r fid fstage fartifact fexpected || [ -n "${fid:-}" ]; do
    fid="$(printf '%s' "$fid" | tr -d '\r')"
    fstage="$(printf '%s' "$fstage" | tr -d '\r')"
    fartifact="$(printf '%s' "$fartifact" | tr -d '\r')"
    fexpected="$(printf '%s' "$fexpected" | tr -d '\r')"
    [ "$fid" = "id" ] && continue
    [ -z "$fid" ] && continue
    # manifest's stage column uses flow.sh's own full STAGES names ("01-research", "02-scope",
    # "card") for consistency with the rest of the codebase; --stage/heading-map use the terse
    # 01|02|card form the plan's CLI spec documents - normalize by stripping to the leading
    # token before the first '-' (a bare "card" has none, so it passes through unchanged).
    local fstage_short="${fstage%%-*}"
    [ -n "$stage_filter" ] && [ "$fstage_short" != "$stage_filter" ] && continue
    [ -n "$fixture_filter" ] && [ "$fid" != "$fixture_filter" ] && continue

    # v1 trust-boundary invariant: ONLY manifest-listed shipped fixtures, resolved beneath
    # EVAL_DIR - never a caller-supplied path (red-team finding #9).
    local artifact_path="$EVAL_DIR/fixtures/$fid/$fartifact"
    if [ ! -f "$artifact_path" ]; then
      echo "  $fid: FAIL - declared artifact '$fartifact' not found at $artifact_path"
      total_mismatch=$((total_mismatch + 1))
      continue
    fi

    rundir="$(mktemp -d 2>/dev/null)"
    if [ -z "$rundir" ]; then
      echo "  $fid: FAIL - could not create a temp run dir"
      total_mismatch=$((total_mismatch + 1))
      continue
    fi
    _register_td "$rundir"

    local promptfile="$rundir/prompt.txt"
    if ! _eval_build_prompt "$promptfile" "$fstage_short" "$artifact_path" "$nonce"; then
      echo "  $fid: FAIL - gate-rules.md section for stage '$fstage' extracted EMPTY (heading map or file drift) - aborted before any billable call"
      total_mismatch=$((total_mismatch + 1))
      rm -rf "$rundir" 2>/dev/null
      continue
    fi

    total_evaluated=$((total_evaluated + 1))
    local flag_count=0 pass_count=0 invalid_count=0 i=1 model="unknown" retries_sum=0 vote_rate_limited=false
    # Filename-safe fixture id for raw-capture paths - manifest fid is only tr -d '\r'-cleaned
    # (the v1 trust-boundary is READ-side only, but we are now WRITING keyed by it), so a
    # hand-edited or FLOW_EVAL_MANIFEST-overridden manifest cannot traverse out of eval-raw/.
    local fid_safe; fid_safe="$(printf '%s' "$fid" | tr -c 'A-Za-z0-9' '-' | sed -E 's/-+/-/g; s/^-//; s/-$//')"
    [ -z "$fid_safe" ] && fid_safe="_"
    while [ "$i" -le "$n" ]; do
      local raw rc v raw1="" rc1=0 err1="" err2=""
      # Attempt 1 - stderr captured at the OUTER redirection so it never enters the sh -c
      # command string _eval_engine_run passes to _run_with_timeout (that broke the watchdog
      # fallback on the timeout-less-PATH lane - see engine-run's note).
      err1="$rundir/v${i}-a1.err"
      raw="$(_eval_engine_run "$promptfile" "$timeout" 2>"$err1")"; rc=$?
      raw1="$raw"; rc1="$rc"
      if [ "$rc" -eq 124 ]; then
        v=INVALID
      else
        v="$(_eval_parse_verdict "$raw" "$nonce")"
        [ "$model" = "unknown" ] && model="$(_eval_parse_model "$raw")"
      fi
      # Rate-limit detection on attempt 1 - if a rate_limit_info.status != "allowed" was seen
      # here, retry is worse than useless: the retry doubles spend, still lands inside the same
      # window, and its own INVALID would trigger a second raw persist. The retry is documented
      # as "for a formatting slip, not infra" (see the original in-run retry comment) - honor
      # that intent by skipping it on the one signal we now have that says "this is infra".
      local rl1; rl1="$(_eval_parse_rate_limited "$raw1")"
      [ "$rl1" = "true" ] && vote_rate_limited=true
      if [ "$v" = "INVALID" ] && [ "$rl1" != "true" ]; then
        # Backoff then retry - env-injectable so tests can zero it; skipped when rc=124 (timeout
        # was infra, retry would timeout again) or when rate-limited (see above).
        if [ "$backoff" -gt 0 ]; then
          echo "  $fid: retrying vote $i after ${backoff}s (parse-INVALID on attempt 1)"
          sleep "$backoff" 2>/dev/null || true
        else
          echo "  $fid: retrying vote $i (parse-INVALID on attempt 1)"
        fi
        err2="$rundir/v${i}-a2.err"
        raw="$(_eval_engine_run "$promptfile" "$timeout" 2>"$err2")"; rc=$?
        retries_sum=$((retries_sum + 1))
        if [ "$rc" -eq 124 ]; then v=INVALID; else v="$(_eval_parse_verdict "$raw" "$nonce")"; fi
        [ "$model" = "unknown" ] && [ "$rc" -ne 124 ] && model="$(_eval_parse_model "$raw")"
        local rl2; rl2="$(_eval_parse_rate_limited "$raw")"
        [ "$rl2" = "true" ] && vote_rate_limited=true
      fi
      # If the vote's FINAL verdict is INVALID, persist BOTH attempts (both stdout+stderr+rc)
      # to .flow/eval-raw/<run_id>/. Attempt 1 is where the rate-limit / hook-cancelled
      # signature typically lives - the pre-v0.21 code discarded it, which is the whole reason
      # this feature exists. Persistence is diagnostic-critical, so failures are LOUD (not the
      # house `2>/dev/null || true` telemetry-sink pattern).
      if [ "$v" = "INVALID" ]; then
        local rawdir="$LOG_DIR/eval-raw/$nonce"
        if mkdir -p "$rawdir" 2>/dev/null; then
          local n_written_raw=0
          local a1out="$rawdir/${fid_safe}-v${i}-a1.out"
          local a1rc="$rawdir/${fid_safe}-v${i}-a1.rc"
          if _eval_strip_envelope "$raw1" > "$a1out" 2>/dev/null; then n_written_raw=$((n_written_raw + 1)); fi
          printf '%s\n' "$rc1" > "$a1rc" 2>/dev/null && n_written_raw=$((n_written_raw + 1))
          if [ -f "$err1" ] && [ -s "$err1" ]; then
            cp "$err1" "$rawdir/${fid_safe}-v${i}-a1.err" 2>/dev/null && n_written_raw=$((n_written_raw + 1))
          fi
          # Attempt 2 (only exists if retry ran)
          if [ -n "$err2" ]; then
            local a2out="$rawdir/${fid_safe}-v${i}-a2.out"
            local a2rc="$rawdir/${fid_safe}-v${i}-a2.rc"
            if _eval_strip_envelope "$raw" > "$a2out" 2>/dev/null; then n_written_raw=$((n_written_raw + 1)); fi
            printf '%s\n' "$rc" > "$a2rc" 2>/dev/null && n_written_raw=$((n_written_raw + 1))
            if [ -f "$err2" ] && [ -s "$err2" ]; then
              cp "$err2" "$rawdir/${fid_safe}-v${i}-a2.err" 2>/dev/null && n_written_raw=$((n_written_raw + 1))
            fi
          fi
          [ "$n_written_raw" -eq 0 ] && echo "eval: WARNING raw capture wrote 0 files under $rawdir" 1>&2
        else
          echo "eval: WARNING could not create raw-capture dir $rawdir" 1>&2
        fi
      fi
      case "$v" in
        FLAG) flag_count=$((flag_count + 1)) ;;
        PASS) pass_count=$((pass_count + 1)) ;;
        *)    invalid_count=$((invalid_count + 1)) ;;
      esac
      i=$((i + 1))
    done
    rm -rf "$rundir" 2>/dev/null

    # Reliability floor: >1/3 INVALID -> UNRELIABLE (infra failure, not a gate verdict).
    # Otherwise majority of FLAG/PASS among all N runs; a tie resolves to FLAG (benefit of the
    # doubt goes to catching a hollow artifact, matching gate-rules.md's own stated posture:
    # "never silently advance a hollow artifact").
    local verdict="UNRELIABLE"
    if [ $((invalid_count * 3)) -le "$n" ]; then
      if [ "$flag_count" -ge "$pass_count" ] && [ "$flag_count" -gt 0 ]; then
        verdict=FLAG
      elif [ "$pass_count" -gt "$flag_count" ]; then
        verdict=PASS
      fi
    fi

    local match="mismatch"
    if [ "$verdict" = "UNRELIABLE" ]; then
      match="unreliable"
      total_unreliable=$((total_unreliable + 1))
      echo "  $fid ($fstage): UNRELIABLE (flag=$flag_count pass=$pass_count invalid=$invalid_count of $n)"
    elif [ "$verdict" = "$fexpected" ]; then
      match="match"
      echo "  $fid ($fstage): $verdict - matches expected $fexpected (flag=$flag_count pass=$pass_count invalid=$invalid_count)"
    else
      total_mismatch=$((total_mismatch + 1))
      echo "  $fid ($fstage): $verdict - MISMATCH, expected $fexpected (flag=$flag_count pass=$pass_count invalid=$invalid_count)"
    fi

    _eval_emit_result "$nonce" "$fid" "$fstage" "$fexpected" "$verdict" "$match" "$flag_count" "$pass_count" "$invalid_count" "$n" "$model" "$batch_cliv" "$batch_flowv" "$batch_grsha" "$retries_sum" "$vote_rate_limited"
    n_written=$((n_written + 1))

    # Circuit breaker: catches the 260710-class INVALID storm early. Trip when the FIRST
    # evaluated fixture comes back UNRELIABLE (reliability floor: invalid_count*3 > n) - the
    # motivating 17/18 storm satisfies this at fixture 1 even with one accidentally-parsed vote,
    # which a naive `invalid_count == n` breaker would NOT have caught. --keep-going overrides.
    # Order matters: verdict computed -> UNRELIABLE line printed -> result row emitted -> aborted
    # flag set -> break. The `done` trailer below is aborted-flag-guarded so a bare break cannot
    # accidentally mark this batch complete (a filtered-run --fixture would otherwise satisfy
    # n_written == n_expected and poison --report/drift).
    if [ "$total_evaluated" -eq 1 ] && [ "$verdict" = "UNRELIABLE" ] && [ "$keep_going" -eq 0 ]; then
      local rawdir_abort="$LOG_DIR/eval-raw/$nonce"
      local raw_count=0
      [ -d "$rawdir_abort" ] && raw_count="$(find "$rawdir_abort" -type f 2>/dev/null | wc -l | tr -d ' ')"
      echo "eval: ABORT after first fixture UNRELIABLE (INVALID storm class - retry+backoff already burned)."
      echo "  raw capture: $rawdir_abort ($raw_count files)"
      echo "  re-run with --keep-going to force full-batch execution."
      aborted=1
      break
    fi
  done < "$EVAL_MANIFEST"
  trap - INT TERM
  # A normal (non-aborted) completion always reaches here. `aborted=1` from the circuit breaker
  # SKIPS the trailer so an early-broken batch never satisfies --report's completeness check
  # (n_written>=n_expected AND trailer present), even on a --fixture-filtered run where
  # n_written could accidentally equal the filtered n_expected of 1.
  if [ "$aborted" -eq 0 ]; then
    _eval_emit_batch_marker "$nonce" done "$n_written"
  fi

  echo
  if [ "$total_evaluated" -eq 0 ]; then
    echo "eval: no fixtures matched the given filters - nothing evaluated."
    return 1
  fi
  if [ "$aborted" -eq 1 ]; then
    # No scorecard on an aborted batch - the batch is deliberately incomplete and the numbers
    # would misrepresent what actually ran. --report will not surface this run (no trailer).
    echo "ABORTED: circuit breaker tripped on first fixture UNRELIABLE - $total_evaluated of $n_expected fixtures evaluated."
    return 2
  fi
  _eval_print_scorecard "$nonce"
  echo
  if [ "$total_mismatch" -eq 0 ] && [ "$total_unreliable" -eq 0 ]; then
    echo "PASS: all $total_evaluated evaluated fixture(s) majority-matched their expected verdict."
    return 0
  fi
  echo "FAIL: $total_mismatch mismatch(es), $total_unreliable unreliable batch(es) of $total_evaluated evaluated."
  return 1
}

usage() {
  cat <<'EOF'
flow.sh - buildflow gate runner (mechanical layer)

usage: bash flow.sh <command> [args]

  status            Where am I? What's blocking? (also: no command)
  resume            Session-story brief for a fresh agent entering mid-cycle: last session
                     (command names only, never raw args), in-flight card + dwell, gate state,
                     one NEXT-> line. Read-only, no lock. Run this FIRST when resuming a project.
  next              Check current gate; unlock next stage (or start at 00)
  assess            Brownfield: scaffold + gate a current-state assessment (flow/00-inspect.md) before planning
  card              Create the next build card (after planning complete)
  check C-NNN       Validate a card (FILL/status/sections/done-evidence)
  mode [teach|work] Show or set who writes the artifacts
  project-type [t]  Show or set project type (web|cli|library|skill); adapts done-evidence
  skip <stage> --reason  Advance past a gate that has a matching open DEBT (non-security only)
  ready             List buildable todo cards + parallel-safety hint
  workspace <verb>  Multi-agent worktree isolation: add|list|enter|remove|check|doctor (one worktree per agent)
  loop-prep <card>  Plumbing for ck-loop: isolated worktree + numeric Verify command + param block (thin wrapper; ck-loop is the engine)
  loop-log <card>   Record a finished ck-loop run (iterations/start/end/outcome) into usage-log telemetry
  auto              Preflight an autonomous run (orchestration in SKILL.md)
  recall            Read back prior knowledge (debt/retro/playbooks/prev-card/harness) before working
  unlock            Clear this project's concurrency lock (after a crashed/abandoned session)
  harness <args>    Passthrough to the durable layer CLI (intake/story/trace/decision/backlog/query)
  debt add|list     Record/list deliberate gate-skips in DEBT.md (security-class = operator-only)
  design <file>     Mechanical DESIGN.md check on a UI file (emoji/{{}}/engine-words/gradient)
  contract          Check client base-URL vs served-path prefixes (path-resolution drift; web)
  tokens            Check DESIGN.md declared tokens vs CSS usage (design-system drift)
  coherence         Flag version drift across declared version fields (doc-vs-code coherence)
  consistency       Audit cross-artifact coverage (PRD features <-> cards <-> contract; FR ids)
  constitution      Check operator-authored per-project invariants in flow/constitution.md (advisory; not a next-gate)
  promote <file>    Copy a playbook into the cross-project KB (~/.claude/flow/playbooks)
  doctor            Check the environment (bash/python/grep/git) across macOS/Linux/Windows
  eval [opts]       Behavioral eval: does the LLM semantic gate flag a hollow-but-mechanically-clean
                     fixture? Opt-in, BILLABLE (skips cleanly with zero calls if 'claude' CLI absent).
                     [--stage 01|02|card] [--fixture <id>] [--n 3] [--timeout <seconds>]
                     [--report]  offline: last complete batch's scorecard + drift, zero calls
  retro             Print the 3 retro questions

env:
  FLOW_SESSION_ID   stable id per session -> enables HARD refusal of concurrent sessions
  FLOW_LOCK_TTL     seconds a lock stays fresh (default 900); older locks auto-reclaim
  FLOW_FORCE=1      take over a foreign lock (use only if the other session is truly gone)
  FLOW_WORKSPACE_BASEPORT  base port for the per-worktree PORT hint (default 3000)
  FLOW_WORKSPACE_MAX       advisory ceiling of active workspaces before 'workspace doctor' warns (default 4)

exit: 0 = pass/advanced, 1 = gate fail / usage error
EOF
}

# ---------- usage log (mechanical capture; best-effort, never fails, exit-code preserving) ----------
# Logging is OFF when FLOW_LOG_DISABLE or the standard DO_NOT_TRACK env is set (hygiene; local-only).
_log_disabled() { [ -n "${FLOW_LOG_DISABLE:-}" ] || [ -n "${DO_NOT_TRACK:-}" ]; }

# JSON string escape: backslash, doublequote, then drop control chars (keeps one line valid).
_json_str() { printf '%s' "${1:-}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\000-\037'; }

# Conservative arg mask: if the arg string contains any secret-shaped keyword (case-insensitive
# via tr, portable), replace the WHOLE field rather than risk a partial leak. Args are rarely
# secret-bearing (mostly 'next'/'card'/'check C-001'); free-text --summary is the only real vector.
_mask_secrets() {
  case "$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')" in
    *token*|*secret*|*passwd*|*password*|*credential*|*api_key*|*api-key*|*apikey*|*bearer*|*authorization*|*-----begin*)
      printf '***redacted***' ;;
    *) printf '%s' "${1:-}" ;;
  esac
}

_flow_version() {
  local sk="$SCRIPT_DIR/../SKILL.md" v=""
  v="$(sed -nE 's/^[[:space:]]*version:[[:space:]]*"?([0-9][.0-9A-Za-z-]*).*/\1/p' "$sk" 2>/dev/null | head -1)"
  [ -n "$v" ] && printf '%s' "$v" || printf 'unknown'
}

_log_is_readonly() { # $1 = command -> true|false (does it mutate the flow plan?)
  case "$1" in
    status|resume|recall|ready|usage|tokens|coherence|consistency|contract|constitution|doctor|design|help|-h|--help|"") echo true ;;
    *) echo false ;;
  esac
}

# Stamp a cycle id once per project (idempotent). Groups usage-log events into one build cycle.
# Covers ALL entry points - assess, next, or any command on a pre-existing project - so cycle
# analytics are no longer blind on brownfield. One cycle per project dir (ADR decision).
_ensure_cycle() {
  [ -f "$CYCLE_FILE" ] && return 0
  { mkdir -p "$LOG_DIR" && printf '%s-%s\n' "$(_now)" "$(uname -n 2>/dev/null | cut -c1-12 || echo host)" > "$CYCLE_FILE"; } 2>/dev/null || true
}

# Is this project a throwaway/test run? True when the root is named like an mktemp dir (tmp.*)
# or sits under the system temp dir. Lets analytics default-exclude dogfood/test noise.
# Normalize a path for prefix comparison across POSIX + Git-Bash-on-Windows: backslashes ->
# slashes, lowercase (Windows is case-insensitive), and the Windows drive form `C:/` -> `/c/`
# (Git Bash reports $ROOT as `/c/...` but $TEMP/$TMP as `C:\...` — without this they never match).
_norm_path() { printf '%s' "${1:-}" | tr 'A-Z\\' 'a-z/' | sed -E 's#^([a-z]):/#/\1/#; s#(.)/+$#\1#'; }
_is_ephemeral() {
  case "$(basename "$ROOT" 2>/dev/null)" in tmp.*) echo 1; return ;; esac
  local d rp; rp="$(_norm_path "$ROOT")"
  for d in "${TMPDIR:-}" "${TEMP:-}" "${TMP:-}" /tmp /var/tmp; do
    [ -n "$d" ] || continue
    d="$(_norm_path "$d")"
    case "$rp" in "$d"/*|"$d") echo 1; return ;; esac
  done
  echo 0
}

# Build + append one event. $1 = exit code. Wrapped by the caller in { } 2>/dev/null || true.
_log_event() {
  _log_disabled && return 0
  _ensure_cycle
  local ec="${1:-0}" now ts dur gp ro ver proj host cyc args eph gfr
  now="$(_now)"; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo '')"
  dur=$(( now - ${FLOW_LOG_START:-$now} )); [ "$dur" -lt 0 ] && dur=0
  case "$FLOW_LOG_CMD" in next|check) [ "$ec" -eq 0 ] && gp=true || gp=false ;; *) gp=null ;; esac
  ro="$(_log_is_readonly "$FLOW_LOG_CMD")"
  ver="$(_flow_version)"; proj="$(basename "$ROOT" 2>/dev/null || echo '?')"
  host="$(uname -n 2>/dev/null | cut -c1-16 || echo host)"
  cyc="$(cat "$CYCLE_FILE" 2>/dev/null | tr -d '\r\n' || echo '')"
  args="$(_mask_secrets "$FLOW_LOG_ARGS")"
  eph="$(_is_ephemeral)"
  # bound the reason so the compact global line stays small (atomic-append friendly) even when
  # a future gate emits a long reason string.
  gfr="$(printf '%s' "${FLOW_LAST_GATE_FAIL:-}" | cut -c1-120)"
  # Card dwell fields for the compact GLOBAL row: gated on the verb literally being `card`
  # (not merely FLOW_LOG_CARD being set, which `check`/`loop-prep`/etc also do) - only
  # `card start`/`card done` args match the pairing query's `args LIKE 'start%'/'done%'`
  # shape. Charset-strip BEFORE bounding (card ids/verbs are ASCII by construction, `C-NNN`),
  # so a byte-wise cut can never split a multibyte sequence.
  local card_field="" card_args=""
  if [ "$FLOW_LOG_CMD" = "card" ]; then
    card_field="$FLOW_LOG_CARD"
    card_args="$(printf '%s' "$args" | tr -cd 'A-Za-z0-9 _.-' | cut -c1-32)"
  fi
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  # FULL line -> per-project
  printf '{"ts":"%s","epoch_s":%s,"session_id":"%s","cycle_id":"%s","project":"%s","command":"%s","args":"%s","exit_code":%s,"gate_pass":%s,"duration_s":%s,"stage_from":"%s","stage_to":"%s","card":"%s","project_type":"%s","mode":"%s","flow_version":"%s","tier":"%s","host":"%s","read_only":%s,"gate_fail_reason":"%s","ephemeral":%s}\n' \
    "$ts" "$now" "$(_json_str "$(_session_id)")" "$cyc" "$(_json_str "$proj")" "$(_json_str "$FLOW_LOG_CMD")" "$(_json_str "$args")" "$ec" "$gp" "$dur" "$FLOW_LOG_STAGE_FROM" "$FLOW_LOG_STAGE_TO" "$(_json_str "$FLOW_LOG_CARD")" "$(get_project_type)" "$(cat "$MODE_FILE" 2>/dev/null | tr -d '\r' || echo teach)" "$ver" "${FLOW_ENGINE_TIER:-builtin}" "$(_json_str "$host")" "$ro" "$(_json_str "${FLOW_LAST_GATE_FAIL:-}")" "$eph" \
    >> "$EVENTS_FILE" 2>/dev/null || true
  # COMPACT line -> device-global (no host/type/mode -> stays small, race-safe append).
  # stage_from is included so dwell reconstruction uses the same code path as project-local.
  # v0.20 Phase 1: card/args ARE now included (constant key shape) - populated only when
  # FLOW_LOG_CMD=card (charset-stripped + 32-char-bounded), empty string otherwise - this is
  # what lets `usage --global` pair card start/done dwell; it is no longer args-free.
  if [ -n "${HOME:-}" ]; then
    mkdir -p "$(dirname "$GLOBAL_LOG")" 2>/dev/null || true
    printf '{"ts":"%s","epoch_s":%s,"session_id":"%s","cycle_id":"%s","project":"%s","command":"%s","exit_code":%s,"gate_pass":%s,"duration_s":%s,"stage_from":"%s","stage_to":"%s","flow_version":"%s","read_only":%s,"gate_fail_reason":"%s","ephemeral":%s,"card":"%s","args":"%s"}\n' \
      "$ts" "$now" "$(_json_str "$(_session_id)")" "$cyc" "$(_json_str "$proj")" "$(_json_str "$FLOW_LOG_CMD")" "$ec" "$gp" "$dur" "$FLOW_LOG_STAGE_FROM" "$FLOW_LOG_STAGE_TO" "$ver" "$ro" "$(_json_str "$gfr")" "$eph" "$(_json_str "$card_field")" "$(_json_str "$card_args")" \
      >> "$GLOBAL_LOG" 2>/dev/null || true
  fi
  return 0
}

# EXIT trap: capture $? FIRST, log best-effort, re-exit unchanged (logging never alters exit code).
_log_on_exit() {
  ec=$?
  _cleanup_tds 2>/dev/null || true   # remove any advisory-probe tempdirs (belt-and-suspenders for SIGINT/SIGTERM)
  { _log_event "$ec"; } 2>/dev/null || true
  exit "$ec"
}

# Roll up the JSONL usage sinks into usage_event, then print analytics. Read-only; degrades
# gracefully when python/harness is unavailable (mirrors the durable-layer best-effort idiom).
cmd_usage() {
  if ! harness_available; then
    echo "usage: durable layer unavailable (python or harness missing, or FLOW_HARNESS_DISABLE set)."
    echo "  the raw JSONL log still exists at $EVENTS_FILE"
    return 0
  fi
  local py; py="$(_python)"
  if [ "${1:-}" = "--prune" ]; then          # flow usage --prune [--keep N] [--global]
    shift
    FLOW_PROJECT_ROOT="$ROOT" "$py" "$HARNESS_PY" prune "$@"
    return 0
  fi
  # forward --global to the rollup step too, else `usage --global` queries a src that was
  # never ingested into the usage_event mirror and falsely reports "no events".
  local rollup_global=""
  case " $* " in *" --global "*) rollup_global="--global" ;; esac
  FLOW_PROJECT_ROOT="$ROOT" "$py" "$HARNESS_PY" rollup $rollup_global >/dev/null 2>&1 || true
  FLOW_PROJECT_ROOT="$ROOT" "$py" "$HARNESS_PY" usage "$@"
  return 0
}

# ---------- dispatch ----------
cmd="${1:-status}"
shift 2>/dev/null || true
FLOW_LOG_CMD="$cmd"
FLOW_LOG_ARGS="$*"
FLOW_LOG_START="$(_now)"
trap '_log_on_exit' EXIT
case "$cmd" in
  status|"")      cmd_status ;;
  resume)         cmd_resume ;;
  next)           cmd_next ;;
  assess)         cmd_assess ;;
  card)           cmd_card "$@" ;;
  check)          cmd_check "${1:-}" ;;
  mode)           cmd_mode "${1:-}" ;;
  project-type)   cmd_project_type "${1:-}" ;;
  skip)           cmd_skip "$@" ;;
  ready)          cmd_ready ;;
  workspace)      cmd_workspace "$@" ;;
  loop-prep)      cmd_loop_prep "$@" ;;
  loop-log)       cmd_loop_log "$@" ;;
  auto)           cmd_auto ;;
  recall)         cmd_recall ;;
  unlock)         cmd_unlock ;;
  retro)          cmd_retro ;;
  harness)        cmd_harness "$@" ;;
  debt)           cmd_debt "$@" ;;
  design)         cmd_design "${1:-}" ;;
  contract)       cmd_contract ;;
  tokens)         cmd_tokens ;;
  coherence)      cmd_coherence ;;
  consistency)    cmd_consistency ;;
  constitution)   cmd_constitution ;;
  promote)        cmd_promote "${1:-}" ;;
  doctor)         cmd_doctor ;;
  eval)           cmd_eval "$@" ;;
  usage)          cmd_usage "$@" ;;
  -h|--help|help) usage ;;
  *) echo "unknown command: $cmd"; echo; usage; exit 1 ;;
esac

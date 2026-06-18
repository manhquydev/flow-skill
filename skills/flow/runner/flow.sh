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
ROOT="${FLOW_PROJECT_ROOT:-$PWD}"
FLOW_DIR="$ROOT/flow"
CARDS_DIR="$ROOT/cards"
MODE_FILE="$ROOT/MODE"
RETRO_FILE="$ROOT/RETRO.md"
DEBT_FILE="$ROOT/DEBT.md"
PROJECT_TYPE_FILE="$ROOT/PROJECT_TYPE"
SKIPPED_FILE="$ROOT/flow/.skipped"
LOCK_FILE="$ROOT/flow/.lock"
HARNESS_PY="$SCRIPT_DIR/../harness/flow_harness.py"

# Usage-log sinks (run-state dir, gitignored). Mechanical flight-recorder: every invocation
# self-records here. Local-only, never transmitted. See flow/05-contract.md (this feature's plan).
LOG_DIR="$ROOT/.flow"
EVENTS_FILE="$LOG_DIR/events.jsonl"                       # per-project FULL event
CYCLE_FILE="$LOG_DIR/cycle_id"                            # stamped when stage 00 unlocks
GLOBAL_LOG="${HOME:-}/.claude/flow/usage.jsonl"           # device-global COMPACT event
# Stage/card carried into the exit event by the commands that know them (set during run).
FLOW_LOG_STAGE_FROM=""; FLOW_LOG_STAGE_TO=""; FLOW_LOG_CARD=""; FLOW_LAST_GATE_FAIL=""

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
  local p
  for p in python3 python; do
    if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys; sys.exit(0 if sys.version_info[0]>=3 else 1)' >/dev/null 2>&1; then
      command -v "$p"; return 0
    fi
  done
  return 0
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

# Identity of THIS invocation. Strong (hard-refusable) via FLOW_SESSION_ID, else a real tty;
# weak (warn-only, never self-block) via host+PPID when neither is available.
flow_lock_owner() {
  # Strip | and newlines from a user-supplied id so it cannot corrupt the pipe-delimited
  # lock line (a mid-field | would mis-split on read-back and break self/foreign matching).
  if [ -n "${FLOW_SESSION_ID:-}" ]; then printf 'sid:%s' "$(printf '%s' "$FLOW_SESSION_ID" | tr -d '\r\n|')"; return; fi
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
  if [ -n "${FLOW_FORCE:-}" ]; then
    if _read_lock && [ -n "$LOCK_OWNER" ] && [ "$LOCK_OWNER" != "$me" ]; then
      echo "NOTE: FLOW_FORCE set - taking over a lock held by [$LOCK_OWNER] (cmd '${LOCK_CMD:-?}')."
    fi
    _write_lock "$1"; return 0
  fi
  if _read_lock; then
    age=$(( $(_now) - LOCK_TS )); [ "$age" -lt 0 ] && age=0
    if [ "$LOCK_OWNER" = "$me" ]; then _write_lock "$1"; return 0; fi          # my own session
    if [ "$age" -ge "$FLOW_LOCK_TTL" ]; then
      echo "NOTE: reclaiming a STALE flow lock from [$LOCK_OWNER] (${age}s old >= ${FLOW_LOCK_TTL}s TTL)."
      _write_lock "$1"; return 0
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
  _write_lock "$1"; return 0                                                   # no lock yet
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

cmd_status() {
  local idx; idx="$(current_stage_idx)"
  echo "flow status"
  echo "  project: $ROOT"
  echo "  mode:    $(cat "$MODE_FILE" 2>/dev/null | tr -d '\r' || echo teach) (default teach)"
  echo "  type:    $(get_project_type) (done = $(done_def_for_type "$(get_project_type)"))"
  lock_warn
  echo
  if [ -f "$FLOW_DIR/00-inspect.md" ]; then
    if scan_gate "$FLOW_DIR/00-inspect.md" >/dev/null 2>&1; then
      echo "brownfield: assessment present, gate clean (flow/00-inspect.md)"
    else
      echo "brownfield: assessment present but gate NOT clean - run '/flow assess'"
    fi
    echo
  fi
  if [ "$idx" -lt 0 ]; then
    echo "planning: not started"
    echo "  -> run '/flow next' to unlock stage 00 (idea)"
  else
    local cur; cur="$(stage_name_at "$idx")"
    echo "planning: at stage $cur"
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
  echo
  local total; total="$(highest_card)"
  if [ "$total" -gt 0 ]; then
    echo "cards: $total created"
    local f st
    for f in "$CARDS_DIR"/C-*.md; do
      [ -e "$f" ] || continue
      st="$(card_status "$f")"
      echo "  $(basename "$f" .md): ${st:-?}"
    done
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

cmd_next() {
  lock_acquire next || return 1
  local idx; idx="$(current_stage_idx)"
  if [ "$idx" -lt 0 ]; then
    mkdir -p "$FLOW_DIR"
    cp "$TEMPLATE_DIR/00-idea.md" "$FLOW_DIR/00-idea.md"
    seed_law_files
    # New build cycle starts here -> stamp a cycle id the usage log groups events under.
    { mkdir -p "$LOG_DIR" && printf '%s-%s\n' "$(_now)" "$(uname -n 2>/dev/null | cut -c1-12 || echo host)" > "$CYCLE_FILE"; } 2>/dev/null || true
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

cmd_card() {
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
      awk '/^## Allowed files/{f=1; next} f && /^## /{f=0} f && NF{print}' "$f" | sed 's/^/      allowed: /'
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
  if [ ! -f "$LOCK_FILE" ]; then echo "no flow lock to clear ($LOCK_FILE)"; return 0; fi
  _read_lock
  rm -f "$LOCK_FILE" 2>/dev/null || true
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
  local td; td="$(mktemp -d)"
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
  local td2 mism; td2="$(mktemp -d)"
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
  # F2: brownfield/assessment mode. Scaffold + gate a current-state map of an EXISTING codebase
  # BEFORE planning. Reuses the stage gate machinery (unchecked boxes / [FILL]). Operator-gated.
  mkdir -p "$FLOW_DIR"
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
  local td; td="$(mktemp -d)"; : > "$td/v"
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
  local td; td="$(mktemp -d)"
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

usage() {
  cat <<'EOF'
flow.sh - buildflow gate runner (mechanical layer)

usage: bash flow.sh <command> [args]

  status            Where am I? What's blocking? (also: no command)
  next              Check current gate; unlock next stage (or start at 00)
  assess            Brownfield: scaffold + gate a current-state assessment (flow/00-inspect.md) before planning
  card              Create the next build card (after planning complete)
  check C-NNN       Validate a card (FILL/status/sections/done-evidence)
  mode [teach|work] Show or set who writes the artifacts
  project-type [t]  Show or set project type (web|cli|library|skill); adapts done-evidence
  skip <stage> --reason  Advance past a gate that has a matching open DEBT (non-security only)
  ready             List buildable todo cards + parallel-safety hint
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
  retro             Print the 3 retro questions

env:
  FLOW_SESSION_ID   stable id per session -> enables HARD refusal of concurrent sessions
  FLOW_LOCK_TTL     seconds a lock stays fresh (default 900); older locks auto-reclaim
  FLOW_FORCE=1      take over a foreign lock (use only if the other session is truly gone)

exit: 0 = pass/advanced, 1 = gate fail / usage error
EOF
}

# ---------- usage log (mechanical capture; best-effort, never fails, exit-code preserving) ----------
# Logging is OFF when FLOW_LOG_DISABLE or the standard DO_NOT_TRACK env is set (hygiene; local-only).
_log_disabled() { [ -n "${FLOW_LOG_DISABLE:-}" ] || [ -n "${DO_NOT_TRACK:-}" ]; }

# JSON string escape: backslash, doublequote, then drop control chars (keeps one line valid).
_json_str() { printf '%s' "${1:-}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\r\n\t'; }

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
    status|recall|ready|usage|tokens|coherence|consistency|contract|constitution|doctor|design|help|-h|--help|"") echo true ;;
    *) echo false ;;
  esac
}

# Build + append one event. $1 = exit code. Wrapped by the caller in { } 2>/dev/null || true.
_log_event() {
  _log_disabled && return 0
  local ec="${1:-0}" now ts dur gp ro ver proj host cyc args
  now="$(_now)"; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo '')"
  dur=$(( now - ${FLOW_LOG_START:-$now} )); [ "$dur" -lt 0 ] && dur=0
  case "$FLOW_LOG_CMD" in next|check) [ "$ec" -eq 0 ] && gp=true || gp=false ;; *) gp=null ;; esac
  ro="$(_log_is_readonly "$FLOW_LOG_CMD")"
  ver="$(_flow_version)"; proj="$(basename "$ROOT" 2>/dev/null || echo '?')"
  host="$(uname -n 2>/dev/null | cut -c1-16 || echo host)"
  cyc="$(cat "$CYCLE_FILE" 2>/dev/null | tr -d '\r\n' || echo '')"
  args="$(_mask_secrets "$FLOW_LOG_ARGS")"
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  # FULL line -> per-project
  printf '{"ts":"%s","epoch_s":%s,"session_id":"%s","cycle_id":"%s","project":"%s","command":"%s","args":"%s","exit_code":%s,"gate_pass":%s,"duration_s":%s,"stage_from":"%s","stage_to":"%s","card":"%s","project_type":"%s","mode":"%s","flow_version":"%s","tier":"%s","host":"%s","read_only":%s,"gate_fail_reason":"%s"}\n' \
    "$ts" "$now" "$(_json_str "${FLOW_SESSION_ID:-}")" "$cyc" "$(_json_str "$proj")" "$(_json_str "$FLOW_LOG_CMD")" "$(_json_str "$args")" "$ec" "$gp" "$dur" "$FLOW_LOG_STAGE_FROM" "$FLOW_LOG_STAGE_TO" "$(_json_str "$FLOW_LOG_CARD")" "$(get_project_type)" "$(cat "$MODE_FILE" 2>/dev/null | tr -d '\r' || echo teach)" "$ver" "${FLOW_ENGINE_TIER:-builtin}" "$(_json_str "$host")" "$ro" "$(_json_str "${FLOW_LAST_GATE_FAIL:-}")" \
    >> "$EVENTS_FILE" 2>/dev/null || true
  # COMPACT line -> device-global (no args/host/stage_from/type/mode -> stays small, <PIPE_BUF, race-safe append)
  if [ -n "${HOME:-}" ]; then
    mkdir -p "$(dirname "$GLOBAL_LOG")" 2>/dev/null || true
    printf '{"ts":"%s","epoch_s":%s,"session_id":"%s","cycle_id":"%s","project":"%s","command":"%s","exit_code":%s,"gate_pass":%s,"duration_s":%s,"stage_to":"%s","flow_version":"%s","read_only":%s}\n' \
      "$ts" "$now" "$(_json_str "${FLOW_SESSION_ID:-}")" "$cyc" "$(_json_str "$proj")" "$(_json_str "$FLOW_LOG_CMD")" "$ec" "$gp" "$dur" "$FLOW_LOG_STAGE_TO" "$ver" "$ro" \
      >> "$GLOBAL_LOG" 2>/dev/null || true
  fi
  return 0
}

# EXIT trap: capture $? FIRST, log best-effort, re-exit unchanged (logging never alters exit code).
_log_on_exit() {
  ec=$?
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
  FLOW_PROJECT_ROOT="$ROOT" "$py" "$HARNESS_PY" rollup >/dev/null 2>&1 || true
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
  next)           cmd_next ;;
  assess)         cmd_assess ;;
  card)           cmd_card ;;
  check)          cmd_check "${1:-}" ;;
  mode)           cmd_mode "${1:-}" ;;
  project-type)   cmd_project_type "${1:-}" ;;
  skip)           cmd_skip "$@" ;;
  ready)          cmd_ready ;;
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
  usage)          cmd_usage "$@" ;;
  -h|--help|help) usage ;;
  *) echo "unknown command: $cmd"; echo; usage; exit 1 ;;
esac

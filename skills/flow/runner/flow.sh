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

_python() { command -v python 2>/dev/null || command -v python3 2>/dev/null || true; }

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
  if [ "$idx" -lt 0 ]; then
    echo "planning: not started"
    echo "  -> run '/flow next' to unlock stage 00 (idea)"
  else
    local cur; cur="$(stage_name_at "$idx")"
    echo "planning: at stage $cur"
    if scan_gate "$FLOW_DIR/$cur.md" >/dev/null 2>&1; then
      if [ "$idx" -ge "$LAST_STAGE_IDX" ]; then
        echo "  gate: PASS - planning complete. '/flow card' is unlocked."
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
    echo "PASS: unlocked stage 00 -> flow/00-idea.md"
    echo "Fill it in, check its gate boxes, then run '/flow next'."
    return 0
  fi
  local cur; cur="$(stage_name_at "$idx")"
  if ! scan_gate "$FLOW_DIR/$cur.md" >/dev/null 2>&1; then
    echo "FAIL: gate for stage $cur is not clean."
    scan_gate "$FLOW_DIR/$cur.md"
    echo
    echo "Fix the above, then run '/flow next' again. (Kill at a gate is also valid.)"
    return 1
  fi
  if [ "$idx" -ge "$LAST_STAGE_IDX" ]; then
    if planning_complete; then
      echo "PASS: stage $cur gate clean. Planning is COMPLETE."
      echo "All planning stages passed (or were debt-skipped). Run '/flow card' to create build cards."
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
    teach|work) printf '%s\n' "$arg" > "$MODE_FILE"; echo "PASS: mode set to '$arg'."; return 0 ;;
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
      printf '%s\n' "$arg" > "$PROJECT_TYPE_FILE"
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

usage() {
  cat <<'EOF'
flow.sh - buildflow gate runner (mechanical layer)

usage: bash flow.sh <command> [args]

  status            Where am I? What's blocking? (also: no command)
  next              Check current gate; unlock next stage (or start at 00)
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
  doctor            Check the environment (bash/python/grep/git) across macOS/Linux/Windows
  retro             Print the 3 retro questions

env:
  FLOW_SESSION_ID   stable id per session -> enables HARD refusal of concurrent sessions
  FLOW_LOCK_TTL     seconds a lock stays fresh (default 900); older locks auto-reclaim
  FLOW_FORCE=1      take over a foreign lock (use only if the other session is truly gone)

exit: 0 = pass/advanced, 1 = gate fail / usage error
EOF
}

# ---------- dispatch ----------
cmd="${1:-status}"
shift 2>/dev/null || true
case "$cmd" in
  status|"")      cmd_status ;;
  next)           cmd_next ;;
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
  doctor)         cmd_doctor ;;
  -h|--help|help) usage ;;
  *) echo "unknown command: $cmd"; echo; usage; exit 1 ;;
esac

#!/usr/bin/env bash
# Regression suite for the v0.20 Phase 3 `flow.sh status` legibility upgrade: NEXT-> line,
# stage-dwell anchored on genuine entry, and >10-card compaction. Run: bash tests/test_flow_status_legibility.sh
# (Git Bash on Windows or any POSIX bash). Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
count_lines() { printf '%s' "$1" | grep -c "$2" || true; }

# Portable timeout: macOS ships neither `timeout` nor `gtimeout` by default (BSD userland, no
# GNU coreutils) - a bare `timeout N cmd...` call exits 127 "command not found" there, which is
# EXACTLY the class of platform gap this section's own regression test exists to guard against.
# Same detect-then-fallback contract as flow.sh's own `_run_with_timeout` (flow.sh:2132).
_portable_timeout() { # $1 = seconds, rest = command
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$secs" "$@"; return $?; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@"; return $?; fi
  "$@" & local pid=$!
  ( sleep "$secs" 2>/dev/null; kill -TERM "$pid" 2>/dev/null ) & local watchdog=$!
  wait "$pid" 2>/dev/null; local rc=$?
  kill "$watchdog" 2>/dev/null; wait "$watchdog" 2>/dev/null
  return "$rc"
}

newsb() { SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards" "$SB/flow"; unset FLOW_LOG_DISABLE; }
clean() { rm -rf "$SB" 2>/dev/null; unset FLOW_PROJECT_ROOT FLOW_SESSION_ID; }
clean_stage() { printf '#%s\n## Gate\n- [x] ok\n\nreal content.\n' "$1" > "$SB/flow/$1.md"; }
mkcard() { # $1 num $2 status
  printf '# C-%03d — card\nstatus: %s\ndeps: none\n## Scope\none thing\n## Allowed files\ninfra/\n## Verify (run these before done)\n- [ ] curl 200\n## Done-evidence (world-state proof)\nurl\n## Evidence (paste actual proof when done)\n%s\n' "$1" "$2" "$([ "$2" = "done" ] && echo "real proof" || echo "(empty until done)")" > "$SB/cards/C-$(printf '%03d' "$1").md"
}

echo "A) NEXT-> is the first content line after the header block, and singular"
newsb
out="$(bash "$RUN" status 2>&1)"; rc=$?
ck 0 "$rc" "status exits 0"
has "$out" "NEXT ->" "NEXT-> line present"
first_content="$(printf '%s\n' "$out" | awk 'BEGIN{h=0} /^$/{h++; next} h>=1{print; exit}')"
has "$first_content" "^NEXT ->" "NEXT-> is the first content line after the header block"
n_next="$(count_lines "$out" '^NEXT ->')"
ck 1 "$n_next" "exactly one NEXT-> line"
clean

echo "B) status and resume never disagree on NEXT for the same state"
newsb
clean_stage 00-idea
out_status="$(bash "$RUN" status 2>&1 | grep '^NEXT ->')"
out_resume="$(bash "$RUN" resume 2>&1 | grep '^NEXT ->')"
ck "$out_status" "$out_resume" "status NEXT-> matches resume NEXT-> (shared _next_action)"
clean

echo "C) anchor strings byte-identical: gate: PASS / gate: BLOCKED / cards: N created / planning: at stage"
newsb
clean_stage 00-idea
out="$(bash "$RUN" status 2>&1)"
has "$out" "planning: at stage 00-idea" "planning anchor line intact"
has "$out" "gate: PASS" "gate: PASS anchor intact"
clean

echo "D) dwell absent without telemetry (no parenthetical appended)"
newsb
clean_stage 00-idea
out="$(FLOW_LOG_DISABLE=1 bash "$RUN" status 2>&1)"
has "$out" "planning: at stage 00-idea" "planning line still present"
no "$out" "planning: at stage 00-idea (for" "no dwell parenthetical when telemetry is disabled"
clean

echo "E) stage dwell anchored on genuine ENTRY, not the latest failed '/flow next' attempt"
newsb
clean_stage 00-idea
# genuine entry into 01-research: stage_from=00-idea, stage_to=01-research
FLOW_SESSION_ID=SA bash "$RUN" status >/dev/null 2>&1
printf '{"ts":"2026-07-10T00:00:00Z","epoch_s":%s,"session_id":"SA","cycle_id":"c1","project":"p","command":"next","args":"","exit_code":0,"gate_pass":true,"duration_s":0,"stage_from":"00-idea","stage_to":"01-research","card":"","project_type":"cli","mode":"work","flow_version":"0.20.0","tier":"builtin","host":"h","read_only":false,"gate_fail_reason":"","ephemeral":false}\n' "$(( $(date +%s) - 3600 ))" >> "$SB/.flow/events.jsonl"
# 3 subsequent FAILED '/flow next' attempts while still on 01-research: these write
# stage_to=01-research too (flow.sh's own failed-next behavior) and must NOT shrink the dwell.
i=1
while [ "$i" -le 3 ]; do
  printf '{"ts":"2026-07-10T00:00:00Z","epoch_s":%s,"session_id":"SA","cycle_id":"c1","project":"p","command":"next","args":"","exit_code":1,"gate_pass":false,"duration_s":0,"stage_from":"01-research","stage_to":"01-research","card":"","project_type":"cli","mode":"work","flow_version":"0.20.0","tier":"builtin","host":"h","read_only":false,"gate_fail_reason":"incomplete","ephemeral":false}\n' "$(( $(date +%s) - (600 * i) ))" >> "$SB/.flow/events.jsonl"
  i=$((i + 1))
done
clean_stage 01-research
out="$(bash "$RUN" status 2>&1)"
has "$out" "planning: at stage 01-research (for 1h)" "dwell anchors at the genuine ~1h-old entry, not the ~10m-old failed-next rows"
clean

echo "F) <=10 cards: full per-card list unchanged (byte-identical beyond the two added lines)"
newsb
clean_stage 00-idea; clean_stage 01-research; clean_stage 02-scope
clean_stage 03-prd; clean_stage 04-adr; clean_stage 05-contract
clean_stage 06-cards
mkcard 1 todo; mkcard 2 done; mkcard 3 todo
out="$(bash "$RUN" status 2>&1)"
has "$out" "cards: 3 created" "full-list form: plain 'cards: N created', no parenthetical summary"
has "$out" "C-001: todo" "full-list form: per-card line for C-001"
has "$out" "C-002: done" "full-list form: per-card line for C-002"
has "$out" "C-003: todo" "full-list form: per-card line for C-003"
clean

echo "G) >10 cards: compact summary with correct X/Y/Z sum, incl. inflight-intersect-todo"
newsb
clean_stage 00-idea; clean_stage 01-research; clean_stage 02-scope
clean_stage 03-prd; clean_stage 04-adr; clean_stage 05-contract
clean_stage 06-cards
i=1
while [ "$i" -le 11 ]; do
  if [ "$i" -le 6 ]; then mkcard "$i" done
  else mkcard "$i" todo
  fi
  i=$((i + 1))
done
# mark one of the todo cards (C-007) in flight via the real registry writer
FLOW_SESSION_ID=SA bash "$RUN" card start C-007 >/dev/null 2>&1
out="$(bash "$RUN" status 2>&1)"
has "$out" "cards: 11 created (6 done" "compact form: total + done count"
has "$out" "1 in flight" "compact form: in-flight count (C-007)"
has "$out" "4 todo" "compact form: remaining todo count (5 todo cards minus the 1 in flight)"
has "$out" "C-007 (in flight" "in-flight card still individually listed"
has "$out" "C-008: todo" "plain todo card still individually listed"
no "$out" "C-001: done" "done cards are summarized away, not individually listed"
has "$out" "+6 more done" "compact form: '+N more done' summary present"
clean

echo "H) status against a genuinely BLOCKED current stage (unfilled FILL template) must return"
echo "   promptly, not hang - code review found the pre-Phase-3 _next_action reason-lookup pipe"
echo "   AND the pipe this phase originally wrapped _gate_state_brief in both hung indefinitely"
echo "   under Git-Bash/MSYS on an early-pipe-reader-exit; timeout-guarded so CI never wedges."
newsb
clean_stage 00-idea; clean_stage 01-research
# leave 02-scope.md as the raw, unfilled FILL template (mirrors a real '/flow next' unlock) -
# this is the genuinely-BLOCKED-current-stage state that was never exercised above (every
# other section's fixtures are gate-clean via clean_stage).
FLOW_SESSION_ID=SA bash "$RUN" next >/dev/null 2>&1   # advances into 02-scope (template, not clean)
out="$(_portable_timeout 20 bash "$RUN" status 2>&1)"; rc=$?
ck 0 "$rc" "status on a BLOCKED current stage returns (not 124=timeout, not a hang)"
has "$out" "NEXT -> fix gate:" "NEXT-> reports the fix-gate action for the blocked stage"
has "$out" "gate: BLOCKED -" "gate state still shown as BLOCKED"
clean

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
exit $?

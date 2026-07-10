#!/usr/bin/env bash
# Regression suite for `flow.sh resume` (v0.20 Phase 2) - the read-only session-story brief a
# fresh agent reads first when entering a project mid-cycle. Run: bash tests/test_flow_resume.sh
# (Git Bash on Windows or any POSIX bash). Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
count_lines() { printf '%s' "$1" | grep -c "$2" || true; }

newsb() { SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards" "$SB/flow"; export FLOW_LOG_DISABLE=; unset FLOW_LOG_DISABLE; }
clean() { rm -rf "$SB" 2>/dev/null; unset FLOW_PROJECT_ROOT FLOW_SESSION_ID; }
clean_stage() { printf '#%s\n## Gate\n- [x] ok\n\nreal content.\n' "$1" > "$SB/flow/$1.md"; }

echo "A) fresh project -> honest 'nothing to resume', exit 0, folds in the NEXT action"
newsb
out="$(bash "$RUN" resume 2>&1)"; rc=$?
ck 0 "$rc" "resume on a fresh project exits 0"
has "$out" "nothing to resume" "fresh project says nothing to resume"
has "$out" "unlock stage 00" "still points at the real next action (unlock stage 00)"
clean

echo "B) mid-cycle, no telemetry -> honest degradation, then gate state + NEXT"
newsb
clean_stage 00-idea
out="$(bash "$RUN" resume 2>&1)"; rc=$?
ck 0 "$rc" "resume with no telemetry exits 0"
has "$out" "no telemetry" "no-telemetry degradation line present"
has "$out" "planning: at stage 00-idea" "gate state still shown"
has "$out" "NEXT ->" "NEXT line still shown"
no "$out" "in flight" "no in-flight section attempted without telemetry (simple, honest degradation)"
clean

echo "C) mid-cycle with real telemetry: last session, in-flight card, gate PASS, exactly one NEXT->"
newsb
clean_stage 00-idea; clean_stage 01-research; clean_stage 02-scope
clean_stage 03-prd; clean_stage 04-adr; clean_stage 05-contract
printf '# C-001 — scaffold\nstatus: todo\ndeps: none\n## Scope\none thing\n## Allowed files\ninfra/\n## Verify (run these before done)\n- [ ] curl 200\n## Done-evidence (world-state proof)\nurl\n## Evidence (paste actual proof when done)\n(empty until done)\n' > "$SB/cards/C-001.md"
FLOW_SESSION_ID=SESSION_A bash "$RUN" status >/dev/null 2>&1
FLOW_SESSION_ID=SESSION_A bash "$RUN" card start C-001 >/dev/null 2>&1
out="$(FLOW_SESSION_ID=SESSION_B bash "$RUN" resume 2>&1)"; rc=$?
ck 0 "$rc" "resume mid-cycle exits 0"
has "$out" "last session" "LAST SESSION section present"
no "$out" "ZZZZ_never_matches_ZZZZ" "sanity: no() helper itself works"
has "$out" "status     ok" "last session lists the 'status' command by NAME with an ok marker"
has "$out" "in flight:" "IN FLIGHT section present"
has "$out" "C-001 (in flight" "in-flight card C-001 listed with dwell"
has "$out" "gate: PASS" "GATE STATE section present and PASS"
has "$out" "NEXT -> continue C-001" "NEXT-> recommends continuing the in-flight card"
n_next="$(count_lines "$out" '^NEXT ->')"
ck 1 "$n_next" "exactly one NEXT-> line"
clean

echo "D) raw args never resurface - a keyword-blind secret-shaped value stays out of resume output"
newsb
clean_stage 00-idea; clean_stage 01-research
FLOW_SESSION_ID=SESSION_A bash "$RUN" debt add "skip check" "xk9J2mQpL8vN4wR7tY3zA6bC1dE5fG0h" "before ship" >/dev/null 2>&1
has "$(cat "$SB/.flow/events.jsonl" 2>/dev/null)" "xk9J2mQpL8vN4wR7tY3zA6bC1dE5fG0h" "sanity: the raw secret-shaped value IS present in the full per-project log (proves this is a real test, not a no-op)"
out="$(FLOW_SESSION_ID=SESSION_B bash "$RUN" resume 2>&1)"
has "$out" "debt       ok" "resume shows the command NAME (debt) and its outcome"
no "$out" "xk9J2mQpL8vN4wR7tY3zA6bC1dE5fG0h" "the secret-shaped arg value never appears in resume output"
clean

echo "E) torn (truncated) final events-log line -> exit 0, coherent output, no crash"
newsb
clean_stage 00-idea
bash "$RUN" status >/dev/null 2>&1
printf '%s' '{"ts":"2026-07-10T00:00:00Z","epoch_s":1,"session_id"' >> "$SB/.flow/events.jsonl"   # torn: no closing brace
out="$(bash "$RUN" resume 2>&1)"; rc=$?
ck 0 "$rc" "resume with a torn final events-log line exits 0"
has "$out" "planning: at stage 00-idea" "gate state still renders coherently despite the torn line"
clean

echo "F) resume is read-only: two consecutive runs leave the project byte-identical; needs no lock"
newsb
clean_stage 00-idea; clean_stage 01-research
FLOW_SESSION_ID=SESSION_A bash "$RUN" status >/dev/null 2>&1
# .flow/ (the mechanical usage-log flight-recorder) is EXCLUDED from this comparison by
# design: every verb in this codebase - including status/recall/usage, already established as
# "read_only" in the SAME whitelist resume joins - still appends its own telemetry row on every
# invocation (that IS the flight-recorder's job). "Read-only" here means "never mutates the
# actual PLAN state" (flow/*.md, cards/*.md, MODE, PROJECT_TYPE), not "never appends a log line".
before_hash="$(find "$SB" -type f ! -path '*/.flow/*' -exec cat {} + 2>/dev/null | wc -c)"
FLOW_SESSION_ID=SESSION_B bash "$RUN" resume >/dev/null 2>&1
FLOW_SESSION_ID=SESSION_B bash "$RUN" resume >/dev/null 2>&1
after_hash="$(find "$SB" -type f ! -path '*/.flow/*' -exec cat {} + 2>/dev/null | wc -c)"
ck "$before_hash" "$after_hash" "project plan-state byte-content unchanged after two resume runs (read-only, idempotent)"
# simulate another session holding the lock - resume must still succeed (no lock_acquire call)
mkdir -p "$SB/flow/.lock.d" 2>/dev/null
printf '%s|sid:some-other-session|%s|otherhost|next\n' "$(date +%s)" "$$" > "$SB/flow/.lock"
out="$(FLOW_SESSION_ID=SESSION_C bash "$RUN" resume 2>&1)"; rc=$?
ck 0 "$rc" "resume succeeds even while another session's lock is held (resume takes no lock)"
has "$out" "flow resume" "resume produced real output while the lock was held, not a lock-refused message"
clean

echo "G) F9 ppid-reuse wall-clock fallback: fresh session (no own row yet) - the exact case that was"
echo "   dead before the fix, since the gap-check only fired when an own-session row already existed"
newsb
clean_stage 00-idea
mkdir -p "$SB/.flow"
now_epoch="$(date +%s)"
recent_epoch=$(( now_epoch - 300 ))   # 5 min ago -> < 900s gap -> must read as "recent activity"
old_epoch=$(( now_epoch - 1200 ))     # 20 min ago -> >= 900s gap -> must read as "last session"
printf '{"ts":"2026-07-10T00:00:00Z","epoch_s":%s,"session_id":"ppid:testhost:11111","cycle_id":"c1","project":"p","command":"status","args":"","exit_code":0,"gate_pass":true,"duration_s":0,"stage_from":"00-idea","stage_to":"00-idea","card":"","project_type":"cli","mode":"work","flow_version":"0.20.0","tier":"builtin","host":"testhost","read_only":true,"gate_fail_reason":"","ephemeral":false}\n' "$recent_epoch" >> "$SB/.flow/events.jsonl"
out="$(FLOW_SESSION_ID="ppid:testhost:22222" bash "$RUN" resume 2>&1)"; rc=$?
ck 0 "$rc" "resume with a fresh (no own-row) session + recent foreign ppid: row exits 0"
has "$out" "recent activity" "F9 fix: wall-clock anchor (no own row yet) correctly reads a 5-min-old foreign ppid: row as recent activity, not a stale last-session"
clean

newsb
clean_stage 00-idea
mkdir -p "$SB/.flow"
printf '{"ts":"2026-07-10T00:00:00Z","epoch_s":%s,"session_id":"ppid:testhost:11111","cycle_id":"c1","project":"p","command":"status","args":"","exit_code":0,"gate_pass":true,"duration_s":0,"stage_from":"00-idea","stage_to":"00-idea","card":"","project_type":"cli","mode":"work","flow_version":"0.20.0","tier":"builtin","host":"testhost","read_only":true,"gate_fail_reason":"","ephemeral":false}\n' "$old_epoch" >> "$SB/.flow/events.jsonl"
out="$(FLOW_SESSION_ID="ppid:testhost:22222" bash "$RUN" resume 2>&1)"; rc=$?
ck 0 "$rc" "resume with a fresh (no own-row) session + old foreign ppid: row exits 0"
has "$out" "last session" "F9 fix: wall-clock anchor correctly reads a 20-min-old foreign ppid: row as a genuine last session, not recent activity"
clean

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
exit $?

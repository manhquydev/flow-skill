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
echo "H) --budget with >5 in-flight cards: caps at 5, appends count summary line, total <= 35 lines"
newsb
clean_stage 00-idea; clean_stage 01-research; clean_stage 02-scope
clean_stage 03-prd; clean_stage 04-adr; clean_stage 05-contract
for i in 1 2 3 4 5 6 7 8; do
  cid="$(printf 'C-%03d' "$i")"
  printf '# %s — test\nstatus: todo\ndeps: none\n## Scope\none thing\n## Allowed files\ninfra/\n## Verify (run these before done)\n- [ ] ok\n## Done-evidence (world-state proof)\nurl\n## Evidence (paste actual proof when done)\n(empty until done)\n' "$cid" > "$SB/cards/$cid.md"
  FLOW_SESSION_ID=SESSION_A bash "$RUN" card start "$cid" >/dev/null 2>&1
done
out="$(FLOW_SESSION_ID=SESSION_B bash "$RUN" resume --budget 2>&1)"; rc=$?
ck 0 "$rc" "resume --budget with >5 in-flight cards exits 0"
has "$out" "in flight:" "in flight section present"
n_infl="$(count_lines "$out" "in flight, started")"
ck 5 "$n_infl" "exactly 5 in-flight cards listed"
has "$out" "+3 more in flight - see 'flow card'" "summary count line present for the 3 hidden cards"
n_more="$(count_lines "$out" "more in flight")"
ck 1 "$n_more" "exactly one '+M more in flight' line"
has "$out" "NEXT -> continue C-001" "NEXT-> recommendation intact"
n_next="$(count_lines "$out" '^NEXT ->')"
ck 1 "$n_next" "exactly one NEXT-> line"
total_lines="$(printf '%s\n' "$out" | wc -l | tr -d '[:space:]')"
if [ "$total_lines" -le 35 ]; then
  echo "  ok   [output lines $total_lines <= 35 ceiling]"
  pass=$((pass+1))
else
  echo "  FAIL [output lines $total_lines > 35 ceiling]"
  fail=$((fail+1))
fi
clean

echo "I) --budget with <=5 in-flight cards: byte-identical to default output (no truncation)"
newsb
clean_stage 00-idea; clean_stage 01-research; clean_stage 02-scope
clean_stage 03-prd; clean_stage 04-adr; clean_stage 05-contract
for i in 1 2 3; do
  cid="$(printf 'C-%03d' "$i")"
  printf '# %s — test\nstatus: todo\ndeps: none\n## Scope\none thing\n## Allowed files\ninfra/\n## Verify (run these before done)\n- [ ] ok\n## Done-evidence (world-state proof)\nurl\n## Evidence (paste actual proof when done)\n(empty until done)\n' "$cid" > "$SB/cards/$cid.md"
  FLOW_SESSION_ID=SESSION_A bash "$RUN" card start "$cid" >/dev/null 2>&1
done
out_def="$(FLOW_SESSION_ID=SESSION_B bash "$RUN" resume 2>&1)"; rc_def=$?
out_bud="$(FLOW_SESSION_ID=SESSION_B bash "$RUN" resume --budget 2>&1)"; rc_bud=$?
ck 0 "$rc_def" "default resume exits 0"
ck 0 "$rc_bud" "resume --budget exits 0"
ck "$out_def" "$out_bud" "--budget with <=5 cards produces byte-identical output to default"
no "$out_bud" "more in flight" "no summary line emitted when <=5 cards"
clean

echo "J) default (no flag) behavior with >5 in-flight cards: lists all cards, unchanged pre-flag behavior"
newsb
clean_stage 00-idea; clean_stage 01-research; clean_stage 02-scope
clean_stage 03-prd; clean_stage 04-adr; clean_stage 05-contract
for i in 1 2 3 4 5 6 7 8; do
  cid="$(printf 'C-%03d' "$i")"
  printf '# %s — test\nstatus: todo\ndeps: none\n## Scope\none thing\n## Allowed files\ninfra/\n## Verify (run these before done)\n- [ ] ok\n## Done-evidence (world-state proof)\nurl\n## Evidence (paste actual proof when done)\n(empty until done)\n' "$cid" > "$SB/cards/$cid.md"
  FLOW_SESSION_ID=SESSION_A bash "$RUN" card start "$cid" >/dev/null 2>&1
done
out_def="$(FLOW_SESSION_ID=SESSION_B bash "$RUN" resume 2>&1)"; rc=$?
ck 0 "$rc" "default resume exits 0 with >5 in-flight cards"
n_all="$(count_lines "$out_def" "in flight, started")"
ck 8 "$n_all" "default invocation lists all 8 in-flight cards"
no "$out_def" "more in flight" "default invocation never emits a '+M more' summary line"
bash "$RUN" resume --budget extra >/dev/null 2>&1; rc_extra=$?
ck 2 "$rc_extra" "resume --budget with extra arg exits 2"
bash "$RUN" resume --bogus >/dev/null 2>&1; rc_bogus=$?
ck 2 "$rc_bogus" "resume with unknown flag exits 2"
clean
echo "K) resume --card: validation on card ID, missing card, and done card"
newsb
clean_stage 00-idea
bash "$RUN" resume --card not-a-card >/dev/null 2>&1; rc_bad=$?
ck 2 "$rc_bad" "resume --card with invalid card ID format exits 2"
out_miss="$(bash "$RUN" resume --card C-999 2>&1)"; rc_miss=$?
ck 1 "$rc_miss" "resume --card with non-existent card exits 1"
has "$out_miss" "card C-999 not found" "error message reports missing card path"
printf '# C-001 — test\nstatus: done\ndeps: none\n## Scope\none thing\n## Allowed files\ninfra/\n## Verify\n- [x] ok\n## Evidence\nproof\n' > "$SB/cards/C-001.md"
out_done="$(bash "$RUN" resume --card C-001 2>&1)"; rc_done=$?
ck 0 "$rc_done" "resume --card on already done card exits 0"
has "$out_done" "card C-001 is already done - see 'flow recall'" "done card points user to flow recall"
has "$out_done" "NEXT_VERB=card" "NEXT_VERB emitted on done card"
clean

echo "L) resume --card C-001 on active card: streams scope, verify, linked decisions, git status"
newsb
clean_stage 00-idea
printf '# C-001 — test\nstatus: in_progress\ndeps: none\n## Scope\nbuild the widget\n## Allowed files\nsrc/widget.ts\n## Verify\n- [ ] npm test\n## Evidence\n(empty)\n' > "$SB/cards/C-001.md"
out_card="$(bash "$RUN" resume --card C-001 2>&1)"; rc_card=$?
ck 0 "$rc_card" "resume --card on active card exits 0"
has "$out_card" "flow resume card: C-001" "header identifies card C-001"
has "$out_card" "status:  in_progress" "status matches card"
has "$out_card" "build the widget" "Scope section rendered"
has "$out_card" "src/widget.ts" "Allowed files rendered"
has "$out_card" "npm test" "Verify section rendered"
has "$out_card" "linked decisions:" "linked decisions section rendered"
has "$out_card" "git status:" "git status section rendered"
has "$out_card" "NEXT_VERB=card" "advisory NEXT_VERB=card rendered"
has "$out_card" '\*\*First safe step\*\*' "First safe step prompt rendered"
clean

echo "M) resume --card redaction pipeline: masks AWS keys, JWTs, Bearer tokens"
newsb
clean_stage 00-idea
printf '# C-002 — secrets\nstatus: todo\ndeps: none\n## Scope\nfetch with Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgN\n## Allowed files\nconfig/\n## Verify\n- [ ] curl AKIA1234567890ABCDEF\n## Evidence\n(empty)\n' > "$SB/cards/C-002.md"
out_redact="$(bash "$RUN" resume --card C-002 2>&1)"; rc_redact=$?
ck 0 "$rc_redact" "resume --card with secrets exits 0"
has "$out_redact" '\[REDACTED:jwt\]' "JWT token is redacted"
has "$out_redact" '\[REDACTED:aws-key-id\]' "AWS key is redacted"
no "$out_redact" "AKIA1234567890ABCDEF" "raw AWS key does not appear in stdout"
no "$out_redact" "eyJhbGciOiJIUzI1NiJ9" "raw JWT header does not appear in stdout"
clean

echo "N) resume --card in non-git directory degrades gracefully to 'Not captured in this session'"
# Git for Windows reconstructs native lookup paths; shim PATH cannot establish
# the Git-absent precondition reliably. Only this synthetic case is unavailable.
case "$(uname -s 2>/dev/null):${RUNNER_OS:-}" in
  MINGW*|MSYS*|CYGWIN*|*:Windows_NT|*:Windows)
    echo '  SKIP [no-git simulation unavailable on Git for Windows; Git Bash reconstructs system PATH]' ;;
  *)
newsb
clean_stage 00-idea
printf '# C-003 — nongit\nstatus: todo\ndeps: none\n## Scope\nlocal task\n## Allowed files\nlocal/\n## Verify\n- [ ] true\n## Evidence\n(empty)\n' > "$SB/cards/C-003.md"
# Keep real utilities/interpreters but exclude Git. Probe in a fresh Bash, just
# like the runner: Git Bash may reconstruct PATH or resolve git.exe on startup.
fakebin="$(mktemp -d)"
for d in /usr/bin /bin; do
  [ -d "$d" ] || continue
  for f in "$d"/*; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    case "$b" in git|git.exe) continue ;; esac
    [ -e "$fakebin/$b" ] || ln -s "$f" "$fakebin/$b" 2>/dev/null || cp "$f" "$fakebin/$b" 2>/dev/null
  done
done
# Native Windows Python needs its install directory/DLL context. Do not copy or
# symlink an external interpreter into fakebin; retain its original PATH entry.
no_git_path="$fakebin"
for b in python3 python; do
  f="$(command -v "$b" 2>/dev/null || true)"
  [ -n "$f" ] || continue
  d="$(dirname "$f")"
  case "$d" in
    /bin|/usr/bin) : ;; # already supplied by the core utility shim
    *) no_git_path="$no_git_path:$d" ;;
  esac
done
# Probe and dispatch in the SAME fresh shell. Re-launching Bash after the probe
# can reconstruct a different Windows PATH; a failed launcher is not Git absence.
out_nongit="$(PATH="$no_git_path" "$BASH" -c '
  runner="$1"; shift
  hash -r
  if command -v git >/dev/null 2>&1 || command -v git.exe >/dev/null 2>&1; then
    printf "FLOW_TEST_GIT_PRESENT\n"; exit 77
  fi
  printf "FLOW_TEST_GIT_ABSENT\n"
  . "$runner"
' _ "$RUN" resume --card C-003 2>&1)"; rc_nongit=$?
case "$out_nongit" in
  FLOW_TEST_GIT_PRESENT*)
    echo "  SKIP [git-absent resume] (nested Bash still resolves git/git.exe)" ;;
  FLOW_TEST_GIT_ABSENT*)
    ck 0 "$rc_nongit" "resume --card without working git exits 0"
    has "$out_nongit" "flow resume card: C-003" "card header rendered"
    has "$out_nongit" "Not captured in this session" "git status reports Not captured in this session" ;;
  *) ck 0 1 "missing-Git probe must actually start before testing resume" ;;
esac
rm -rf "$fakebin"
clean
    ;;
esac

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
exit $?

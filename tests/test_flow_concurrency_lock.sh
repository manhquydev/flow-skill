#!/usr/bin/env bash
# Regression suite for the flow.sh concurrency lock (prevents two sessions stomping one project).
# Run: bash tests/test_flow_concurrency_lock.sh   (Git Bash on Windows or any POSIX bash)
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
exists() { [ -f "$1" ] && echo 0 || echo 1; }

newsb()     { SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow"; }
write_lock() { # $1 owner  $2 seconds-ago  $3 cmd-label
  printf '%s|%s|111|testhost|%s\n' "$(( $(date +%s) - ${2:-0} ))" "$1" "${3:-next}" > "$SB/flow/.lock"
}

echo "A) no lock -> next acquires + writes flow/.lock"
newsb
out="$(FLOW_SESSION_ID=A bash "$RUN" next 2>&1)"; rc=$?
ck 0 "$rc" "first next succeeds with no pre-existing lock"
ck 0 "$(exists "$SB/flow/.lock")" "flow/.lock created"
has "$(cat "$SB/flow/.lock" 2>/dev/null)" "sid:A" "lock records this session's owner"
rm -rf "$SB"

echo "B) fresh foreign STRONG lock -> next AND card refused (exit 1)"
newsb; write_lock "sid:OTHER" 5 next
out="$(FLOW_SESSION_ID=ME bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" "next refused on fresh foreign strong lock"
has "$out" "BLOCKED" "refusal prints BLOCKED"
out="$(FLOW_SESSION_ID=ME bash "$RUN" card 2>&1)"; rc=$?
ck 1 "$rc" "card refused on fresh foreign strong lock"
has "$out" "another flow session is active" "card refusal message"
rm -rf "$SB"

echo "C) SAME session (matching id) -> not blocked"
newsb; write_lock "sid:SAME" 5 next
out="$(FLOW_SESSION_ID=SAME bash "$RUN" next 2>&1)"; rc=$?
ck 0 "$rc" "same-session next proceeds"
no "$out" "BLOCKED" "no BLOCKED for same session"
rm -rf "$SB"

echo "D) STALE foreign lock (age >= TTL) -> reclaimed"
newsb; write_lock "sid:OLD" 50 next
out="$(FLOW_LOCK_TTL=1 FLOW_SESSION_ID=ME bash "$RUN" next 2>&1)"; rc=$?
ck 0 "$rc" "stale lock reclaimed, next proceeds"
has "$out" "reclaiming a STALE" "stale-reclaim note printed"
rm -rf "$SB"

echo "E) FLOW_FORCE=1 -> takes over a fresh foreign lock"
newsb; write_lock "sid:OTHER" 5 next
out="$(FLOW_FORCE=1 FLOW_SESSION_ID=ME bash "$RUN" next 2>&1)"; rc=$?
ck 0 "$rc" "force takes over and proceeds"
has "$out" "taking over" "force-takeover note printed"
rm -rf "$SB"

echo "F) status WARNS on fresh foreign lock but never blocks"
newsb; write_lock "sid:OTHER" 5 next
out="$(FLOW_SESSION_ID=ME bash "$RUN" status 2>&1)"; rc=$?
ck 0 "$rc" "status exit 0 (read-only)"
has "$out" "WARNING" "status warns about the foreign lock"
rm -rf "$SB"

echo "G) WEAK identity (no FLOW_SESSION_ID, no tty) -> warn, never self-block"
newsb; write_lock "ppid:otherhost:99999" 5 next
out="$(bash "$RUN" next < /dev/null 2>&1)"; rc=$?
ck 0 "$rc" "weak-identity next proceeds (no self-block)"
no "$out" "BLOCKED" "weak identity never hard-refuses"
rm -rf "$SB"

echo "H) unlock clears the lock"
newsb; write_lock "sid:OTHER" 5 next
out="$(bash "$RUN" unlock 2>&1)"; rc=$?
ck 0 "$rc" "unlock exit 0"
ck 1 "$(exists "$SB/flow/.lock")" "lock file removed"
rm -rf "$SB"

echo "I) fresh foreign STRONG lock also refuses skip and auto"
newsb; write_lock "sid:OTHER" 5 next
out="$(FLOW_SESSION_ID=ME bash "$RUN" skip 01-research --reason whatever 2>&1)"; rc=$?
ck 1 "$rc" "skip refused on fresh foreign strong lock"
has "$out" "BLOCKED" "skip refusal prints BLOCKED"
out="$(FLOW_SESSION_ID=ME bash "$RUN" auto 2>&1)"; rc=$?
ck 1 "$rc" "auto refused on fresh foreign strong lock"
rm -rf "$SB"

echo "J) garbage/unparseable lock file -> reclaimed as stale, no crash"
newsb; printf 'totally-garbage-no-delimiters\n' > "$SB/flow/.lock"
out="$(FLOW_SESSION_ID=ME bash "$RUN" next 2>&1)"; rc=$?
ck 0 "$rc" "garbage lock does not crash; next proceeds (ts->0 => stale reclaim)"
rm -rf "$SB"

echo "K) pipe in FLOW_SESSION_ID is sanitized (no lock-line corruption, no self-block)"
newsb
FLOW_SESSION_ID='a|b|c' bash "$RUN" next >/dev/null 2>&1   # creates lock + 00-idea template
has "$(cat "$SB/flow/.lock" 2>/dev/null)" "sid:abc" "pipe stripped from owner written to lock line"
printf '#00\n## Gate\n- [x] ok\n\nreal content.\n' > "$SB/flow/00-idea.md"   # clean gate so 'next' would advance if the lock allows
out="$(FLOW_SESSION_ID='a|b|c' bash "$RUN" next 2>&1)"; rc=$?
ck 0 "$rc" "same pipe-id session proceeds (lock allows; not self-blocked)"
no "$out" "BLOCKED" "no BLOCKED for same pipe-id session"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

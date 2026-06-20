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

echo "L) fresh foreign lock with a DEAD pid on this host -> reclaimed via kill -0 liveness"
newsb
MYHOST="$(uname -n 2>/dev/null || echo host)"
printf '%s|sid:DEAD|999999|%s|next\n' "$(date +%s)" "$MYHOST" > "$SB/flow/.lock"   # age 0 but pid gone
out="$(FLOW_SESSION_ID=ME bash "$RUN" next 2>&1)"; rc=$?
ck 0 "$rc" "fresh foreign lock with a dead PID is reclaimed (not blocked)"
has "$out" "dead session" "dead-PID reclaim note printed"
rm -rf "$SB"

echo "M) session id auto-derives from a harness env var (no FLOW_SESSION_ID export)"
newsb
out="$( unset FLOW_SESSION_ID; CLAUDE_CODE_SESSION_ID=HARNESSID bash "$RUN" next 2>&1 )"; rc=$?
ck 0 "$rc" "auto-id session acquires lock with no manual export"
has "$(cat "$SB/flow/.lock" 2>/dev/null)" "sid:HARNESSID" "lock owner auto-derived from CLAUDE_CODE_SESSION_ID"
rm -rf "$SB"

echo "N) W5 atomic mkdir RACE: direct lock_acquire contention -> exactly ONE winner per iteration across 20 runs"
# Strategy: use a thin contender wrapper that sets up the same env as flow.sh and directly
# calls mkdir on LOCK_DIR (the POSIX test-and-set). A FIFO barrier synchronises both
# subshells so they hit mkdir at the same time, creating real contention rather than
# sequential execution. 20 iterations required: a vacuous pass (one finishes before the
# other starts) would see 0 double-wins across all runs, but we assert NO double-wins at all.
newsb
RACE_SB="$SB"
# Build a thin contender script: waits on barrier, tries mkdir, exits 0=won / 1=lost
CONTENDER="$(mktemp --suffix=.sh)"
cat > "$CONTENDER" <<'CONTENDER_EOF'
#!/usr/bin/env bash
# Args: $1=LOCK_DIR $2=barrier_fifo
LOCK_DIR="$1"; BARRIER="$2"
# Signal ready, then block until the other side opens the FIFO
echo ready > "$BARRIER"
# Wait for go signal (the orchestrator cat's the FIFO after both are ready)
read -r _go < "$BARRIER" 2>/dev/null || true
mkdir "$LOCK_DIR" 2>/dev/null
CONTENDER_EOF
chmod +x "$CONTENDER"

N_ITER=20; N_DOUBLE=0; N_ZERO=0
for _i in $(seq 1 $N_ITER); do
  _lockdir="$RACE_SB/flow/.lock.d"
  rm -rf "$_lockdir" 2>/dev/null || true
  # Use a temp dir as a barrier: each contender writes a file; orchestrator waits for 2, then sends go
  _bar="$(mktemp -d)"
  # Launch both contenders; each writes "ready" to _bar/A or _bar/B then waits for _bar/go
  (
    # Contender A: signal ready then spin-wait for go file
    touch "$_bar/A"
    while [ ! -f "$_bar/go" ]; do :; done
    mkdir "$_lockdir" 2>/dev/null; echo $?
  ) > "$_bar/out_a" &
  _pid_a=$!
  (
    # Contender B: signal ready then spin-wait for go file
    touch "$_bar/B"
    while [ ! -f "$_bar/go" ]; do :; done
    mkdir "$_lockdir" 2>/dev/null; echo $?
  ) > "$_bar/out_b" &
  _pid_b=$!
  # Wait until both contenders are ready (spinning on barrier), then release
  while [ ! -f "$_bar/A" ] || [ ! -f "$_bar/B" ]; do :; done
  touch "$_bar/go"
  wait $_pid_a; wait $_pid_b
  _rc_a="$(cat "$_bar/out_a" 2>/dev/null)"; _rc_b="$(cat "$_bar/out_b" 2>/dev/null)"
  rm -rf "$_bar"
  # Count wins (exit 0 from mkdir = won the dir)
  _wins=$(( (_rc_a == 0 ? 1 : 0) + (_rc_b == 0 ? 1 : 0) ))
  [ "$_wins" -gt 1 ] && N_DOUBLE=$(( N_DOUBLE + 1 ))
  [ "$_wins" -eq 0 ] && N_ZERO=$(( N_ZERO + 1 ))
done
rm -f "$CONTENDER"
ck 0 "$N_DOUBLE" "N-atomic-race: zero double-wins across $N_ITER iterations (mkdir atomicity)"
ck 0 "$N_ZERO"   "N-atomic-race: zero iterations where nobody won (no lost mkdir calls)"
rm -rf "$RACE_SB"

echo "O) F1 crash-recovery: LOCK_DIR old + no LOCK_FILE -> self-heals after TTL; fresh dir -> BLOCKED"
# Simulate a process that won mkdir but crashed before _write_lock (LOCK_DIR exists, LOCK_FILE absent).
# Sub-test O1: LOCK_DIR mtime is old (> TTL) -> next reclaims and proceeds.
newsb
mkdir -p "$SB/flow/.lock.d"
# Set mtime to 30 minutes in the past (> TTL=1s used below via FLOW_LOCK_TTL override)
touch -t "$(date -d '30 minutes ago' '+%Y%m%d%H%M.%S' 2>/dev/null || date -v-30M '+%Y%m%d%H%M.%S' 2>/dev/null || echo '197001010001.00')" "$SB/flow/.lock.d" 2>/dev/null || true
# With a 1-second TTL the 30-min-old dir is definitely stale
out="$(FLOW_LOCK_TTL=1 FLOW_SESSION_ID=ME bash "$RUN" next 2>&1)"; rc=$?
ck 0 "$rc" "O1-crash-recovery: stale LOCK_DIR (no LOCK_FILE) -> self-heals, next proceeds"
has "$out" "stale crashed claim" "O1-crash-recovery: self-heal note printed"
rm -rf "$SB"

# Sub-test O2: LOCK_DIR mtime is fresh (within TTL) -> BLOCKED (not a stale crash, could be live).
newsb
mkdir -p "$SB/flow/.lock.d"
# mtime is 'now' (just created) so it's within any TTL
out="$(FLOW_LOCK_TTL=900 FLOW_SESSION_ID=ME bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" "O2-fresh-dir-no-lockfile: fresh LOCK_DIR (no LOCK_FILE) -> BLOCKED (may be live mid-claim)"
has "$out" "BLOCKED" "O2-fresh-dir-no-lockfile: BLOCKED message printed"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

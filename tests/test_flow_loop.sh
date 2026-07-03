#!/usr/bin/env bash
# Regression suite for the ck-loop thin-wrapper verbs (flow.sh loop-prep / loop-log).
# These are PLUMBING ONLY - no iteration logic lives in flow.sh; ck-loop (the installed
# ClaudeKit skill) stays the untouched execution engine. Run: bash tests/test_flow_loop.sh
# (Git Bash on Windows or any POSIX bash). Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

# A real git repo with one commit (worktree add needs a HEAD) + a minimal card + two throwaway
# test suites (one always-green, one always-red) so the Verify aggregator has real RESULT lines
# to sum, mirroring the repo's own tests/test_*.sh convention.
newsb() {
  SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; export FLOW_SESSION_ID=LOOP
  git -C "$SB" init -q
  git -C "$SB" config user.email t@t; git -C "$SB" config user.name t
  mkdir -p "$SB/cards" "$SB/tests" "$SB/flow"
  printf 'status: todo\n## Allowed files\n- tests/\n' > "$SB/cards/C-001.md"
  printf '#!/usr/bin/env bash\necho "RESULT: 2 passed, 0 failed"\nexit 0\n' > "$SB/tests/test_flow_green.sh"
  printf '#!/usr/bin/env bash\necho "RESULT: 1 passed, 1 failed"\nexit 1\n' > "$SB/tests/test_flow_red.sh"
  chmod +x "$SB/tests/"*.sh
  git -C "$SB" add -A; git -C "$SB" commit -q -m init
}
clean() { # remove the sandbox AND any sibling worktrees it spawned
  local base; base="$(dirname "$SB")/$(basename "$SB")"
  local d; for d in "$base"-*; do [ -d "$d" ] && rm -rf "$d" 2>/dev/null; done
  rm -rf "$SB" 2>/dev/null
}

echo "A) loop-prep on a clean fresh worktree emits cd + Goal/Scope/Verify block"
newsb
out="$(bash "$RUN" loop-prep C-001 2>&1)"; rc=$?
ck 0 "$rc" "loop-prep exit 0 on clean worktree"
has "$out" "PASS: loop-prep ready" "prints PASS summary"
has "$out" "cd \"" "prints cd line"
has "$out" "^Goal:" "prints Goal field" || has "$out" "Goal:" "prints Goal field (fallback grep)"
has "$out" "Scope: tests/" "prints Scope field derived from the card's own Allowed files"
has "$out" "Verify:" "prints Verify field"
has "$out" "Iterations: 10" "default Iterations is 10"
has "$out" "Direction: lower" "Direction is lower for a failing-count metric"
no  "$out" "^Guard:" "no Guard line without --guard flag"
clean

echo "I) Scope is derived from the card's REAL Allowed files, NOT hardcoded to test files (red-team regression)"
newsb
printf 'status: todo\n## Allowed files\n- src/foo.js\n- src/bar.js\n' > "$SB/cards/C-001.md"
mkdir -p "$SB/src"; printf 'x' > "$SB/src/foo.js"; printf 'y' > "$SB/src/bar.js"
git -C "$SB" add -A; git -C "$SB" commit -q -m "add src files"
out="$(bash "$RUN" loop-prep C-001 2>&1)"; rc=$?
ck 0 "$rc" "loop-prep exit 0 with real src Scope"
has "$out" "^Scope:.*src/foo\.js" "Scope lists src/foo.js from the card's own Allowed files"
has "$out" "^Scope:.*src/bar\.js" "Scope lists src/bar.js from the card's own Allowed files"
no  "$out" "Scope: tests/test_\*.sh" "Scope is NOT hardcoded to the Verify target's test files"
clean

echo "J) a card declaring NO Allowed files falls back to tests/test_*.sh (last-resort, documented)"
newsb
printf 'status: todo\n' > "$SB/cards/C-001.md"
git -C "$SB" add -A; git -C "$SB" commit -q -m "card with no allowed files"
out="$(bash "$RUN" loop-prep C-001 2>&1)"; rc=$?
ck 0 "$rc" "loop-prep exit 0 with no declared Allowed files"
has "$out" "Scope: tests/test_\*.sh" "falls back to tests/test_*.sh when card declares nothing"
clean

echo "K) --iterations validated: non-numeric/zero/negative rejected before any git action"
newsb
out="$(bash "$RUN" loop-prep C-001 --iterations 0 2>&1)"; rc=$?
ck 1 "$rc" "--iterations 0 exits 1"
has "$out" "positive integer" "names the iterations-validation condition"
out2="$(bash "$RUN" loop-prep C-001 --iterations abc 2>&1)"; rc2=$?
ck 1 "$rc2" "--iterations abc exits 1"
clean

echo "L) Verify dry-run timeout aborts a hanging suite instead of blocking forever"
newsb
printf '#!/usr/bin/env bash\nsleep 5\necho "RESULT: 0 passed, 0 failed"\nexit 0\n' > "$SB/tests/test_flow_slow.sh"
chmod +x "$SB/tests/test_flow_slow.sh"
git -C "$SB" add -A; git -C "$SB" commit -q -m "add a slow suite"
out="$(FLOW_LOOP_VERIFY_TIMEOUT=1 bash "$RUN" loop-prep C-001 2>&1)"; rc=$?
ck 1 "$rc" "hanging Verify dry-run exits 1, not left running"
has "$out" "ABORT:.*timed out at 1s" "names the timeout condition with the configured cap"
clean

echo "M) an existing loop/* branch with no live worktree is reused with a WARNING, not silently"
newsb
git -C "$SB" branch "loop/C-001"
out="$(bash "$RUN" loop-prep C-001 2>&1)"; rc=$?
ck 0 "$rc" "loop-prep exit 0 reusing a pre-existing branch"
has "$out" "WARNING:.*already exists" "warns before checking out a pre-existing loop/* branch"
clean

echo "N) loop-log rejects an unknown card BEFORE writing to the usage-log (closes the card-id masking bypass)"
newsb
out="$(bash "$RUN" loop-log C-999 --iterations 1 --start 1 --end 0 --outcome converged 2>&1)"; rc=$?
ck 1 "$rc" "loop-log on unknown card exits 1"
has "$out" "not found" "names the missing-card condition"
evt="$(cat "$SB/.flow/events.jsonl" 2>/dev/null | grep '"command":"loop-log"' | grep '"card":"C-999"')"
ck "" "$evt" "unknown/unvalidated card-id string never reaches the usage-log card field"
clean

echo "B) --guard adds a Guard line pointing at run_all.sh-style regression check"
newsb
out="$(bash "$RUN" loop-prep C-001 --guard 2>&1)"; rc=$?
ck 0 "$rc" "loop-prep --guard exit 0"
has "$out" "^Guard:" "Guard line present with --guard"
clean

echo "C) Verify dry-run aggregates RESULT lines into one integer (1 failing suite -> count 1)"
newsb
out="$(bash "$RUN" loop-prep C-001 2>&1)"
has "$out" "failing-assertion count: 1" "aggregator sums the red suite's 1 failure (green suite contributes 0)"
clean

echo "D) dirty worktree aborts with a named reason, does not print a param block"
newsb
bash "$RUN" loop-prep C-001 >/dev/null 2>&1   # create the worktree once
wt="$(dirname "$SB")/$(basename "$SB")-loop-C-001"
echo "dirty" > "$wt/dirty.txt"
out="$(bash "$RUN" loop-prep C-001 2>&1)"; rc=$?
ck 1 "$rc" "dirty tree exit 1"
has "$out" "ABORT:.*uncommitted changes" "names the dirty-tree condition"
no  "$out" "^Verify:" "does not emit a param block on abort"
clean

echo "E) unknown card aborts before touching git"
newsb
out="$(bash "$RUN" loop-prep C-999 2>&1)"; rc=$?
ck 1 "$rc" "unknown card exit 1"
has "$out" "not found" "names the missing-card condition"
clean

echo "F) loop-log outcome maps to distinct exit codes (converged=0, circuit-broke=1, no-improve=2)"
newsb
out="$(bash "$RUN" loop-log C-001 --iterations 4 --start 12 --end 0 --outcome converged 2>&1)"; rc=$?
ck 0 "$rc" "converged exits 0"
has "$out" "LOOP C-001: 12->0 in 4 iters (converged)" "prints one-line summary"
rc2=0; bash "$RUN" loop-log C-001 --iterations 10 --start 5 --end 3 --outcome circuit-broke >/dev/null 2>&1 || rc2=$?
ck 1 "$rc2" "circuit-broke exits 1"
rc3=0; bash "$RUN" loop-log C-001 --iterations 10 --start 5 --end 5 --outcome no-improve >/dev/null 2>&1 || rc3=$?
ck 2 "$rc3" "no-improve exits 2"
rc4=0; bash "$RUN" loop-log C-001 --iterations 1 --start 1 --end 0 --outcome bogus >/dev/null 2>&1 || rc4=$?
ck 1 "$rc4" "unknown outcome exits 1 (usage error)"
clean

echo "G) loop-log rejects non-integer args before recording"
newsb
out="$(bash "$RUN" loop-log C-001 --iterations x --start 1 --end 0 --outcome converged 2>&1)"; rc=$?
ck 1 "$rc" "non-integer --iterations exits 1"
has "$out" "usage:" "prints usage on bad input"
clean

echo "H) loop-log is captured by the usage-log EXIT trap as a non-read-only build event"
newsb
FLOW_SESSION_ID=LOOP bash "$RUN" loop-log C-001 --iterations 4 --start 12 --end 0 --outcome converged >/dev/null 2>&1
evt="$(cat "$SB/.flow/events.jsonl" 2>/dev/null | grep '"command":"loop-log"')"
has "$evt" '"command":"loop-log"' "raw event captured with command=loop-log"
has "$evt" '"read_only":false' "loop-log recorded as a build event, not read-only"
has "$evt" '"card":"C-001"' "card id attached to the loop-log event"
# The python harness rollup->`flow usage` summary itself has a pre-existing Windows path-separator
# quirk in THIS dev sandbox unrelated to loop-log (reproduced identically for the existing
# 'status' command) - asserting against the raw JSONL (above) is the reliable signal.
clean

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

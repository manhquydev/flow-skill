#!/usr/bin/env bash
# macos-timeout-watchdog-diag.sh — bounded diagnosis of the _run_with_timeout fallback.
#
# OPERATOR CHECKPOINT (Phase 6): run this as a macos-latest CI step on a PR whose
# base is master (this branch's pushes do not run GHA). Mask PATH first so a
# keg-only coreutils gtimeout cannot silently take the GNU-timeout lane.
# Bound: 2 iterations max. Do not treat a green Linux run as evidence.
#
# What it measures: spawn a mock-slow child (sleep), fire kill -TERM, assert
# return latency. Distinguishes "kill did not reach the child" vs "wait did not
# unblock" without modifying _run_with_timeout.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "diag: host=$(uname -s 2>/dev/null) root=$ROOT"

# Mask PATH: keep a tiny allowlist, never timeout/gtimeout.
shim="$(mktemp -d)"
cleanup() { rm -rf "$shim"; }
trap cleanup EXIT
for t in bash sh sleep kill wait mktemp date uname printf echo ls cat; do
  p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$shim/$t" || true
done
export PATH="$shim"
if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
  echo "FAIL: timeout/gtimeout still on PATH after mask — abort (would not exercise the DEBT lane)"
  exit 2
fi
echo "OK: PATH masked; no timeout/gtimeout"

# Reproduce the fallback shape from flow.sh comments: sh -c child + watchdog kill.
# Child sleeps 20s; watchdog fires at 2s. Bound return should be ~2s, not ~20s.
child_log="$(mktemp)"
t0=$(date +%s)
sh -c "sleep 20; echo CHILD_FINISHED > '$child_log'" &
pid=$!
(
  sleep 2
  if kill -TERM "$pid" 2>/dev/null; then
    echo "diag: kill -TERM reached pid=$pid"
  else
    echo "diag: kill -TERM missed pid=$pid (already gone or not reachable)"
  fi
) &
watchdog=$!
wait "$pid" 2>/dev/null
wait_rc=$?
t1=$(date +%s)
elapsed=$((t1 - t0))
kill "$watchdog" 2>/dev/null
wait "$watchdog" 2>/dev/null || true

echo "diag: wait_rc=$wait_rc elapsed=${elapsed}s child_log=$(cat "$child_log" 2>/dev/null || echo EMPTY)"
rm -f "$child_log"

# Confirm: bounded if we returned well under the 20s sleep.
if [ "$elapsed" -le 5 ]; then
  echo "RESULT: kill appeared to bound the child (elapsed=${elapsed}s <= 5). Mechanism still needs a second iteration if wait_rc is unexpected."
  echo "wait_rc=$wait_rc (143=SIGTERM typical; 0=child exited clean — suspicious if CHILD_FINISHED)"
  exit 0
fi
echo "RESULT: child was NOT bounded (elapsed=${elapsed}s). Hypothesis: kill -TERM did not reach the sh -c child, or wait did not unblock."
exit 1

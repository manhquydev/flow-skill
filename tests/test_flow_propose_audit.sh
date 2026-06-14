#!/usr/bin/env bash
# Regression suite for the harness self-improvement loop (Option B):
# audit (entropy/drift), propose (deterministic friction/intervention -> backlog), decision outcome.
# Run: bash tests/test_flow_propose_audit.sh   (needs python; skips cleanly without it)
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HARNESS="$HERE/../skills/flow/harness/flow_harness.py"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

py="$(command -v python || command -v python3 || true)"
if [ -z "$py" ] || ! "$py" --version >/dev/null 2>&1; then
  echo "SKIP: no python -> durable layer unavailable"; echo "RESULT: 0 passed, 0 failed"; exit 0
fi
H() { FLOW_PROJECT_ROOT="$SB" "$py" "$HARNESS" "$@"; }
newsb() { SB="$(mktemp -d)"; }

echo "A) compile + audit on empty db = clean, entropy 0"
"$py" -m py_compile "$HARNESS"; ck 0 $? "flow_harness.py compiles"
newsb
out="$(H audit)"; ck 0 $? "audit exit 0"
has "$out" "entropy score 0" "empty db scores 0"
has "$out" "clean" "no drift findings on empty db"
rm -rf "$SB"

echo "B) propose groups repeated friction (>=2, normalized) and --commit writes backlog"
newsb
H trace --summary t1 --friction "scan-time registry fetch is non-deterministic" --lane tiny >/dev/null
H trace --summary t2 --friction "Scan-time registry fetch is non-deterministic!" --lane tiny >/dev/null
out="$(H propose)"
has "$out" "Reduce repeated friction" "groups 2 normalized-identical frictions"
no  "$out" "backlog #" "dry-run does NOT commit"
out="$(H propose --commit)"; has "$out" "backlog #" "--commit writes a backlog row"
out="$(H query backlog --open)"; has "$out" "Reduce repeated friction" "committed proposal is in open backlog"
rm -rf "$SB"

echo "C) single friction (count 1) does NOT propose (noise filter)"
newsb
H trace --summary t1 --friction "a genuine one-off glitch never seen again" --lane tiny >/dev/null
out="$(H propose)"; no "$out" "Reduce repeated friction" "count<2 friction is not proposed"
rm -rf "$SB"

echo "D) audit detects drift (orphaned story) with entropy weight"
newsb
H story add --id S-1 --title orphan --lane normal >/dev/null
H story update --id S-1 --status planned >/dev/null
out="$(H audit)"
has "$out" "orphaned" "orphaned story detected"
has "$out" "entropy score 10" "orphaned story weighted 10"
rm -rf "$SB"

echo "E) repeated interventions are proposed"
newsb
H intervention --type correction --description "fixed VITE_API_BASE prefix" --source human >/dev/null
H intervention --type correction --description "Fixed VITE_API_BASE prefix." --source reviewer >/dev/null
out="$(H propose)"; has "$out" "Address repeated intervention" "groups repeated interventions"
rm -rf "$SB"

echo "F) decision predicted-vs-actual loop: outcome write + query"
newsb
H decision add --id d-1 --title "use sqlite" --predicted "low risk" >/dev/null
out="$(H query decisions)"; has "$out" "actual: -" "actual is empty before close"
H decision outcome --id d-1 --actual "shipped clean across 5 runs" --status accepted >/dev/null
out="$(H query decisions)"; has "$out" "shipped clean" "actual recorded after outcome"
rm -rf "$SB"

echo "G) flow.sh wiring: recall shows audit health; retro surfaces propose"
newsb; mkdir -p "$SB/flow"
H trace --summary t1 --friction "same friction here now ok" --lane tiny >/dev/null
H trace --summary t2 --friction "Same friction here now, ok!" --lane tiny >/dev/null
out="$(FLOW_PROJECT_ROOT="$SB" bash "$RUN" recall 2>&1)"; has "$out" "health:" "recall surfaces an audit health line"
out="$(FLOW_PROJECT_ROOT="$SB" bash "$RUN" retro 2>&1)"; has "$out" "Harness proposes" "retro surfaces deterministic proposals"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

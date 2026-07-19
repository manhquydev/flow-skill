#!/usr/bin/env bash
# Regression suite for the card-lifecycle verbs '/flow card start|done' + the in-flight line in
# '/flow status'. The in-flight state is a PORTABLE side registry (cards/.inflight) that never
# touches the gated 'status:' frontmatter; both verbs COEXIST with hand-edit + '/flow check'.
# Harness disabled so the suite is python-independent. Run: bash tests/test_flow_card_lifecycle.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
export FLOW_HARNESS_DISABLE=1
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected $1 got $2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected /$2/)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

mkcard() { # $1 status  $2 verifybox  $3 evidence
  printf '# C-001 — scaffold\nstatus: %s\ndeps: none\n## Scope\none thing\n## Allowed files\ninfra/\n## Verify (run these before done)\n- [%s] curl 200\n## Done-evidence (world-state proof)\nurl\n## Evidence (paste actual proof when done)\n%s\n' "$1" "$2" "$3" > "$SB/cards/C-001.md"
}

echo "A) card start: not-found + happy path + in-flight display"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
bash "$RUN" card start C-404 >/dev/null 2>&1; ck 1 $? "card start on a missing card -> exit 1"
mkcard todo " " "(empty until done)"
bash "$RUN" card start C-001 >/dev/null; ck 0 $? "card start C-001 -> exit 0"
has "$(cat "$SB/cards/.inflight")" "C-001 " "C-001 recorded in the .inflight registry"
has "$(bash "$RUN" status)" "in flight" "status shows the in-flight section"
has "$(bash "$RUN" status)" "C-001 (in flight" "status lists C-001 as in flight"
rm -rf "$SB"

echo "B) card done: hollow-done reverts (gate parity); real done flips + clears in-flight"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
mkcard todo " " "(empty until done)"
bash "$RUN" card start C-001 >/dev/null
bash "$RUN" card done C-001 >/dev/null 2>&1; ck 1 $? "card done with empty evidence + unchecked verify -> exit 1"
has "$(cat "$SB/cards/C-001.md")" "status: todo" "hollow done was REVERTED to todo (never a hollow done)"
has "$(cat "$SB/cards/.inflight")" "C-001 " "still in flight after a reverted done"
mkcard todo "x" '$ curl https://x/healthz -> {"ok":true}'   # now genuinely shippable
bash "$RUN" card start C-001 >/dev/null
bash "$RUN" card done C-001 >/dev/null; ck 0 $? "card done with checked verify + real evidence -> exit 0"
has "$(cat "$SB/cards/C-001.md")" "status: done" "verb performed the CLI-owned flip to done"
no "$(cat "$SB/cards/.inflight" 2>/dev/null)" "C-001 " "done card cleared from .inflight"
no "$(bash "$RUN" status)" "in flight" "status no longer shows an in-flight section once done"
rm -rf "$SB"

echo "C) start refuses a done card; coexist with hand-edit + check"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
mkcard done "x" 'real proof here'
bash "$RUN" card start C-001 >/dev/null 2>&1; ck 1 $? "card start on an already-done card -> exit 1"
bash "$RUN" check C-001 >/dev/null 2>&1; ck 0 $? "hand-edited done card still passes '/flow check' (coexist, no regression)"
rm -rf "$SB"

echo "D) bare 'card' still CREATES (dispatch did not break the create verb)"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow" "$SB/cards"
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do printf '#%s\n## Gate\n- [x] ok\n\nbody\n' "$s" > "$SB/flow/$s.md"; done
bash "$RUN" card >/dev/null; ck 0 $? "bare '/flow card' still creates the next card"
test -f "$SB/cards/C-001.md"; ck 0 $? "C-001.md was created by bare 'card'"
rm -rf "$SB"

echo "E) card done on a status-less card refuses cleanly (no misleading revert message)"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
printf '# C-001 — no status line\ndeps: none\n## Scope\nx\n## Allowed files\nx\n## Verify\n- [x] x\n## Done-evidence\nu\n## Evidence\nreal proof\n' > "$SB/cards/C-001.md"
out="$(bash "$RUN" card done C-001 2>&1)"; ck 1 $? "card done on a card with no status: line -> exit 1"
has "$out" "no 'status:' line" "refuses with a clear no-status message (not a fake revert)"
no "$out" "REVERTED" "does not print a misleading REVERTED line"
rm -rf "$SB"

echo "F) durable complete path with harness ON (AC7 trust-align)"
# Sections A–E keep FLOW_HARNESS_DISABLE=1 for python-independence; this block needs the durable layer.
if command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
  SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
  unset FLOW_HARNESS_DISABLE
  PY="$(command -v python || command -v python3)"
  H="$HERE/../skills/flow/harness/flow_harness.py"
  # seed durable story (same as card create would) then check done
  FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null
  FLOW_PROJECT_ROOT="$SB" "$PY" "$H" story add --id C-001 --title C-001 --lane normal >/dev/null
  printf '# C-001 — scaffold\nstatus: done\ndeps: none\n## Scope\nx\n## Allowed files\nx\n## Verify\n- [x] curl 200\n## Done-evidence\nurl\n## Evidence\nreal curl proof\n' > "$SB/cards/C-001.md"
  bash "$RUN" check C-001 >/dev/null 2>&1; ck 0 $? "check done with harness ON -> exit 0"
  row="$("$PY" - "$SB/.flow/harness.db" <<'PY'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
r=c.execute("select status, notes from story where id='C-001'").fetchone()
print(r if r else "NO_ROW")
PY
)"
  has "$row" "implemented" "durable story implemented after check"
  has "$row" "card_markdown_gate" "proof_source stamped"
  export FLOW_HARNESS_DISABLE=1
  rm -rf "$SB"
else
  echo "  ok   [skip harness-on durable (no python)]"; pass=$((pass+1))
fi

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

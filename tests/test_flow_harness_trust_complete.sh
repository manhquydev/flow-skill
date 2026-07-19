#!/usr/bin/env bash
# Story completion trust boundary (plan phase 3). Run: bash tests/test_flow_harness_trust_complete.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HDIR="$HERE/../skills/flow/harness"
H="$HDIR/flow_harness.py"
RUN="$HERE/../skills/flow/runner/flow.sh"
PY="$(command -v python || command -v python3)"
if [ -z "$PY" ]; then echo "SKIP: python not found"; exit 0; fi
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qE "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] in: $(printf '%.100s' "$1")"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -qiE "$2"; then echo "  FAIL [$3]"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

Hrun() { FLOW_PROJECT_ROOT="$SB" "$PY" "$H" "$@"; }

echo "A) reject bare implemented; status unchanged"
SB="$(mktemp -d)"
Hrun init >/dev/null
Hrun story add --id S1 --title t --lane normal >/dev/null
rc=0; out="$(Hrun story update --id S1 --status implemented 2>&1)" || rc=$?
ck 1 "$rc" "update implemented rejected"
st="$(FLOW_PROJECT_ROOT="$SB" "$PY" - "$SB/.flow/harness.db" <<'PY'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("select status from story where id='S1'").fetchone()[0])
PY
)"
ck "planned" "$st" "status remains planned after reject"
rm -rf "$SB"; unset rc

echo "B) complete card_markdown_gate succeeds; no forged last_verified=pass"
SB="$(mktemp -d)"
Hrun init >/dev/null
Hrun story add --id S1 --title t --lane normal >/dev/null
rc=0; out="$(Hrun story complete --id S1 --proof-source card_markdown_gate --evidence 'gate ok' 2>&1)" || rc=$?
ck 0 "$rc" "complete card_markdown_gate ok"
has "$out" "complete|proof_source" "mentions complete"
row="$(FLOW_PROJECT_ROOT="$SB" "$PY" - "$SB/.flow/harness.db" <<'PY'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
st, notes, lvr, ev = c.execute(
  "select status, notes, last_verified_result, evidence from story where id='S1'").fetchone()
print(st)
print(notes or "")
print(repr(lvr))
print(ev or "")
PY
)"
has "$row" "implemented" "status implemented"
has "$row" "proof_source=card_markdown_gate" "notes carry proof_source"
has "$row" "None" "last_verified_result is None (not forged pass)"
has "$row" "gate ok" "evidence stored"
rm -rf "$SB"

echo "C) complete verify_command without prior verify fails"
SB="$(mktemp -d)"
Hrun init >/dev/null
Hrun story add --id S1 --title t --lane normal --verify "true" >/dev/null
rc=0; out="$(Hrun story complete --id S1 --proof-source verify_command 2>&1)" || rc=$?
ck 1 "$rc" "verify_command without pass fails"
Hrun story verify --id S1 >/dev/null
rc=0; out="$(Hrun story complete --id S1 --proof-source verify_command 2>&1)" || rc=$?
ck 0 "$rc" "after verify pass, complete ok"
rm -rf "$SB"

echo "D) in_progress update still works"
SB="$(mktemp -d)"
Hrun init >/dev/null
Hrun story add --id S1 --title t --lane normal >/dev/null
Hrun story update --id S1 --status in_progress >/dev/null; ck 0 $? "in_progress ok"
rm -rf "$SB"

echo "E) /flow check done durable complete with harness ON"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
unset FLOW_HARNESS_DISABLE
mkdir -p "$SB/cards"
printf '# C-001 — scaffold\nstatus: done\ndeps: none\n## Scope\nx\n## Allowed files\nx\n## Verify (run these before done)\n- [x] curl 200\n## Done-evidence\nurl\n## Evidence\n$ curl https://x/healthz -> ok\n' > "$SB/cards/C-001.md"
# seed story as card create would
Hrun init >/dev/null
Hrun story add --id C-001 --title C-001 --lane normal >/dev/null
bash "$RUN" check C-001 >/dev/null 2>&1; ck 0 $? "check done exit 0"
row="$(FLOW_PROJECT_ROOT="$SB" "$PY" - "$SB/.flow/harness.db" <<'PY'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(c.execute("select status, notes from story where id='C-001'").fetchone())
PY
)"
has "$row" "implemented" "check done set implemented"
has "$row" "card_markdown_gate" "proof_source recorded"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

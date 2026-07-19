#!/usr/bin/env bash
# Lineage contract: gap matrix + schema inventory + rust refuse (plan phase 1).
# Run: bash tests/test_flow_harness_lineage_contract.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HDIR="$HERE/../skills/flow/harness"
H="$HDIR/flow_harness.py"
MATRIX="$HDIR/GAP-MATRIX-0.1.17.md"
README="$HDIR/README.md"
PY="$(command -v python || command -v python3)"
if [ -z "$PY" ]; then echo "SKIP: python not found"; exit 0; fi
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qE "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] missing /$2/ in: $(printf '%.80s' "$1")"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -qiE "$2"; then echo "  FAIL [$3] unexpected /$2/"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
# Capture stdout+stderr and real exit code (do not use `out=$(cmd) || true` — that zeroes $?).
run_cap() { # sets CAP_OUT CAP_RC
  CAP_OUT=""; CAP_RC=0
  CAP_OUT="$("$@" 2>&1)" || CAP_RC=$?
}

echo "A) GAP matrix required content"
test -f "$MATRIX"; ck 0 $? "GAP-MATRIX-0.1.17.md exists"
M="$(cat "$MATRIX" 2>/dev/null || true)"
has "$M" "0\.1\.14" "pin protocol floor 0.1.14"
has "$M" "0\.1\.17" "pin trust CLI 0.1.17"
has "$M" "0\.1\.16" "mentions 0.1.16 (do-not-use)"
has "$M" "009.*012|009–012|009-012" "009-012 collision noted"
has "$M" "[Rr]ust refuse|refuse-forward|flow-lineage" "rust refuse documented"
has "$M" "005" "005 caveat present"
# ban false parity claims (not the phrase "does not claim … US-101")
if printf '%s' "$M" | grep -qiE 'bit-identical US-101|isomorphic to US-101|US-101 parity'; then
  bad=1; echo "  FAIL [false US-101 parity language]"; fail=$((fail+1))
else
  echo "  ok   [no false US-101 parity claim]"; pass=$((pass+1))
fi

echo "B) schema inventory exactly 001-005 + 009-012"
SCH="$(cd "$HDIR/schema" && ls -1 *.sql 2>/dev/null | sort | tr '\n' ' ')"
has "$SCH" "001-init" "has 001"
has "$SCH" "005-tool" "has 005"
has "$SCH" "009-accessed" "has 009"
has "$SCH" "012-usage" "has 012"
no "$SCH" "006-" "no 006 migration file"
no "$SCH" "007-" "no 007 migration file"
no "$SCH" "008-" "no 008 migration file"
no "$SCH" "013-" "no 013 migration file"

echo "C) README pins"
R="$(cat "$README" 2>/dev/null || true)"
has "$R" "0\.1\.17" "README pin 0.1.17"
has "$R" "0\.1\.14" "README pin 0.1.14"

echo "D) rust refuse on flow-lineage DB"
SB="$(mktemp -d)"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null
# Fake rust backend binary that would succeed if called
FAKE="$SB/fake-harness-cli"
printf '#!/bin/sh\necho should-not-run\nexit 0\n' > "$FAKE"
chmod +x "$FAKE" 2>/dev/null || true
CAP_RC=0
CAP_OUT="$(FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_BACKEND=rust FLOW_HARNESS_CLI="$FAKE" \
  "$PY" "$H" query matrix 2>&1)" || CAP_RC=$?
ck 2 "$CAP_RC" "rust backend on flow-lineage exits 2"
has "$CAP_OUT" "refus|diverge|flow-lineage" "refuse message guides operator"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

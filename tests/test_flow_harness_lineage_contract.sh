#!/usr/bin/env bash
# Lineage contract: gap matrix + schema inventory + rust refuse (authority continuity).
# Run: bash tests/test_flow_harness_lineage_contract.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HDIR="$HERE/../skills/flow/harness"
H="$HDIR/flow_harness.py"
MATRIX="$HDIR/GAP-MATRIX-0.1.17.md"
README="$HDIR/README.md"
PY="$(command -v python3 || command -v python)"
if [ -z "$PY" ]; then echo "SKIP: python not found"; exit 0; fi
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qE "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] missing /$2/ in: $(printf '%.80s' "$1")"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -qiE "$2"; then echo "  FAIL [$3] unexpected /$2/"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

echo "A) GAP matrix required content (superseded / historical)"
test -f "$MATRIX"; ck 0 $? "GAP-MATRIX-0.1.17.md exists"
M="$(cat "$MATRIX" 2>/dev/null || true)"
has "$M" "[Ss]UPERSEDED|no (further )?schema sync|no upstream schema sync" "supersede / no-sync policy"
has "$M" "flow-owned|flow owned" "flow-owned ownership"
# Historical archive may still mention old pins under Historical section
has "$M" "0\.1\.22|0\.1\.17|historical|archive|EOL|end of life|end-of-life" "historical/EOL archive noted"
has "$M" "009.*012|009–012|009-012" "009-012 collision noted"
has "$M" "[Rr]ust refuse|refuse-forward|flow-lineage" "rust refuse documented"
has "$M" "005" "005 caveat present"
has "$M" "014" "flow-owned graph band 014+ documented"
has "$M" "[Ss]upersed|[Ss]UPERSED" "work-graph red-line supersession recorded"
# Ban affirmative parity claims (negations like "does not claim …" are OK)
if printf '%s' "$M" | grep -niE 'bit-identical US-101|isomorphic to US-101|US-101 parity' \
  | grep -viE 'not |never |no ' >/dev/null; then
  echo "  FAIL [false US-101 parity language]"; fail=$((fail+1))
else
  echo "  ok   [no false US-101 parity claim]"; pass=$((pass+1))
fi

echo "B) schema inventory exactly 001-005 + 009-012 + 014 (flow-owned graph band)"
SCH="$(cd "$HDIR/schema" && ls -1 *.sql 2>/dev/null | sort | tr '\n' ' ')"
has "$SCH" "001-init" "has 001"
has "$SCH" "005-tool" "has 005"
has "$SCH" "009-accessed" "has 009"
has "$SCH" "012-usage" "has 012"
has "$SCH" "014-graph" "has 014 (flow-owned graph executor)"
no "$SCH" "006-" "no 006 migration file"
no "$SCH" "007-" "no 007 migration file"
no "$SCH" "008-" "no 008 migration file"
no "$SCH" "013-" "no 013 migration file"

echo "C) README live authority (not live trust pin table)"
R="$(cat "$README" 2>/dev/null || true)"
has "$R" "flow-owned|live authority" "README live authority / flow-owned"
has "$R" "story complete" "README story complete"
has "$R" "proof_source|proof-source" "README proof-source"
if printf '%s' "$R" | grep -E '^\| *Trust / consumer *\|' | grep -q '0\.1\.17'; then
  echo "  FAIL [live Trust/consumer pin table]"; fail=$((fail+1))
else
  echo "  ok   [no live Trust/consumer pin table]"; pass=$((pass+1))
fi

echo "D) rust refuse on flow-lineage DB"
SB="$(mktemp -d)"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null
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

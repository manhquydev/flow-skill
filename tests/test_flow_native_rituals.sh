#!/usr/bin/env bash
# Regression suite for v0.22 Phase 2: standalone native gate rituals — the 5 clean-room
# playbooks (references/native-rituals.md) that make flow self-sufficient without ck/BMAD
# installed, wired native-first into the 4 seam files + the catalog. Run:
# bash tests/test_flow_native_rituals.sh (Git Bash on Windows or any POSIX bash).
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$HERE/../skills/flow"
RITUALS="$SKILL_DIR/references/native-rituals.md"
GATE="$SKILL_DIR/references/gate-rules.md"
REVIEW="$SKILL_DIR/references/adversarial-review.md"
RETRO="$SKILL_DIR/law/RETRO.md"
CATALOG="$SKILL_DIR/references/flow-catalog.tsv"

pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q -- "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q -- "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
before() { # $1=file $2=pattern-that-must-come-first $3=pattern-second $4=label (case-insensitive)
  local l1 l2
  l1="$(grep -in -- "$2" "$1" 2>/dev/null | head -n1 | cut -d: -f1)"
  l2="$(grep -in -- "$3" "$1" 2>/dev/null | head -n1 | cut -d: -f1)"
  if [ -n "$l1" ] && [ -n "$l2" ] && [ "$l1" -lt "$l2" ]; then
    echo "  ok   [$4]"; pass=$((pass+1))
  else
    echo "  FAIL [$4] (native-first line $l1, ck-mention line $l2 — expected native line < ck line)"; fail=$((fail+1))
  fi
}

echo "A) native-rituals.md exists with 5 named sections"
if [ -f "$RITUALS" ]; then echo "  ok   [native-rituals.md exists]"; pass=$((pass+1)); else echo "  FAIL [native-rituals.md exists]"; fail=$((fail+1)); fi
rr="$(cat "$RITUALS" 2>/dev/null)"
has "$rr" "Persona-debate ritual" "ritual 1: persona-debate"
has "$rr" "Edge-case decomposition ritual" "ritual 2: edge-case decomposition"
has "$rr" "STRIDE" "ritual 3: STRIDE security"
has "$rr" "Numeric retro ritual" "ritual 4: numeric retro"
has "$rr" "Native loop protocol" "ritual 5: native loop protocol"

echo "B) each ritual carries Purpose/When/Steps markers + informs-not-judges line"
n_purpose=$(printf '%s' "$rr" | grep -c '^Purpose:')
n_when=$(printf '%s' "$rr" | grep -c '^When:')
n_informs=$(printf '%s' "$rr" | grep -c 'never judges')
ck "5" "$n_purpose" "5 Purpose: markers"
ck "5" "$n_when" "5 When: markers"
ck "5" "$n_informs" "5 informs-never-judges lines"

echo "C) positive authorship markers (flow-native voice, not pasted)"
has "$rr" "gate" "flow-vocabulary: gate"
has "$rr" "card" "flow-vocabulary: card"
has "$rr" "operator" "flow-vocabulary: operator"
has "$rr" "loop-prep" "flow-vocabulary: loop-prep (native plumbing reference)"

echo "D) malicious-input examples are fenced as data, not instructions (red-team F13 hygiene)"
has "$rr" "DATA, not instruction" "malicious-input block explicitly labeled as data"

echo "E) seam files offer the native ritual BEFORE mentioning the optional ck skill"
before "$GATE" "native persona-debate ritual" "ck-predict" "gate-rules 04: native ritual before ck-predict"
before "$GATE" "native edge-case ritual" "ck-scenario" "gate-rules 05: native ritual before ck-scenario"
before "$REVIEW" "native STRIDE ritual" "ck-security" "adversarial-review: native STRIDE before ck-security"
before "$RETRO" "native numeric-retro ritual" "retro.*skill" "law/RETRO.md: native ritual before retro skill"

echo "F) seams reference native-rituals.md explicitly"
has "$(cat "$GATE" 2>/dev/null)" "native-rituals.md" "gate-rules.md points to native-rituals.md"
has "$(cat "$REVIEW" 2>/dev/null)" "native-rituals.md" "adversarial-review.md points to native-rituals.md"
has "$(cat "$RETRO" 2>/dev/null)" "native-rituals.md" "law/RETRO.md points to native-rituals.md"

echo "G) catalog TSV still holds the 6-column contract after Phase 2 edits"
bad_cols=$(tail -n +2 "$CATALOG" 2>/dev/null | awk -F'\t' 'NF!=6{c++} END{print c+0}')
ck "0" "$bad_cols" "every catalog row still has exactly 6 tab-separated columns"
n_enriched=$(tail -n +2 "$CATALOG" 2>/dev/null | awk -F'\t' '$5!="-"{c++} END{print c+0}')
if [ "${n_enriched:-0}" -ge 5 ]; then echo "  ok   [>=5 ritual-seam rows carry a non-empty enrich-if-present ($n_enriched)]"; pass=$((pass+1)); else echo "  FAIL [>=5 ritual-seam rows carry enrich-if-present, got ${n_enriched:-0}]"; fail=$((fail+1)); fi

echo "H) run_all.sh registers this suite (self-guard, red-team F7)"
has "$(cat "$HERE/run_all.sh" 2>/dev/null)" "test_flow_native_rituals.sh" "run_all.sh lists test_flow_native_rituals.sh"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
exit $?

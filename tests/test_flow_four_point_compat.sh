#!/usr/bin/env bash
# Four-Point Live Verification Protocol regression guards.
# Static + mechanical checks that the "Support Thật" governance surface stays
# coherent: authoritative gate definitions, SOP pointer-not-copy discipline,
# mechanical gate-stop behavior of runner/flow.sh, and verdict infrastructure.
# Protocol home: plans/research/harness-expansion/architecture-compatibility-matrix.md #1.2
# SOP: docs/harness-qualification-process.md (Phase 4, §3.3)
# Run: bash tests/test_flow_four_point_compat.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
RUN="$ROOT/skills/flow/runner/flow.sh"
MATRIX="$ROOT/plans/research/harness-expansion/architecture-compatibility-matrix.md"
SOP="$ROOT/docs/harness-qualification-process.md"
EVID="$ROOT/plans/research/harness-expansion/evidence"
pass=0
fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass + 1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail + 1)); fi; }

echo "A) authoritative home: matrix #1.2 defines all four gates"
grep -q '1\.2 The Four-Point Live Verification Protocol' "$MATRIX" && ck 0 0 "matrix section 1.2 heading present" || ck 0 1 "matrix section 1.2 heading present"
for g in 'Ingestion Check' 'Invocation Check' 'Gate-Stop Check' 'State Integrity'; do
  grep -q "$g" "$MATRIX" && ck 0 0 "matrix defines gate: $g" || ck 0 1 "matrix defines gate: $g"
done

echo "B) SOP points to the home, names gates, mandates force-failure fixtures"
grep -q 'architecture-compatibility-matrix.md#12-the-four-point-live-verification-protocol' "$SOP" && ck 0 0 "SOP links the single authoritative home" || ck 0 1 "SOP links the single authoritative home"
for g in 'Ingestion Check' 'Invocation Check' 'Gate-Stop Check' 'State Integrity'; do
  grep -q "$g" "$SOP" && ck 0 0 "SOP names gate: $g" || ck 0 1 "SOP names gate: $g"
done
grep -q '\[FILL\]' "$SOP" && ck 0 0 "SOP mandates [FILL] force-failure fixture" || ck 0 1 "SOP mandates [FILL] force-failure fixture"
# Section-scoped check: Gate 3's own Test Setup must mandate the open-checklist breach,
# so removing it fails even when unrelated audit checkboxes exist elsewhere in the SOP.
gate3_section="$(sed -n '/^### Gate 3:/,/^### Gate 4:/p' "$SOP")"
printf '%s' "$gate3_section" | grep -Fn '(`- [ ]`)' && ck 0 0 "Gate 3 audit section mandates open-checklist force-failure fixture" || ck 0 1 "Gate 3 audit section mandates open-checklist force-failure fixture"
for g in 'Gate 1' 'Gate 2' 'Gate 3' 'Gate 4'; do
  grep -q "### $g:" "$SOP" && ck 0 0 "SOP has audit section: $g" || ck 0 1 "SOP has audit section: $g"
done

echo "C) verdict infrastructure: evidence dir + template covers all four gates"
[ -f "$EVID/template-qualification-record.md" ] && ck 0 0 "qualification record template exists" || ck 0 1 "qualification record template exists"
for g in 'Gate 1' 'Gate 2' 'Gate 3' 'Gate 4'; do
  grep -q "$g.*PASS / FAIL" "$EVID/template-qualification-record.md" && ck 0 0 "template has verdict row: $g" || ck 0 1 "template has verdict row: $g"
done
[ -d "$EVID/fixtures/candidate-gate3-failure" ] && ck 0 0 "gate-3 failure fixture dir exists" || ck 0 1 "gate-3 failure fixture dir exists"

echo "D) mechanical gate-stop: runner refuses broken artifacts, passes clean ones"
stage_clean() { printf '#%s\n## Gate\n- [x] honestly done\n\nreal content.\n' "$1" > "$2"; }
SB="$(mktemp -d)"
export FLOW_PROJECT_ROOT="$SB"
mkdir -p "$SB/flow"
# Gate-Stop fixture per SOP §3.3 Gate 3: unfilled [FILL] + open checklist on stage 00.
bash "$RUN" next >/dev/null 2>&1
out="$(bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" "fresh template with [FILL] markers -> gate-stop exit 1"
printf '%s' "$out" | grep -q 'FILL' && ck 0 0 "gate-stop diagnostic names the [FILL] breach" || ck 0 1 "gate-stop diagnostic names the [FILL] breach"
# Repaired artifact advances (mechanical pass, exit 0).
stage_clean "Idea" "$SB/flow/00-idea.md"
bash "$RUN" next >/dev/null 2>&1; ck 0 $? "clean stage 00 advances (exit 0)"
# Isolated open-checklist fixture: unchecked gate box only, NO [FILL] markers -
# proves the checklist gate stops on its own (cubic review: fixture independence).
printf '#Idea\n## Gate\n- [ ] open checklist item\n\nreal content.\n' > "$SB/flow/00-idea.md"
out="$(bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" "unchecked gate box alone (no [FILL]) -> gate-stop exit 1"
printf '%s' "$out" | grep -q 'unchecked gate boxes' && ck 0 0 "gate-stop diagnostic names the open-checklist breach" || ck 0 1 "gate-stop diagnostic names the open-checklist breach"
# State integrity: next wrote and reads back progression from disk (01 unlocked).
[ -f "$SB/flow/01-research.md" ] && ck 0 0 "stage progression artifact 01-research.md unlocked on disk" || ck 0 1 "stage progression artifact 01-research.md unlocked on disk"
out="$(bash "$RUN" status 2>&1)"; rc=$?
ck 0 "$rc" "fresh flow status exits clean"
printf '%s' "$out" | grep -q 'planning: at stage 01-research' && ck 0 0 "fresh flow status readback reports the current stage" || ck 0 1 "fresh flow status readback reports the current stage"
rm -rf "$SB"

echo "E) categorization taxonomy: honest four-category disclosure present"
for c in 'Category A' 'Category B' 'Category C' 'Category D'; do
  grep -q "$c" "$MATRIX" && ck 0 0 "matrix discloses $c" || ck 0 1 "matrix discloses $c"
  grep -q "$c" "$SOP" && ck 0 0 "SOP discloses $c" || ck 0 1 "SOP discloses $c"
done

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

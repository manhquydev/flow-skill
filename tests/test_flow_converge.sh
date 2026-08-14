#!/usr/bin/env bash
# Regression suite for C-CONVERGE (D-2): transactional append-only remainder-card writer.
# Contracts: no-findings leaves cards/ byte-identical + prints CONVERGED; findings append C-NNN
# without touching C-001; missing-planning fails; invalid gap-type/schema writes NOTHING;
# unrequested -> review card, never deletes code; a mid-batch refuse rolls back (all-or-nothing).
# Portable: no `sed -i`. Run: bash tests/test_flow_converge.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q -- "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q -- "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

newsb() {
  SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_DISABLE=1 FLOW_LOG_DISABLE=1
  mkdir -p "$SB/flow" "$SB/cards" "$SB/.flow" "$SB/src"
}
seed_planning() { local s; for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do printf '#%s\n## Gate\n- [x] ok\n\nreal.\n' "$s" > "$SB/flow/$s.md"; done; }
seed_c001() { printf '# C-001\nstatus: done\nimplements: FR1\n\n## Scope\nx\n## Allowed files\na\n## Verify\n- [x] ok\n## Done-evidence\nurl\n## Evidence\ndone\n' > "$SB/cards/C-001.md"; }
CV() { bash "$RUN" converge 2>&1; }
cards_sum() { (cd "$SB/cards" && ls | sort | while read -r f; do cksum "$f"; done); }

echo "A) no payload -> CONVERGED, cards/ byte-identical"
newsb; seed_planning; seed_c001; before="$(cards_sum)"
out="$(CV)"; ck 0 $? "no payload exits 0"
has "$out" "CONVERGED" "prints CONVERGED"
ck "$before" "$(cards_sum)" "cards/ byte-identical after CONVERGED"
rm -rf "$SB"

echo "B) findings -> append C-002 without touching C-001"
newsb; seed_planning; seed_c001; c1="$(cksum "$SB/cards/C-001.md")"
cat > "$SB/.flow/converge-pending.md" <<'EOF'
schema: flow-converge/v1
findings: 1

---
gap-type: missing
severity: HIGH
implements: FR2
source-ref: 03-prd.md:FR2
title: implement the mark-task-done endpoint
deps: C-001
allowed: src/app.py
EOF
out="$(CV)"; ck 0 $? "findings exit 0"
has "$out" "PASS: appended" "reports appended"
if [ -f "$SB/cards/C-002.md" ]; then echo "  ok   [C-002 created]"; pass=$((pass+1)); else echo "  FAIL [C-002 created]"; fail=$((fail+1)); fi
ck "$c1" "$(cksum "$SB/cards/C-001.md")" "C-001 untouched (cksum)"
has "$(cat "$SB/cards/C-002.md")" "implements: FR2" "C-002 implements FR2"
has "$(cat "$SB/cards/C-002.md")" "FILL" "C-002 ships with [FILL] (not built yet)"
rm -rf "$SB"

echo "C) missing planning -> FAIL, nothing written"
newsb; seed_c001  # no seed_planning (00-idea absent)
printf 'schema: flow-converge/v1\nfindings: 1\n\n---\ngap-type: missing\ntitle: x\n' > "$SB/.flow/converge-pending.md"
before="$(cards_sum)"; out="$(CV)"; ck 1 $? "missing planning exits 1"
ck "$before" "$(cards_sum)" "cards/ unchanged"
rm -rf "$SB"

echo "D) no cards yet -> FAIL"
newsb; seed_planning
printf 'schema: flow-converge/v1\nfindings: 1\n\n---\ngap-type: missing\ntitle: x\n' > "$SB/.flow/converge-pending.md"
out="$(CV)"; ck 1 $? "no cards exits 1"
rm -rf "$SB"

echo "E) invalid gap-type -> FAIL, nothing written"
newsb; seed_planning; seed_c001; before="$(cards_sum)"
printf 'schema: flow-converge/v1\nfindings: 1\n\n---\ngap-type: bogus\ntitle: x\n' > "$SB/.flow/converge-pending.md"
out="$(CV)"; ck 1 $? "invalid gap-type exits 1"
ck "$before" "$(cards_sum)" "cards/ unchanged (nothing written)"
rm -rf "$SB"

echo "F) bad schema header -> FAIL"
newsb; seed_planning; seed_c001
printf 'schema: something-else\n\n---\ngap-type: missing\ntitle: x\n' > "$SB/.flow/converge-pending.md"
out="$(CV)"; ck 1 $? "bad schema exits 1"
has "$out" "flow-converge/v1" "names the required schema"
rm -rf "$SB"

echo "G) unrequested -> review card (implements none), never deletes seeded source"
newsb; seed_planning; seed_c001
printf 'do not delete me\n' > "$SB/src/extra.py"
cat > "$SB/.flow/converge-pending.md" <<'EOF'
schema: flow-converge/v1
findings: 1

---
gap-type: unrequested
severity: LOW
source-ref: src/extra.py
title: the extra.py surface no feature asked for
allowed: src/extra.py
EOF
out="$(CV)"; ck 0 $? "unrequested exits 0"
if [ -f "$SB/src/extra.py" ]; then echo "  ok   [source file NOT deleted]"; pass=$((pass+1)); else echo "  FAIL [source file NOT deleted]"; fail=$((fail+1)); fi
has "$(cat "$SB/cards/C-002.md")" "implements: none" "review card implements none"
has "$(cat "$SB/cards/C-002.md")" "review unrequested surface" "titled as a review card"
rm -rf "$SB"

echo "H) transactional all-or-nothing: a LATER invalid finding aborts the whole batch (first card not written)"
newsb; seed_planning; seed_c001; before="$(cards_sum)"
cat > "$SB/.flow/converge-pending.md" <<'EOF'
schema: flow-converge/v1
findings: 2

---
gap-type: missing
title: first remainder (valid, would be C-002)
---
gap-type: bogus
title: second remainder (invalid gap-type — must abort the whole batch)
EOF
out="$(CV)"; ck 1 $? "batch with a later-invalid finding exits 1"
if [ -f "$SB/cards/C-002.md" ]; then echo "  FAIL [C-002 must NOT persist (all-or-nothing)]"; fail=$((fail+1)); else echo "  ok   [C-002 not written — validate-all-before-commit]"; pass=$((pass+1)); fi
ck "$before" "$(cards_sum)" "cards/ byte-identical (nothing appended)"
rm -rf "$SB"

echo "L) explicit --file with a missing path -> FAIL (not a false CONVERGED)"
newsb; seed_planning; seed_c001
out="$(bash "$RUN" converge --file "$SB/.flow/nope.md" 2>&1)"; ck 1 $? "--file <missing> exits 1"
no "$out" "CONVERGED" "does not falsely report CONVERGED"
rm -rf "$SB"

echo "M) an empty ---/--- block between two real findings is skipped (positions stay in sync)"
newsb; seed_planning; seed_c001
printf 'schema: flow-converge/v1\nfindings: 2\n\n---\ngap-type: missing\ntitle: first real\n---\n---\ngap-type: partial\ntitle: second real\n' > "$SB/.flow/converge-pending.md"
out="$(CV)"; ck 0 $? "empty middle block -> exit 0"
if [ -f "$SB/cards/C-002.md" ] && [ -f "$SB/cards/C-003.md" ] && [ ! -f "$SB/cards/C-004.md" ]; then echo "  ok   [exactly 2 cards appended (empty block skipped)]"; pass=$((pass+1)); else echo "  FAIL [exactly 2 cards appended] ($(ls "$SB/cards"))"; fail=$((fail+1)); fi
rm -rf "$SB"

echo "I) LAW: cmd_next never calls cmd_converge; cmd_converge never calls cmd_auto"
nextbody="$(sed -n '/^cmd_next()/,/^}/p' "$RUN")"
n1="$(printf '%s' "$nextbody" | grep -c 'cmd_converge' || true)"
ck 0 "$n1" "cmd_next body has zero cmd_converge"
convbody="$(sed -n '/^cmd_converge()/,/^}/p' "$RUN")"
has "$convbody" "cmd_converge" "cmd_converge body extracted (range non-empty)"
n2="$(printf '%s' "$convbody" | grep -c 'cmd_auto' || true)"
ck 0 "$n2" "cmd_converge never calls cmd_auto"
has "$(grep -A1 '^  converge)' "$RUN")" "cmd_converge" "converge IS reachable via dispatch"

echo "J) converge is NOT on the read-only list (it mutates cards/)"
roline="$(grep -n '_log_is_readonly' "$RUN" | head -1)"
ro="$(sed -n '/_log_is_readonly()/,/esac/p' "$RUN")"
no "$ro" "|converge|" "converge absent from the read-only case list"

echo "K) manifest.txt registers this suite"
has "$(cat "$HERE/manifest.txt" 2>/dev/null)" "test_flow_converge.sh" "manifest.txt lists test_flow_converge.sh"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
exit $?

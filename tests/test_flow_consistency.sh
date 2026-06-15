#!/usr/bin/env bash
# Regression suite for the cross-artifact consistency audit (flow.sh consistency):
# every PRD FRn must be claimed by a card (implements:) and served by a contract interface;
# numeric success metric; placeholder sweep. Advisory, ID-based, project-type agnostic.
# Run: bash tests/test_flow_consistency.sh   (exit 0 = all pass, 1 = any fail)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fi; [ "$1" = "$2" ] || fail=$((fail+1)); }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
newsb() { SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow" "$SB/cards"; }

# minimal PRD with FR ids + a numeric success metric
prd() { # $1=root  $2=success-metric-body
  cat > "$1/flow/03-prd.md" <<EOF
# Stage 03 - PRD
## Features
- FR1: As a user, I list X, I see X.
- FR2: As a user, I search X, I see filtered X.
## Success metric (numbers only)
$2
EOF
}
contract() { # $1=root  $2=FR refs present in the map
  cat > "$1/flow/05-contract.md" <<EOF
# Stage 05 - Contract
## Feature -> interface map
$2
EOF
}
card() { # $1=root  $2=id  $3=implements-value
  cat > "$1/cards/$2.md" <<EOF
# $2 - x
status: todo
deps: none
implements: $3
EOF
}

echo "A) no PRD -> graceful skip, exit 0"
newsb
out="$(bash "$RUN" consistency)"; ck 0 $? "exit 0 with no PRD"
has "$out" "planning incomplete" "skip message shown"
rm -rf "$SB"

echo "B) clean: every FR covered by a card + contract, numeric metric -> PASS exit 0"
newsb
prd "$SB" "10 items listed in week 1"
contract "$SB" "- FR1 -> GET /x
- FR2 -> GET /x?q="
card "$SB" C-001 "FR1"
card "$SB" C-002 "FR2"
out="$(bash "$RUN" consistency)"; ck 0 $? "clean -> exit 0"
has "$out" "PASS" "reports PASS"
rm -rf "$SB"

echo "C) FR2 has no card -> CRITICAL, exit 1"
newsb
prd "$SB" "10 items listed in week 1"
contract "$SB" "- FR1 -> GET /x
- FR2 -> GET /x?q="
card "$SB" C-001 "FR1"
out="$(bash "$RUN" consistency)"; ck 1 $? "uncovered FR -> exit 1"
has "$out" "CRITICAL" "severity CRITICAL present"
has "$out" "FR2 has no card" "names the uncovered feature"
rm -rf "$SB"

echo "D) card implements an FR absent from PRD -> HIGH, exit 1"
newsb
prd "$SB" "10 items listed in week 1"
contract "$SB" "- FR1 -> GET /x
- FR2 -> GET /x?q="
card "$SB" C-001 "FR1"
card "$SB" C-002 "FR2"
card "$SB" C-003 "FR9"
out="$(bash "$RUN" consistency)"; ck 1 $? "phantom FR -> exit 1"
has "$out" "FR9 is not declared" "names the phantom feature"
rm -rf "$SB"

echo "E) FR not in contract map -> HIGH, exit 1"
newsb
prd "$SB" "10 items listed in week 1"
contract "$SB" "- FR1 -> GET /x"
card "$SB" C-001 "FR1"
card "$SB" C-002 "FR2"
out="$(bash "$RUN" consistency)"; ck 1 $? "FR missing from contract -> exit 1"
has "$out" "absent from the contract" "names the seam gap"
rm -rf "$SB"

echo "F) success metric with no number -> HIGH, exit 1"
newsb
prd "$SB" "save users a lot of time and improve UX"
contract "$SB" "- FR1 -> GET /x
- FR2 -> GET /x?q="
card "$SB" C-001 "FR1"
card "$SB" C-002 "FR2"
out="$(bash "$RUN" consistency)"; ck 1 $? "vibes metric -> exit 1"
has "$out" "no number" "flags the non-numeric metric"
rm -rf "$SB"

echo "G) PRD without FR ids -> info, coverage skipped, exit 0"
newsb
cat > "$SB/flow/03-prd.md" <<EOF
# Stage 03 - PRD
## Features
- As a user, I list X.
## Success metric (numbers only)
10 items in week 1
EOF
out="$(bash "$RUN" consistency)"; ck 0 $? "no FR ids -> exit 0"
has "$out" "no FR ids found" "info message shown"
rm -rf "$SB"

echo "H) placeholder sweep across planning set -> LOW finding (no CRITICAL/HIGH -> exit 0)"
newsb
prd "$SB" "10 items in week 1"
contract "$SB" "- FR1 -> GET /x
- FR2 -> GET /x?q="
card "$SB" C-001 "FR1"
card "$SB" C-002 "FR2"
printf '# Stage 02\n- [FILL: a leftover]\n' > "$SB/flow/02-scope.md"
out="$(bash "$RUN" consistency)"; ck 0 $? "only LOW -> exit 0"
has "$out" "LOW" "LOW placeholder finding present"
no "$out" "FLAGGED" "not FLAGGED (no CRITICAL/HIGH)"
rm -rf "$SB"

echo "I) FR1 + FR10 co-declared, contract has FR1 only -> flags FR10, never FR1 (boundary, not substring)"
newsb
cat > "$SB/flow/03-prd.md" <<EOF
# Stage 03 - PRD
## Features
- FR1: As a user, I list X, I see X.
- FR10: As an admin, I see the admin view.
## Success metric (numbers only)
10 items in week 1
EOF
contract "$SB" "- FR1 -> GET /x"
card "$SB" C-001 "FR1"
card "$SB" C-010 "FR10"
out="$(bash "$RUN" consistency)"; ck 1 $? "FR10 missing from contract -> exit 1"
has "$out" "FR10 is absent" "FR10 flagged"
no "$out" "FR1 is absent" "FR1 NOT falsely flagged (FR1 must not match the FR10 line)"
rm -rf "$SB"

echo "J) FR id mentioned only in PRD prose (outside Features) is NOT treated as a declared feature"
newsb
cat > "$SB/flow/03-prd.md" <<EOF
# Stage 03 - PRD
## Features
- FR1: As a user, I list X, I see X.
## Context
This replaces the old FR9 approach we abandoned.
## Success metric (numbers only)
10 items in week 1
EOF
contract "$SB" "- FR1 -> GET /x"
card "$SB" C-001 "FR1"
out="$(bash "$RUN" consistency)"; ck 0 $? "prose FR9 ignored -> clean exit 0"
no "$out" "FR9" "FR9 (prose-only) is not in the declared set"
rm -rf "$SB"

echo "K) multiple FRs on one implements line: 'implements: FR1, FR2, FR3' -> all covered, exit 0"
newsb
cat > "$SB/flow/03-prd.md" <<EOF
# PRD
## Features
- FR1: a
- FR2: b
- FR3: c
## Success metric (numbers only)
10 in wk1
EOF
contract "$SB" "- FR1 -> /a
- FR2 -> /b
- FR3 -> /c"
card "$SB" C-001 "FR1, FR2, FR3"
out="$(bash "$RUN" consistency)"; ck 0 $? "one card covering 3 FRs -> exit 0"
has "$out" "PASS" "PASS reported"
rm -rf "$SB"

echo "L) 'implements: infra' card must NOT be flagged as a phantom FR"
newsb
prd "$SB" "10 in wk1"
contract "$SB" "- FR1 -> /a
- FR2 -> /b"
card "$SB" C-001 "FR1"
card "$SB" C-002 "FR2"
card "$SB" C-003 "infra"
out="$(bash "$RUN" consistency)"; ck 0 $? "infra card -> exit 0"
no "$out" "infra" "infra never appears as a finding"
rm -rf "$SB"

echo "M) no cards/ dir at all + a declared FR -> CRITICAL, exit 1, no crash"
newsb; rmdir "$SB/cards"
cat > "$SB/flow/03-prd.md" <<EOF
# PRD
## Features
- FR1: a
## Success metric (numbers only)
10 in wk1
EOF
out="$(bash "$RUN" consistency 2>&1)"; ck 1 $? "missing cards/ -> exit 1"
has "$out" "CRITICAL" "FR1 flagged CRITICAL"
no "$out" "No such file" "no shell error leaked"
rm -rf "$SB"

echo "N) contract absent, FR covered by a card -> coverage clean, contract check skipped, exit 0"
newsb
cat > "$SB/flow/03-prd.md" <<EOF
# PRD
## Features
- FR1: a
## Success metric (numbers only)
10 in wk1
EOF
card "$SB" C-001 "FR1"
out="$(bash "$RUN" consistency)"; ck 0 $? "no contract -> exit 0"
has "$out" "PASS" "PASS (contract check gracefully skipped)"
rm -rf "$SB"

echo "O) FR1 + FR10 + FR100 three-way: no substring collision anywhere -> exit 0"
newsb
cat > "$SB/flow/03-prd.md" <<EOF
# PRD
## Features
- FR1: a
- FR10: b
- FR100: c
## Success metric (numbers only)
10 in wk1
EOF
contract "$SB" "- FR1 -> /a
- FR10 -> /b
- FR100 -> /c"
card "$SB" C-001 "FR1, FR10, FR100"
out="$(bash "$RUN" consistency)"; ck 0 $? "3-way numeric boundary -> exit 0"
has "$out" "PASS" "no false collision finding"
rm -rf "$SB"

echo "P) CRLF line endings (Windows) must not break matching -> exit 0"
newsb
printf '# PRD\r\n## Features\r\n- FR1: a\r\n- FR2: b\r\n## Success metric (numbers only)\r\n10 in wk1\r\n' > "$SB/flow/03-prd.md"
printf '# Contract\r\n## Feature -> interface map\r\n- FR1 -> /a\r\n- FR2 -> /b\r\n' > "$SB/flow/05-contract.md"
printf '# C-001\r\nstatus: todo\r\ndeps: none\r\nimplements: FR1, FR2\r\n' > "$SB/cards/C-001.md"
out="$(bash "$RUN" consistency)"; ck 0 $? "CRLF artifacts -> exit 0"
has "$out" "PASS" "matching robust to trailing CR"
rm -rf "$SB"

echo "Q) combined: FR1 uncovered (CRITICAL) + card FR9 phantom (HIGH) reported together, exit 1"
newsb
prd "$SB" "10 in wk1"
contract "$SB" "- FR1 -> /a
- FR2 -> /b"
card "$SB" C-001 "FR2, FR9"
out="$(bash "$RUN" consistency)"; ck 1 $? "two findings -> exit 1"
has "$out" "CRITICAL" "FR1 CRITICAL present"
has "$out" "FR9 is not declared" "FR9 HIGH present"
rm -rf "$SB"

echo "R) DF6-3 nudge: planning complete + PRD declares FRn -> status & next nudge consistency"
newsb
for s in 00-idea 01-research 02-scope 04-adr 05-contract; do printf '#%s\n## Gate\n- [x] ok\n' "$s" > "$SB/flow/$s.md"; done
printf '# PRD\n## Gate\n- [x] ok\n## Features\n- FR1: a\n## Success metric (numbers only)\n10\n' > "$SB/flow/03-prd.md"
out="$(bash "$RUN" status)"
has "$out" "FR->card->contract" "status nudges consistency when PRD declares FR"
out2="$(bash "$RUN" next)"
has "$out2" "FR->card->contract" "next (planning complete) nudges consistency"
rm -rf "$SB"

echo "S) no nudge when PRD declares no FR ids"
newsb
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do printf '#%s\n## Gate\n- [x] ok\n' "$s" > "$SB/flow/$s.md"; done
out="$(bash "$RUN" status)"
no "$out" "FR->card->contract" "no consistency nudge without FR ids"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

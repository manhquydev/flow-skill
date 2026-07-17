#!/usr/bin/env bash
# Regression suite for v0.22 Phase 3: forge-idea ritual (references/forge-idea.md) —
# ported from BMAD-METHOD's bmad-forge-idea (MIT, Copyright (c) 2025 BMad Code, LLC),
# offered opt-in at Idea/Scope, never a gate condition. Run:
# bash tests/test_flow_forge_idea.sh (Git Bash on Windows or any POSIX bash).
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$HERE/../skills/flow"
FORGE="$SKILL_DIR/references/forge-idea.md"
GATE="$SKILL_DIR/references/gate-rules.md"
CATALOG="$SKILL_DIR/references/flow-catalog.tsv"
SKILLMD="$SKILL_DIR/SKILL.md"

pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q -- "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q -- "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

echo "A) forge-idea.md exists with verbatim MIT notice"
if [ -f "$FORGE" ]; then echo "  ok   [forge-idea.md exists]"; pass=$((pass+1)); else echo "  FAIL [forge-idea.md exists]"; fail=$((fail+1)); fi
fi_txt="$(cat "$FORGE" 2>/dev/null)"
has "$fi_txt" "Permission is hereby granted, free of charge" "verbatim MIT permission sentence"
has "$fi_txt" "Copyright (c) 2025 BMad Code, LLC" "exact copyright line (note the comma)"
has "$fi_txt" "THE SOFTWARE IS PROVIDED \"AS IS\"" "verbatim MIT warranty disclaimer present"

echo "B) ritual structure markers"
has "$fi_txt" "persona" "persona-round structure present"
has "$fi_txt" "kill" "kill-outcome path documented"
has "$fi_txt" "valid" "kill framed as a valid/honored outcome (flow's kill-at-gate DNA)"
has "$fi_txt" "opt-in" "offered opt-in, not a gate condition"

echo "C) never wired as a gate condition (positive claim would be a red flag)"
no "$fi_txt" "gate requires" "ritual text never claims the gate requires it"
no "$fi_txt" "must complete this ritual" "ritual text never claims it must be completed"
has "$fi_txt" "never required to advance" "ritual text explicitly denies being required"

echo "D) gate-rules.md offers it at Idea (00) and Scope (02), opt-in-with-prompt"
gr="$(cat "$GATE" 2>/dev/null)"
stage00_block="$(awk '/^## Stage 00/,/^## Stage 01/' "$GATE" 2>/dev/null)"
stage02_block="$(awk '/^## Stage 02/,/^## Stage 03/' "$GATE" 2>/dev/null)"
has "$stage00_block" "forge-idea" "stage 00 offers forge-idea"
has "$stage02_block" "forge-idea" "stage 02 offers forge-idea"
has "$gr" "opt-in" "offer is opt-in-with-prompt somewhere near the forge-idea mentions"

echo "E) catalog: kill-doubt-idea row updated, action stays an existing verb (invariant holds)"
row="$(awk -F'\t' '$1=="kill-doubt-idea"{print}' "$CATALOG" 2>/dev/null)"
act="$(printf '%s' "$row" | awk -F'\t' '{print $3}')"
note="$(printf '%s' "$row" | awk -F'\t' '{print $4}')"
has "$note" "forge-idea" "kill-doubt-idea gate-note now references forge-idea.md"
verbs="$(grep '^| `/flow' "$SKILL_DIR/references/command-dispatch.md" | grep -v '^| `/flow` |' | sed -E 's/^\| `\/flow ([a-zA-Z_-]+)[^`]*`.*/\1/'; printf 'status\n')"
printf '%s\n' "$verbs" | grep -qx -- "$act" && { echo "  ok   [kill-doubt-idea action ('$act') is still an existing dispatcher verb]"; pass=$((pass+1)); } || { echo "  FAIL [kill-doubt-idea action ('$act') is NOT a dispatcher verb]"; fail=$((fail+1)); }
bad_cols=$(tail -n +2 "$CATALOG" 2>/dev/null | awk -F'\t' 'NF!=6{c++} END{print c+0}')
ck "0" "$bad_cols" "catalog still holds the 6-column contract"

echo "F) SKILL.md references the ritual + attribution"
sk="$(cat "$SKILLMD" 2>/dev/null)"
has "$sk" "forge-idea.md" "SKILL.md points to forge-idea.md"
has "$sk" "BMAD-METHOD" "SKILL.md attribution still names BMAD-METHOD"

echo "G) run_all.sh registers this suite (self-guard, red-team F7)"
has "$(cat "$HERE/run_all.sh" 2>/dev/null)" "test_flow_forge_idea.sh" "run_all.sh lists test_flow_forge_idea.sh"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
exit $?

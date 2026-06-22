#!/usr/bin/env bash
# Regression suite for the monorepo dual-root guard (Fix B): running flow from a subdir of an
# existing flow project must ADOPT the ancestor root, not silently mint a second .flow root.
# Run: bash tests/test_flow_monorepo_root.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

# Parent flow project with a flow/ planning dir; a frontend/ subdir with no flow state of its own.
newsb() { SB="$(mktemp -d)"; mkdir -p "$SB/flow" "$SB/frontend/src"; printf '# 00\n## Gate\n- [x] ok\n\nx.\n' > "$SB/flow/00-idea.md"; }

echo "A) from a subdir with no flow/ -> ADOPT the ancestor root + stderr note"
newsb
out="$( cd "$SB/frontend" && unset FLOW_PROJECT_ROOT; bash "$RUN" status 2>&1 )"
has "$out" "note: using flow root" "prints adoption note to stderr"
has "$out" "project: $SB" "status resolves to the ANCESTOR project, not the subdir"
no  "$out" "project: $SB/frontend" "does NOT mint a child root at the subdir"
# and no second .flow was created under frontend/
ck 1 "$([ -d "$SB/frontend/.flow" ] && echo 0 || echo 1)" "no second .flow root created under frontend/"
rm -rf "$SB"

echo "B) subdir WITH its own flow/ (deliberate sub-project) -> NOT adopted"
newsb; mkdir -p "$SB/frontend/flow"
out="$( cd "$SB/frontend" && unset FLOW_PROJECT_ROOT; bash "$RUN" status 2>&1 )"
no  "$out" "note: using flow root" "deliberate sub-project is left alone (no adoption)"
has "$out" "project: $SB/frontend" "sub-project keeps its own root"
rm -rf "$SB"

echo "C) explicit FLOW_PROJECT_ROOT always wins (no adoption walk)"
newsb
out="$( cd "$SB/frontend" && FLOW_PROJECT_ROOT="$SB/frontend" bash "$RUN" status 2>&1 )"
no  "$out" "note: using flow root" "override suppresses the adoption walk"
has "$out" "project: $SB/frontend" "override root respected"
rm -rf "$SB"

echo "D) a standalone dir NOT under any flow project -> stays itself (no false adoption)"
SB="$(mktemp -d)"; mkdir -p "$SB/plain"
out="$( cd "$SB/plain" && unset FLOW_PROJECT_ROOT; bash "$RUN" status 2>&1 )"
no  "$out" "note: using flow root" "no adoption when no ancestor is a flow project"
rm -rf "$SB"

echo "E) DECOY: ancestor has a bare flow/ dir but NO stage artifact -> must NOT adopt (real-signature guard)"
SB="$(mktemp -d)"; mkdir -p "$SB/flow" "$SB/deep/sub"   # flow/ exists but is EMPTY (no 00-idea.md, no .flow/, no cards)
out="$( cd "$SB/deep/sub" && unset FLOW_PROJECT_ROOT; bash "$RUN" status 2>&1 )"
no  "$out" "note: using flow root" "a bare flow/ folder (e.g. ~/flow) is NOT a flow project — no adoption"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

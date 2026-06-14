#!/usr/bin/env bash
# Regression suite for F2: brownfield assessment mode (flow.sh assess + flow/00-inspect.md).
# Run: bash tests/test_flow_assess.sh
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
exists() { [ -f "$1" ] && echo 0 || echo 1; }
newsb() { SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; }
clean_inspect() {
  mkdir -p "$SB/flow"
  cat > "$SB/flow/00-inspect.md" <<'EOF'
# Stage 00-inspect — Brownfield assessment
## Gate
- [x] stack detected
- [x] components mapped
- [x] functionality assessed with evidence
- [x] ui/ux assessed
- [x] risks listed
- [x] tests noted
- [x] human reviewed
- [x] no fill remains
## What this product is
A real existing product, assessed from the code.
## Verdict
Healthy enough to build on; fix X first.
EOF
}

echo "A) assess scaffolds flow/00-inspect.md + seeds an auto-scan"
newsb
printf '{"name":"x"}\n' > "$SB/package.json"; mkdir -p "$SB/.github/workflows"
out="$(bash "$RUN" assess 2>&1)"; ck 0 $? "assess exit 0"
has "$out" "created" "creates the assessment artifact"
ck 0 "$(exists "$SB/flow/00-inspect.md")" "flow/00-inspect.md created"
has "$(cat "$SB/flow/00-inspect.md")" "node (package.json)" "auto-scan detected node"
has "$(cat "$SB/flow/00-inspect.md")" "github actions" "auto-scan detected CI"
rm -rf "$SB"

echo "B) unfilled template -> gate NOT clean (exit 1)"
newsb
bash "$RUN" assess >/dev/null 2>&1   # first call creates the template
out="$(bash "$RUN" assess 2>&1)"; rc=$?
ck 1 "$rc" "exit 1 on unfilled assessment"
has "$out" "not clean" "gate flagged as not clean"
rm -rf "$SB"

echo "C) filled assessment -> gate clean (exit 0)"
newsb; clean_inspect
out="$(bash "$RUN" assess 2>&1)"; rc=$?
ck 0 "$rc" "exit 0 when assessment filled"
has "$out" "gate clean" "passes when the gate is satisfied"
rm -rf "$SB"

echo "D) status surfaces the brownfield assessment + its gate state"
newsb; clean_inspect
out="$(bash "$RUN" status 2>&1)"
has "$out" "brownfield: assessment present" "status shows the assessment"
has "$out" "gate clean" "status shows the gate state"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

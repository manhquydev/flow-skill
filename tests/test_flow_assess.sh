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

echo "E) assess seeds a RANKED repo-map; the widely-referenced file ranks"
newsb
mkdir -p "$SB/src"
printf 'def shared_helper():\n    return 1\n' > "$SB/src/core.py"
for i in 1 2 3 4; do printf 'from core import shared_helper\nx = shared_helper()\nshared_helper()\n' > "$SB/src/user$i.py"; done
out="$(bash "$RUN" assess 2>&1)"; ck 0 $? "assess exit 0 with a src tree"
insp="$(cat "$SB/flow/00-inspect.md")"
has "$insp" "ranked surfaces" "ranked-surfaces section seeded into 00-inspect.md"
has "$insp" "src/core.py" "the widely-referenced file is ranked"
rm -rf "$SB"

echo "F) assess with no rankable source -> graceful note, still exit 0 (fallback never errors)"
newsb
printf '{"name":"x"}\n' > "$SB/package.json"
out="$(bash "$RUN" assess 2>&1)"; ck 0 $? "assess exit 0 with no source files"
insp="$(cat "$SB/flow/00-inspect.md")"
has "$insp" "ranked surfaces" "ranked-surfaces line present even with no source"
if printf '%s' "$insp" | grep -qE "no rankable source symbols|ranking unavailable"; then
  echo "  ok   [graceful no-source note]"; pass=$((pass+1))
else echo "  FAIL [graceful no-source note]"; fail=$((fail+1)); fi
rm -rf "$SB"

echo "G) ranker excludes non-unique + stopword symbols (only meaningful surfaces rank)"
py="$(command -v python || command -v python3 || true)"
if [ -n "$py" ]; then
  RM="$HERE/../skills/flow/harness/repo_map.py"
  SB="$(mktemp -d)"; mkdir -p "$SB/src"
  printf 'def helper():\n    return 1\n' > "$SB/src/a.py"      # 'helper' defined twice -> non-unique
  printf 'def helper():\n    return 2\n' > "$SB/src/b.py"
  printf 'def main():\n    helper()\n' > "$SB/src/c.py"        # 'main' is a stopword
  printf 'def compute_invoice_total():\n    return 0\n' > "$SB/src/core.py"
  for i in 1 2 3; do printf 'from core import compute_invoice_total\ncompute_invoice_total()\n' > "$SB/src/u$i.py"; done
  out="$("$py" "$RM" "$SB" 10)"
  has "$out" "src/core.py" "unique, widely-referenced symbol ranks"
  if printf '%s' "$out" | grep -qE "src/a\.py|src/b\.py"; then echo "  FAIL [non-unique 'helper' definer excluded]"; fail=$((fail+1)); else echo "  ok   [non-unique 'helper' definer excluded]"; pass=$((pass+1)); fi
  if printf '%s' "$out" | grep -q "src/c\.py"; then echo "  FAIL [stopword 'main' definer excluded]"; fail=$((fail+1)); else echo "  ok   [stopword 'main' definer excluded]"; pass=$((pass+1)); fi
  rm -rf "$SB"
else
  echo "  SKIP: no python"
fi

echo "H) ranker detects TS typed-arrow consts (const NAME: Type = ) not just bare const NAME ="
py="$(command -v python || command -v python3 || true)"
if [ -n "$py" ]; then
  RM="$HERE/../skills/flow/harness/repo_map.py"
  SB="$(mktemp -d)"; mkdir -p "$SB/src"
  printf 'export const resolveTenantScope: RequestHandler = async (req) => {\n  return req;\n};\n' > "$SB/src/core.ts"
  for i in 1 2 3; do printf 'import { resolveTenantScope } from "./core";\nresolveTenantScope();\n' > "$SB/src/u$i.ts"; done
  out="$("$py" "$RM" "$SB" 10)"
  has "$out" "src/core.ts" "typed-arrow const definer ranks (regression: colon-annotation no longer hides it)"
  rm -rf "$SB"
else
  echo "  SKIP: no python"
fi

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

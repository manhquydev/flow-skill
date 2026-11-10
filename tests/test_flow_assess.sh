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
- [x] Every material claim in this assessment is tagged in the Evidence ledger
- [x] no fill remains
## What this product is
A real existing product, assessed from the code.
## Evidence ledger (claims)
| Claim | Tag | Source (path or "none") |
|-------|-----|-------------------------|
| package.json names the app | Observed | package.json:1 |
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
insp="$(cat "$SB/flow/00-inspect.md")"
has "$insp" "node (package.json)" "auto-scan detected node"
has "$insp" "github actions" "auto-scan detected CI"
has "$insp" "Evidence ledger" "scaffold has Evidence ledger"
has "$insp" "Authoritative" "scaffold has Authoritative tag vocab"
has "$insp" "Decision required" "scaffold has Decision required tag vocab"
has "$insp" "material claim" "scaffold has claim-tagging gate checkbox"
rm -rf "$SB"
echo "A2) polyglot scan: monorepo workspaces, dev compose, odoo addons, subdir python"
newsb
printf '{"name":"x"}\n' > "$SB/package.json"
mkdir -p "$SB/.github/workflows"
mkdir -p "$SB/src/odoo/addons/alpha" "$SB/src/odoo/addons/beta"
touch "$SB/src/odoo/addons/alpha/__manifest__.py"
touch "$SB/src/odoo/addons/beta/__manifest__.py"
touch "$SB/pnpm-workspace.yaml"
touch "$SB/docker-compose.dev.yml"
mkdir -p "$SB/src/svc"
touch "$SB/src/svc/main.py"
out="$(bash "$RUN" assess 2>&1)"; ck 0 $? "assess exit 0 on polyglot repo"
ck 0 "$(exists "$SB/flow/00-inspect.md")" "flow/00-inspect.md created"
insp="$(cat "$SB/flow/00-inspect.md")"
has "$insp" "node (package.json)" "auto-scan detected node"
has "$insp" "github actions" "auto-scan detected CI"
has "$insp" "odoo (2 addons)" "auto-scan detected odoo with 2 addons"
has "$insp" "monorepo (workspaces)" "auto-scan detected monorepo workspaces"
has "$insp" "docker" "auto-scan detected docker via dev compose"
has "$insp" "python (subdirectories)" "auto-scan detected subdir python"
rm -rf "$SB"

echo "A3) subdir pyproject and compose v2 defaults detected without root/other signals"
newsb
mkdir -p "$SB/apps/api"
touch "$SB/apps/api/pyproject.toml"
touch "$SB/compose.yaml"
out="$(bash "$RUN" assess 2>&1)"; ck 0 $? "assess exit 0 on apps-only repo"
insp="$(cat "$SB/flow/00-inspect.md")"
has "$insp" "python (subdirectories)" "auto-scan detected subdir pyproject/requirements"
has "$insp" "docker" "auto-scan detected compose v2 default filename"
rm -rf "$SB"

echo "A4) composer.yml alone does not report docker (glob must not overmatch)"
newsb
touch "$SB/composer.yml"
out="$(bash "$RUN" assess 2>&1)"; ck 0 $? "assess exit 0 with composer.yml"
insp="$(cat "$SB/flow/00-inspect.md")"
printf '%s' "$insp" | grep -q "  - docker"
ck 1 $? "composer.yml alone does not produce docker line"
rm -rf "$SB"

echo "A5) status directs dirty assessments to assess; next unlocks idea only once clean"
newsb
printf '{"name":"x"}\n' > "$SB/package.json"; mkdir -p "$SB/.github/workflows"
out="$(bash "$RUN" assess 2>&1)"; ck 0 $? "assess creates dirty assessment"
out="$(bash "$RUN" status 2>&1)"; ck 0 $? "status exits 0 on dirty assessment"
has "$out" "brownfield: assessment present but gate NOT clean" "status identifies dirty assessment gate"
has "$out" "NEXT -> run '/flow assess'" "NEXT recommends assessment correction"
has "$out" "NEXT_VERB=none" "assessment correction preserves the closed advisory enum"
has "$out" "planning: not started" "planning has not started"
has "$out" "  -> run '/flow assess'" "planning guidance recommends assessment correction"
printf '%s' "$out" | grep -q "run '/flow next' to unlock stage 00"
ck 1 $? "dirty status never recommends next to unlock stage 00"
out="$(bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" "next exits 1 on dirty assessment"
has "$out" "FAIL" "next reports gate failure"
has "$out" "brownfield.*00-inspect" "next identifies the brownfield assessment"
ck 1 "$(exists "$SB/flow/00-idea.md")" "dirty assessment does not create 00-idea"
clean_inspect
out="$(bash "$RUN" status 2>&1)"; ck 0 $? "status exits 0 on clean assessment"
has "$out" "NEXT -> run '/flow next' to unlock stage 00" "clean assessment NEXT recommends next"
has "$out" "NEXT_VERB=next" "clean assessment next verb is next"
has "$out" "  -> run '/flow next' to unlock stage 00 (idea)" "clean planning guidance recommends next"
out="$(bash "$RUN" next 2>&1)"; rc=$?
ck 0 "$rc" "next exits 0 on clean assessment"
ck 0 "$(exists "$SB/flow/00-idea.md")" "clean assessment unlocks 00-idea"
rm -rf "$SB"

echo "A6) no-assessment status keeps greenfield next guidance"
newsb
out="$(bash "$RUN" status 2>&1)"; ck 0 $? "status exits 0 without an assessment"
has "$out" "NEXT -> run '/flow next' to unlock stage 00" "greenfield NEXT recommends next"
has "$out" "NEXT_VERB=next" "greenfield next verb is next"
has "$out" "  -> run '/flow next' to unlock stage 00 (idea)" "greenfield planning guidance recommends next"
ck 1 "$(exists "$SB/flow/00-inspect.md")" "status does not create an assessment"
out="$(bash "$RUN" next 2>&1)"; ck 0 $? "next exits 0 without an assessment"
ck 0 "$(exists "$SB/flow/00-idea.md")" "greenfield next unlocks 00-idea"
rm -rf "$SB"

echo "A7) hollow/sound fixtures govern planning completion and advancement"
for kind in unchecked supported; do
  newsb
  mkdir -p "$SB/flow"
  cp "$HERE/../skills/flow/eval/fixtures/b00_$kind/flow/00-inspect.md" "$SB/flow/00-inspect.md"
  for stage in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
    printf '# Completed stage\n- [x] Reviewed\n' > "$SB/flow/$stage.md"
  done
  out="$(bash "$RUN" next 2>&1)"; rc=$?
  if [ "$kind" = unchecked ]; then
    ck 1 "$rc" "hollow inspect blocks next after planning starts"
    has "$out" "'/flow assess'" "next directs assessment repair"
    out="$(bash "$RUN" status 2>&1)"
    has "$out" "NEXT -> run '/flow assess'" "dirty inspect wins over completed stages"
    out="$(bash "$RUN" card 2>&1)"; ck 1 $? "dirty inspect prevents planning completion"
    printf '%s\n' '- [ ] DEBT: skip 01-research' > "$SB/DEBT.md"
    out="$(bash "$RUN" skip 00-inspect --reason 'defer assessment' 2>&1)"; ck 1 $? "unrelated debt cannot skip assessment"
    printf '%s\n' '- [ ] DEBT: skip 00-inspect' > "$SB/DEBT.md"
    out="$(bash "$RUN" skip 00-inspect --reason 'defer assessment' 2>&1)"; ck 0 $? "stage-matched debt permits explicit assessment skip"
    out="$(bash "$RUN" next 2>&1)"; ck 0 $? "explicit assessment skip permits completion"
  else
    ck 0 "$rc" "sound inspect permits completion"
    has "$out" "COMPLETE" "sound fixture reaches planning completion"
  fi
  rm -rf "$SB"
done


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

echo "I) flow next blocks dirty assessments; clean, debt-skipped or absent assessments agree with status/resume"
for assessment in dirty clean debt-skipped absent; do
  newsb
  case "$assessment" in
    dirty|debt-skipped)
      out="$(bash "$RUN" assess 2>&1)"; ck 0 $? "I: $assessment scaffolds assessment"
      if [ "$assessment" = debt-skipped ]; then
        printf '%s\n' '- [ ] DEBT: skip 00-inspect' > "$SB/DEBT.md"
        out="$(bash "$RUN" skip 00-inspect --reason 'defer assessment' 2>&1)"; ck 0 $? "I: records explicit assessment skip"
      fi
      ;;
    clean) clean_inspect ;;
  esac
  if [ "$assessment" = dirty ]; then
    expected_next="run '/flow assess'"
    expected_verb=none
  else
    expected_next="run '/flow next' to unlock stage 00"
    expected_verb=next
  fi
  for surface in status resume; do
    out="$(bash "$RUN" "$surface" 2>&1)"; ck 0 $? "I: $assessment $surface exits 0"
    case "$surface" in
      status) expected_prefix="NEXT ->" ;;
      resume) expected_prefix="nothing to resume -" ;;
    esac
    has "$out" "$expected_prefix $expected_next" "I: $assessment $surface agrees with assessment gate"
    has "$out" "NEXT_VERB=$expected_verb" "I: $assessment $surface advisory agrees"
  done
  out="$(bash "$RUN" next 2>&1)"; rc=$?
  if [ "$assessment" = dirty ]; then
    ck 1 "$rc" "I: dirty assessment blocks next"
    has "$out" "FAIL: brownfield assessment gate for flow/00-inspect.md is not clean." "I: failure identifies assessment gate"
    has "$out" "run '/flow assess' again" "I: failure directs assessment repair"
    ck 1 "$(exists "$SB/flow/00-idea.md")" "I: dirty assessment does not unlock idea"
  else
    ck 0 "$rc" "I: $assessment assessment permits next"
    has "$out" "PASS: unlocked stage 00" "I: $assessment assessment reports unlocked stage"
    ck 0 "$(exists "$SB/flow/00-idea.md")" "I: $assessment assessment unlocks idea"
    if [ "$assessment" = absent ]; then
      ck 1 "$(exists "$SB/flow/00-inspect.md")" "I: greenfield next does not create assessment"
    fi
  fi
  rm -rf "$SB"
done

echo "J) Stage 00 manifest pair enters the real evaluator through offline replay"
newsb
EVAL_DIR="$HERE/../skills/flow/eval"
SCRIPT_DIR="$HERE/../skills/flow/runner"
# Load only read-only prompt/hash helpers, not dispatch or either eval STOP body.
for helper in _eval_heading_pattern _eval_extract_section _eval_build_prompt _eval_gate_rules_files _eval_gate_rules_sha; do
  eval "$(sed -n "/^${helper}()/,/^}/p" "$RUN")"
done
rows="$(awk -F '\t' '$2 == "00-inspect" { n++ } END { print n+0 }' "$EVAL_DIR/manifest.tsv")"
ck 2 "$rows" "manifest census contains both Stage 00 fixtures"
for entry in b00_unchecked:FLAG b00_supported:PASS; do
  fid="${entry%:*}"; expected="${entry#*:}"
  row="$(awk -F '\t' -v id="$fid" '$1 == id { print $2 ":" $3 ":" $4 }' "$EVAL_DIR/manifest.tsv")"
  ck "00-inspect:flow/00-inspect.md:$expected" "$row" "$fid registered with discriminating verdict"
  _eval_build_prompt "$SB/$fid.prompt" 00 "$EVAL_DIR/fixtures/$fid/flow/00-inspect.md" offline00
  ck 0 $? "$fid builds a nonempty Stage 00 prompt"
  prompt="$(cat "$SB/$fid.prompt")"
  has "$prompt" "Stage 00.*Idea" "idea challenge retained in Stage 00 route"
  has "$prompt" "Brownfield inspection prerequisite" "$fid receives brownfield challenge"
  has "$prompt" "An existing assessment must be clean" "$fid prompt enforces assessment prerequisite"
  has "$prompt" "Existing behavior has been inspected" "$fid artifact is inlined"
done
# Synthetic verdicts exercise routing/parser/mismatch enforcement, not a live judge.
replay="$SB/replay"
mkdir -p "$replay/b00-unchecked" "$replay/b00-supported"
printf 'nonce=offline00\ngate_rules_sha=%s\nmodel=synthetic\nn=1\n' "$(_eval_gate_rules_sha)" > "$replay/meta"
printf 'GATE-EVAL-offline00: FLAG\n' > "$replay/b00-unchecked/1.txt"
printf 'GATE-EVAL-offline00: PASS\n' > "$replay/b00-supported/1.txt"
out="$(FLOW_EVAL_REPLAY_DIR="$replay" bash "$RUN" eval --stage 00 --replay --n 1 2>&1)"; ck 0 $? "Stage 00 replay accepts correct pair"
has "$out" "b00_unchecked (00-inspect): FLAG - matches expected FLAG" "hollow enters evaluator and is flagged"
has "$out" "b00_supported (00-inspect): PASS - matches expected PASS" "sound enters evaluator and passes"
has "$out" "all 2 evaluated fixture(s)" "both manifest rows actually evaluated"
printf 'GATE-EVAL-offline00: PASS\n' > "$replay/b00-unchecked/1.txt"
out="$(FLOW_EVAL_REPLAY_DIR="$replay" bash "$RUN" eval --stage 00 --replay --n 1 2>&1)"; ck 1 $? "hollow false PASS fails replay"
has "$out" "MISMATCH, expected FLAG" "hollow expected verdict enforced"
printf 'GATE-EVAL-offline00: FLAG\n' > "$replay/b00-unchecked/1.txt"
printf 'GATE-EVAL-offline00: FLAG\n' > "$replay/b00-supported/1.txt"
out="$(FLOW_EVAL_REPLAY_DIR="$replay" bash "$RUN" eval --stage 00 --replay --n 1 2>&1)"; ck 1 $? "sound false FLAG fails replay"
has "$out" "MISMATCH, expected PASS" "sound expected verdict enforced"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

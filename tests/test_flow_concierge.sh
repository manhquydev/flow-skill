#!/usr/bin/env bash
# Regression suite for v0.22 Phase 1: concierge conversational entry — the chat-first
# default front-door to /flow (references/concierge.md + references/flow-catalog.tsv +
# the SKILL.md pointer). Run: bash tests/test_flow_concierge.sh (Git Bash on Windows or
# any POSIX bash). Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$HERE/../skills/flow"
CONCIERGE="$SKILL_DIR/references/concierge.md"
CATALOG="$SKILL_DIR/references/flow-catalog.tsv"
DISPATCH="$SKILL_DIR/references/command-dispatch.md"
SKILLMD="$SKILL_DIR/SKILL.md"

pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q -- "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q -- "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

echo "A) required files exist"
if [ -f "$CONCIERGE" ]; then echo "  ok   [concierge.md exists]"; pass=$((pass+1)); else echo "  FAIL [concierge.md exists]"; fail=$((fail+1)); fi
if [ -f "$CATALOG" ]; then echo "  ok   [flow-catalog.tsv exists]"; pass=$((pass+1)); else echo "  FAIL [flow-catalog.tsv exists]"; fail=$((fail+1)); fi

cc="$(cat "$CONCIERGE" 2>/dev/null)"

echo "B) concierge.md structural markers"
has "$cc" "## Entry loop" "entry loop section"
has "$cc" "May-run" "may-run section"
has "$cc" "Must-ask" "must-ask section"
has "$cc" "Default-deny" "default-deny rule present"
has "$cc" "any verb not explicitly listed under May-run above is must-ask" "default-deny sentence literal"
has "$cc" "mode work" "mode-work consent path documented"
has "$cc" "BMAD-METHOD" "bmad-help attribution present"
has "$cc" "MIT" "MIT license mention present"

echo "C) next is must-ask, not may-run (red-team F2)"
mayrun_block="$(awk '/\*\*May-run/,/\*\*Must-ask/' "$CONCIERGE" 2>/dev/null)"
mustask_block="$(awk '/\*\*Must-ask/,/\*\*Default-deny/' "$CONCIERGE" 2>/dev/null)"
has "$mustask_block" "^- next$" "next listed under must-ask"
no "$mayrun_block" "^- next$" "next NOT listed under may-run"

echo "D) may-run/must-ask covers every dispatcher verb exactly once (red-team F1)"
verbs_body="$(grep '^| `/flow' "$DISPATCH" | grep -v '^| `/flow` |' | sed -E 's/^\| `\/flow ([a-zA-Z_-]+)[^`]*`.*/\1/')"
verbs="$(printf '%s\nstatus\n' "$verbs_body" | sort -u)"
n_verbs=0; n_covered=0; problems=""
for v in $verbs; do
  n_verbs=$((n_verbs+1))
  in_may=0; in_must=0
  printf '%s\n' "$mayrun_block" | grep -qx -- "- $v" && in_may=1
  printf '%s\n' "$mustask_block" | grep -qx -- "- $v" && in_must=1
  hits=$((in_may + in_must))
  if [ "$hits" -eq 1 ]; then n_covered=$((n_covered+1))
  else problems="$problems $v(hits=$hits)"
  fi
done
ck "$n_verbs" "$n_covered" "every dispatcher verb ($n_verbs total) classified exactly once${problems:+ [problems:$problems]}"

echo "E) high-risk verbs are must-ask (promote/harness/auto/skip/next)"
for v in promote harness auto skip next; do
  has "$mustask_block" "^- $v$" "$v is must-ask"
done

echo "F) SKILL.md references the conversational entry"
sk="$(cat "$SKILLMD" 2>/dev/null)"
has "$sk" "concierge.md" "SKILL.md points to concierge.md"
has "$sk" "flow-catalog.tsv" "SKILL.md points to flow-catalog.tsv"

echo "G) catalog TSV shape"
header="$(head -n1 "$CATALOG" 2>/dev/null)"
expected_header="$(printf 'intent-class\tstate-precondition\taction\tgate-note\tenrich-if-present\tsource')"
ck "$expected_header" "$header" "TSV header exact match (tab-separated, 6 columns)"
nrows=$(tail -n +2 "$CATALOG" 2>/dev/null | grep -c '.' || true)
if [ "${nrows:-0}" -ge 12 ]; then echo "  ok   [>=12 data rows ($nrows)]"; pass=$((pass+1)); else echo "  FAIL [>=12 data rows, got ${nrows:-0}]"; fail=$((fail+1)); fi
bad_cols=$(tail -n +2 "$CATALOG" 2>/dev/null | awk -F'\t' 'NF!=6{c++} END{print c+0}')
ck "0" "$bad_cols" "every row has exactly 6 tab-separated columns"
empty_cells=$(tail -n +2 "$CATALOG" 2>/dev/null | awk -F'\t' '$1==""||$3==""{c++} END{print c+0}')
ck "0" "$empty_cells" "no empty intent-class/action cells"

echo "H) every catalog action resolves to an existing dispatcher verb (Phase-1 invariant)"
bad_actions=""
while IFS= read -r a; do
  [ -z "$a" ] && continue
  printf '%s\n' "$verbs" | grep -qx -- "$a" || bad_actions="$bad_actions $a"
done < <(tail -n +2 "$CATALOG" 2>/dev/null | awk -F'\t' '{print $3}' | sed -E 's/ .*//' | sort -u)
ck "" "$bad_actions" "all catalog actions are existing verbs${bad_actions:+ [unknown:$bad_actions]}"

echo "I) routing spot-checks (>=5 utterance-mapped intent-classes with correct action)"
check_route() { # $1=intent-class $2=expected action
  row="$(awk -F'\t' -v k="$1" '$1==k{print}' "$CATALOG" 2>/dev/null)"
  act="$(printf '%s' "$row" | awk -F'\t' '{print $3}' | sed -E 's/ .*//')"
  ck "$2" "$act" "intent-class $1 routes to action '$2'"
}
check_route "resume-where-am-i" "resume"
check_route "what-next" "status"
check_route "check-card-done" "check"
check_route "retro-ask" "retro"
check_route "usage-metrics-ask" "usage"

echo "J) run_all.sh registers this suite (self-guard, red-team F7)"
has "$(cat "$HERE/run_all.sh" 2>/dev/null)" "test_flow_concierge.sh" "run_all.sh lists test_flow_concierge.sh"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
exit $?

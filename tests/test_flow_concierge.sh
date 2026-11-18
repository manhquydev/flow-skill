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

echo "J) manifest.txt registers this suite (self-guard, red-team F7)"
has "$(cat "$HERE/manifest.txt" 2>/dev/null)" "test_flow_concierge.sh" "manifest.txt lists test_flow_concierge.sh"

has_lit() { if printf '%s' "$1" | grep -Fq -- "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing literal: $2)"; fail=$((fail+1)); fi; }
no_lit()  { if printf '%s' "$1" | grep -Fq -- "$2"; then echo "  FAIL [$3] (unexpected literal: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

echo "K) bilingual EN/VI plain-language dictionary & inclusive pronoun contract"
has_lit "$cc" "## Plain-language dictionary" "concierge.md has plain-language dictionary section"
has_lit "$cc" '`gate` & `Kill at a gate`' "dictionary defines gate & Kill at a gate"
has_lit "$cc" "KHÔNG phải" "dictionary clarifies Kill at a gate does not delete files (VI)"
has_lit "$cc" '`card` (`C-001`)' "dictionary defines card"
has_lit "$cc" '`ADR` (`flow/04-adr.md`)' "dictionary defines ADR"
has_lit "$cc" '`contract / seam`' "dictionary defines contract / seam"
has_lit "$cc" '`world-state done-evidence`' "dictionary defines world-state done-evidence"
has_lit "$cc" '`worktree / workspace`' "dictionary defines worktree / workspace"
has_lit "$cc" '`receipt / attest`' "dictionary defines receipt / attest"
has_lit "$cc" '"bạn"' "concierge.md uses inclusive Vietnamese pronoun bạn"
no_lit "$cc" "anh duyệt" "zero 'anh duyệt' pronoun bias in concierge.md"
no_lit "$cc" "anh có muốn" "zero 'anh có muốn' pronoun bias in concierge.md"

echo "L) gate-FAIL coaching preserves rigor (never softens FAIL) & filters host metadata"
has_lit "$cc" "## Coaching on gate FAILs" "concierge.md has gate-FAIL coaching section"
has_lit "$cc" 'Mechanical `FAIL` → `STOP`' "concierge.md preserves hard mechanical FAIL -> STOP"
has_lit "$cc" 'Never soften a `FAIL`' "concierge.md forbids softening mechanical FAIL"
has_lit "$cc" '[FILL: ...]' "concierge.md coaches [FILL: ...] bracket replacement"
has_lit "$cc" '- [x]' "concierge.md coaches - [x] checkbox completion"
has_lit "$cc" 'done-evidence' "concierge.md coaches world-state done-evidence"
has_lit "$cc" '/flow mode work' "concierge.md offers /flow mode work when stuck in teach"
has_lit "$cc" 'PIN v1' "concierge.md addresses PIN v1"
has_lit "$cc" 'host-internal metadata' "concierge.md treats PIN v1 as host-internal metadata"
has_lit "$sk" 'FAIL → STOP' "SKILL.md preserves FAIL -> STOP in dispatch rules"
has_lit "$sk" '[FILL]' "SKILL.md dispatch rules translate [FILL]"
has_lit "$sk" '- [x]' "SKILL.md dispatch rules translate - [x]"
has_lit "$sk" 'done-evidence' "SKILL.md dispatch rules translate done-evidence"
has_lit "$sk" '/flow mode work' "SKILL.md offers /flow mode work when stuck in teach"
has_lit "$sk" 'never dump `PIN v1` as user prose' "SKILL.md keeps PIN v1 host-internal"

echo "M) mode-work non-coder interview & scope sign-off guidance"
MODE_WORK="$SKILL_DIR/references/mode-work.md"
mw="$(cat "$MODE_WORK" 2>/dev/null)"
has_lit "$mw" "no preference / pick for me / bạn chọn giúp mình" "mode-work.md welcomes no-preference / pick-for-me stack answer"
has_lit "$mw" "beginner-friendly stack" "mode-work.md instructs choosing a simple beginner-friendly stack"
has_lit "$mw" "translate Flow shorthand into everyday EN/VI words" "mode-work.md translates scope shorthand before sign-off"
has_lit "$mw" '`Impact H/M/L`' "mode-work.md explains Impact H/M/L"
has_lit "$mw" '`Grade A/B/C`' "mode-work.md explains Grade A/B/C"
has_lit "$mw" '`GO/KILL`' "mode-work.md explains GO/KILL"

echo "N) front-door README EN/VI onboarding & deferred runner spec"
REPO_ROOT="$HERE/.."
rm_en="$(cat "$REPO_ROOT/README.md" 2>/dev/null)"
rm_vn="$(cat "$REPO_ROOT/README_VN.md" 2>/dev/null)"
DEF_SPEC="$REPO_ROOT/docs/deferred-runner-ux-proposals.md"
def_doc="$(cat "$DEF_SPEC" 2>/dev/null)"
has_lit "$rm_en" "## In plain words" "README.md includes ## In plain words intro"
has_lit "$rm_en" "/flow I want to build" "README.md includes concrete /flow chat example"
has_lit "$rm_en" "Git Bash" "README.md documents Windows Git Bash prerequisite"
has_lit "$rm_en" ">= 3.7" "README.md documents Python >= 3.7 prerequisite"
has_lit "$rm_en" "## Key terms in plain words" "README.md includes key-terms decoder"
has_lit "$rm_vn" "## Hiểu đơn giản" "README_VN.md includes ## Hiểu đơn giản intro"
has_lit "$rm_vn" "/flow mình muốn làm" "README_VN.md includes concrete /flow VI chat example"
has_lit "$rm_vn" "Git Bash" "README_VN.md documents Windows Git Bash prerequisite"
has_lit "$rm_vn" ">= 3.7" "README_VN.md documents Python >= 3.7 prerequisite"
has_lit "$rm_vn" "## Giải nghĩa nhanh thuật ngữ" "README_VN.md includes VI key-terms decoder"
if [ -f "$DEF_SPEC" ]; then echo "  ok   [docs/deferred-runner-ux-proposals.md exists]"; pass=$((pass+1)); else echo "  FAIL [docs/deferred-runner-ux-proposals.md exists]"; fail=$((fail+1)); fi
has_lit "$def_doc" "skills/flow/runner/flow.sh" "deferred spec documents flow.sh proposals"
has_lit "$def_doc" "skills/flow/runner/flow.cmd" "deferred spec documents flow.cmd proposals"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
exit $?

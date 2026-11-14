#!/usr/bin/env bash
# Docs/skills contract: authority honesty + non-negotiable trust greps (plan 260811-1405).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../skills/flow"
pass=0; fail=0
ok() { echo "  ok   [$1]"; pass=$((pass+1)); }
bad() { echo "  FAIL [$1]"; fail=$((fail+1)); }

echo "A) live authority ownership (flow-owned durable; no live trust-pin table)"
for f in "$ROOT/harness/README.md" "$ROOT/harness/GAP-MATRIX-0.1.17.md"; do
  test -f "$f" || { bad "missing $f"; continue; }
  grep -qiE 'flow-owned|live authority' "$f" && ok "flow-owned/live authority in $(basename "$f")" || bad "flow-owned/live authority in $(basename "$f")"
  grep -qiE 'no (further )?schema sync|no upstream schema sync|SUPERSEDED' "$f" && ok "no-sync/supersede in $(basename "$f")" || bad "no-sync/supersede in $(basename "$f")"
done
# Ban live trust-pin table framing (historical mentions under Historical still OK in GAP)
if grep -E '^\| *Trust / consumer *\|' "$ROOT/harness/README.md" 2>/dev/null | grep -q '0\.1\.17'; then
  bad "README still has live Trust/consumer 0.1.17 table row"
else
  ok "README has no live Trust/consumer 0.1.17 table row"
fi

echo "B) no instructional bare story update --status implemented"
for f in "$ROOT/harness/README.md" "$ROOT/references/agent-stage-mapping.md" "$ROOT/references/auto-run.md" "$ROOT/SKILL.md"; do
  test -f "$f" || continue
  if grep -nE 'story update[[:space:]]+--status[[:space:]]+implemented' "$f" | grep -viE 'reject|never|forbidden|not |ban|do not'; then
    bad "bare update implemented recipe in $f"
  else
    ok "no bare implemented recipe in $(basename "$f")"
  fi
done

echo "C) complete guidance present"
grep -q 'story complete' "$ROOT/harness/README.md" && ok "story complete in README" || bad "story complete in README"
grep -q 'proof_source\|proof-source' "$ROOT/harness/README.md" && ok "proof-source in README" || bad "proof-source in README"

echo "D) in-repo canonical harness skill (complete-only; no live pin product claim)"
SK="$HERE/../skills/harness-skill/SKILL.md"
test -f "$SK" && ok "canonical harness skill exists" || bad "canonical harness skill missing"
if [ -f "$SK" ]; then
  grep -q 'story complete' "$SK" && ok "complete-only guidance" || bad "complete-only guidance"
  grep -qiE 'Forbidden:.*implemented|Forbidden.*story update' "$SK" && ok "forbidden implemented" || bad "forbidden implemented"
  grep -q 'proof-source\|proof_source' "$SK" && ok "proof-source in skill" || bad "proof-source in skill"
  grep -qiE '/flow harness|flow harness' "$SK" && ok "redirects to /flow harness" || bad "redirects to /flow harness"
  # Must not claim live trust pin as product
  if grep -qiE 'trust CLI \*\*`?harness-cli-v0\.1\.17|Pin CLI harness-cli-v0\.1\.17' "$SK"; then
    bad "harness-skill still claims live pin 0.1.17"
  else
    ok "harness-skill no live pin product claim"
  fi
fi

echo "E) SKILL.md harness bullet: no live pin framing"
if grep -E 'Pins: protocol floor `harness-cli-v0\.1\.14`' "$ROOT/SKILL.md" >/dev/null 2>&1; then
  bad "SKILL.md still has live Pins: protocol floor line"
else
  ok "SKILL.md harness bullet without live pin line"
fi
if grep -qiE 'flow-owned|R-IMPROVE|Improve-flow-harness' "$ROOT/SKILL.md"; then
  ok "SKILL links ownership or improve ritual"
else
  bad "SKILL must mention flow-owned or R-IMPROVE-HARNESS"
fi

echo "F) every flow.sh dispatch verb label is documented in command-dispatch.md"
# Extract the MAIN dispatch case block (after FLOW_LOG_START=, tolerating trailing
# comments/whitespace on `case "$cmd" in` and `esac`). Filter logic:
# - take only arms of the form `<word>|<word>) cmd_xxx`; alternation labels are split
#   on '|' and each alternative checked separately;
# - skip the empty-string alternative (`""`) - it documents `/flow` itself via the status row;
# - underscores in labels map to dashes (project-type) to match doc spelling;
# - match ONLY the first table cell (column 1 between first and second `|`) as `` `/flow <verb>` ``
#   or `` `/flow <verb> `` (with an explicit exception for default `status` -> `` `/flow` ``),
#   so unrelated words in column 3 (e.g. `converged` in `loop-log`) never mask a missing row;
# - fail closed if `$RUNNER`/`$DISPATCH_DOC` is missing or extracted verb count == 0.
RUNNER="$HERE/../skills/flow/runner/flow.sh"
DISPATCH_DOC="$HERE/../skills/flow/references/command-dispatch.md"

_extract_dispatch_verbs() {
  local runner_path="$1"
  awk '
    /^FLOW_LOG_START=/ { in_dispatch = 1 }
    in_dispatch && /^case "\$cmd" in([[:space:]]*(#.*)?)?$/ { in_case = 1; next }
    in_case && /^esac([[:space:]]*(#.*)?)?$/ { exit }
    in_case { print }
  ' "$runner_path" \
    | grep -E '^[[:space:]]*[a-z_"|-]+\)[[:space:]]+cmd_' \
    | sed -E 's/^[[:space:]]*//; s/\)[[:space:]]+cmd_.*$//' \
    | tr '|' '\n' \
    | sed -E 's/^"(.*)"$/\1/; /^""?$/d; /^$/d' \
    | sort -u
}

_check_dispatch_coverage() {
  local runner_path="$1" dispatch_doc="$2" quiet="${3:-0}"
  [ -f "$runner_path" ] || { [ "$quiet" -eq 0 ] && echo "  FAIL [runner missing: $runner_path]"; return 1; }
  [ -f "$dispatch_doc" ] || { [ "$quiet" -eq 0 ] && echo "  FAIL [dispatch doc missing: $dispatch_doc]"; return 1; }

  local verbs count
  verbs="$(_extract_dispatch_verbs "$runner_path")"
  count="$(printf '%s\n' "$verbs" | grep -c . || true)"
  if [ "$count" -eq 0 ]; then
    [ "$quiet" -eq 0 ] && echo "  FAIL [extracted 0 dispatch verbs from $runner_path]"
    return 1
  fi

  local col1 missing=0 label doc_label
  col1="$(awk -F'|' '/^\|/{print $2}' "$dispatch_doc")"
  while IFS= read -r label; do
    [ -n "$label" ] || continue
    doc_label="$(printf '%s' "$label" | tr '_' '-')"
    if [ "$doc_label" = "status" ]; then
      if ! printf '%s\n' "$col1" | grep -qE '`/flow(`|[[:space:]]+status([[:space:]`]|$))'; then
        [ "$quiet" -eq 0 ] && echo "  FAIL [default 'status' verb (/flow) missing from column 1 of command-dispatch.md]"
        missing=$((missing+1))
      fi
    else
      if ! printf '%s\n' "$col1" | grep -qE "\`/flow ${doc_label}([[:space:]\`]|$)"; then
        [ "$quiet" -eq 0 ] && echo "  FAIL [dispatch verb '$doc_label' missing from column 1 of command-dispatch.md]"
        missing=$((missing+1))
      fi
    fi
  done <<VERBS
$verbs
VERBS
  [ "$missing" -eq 0 ]
}

if _check_dispatch_coverage "$RUNNER" "$DISPATCH_DOC"; then
  verb_count="$(_extract_dispatch_verbs "$RUNNER" | wc -l | tr -d ' ')"
  ok "all $verb_count flow.sh dispatch verbs present in column 1 of command-dispatch.md"
else
  bad "dispatch verb coverage check failed"
fi

# Self-negative checks in disposable temp dir (must fail closed when wrong).
neg_tmp="$(mktemp -d)"
trap 'rm -rf "$neg_tmp"' EXIT

# Neg 1: removing `/flow converge` row from column 1 must FAIL (not masked by `converged` in loop-log).
grep -v '^| `/flow converge`' "$DISPATCH_DOC" > "$neg_tmp/dispatch-no-converge.md"
if _check_dispatch_coverage "$RUNNER" "$neg_tmp/dispatch-no-converge.md" 1; then
  bad "negative guard: missing /flow converge row unexpectedly passed"
else
  ok "negative guard: missing /flow converge row fails closed"
fi

# Neg 2: empty extracted verb list must FAIL (never vacuous pass).
printf 'FLOW_LOG_START=1\ncase "$cmd" in\nesac\n' > "$neg_tmp/empty-runner.sh"
if _check_dispatch_coverage "$neg_tmp/empty-runner.sh" "$DISPATCH_DOC" 1; then
  bad "negative guard: empty extracted verb list unexpectedly passed"
else
  ok "negative guard: empty extracted verb list fails closed"
fi

# Neg 3: trailing comment on `case "$cmd" in # dispatch` must still extract and pass.
sed 's/^case "\$cmd" in$/case "$cmd" in # dispatch/' "$RUNNER" > "$neg_tmp/commented-runner.sh"
if _check_dispatch_coverage "$neg_tmp/commented-runner.sh" "$DISPATCH_DOC" 1; then
  ok "resilience guard: trailing comment on case line still extracts all verbs"
else
  bad "resilience guard: trailing comment on case line broke extraction"
fi

rm -rf "$neg_tmp"
trap - EXIT

# H) argument-hint covers every dispatch verb parsed from flow.sh (no hard-coded list).
SKILL_MD="$HERE/../skills/flow/SKILL.md"
hint_line="$(grep '^argument-hint:' "$SKILL_MD")"
hint_missing=0
while IFS= read -r verb; do
  [ -n "$verb" ] || continue
  if ! printf '%s' "$hint_line" | grep -qE "(^|[ |[])${verb}([ |[]|\])"; then
    echo "  FAIL [dispatch verb '$verb' missing from argument-hint in SKILL.md]"
    hint_missing=$((hint_missing+1))
  fi
done <<HINTVERBS
$(_extract_dispatch_verbs "$RUNNER")
HINTVERBS
if [ "$hint_missing" -eq 0 ]; then
  verb_count="$(_extract_dispatch_verbs "$RUNNER" | grep -c . || true)"
  ok "all $verb_count dispatch verbs present in argument-hint"
else
  bad "$hint_missing dispatch verbs missing from argument-hint"
fi

# H neg: a hint line missing 'rules' must FAIL.
neg_tmp="$(mktemp -d)"
trap 'rm -rf "$neg_tmp"' EXIT
printf '%s\n' "$(printf '%s' "$hint_line" | sed 's/ | rules |//')" > "$neg_tmp/hint-no-rules.md"
hint_neg_missing=0
while IFS= read -r verb; do
  [ -n "$verb" ] || continue
  printf '%s' "$(cat "$neg_tmp/hint-no-rules.md")" | grep -qE "(^|[ |[])${verb}([ |[]|\])" || hint_neg_missing=$((hint_neg_missing+1))
done <<HINTVERBS2
$(_extract_dispatch_verbs "$RUNNER")
HINTVERBS2
if [ "$hint_neg_missing" -gt 0 ]; then
  ok "negative guard: argument-hint missing a dispatch verb fails closed"
else
  bad "negative guard: truncated argument-hint unexpectedly passed"
fi

# I) .agents pointer description must equal the canonical SKILL.md description line.
POINTER="$HERE/../.agents/skills/flow/SKILL.md"
canon_desc="$(grep '^description:' "$SKILL_MD")"
ptr_desc="$(grep '^description:' "$POINTER")"
if [ -n "$canon_desc" ] && [ "$canon_desc" = "$ptr_desc" ]; then
  ok ".agents pointer description is byte-identical to canonical SKILL.md description"
else
  bad ".agents pointer description diverges from canonical SKILL.md description"
fi

# I neg: diverging pointer description must FAIL.
sed 's/^description: .*/description: Drifted pointer description./' "$SKILL_MD" > "$neg_tmp/skill-drifted.md"
neg_canon="$(grep '^description:' "$neg_tmp/skill-drifted.md")"
if [ "$neg_canon" != "$ptr_desc" ]; then
  ok "negative guard: drifted description comparison fails closed"
else
  bad "negative guard: drifted description unexpectedly matched"
fi

rm -rf "$neg_tmp"
trap - EXIT

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

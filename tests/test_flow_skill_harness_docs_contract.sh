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
# Extract the MAIN dispatch case block (the one whose arms call cmd_*), not the earlier
# pre-flight blocks (graph guards / trap setup). Filter logic:
# - take only arms of the form `<word>|<word>) ... cmd_xxx`; alternation labels are split
#   on '|' and each alternative checked separately;
# - skip the empty-string alternative (`""`) - it documents `/flow` itself via the status row;
# - composite card subcommands (`card` label arms like `card start C-NNN`) are covered by the
#   dedicated `/flow card ...` rows, so the plain `card` label just needs any row mentioning it;
# - underscores in labels map to dashes (project-type) to match doc spelling.
RUNNER="$HERE/../skills/flow/runner/flow.sh"
DISPATCH_DOC="$HERE/../skills/flow/references/command-dispatch.md"
missing=0
while IFS= read -r label; do
  doc_label="$(printf '%s' "$label" | tr '_' '-')"
  if ! grep -q "$doc_label" "$DISPATCH_DOC"; then
    echo "  FAIL [dispatch verb '$doc_label' missing from command-dispatch.md]"
    missing=$((missing+1))
  fi
done < <(sed -n '/^FLOW_LOG_START=/,$p' "$RUNNER" | sed -n "/^case \"\$cmd\" in$/,/^esac$/p" | grep -oE '^[[:space:]]*[a-z_"|-]+[)][[:space:]]+cmd_' | sed -E 's/^[[:space:]]*//; s/\)[[:space:]]+cmd_$//; s/^"(.*)"$/\1/' | tr '|' '\n' | sed -E '/^""?$/d; /^$/d' | sort -u)
if [ "$missing" -eq 0 ]; then
  ok "all flow.sh dispatch verbs present in command-dispatch.md"
else
  bad "$missing dispatch verb(s) missing from command-dispatch.md"
fi

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

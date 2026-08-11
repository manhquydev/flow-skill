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

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

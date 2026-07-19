#!/usr/bin/env bash
# Docs/skills contract: no bare implemented recipes; pins present (plan phase 4).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../skills/flow"
pass=0; fail=0
ok() { echo "  ok   [$1]"; pass=$((pass+1)); }
bad() { echo "  FAIL [$1]"; fail=$((fail+1)); }

echo "A) pins in harness README + GAP matrix"
for f in "$ROOT/harness/README.md" "$ROOT/harness/GAP-MATRIX-0.1.17.md"; do
  test -f "$f" || { bad "missing $f"; continue; }
  grep -q '0\.1\.17' "$f" && ok "0.1.17 in $(basename "$f")" || bad "0.1.17 in $(basename "$f")"
  grep -q '0\.1\.14' "$f" && ok "0.1.14 in $(basename "$f")" || bad "0.1.14 in $(basename "$f")"
done

echo "B) no instructional bare story update --status implemented"
# Allow mentions of "rejected" / "never" but ban the operational recipe line without complete nearby
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

echo "D) in-repo canonical harness skill"
SK="$HERE/../skills/harness-skill/SKILL.md"
test -f "$SK" && ok "canonical harness skill exists" || bad "canonical harness skill missing"
if [ -f "$SK" ]; then
  grep -q 'query contract' "$SK" && ok "query contract guidance" || bad "query contract guidance"
  grep -q 'story complete' "$SK" && ok "complete-only guidance" || bad "complete-only guidance"
  grep -q '0\.1\.17' "$SK" && ok "pin 0.1.17 in skill" || bad "pin 0.1.17 in skill"
fi

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

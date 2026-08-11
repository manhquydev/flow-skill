#!/usr/bin/env bash
# Offline release coherence (v0.28 dual-version + next prerelease policy).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }

echo "A) offline checker green on repo"
bash "$HERE/../scripts/check-release-coherence.sh" >/tmp/coh.out 2>&1
ck 0 $? "coherence exit 0"
grep -q 'PASS: release coherence' /tmp/coh.out && ck 0 0 "pass line" || ck 0 1 "pass line"

echo "B) deliberate skill mirror drift fails"
tmp=$(mktemp -d)
mkdir -p "$tmp/r/skills/flow/runner" "$tmp/r/skills/flow/references" "$tmp/r/.claude-plugin" \
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows"
cp "$HERE/../scripts/check-release-coherence.sh" "$tmp/r/scripts/"
cp "$HERE/../skills/flow/SKILL.md" "$tmp/r/skills/flow/"
cp "$HERE/../portable-manifest.json" "$tmp/r/"
cp "$HERE/../npm-wrapper/package.json" "$tmp/r/npm-wrapper/"
cp "$HERE/../README.md" "$tmp/r/"
cp "$HERE/../tests/run_all.sh" "$tmp/r/tests/"
cp "$HERE/../.github/workflows/publish-npm-wrapper.yml" "$tmp/r/.github/workflows/"
cp "$HERE/../skills/flow/runner/attestations.sh" "$tmp/r/skills/flow/runner/"
cp "$HERE/../skills/flow/references/attestations.md" "$tmp/r/skills/flow/references/"
printf '{\n  "version": "0.0.0-drift"\n}\n' > "$tmp/r/.claude-plugin/plugin.json"
# touch every suite named in run_all so the suite-existence check is not noise
suite_line="$(grep -E 'for suite in ' "$tmp/r/tests/run_all.sh" | head -1)"
for suite in $suite_line; do
  case "$suite" in *.sh) : > "$tmp/r/tests/$suite" ;; esac
done
bash "$tmp/r/scripts/check-release-coherence.sh" >/tmp/coh2.out 2>&1
ck 1 $? "drift fails"
rm -rf "$tmp"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

#!/usr/bin/env bash
# Offline release coherence for skill + npm dual-version surface.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2
rc=0
fail() { echo "FAIL: $*" >&2; rc=1; }
ok() { echo "OK: $*"; }

skill_v="$(sed -nE 's/^[[:space:]]*version:[[:space:]]*"?([0-9][.0-9A-Za-z-]*).*/\1/p' skills/flow/SKILL.md | head -1)"
plugin_v="$(sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' .claude-plugin/plugin.json | head -1)"
portable_v="$(sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' portable-manifest.json | head -1)"
npm_v="$(sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' npm-wrapper/package.json | head -1)"

echo "skill=$skill_v plugin=$plugin_v portable=$portable_v npm=$npm_v"

[ -n "$skill_v" ] || fail "missing skill version"
if [ "$skill_v" = "$plugin_v" ] && [ "$skill_v" = "$portable_v" ]; then
  ok "skill mirrors agree ($skill_v)"
else
  fail "skill mirrors disagree"
fi
[ -n "$npm_v" ] && ok "npm package version $npm_v" || fail "missing npm version"
if [ "$npm_v" != "$skill_v" ]; then
  ok "dual-axis versions differ (npm=$npm_v skill=$skill_v)"
else
  fail "npm version equals skill (usually accidental)"
fi

grep -qE "v${skill_v}|${skill_v}" README.md && ok "README mentions skill $skill_v" || fail "README missing skill $skill_v"
grep -q "$npm_v" npm-wrapper/package.json && ok "npm package.json $npm_v" || fail "npm package.json missing version"

# Every suite named by run_all.sh must exist on disk
suite_line="$(grep -E 'for suite in ' tests/run_all.sh | head -1)"
for suite in $suite_line; do
  case "$suite" in
    *.sh) [ -f "tests/$suite" ] || fail "run_all suite missing: $suite" ;;
  esac
done
ok "run_all suite files checked"

if grep -q "dist_tag=next\|default: 'next'\|options: \[next, latest\]" .github/workflows/publish-npm-wrapper.yml 2>/dev/null; then
  ok "publish workflow uses next prerelease policy"
else
  fail "publish workflow missing next prerelease policy"
fi
if grep -E "default: 'rc'|options: \[rc, latest\]" .github/workflows/publish-npm-wrapper.yml >/dev/null 2>&1; then
  fail "publish workflow still operationally defaults to rc"
else
  ok "publish workflow not defaulting to rc"
fi

[ -f skills/flow/runner/attestations.sh ] && ok "attestations.sh present" || fail "missing attestations.sh"
[ -f skills/flow/references/attestations.md ] && ok "attestations.md present" || fail "missing attestations.md"

if [ "$rc" -eq 0 ]; then echo "PASS: release coherence"; else echo "FAIL: release coherence"; fi
exit "$rc"

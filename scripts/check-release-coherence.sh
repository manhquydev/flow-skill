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
if [ -n "$npm_v" ] && [ "$npm_v" = "$skill_v" ]; then
  ok "unified version (npm_v === skill_v): $npm_v"
else
  fail "npm and skill versions must share one SemVer (npm=$npm_v skill=$skill_v)"
fi

# C5 — the pack-time runner hash recorded by sync.mjs must match the checkout runner bytes.
manifest_h="$(sed -nE 's/.*"skills\/flow\/runner\/flow\.sh"[[:space:]]*:[[:space:]]*"([0-9a-f]{64})".*/\1/p' portable-manifest.json | head -1)"
if [ -n "$manifest_h" ]; then
  if command -v shasum >/dev/null 2>&1; then
    live_h="$(shasum -a 256 skills/flow/runner/flow.sh | awk '{print $1}')"
  else
    live_h="$(sha256sum skills/flow/runner/flow.sh | awk '{print $1}')"
  fi
  if [ "$manifest_h" = "$live_h" ]; then
    ok "runner hash matches manifest (${manifest_h%"${manifest_h#????????}"})"
  else
    fail "runner hash mismatch (manifest ${manifest_h%"${manifest_h#????????}"} vs checkout ${live_h%"${live_h#????????}"}) - re-run sync.mjs"
  fi
else
  fail "portable-manifest.json missing hashes entry for skills/flow/runner/flow.sh (re-run sync.mjs)"
fi

grep -qE "v${skill_v}|${skill_v}" README.md && ok "README mentions skill $skill_v" || fail "README missing skill $skill_v"
grep -q "$npm_v" npm-wrapper/package.json && ok "npm package.json $npm_v" || fail "npm package.json missing version"
grep -q "$npm_v" README.md && ok "README mentions npm $npm_v" || fail "README missing npm $npm_v"
[ -f README_VN.md ] || fail "missing README_VN.md"
grep -qE "v${skill_v}|${skill_v}" README_VN.md && ok "README_VN mentions skill $skill_v" || fail "README_VN missing skill $skill_v"
grep -q "$npm_v" README_VN.md && ok "README_VN mentions npm $npm_v" || fail "README_VN missing npm $npm_v"
[ -f npm-wrapper/README.md ] || fail "missing npm-wrapper/README.md"
(grep -q "$npm_v" npm-wrapper/README.md && grep -qE "v${skill_v}|${skill_v}" npm-wrapper/README.md) && ok "npm-wrapper/README.md matches versions ($npm_v / $skill_v)" || fail "npm-wrapper/README.md does not match current versions ($npm_v / $skill_v)"
[ -f npm-wrapper/README_VN.md ] || fail "missing npm-wrapper/README_VN.md"
(grep -q "$npm_v" npm-wrapper/README_VN.md && grep -qE "v${skill_v}|${skill_v}" npm-wrapper/README_VN.md) && ok "npm-wrapper/README_VN.md matches versions ($npm_v / $skill_v)" || fail "npm-wrapper/README_VN.md does not match current versions ($npm_v / $skill_v)"
grep -qE "## \[?${skill_v}\]?" CHANGELOG.md && ok "CHANGELOG.md contains entry for skill $skill_v" || fail "CHANGELOG.md missing entry for skill $skill_v"
grep -qE "## \[?${npm_v}\]?" npm-wrapper/CHANGELOG.md && ok "npm-wrapper/CHANGELOG.md contains entry for npm $npm_v" || fail "npm-wrapper/CHANGELOG.md missing entry for npm $npm_v"

# Every suite named in tests/manifest.txt must exist on disk.
# Empty extract is a fail (do not ok a no-op after the runner left the hardcoded loop).
n=0
if [ ! -f tests/manifest.txt ]; then
  fail "missing tests/manifest.txt"
else
  while IFS= read -r suite || [ -n "$suite" ]; do
    suite="${suite%$'\r'}"
    case "$suite" in
      ''|\#*) continue ;;
    esac
    n=$((n + 1))
    [ -f "tests/$suite" ] || fail "manifest suite missing: $suite"
  done < tests/manifest.txt
fi
if [ "$n" -eq 0 ]; then
  fail "empty suite registry (tests/manifest.txt)"
else
  ok "manifest suite files checked ($n)"
fi

if grep -q "parseSemver(version).prerelease ? 'next' : 'latest'" scripts/release-workflow.mjs \
  && grep -q 'DIST_TAG:.*channel' .github/workflows/publish-npm-wrapper.yml; then
  ok "publish workflow maps prereleases to next and stable to latest"
else
  fail "publish workflow missing SemVer channel mapping"
fi
if grep -Eq 'promote_to|dist-tag add|npm@\*' .github/workflows/publish-npm-wrapper.yml; then
  fail "publish workflow contains a tag or dist-tag promotion bypass"
else
  ok "publish workflow has no tag or dist-tag promotion bypass"
fi

trusted_sha_check="$(grep -Fc 'process.env.GITHUB_SHA !== sha' scripts/release-workflow.mjs)"
per_job_ok=1
for job in eligibility publish; do
  job_block="$(awk -v target="$job" '
    $0 ~ "^  " target ":$" { in_job = 1; next }
    in_job && /^  [A-Za-z][A-Za-z0-9_-]*:$/ { exit }
    in_job { print }
  ' .github/workflows/publish-npm-wrapper.yml)"
  job_ref_count="$(printf '%s\n' "$job_block" | grep -Ec '^[[:space:]]+ref: \$\{\{ github\.sha \}\}$' || true)"
  job_untrusted="$(printf '%s\n' "$job_block" | grep -Ec 'ref: \$\{\{ inputs\.expected_sha \}\}' || true)"
  [ "$job_ref_count" -eq 1 ] && [ "$job_untrusted" -eq 0 ] || per_job_ok=0
done
if [ "$per_job_ok" -eq 1 ] && [ "$trusted_sha_check" -eq 1 ]; then
  ok "publisher gate and publish jobs use trusted workflow SHA, then compare requested SHA"
else
  fail "publisher must checkout github.sha for both jobs and validate the request SHA in trusted gate code"
fi

pack_workdir="$(grep -nE '^[[:space:]]*working-directory: npm-wrapper$' .github/workflows/publish-npm-wrapper.yml | head -1 | cut -d: -f1)"
pack_line="$(grep -nE '^[[:space:]]*npm pack --pack-destination' .github/workflows/publish-npm-wrapper.yml | head -1 | cut -d: -f1)"
audit_line="$(grep -nE 'npm-attestation-audit\.mjs' .github/workflows/publish-npm-wrapper.yml | head -1 | cut -d: -f1)"
smoke_line="$(grep -nE 'npm-wrapper/scripts/smoke\.mjs' .github/workflows/publish-npm-wrapper.yml | head -1 | cut -d: -f1)"
pkg_upload_line="$(grep -nE 'name: npm-package-' .github/workflows/publish-npm-wrapper.yml | head -1 | cut -d: -f1)"
receipt_upload_line="$(grep -nE 'name: npm-verification-' .github/workflows/publish-npm-wrapper.yml | head -1 | cut -d: -f1)"
publish_line="$(grep -nE 'npm publish' .github/workflows/publish-npm-wrapper.yml | head -1 | cut -d: -f1)"
if [ -n "$pack_workdir" ] && [ -n "$pack_line" ] && [ "$pack_workdir" -lt "$pack_line" ]; then
  ok "package pack runs from npm-wrapper"
else
  fail "npm pack must run with npm-wrapper as working-directory"
fi
if [ -n "$audit_line" ] && [ -n "$smoke_line" ] && [ -n "$publish_line" ] && [ "$publish_line" -lt "$audit_line" ] && [ "$audit_line" -lt "$smoke_line" ]; then
  ok "verified audit runs after publish and before install smoke"
else
  fail "publisher must run npm publish before the signature audit and the audit before the installer smoke"
fi
upload_path_values() {
  awk -v start="$1" '
    NR < start { next }
    NR == start { in_step = 1 }
    in_step && NR > start && /^      - / { exit }
    in_step && /path:[[:space:]]*\|/ { in_path = 1; next }
    in_path {
      indent = match($0, /[^ ]/) - 1
      if (indent < 12) exit
      print substr($0, indent + 1)
    }
  ' .github/workflows/publish-npm-wrapper.yml
}
if [ -n "$pkg_upload_line" ] && [ -n "$pack_line" ] && [ -n "$publish_line" ] && [ "$pkg_upload_line" -gt "$pack_line" ] && [ "$pkg_upload_line" -lt "$publish_line" ]; then
  pkg_paths="$(upload_path_values "$pkg_upload_line")"
  if printf '%s\n' "$pkg_paths" | grep -qx '\${{ runner.temp }}/\*\.tgz' && printf '%s\n' "$pkg_paths" | grep -qx '\${{ runner.temp }}/release-artifact\.json'; then
    ok "exact packed archive and metadata retained before publish"
  else
    fail "package upload path block must retain both *.tgz and release-artifact.json"
  fi
else
  fail "package artifact must upload after pack and before publish"
fi
gh_verify_line="$(grep -nE 'verify-attestation-with-gh\.mjs' .github/workflows/publish-npm-wrapper.yml | head -1 | cut -d: -f1)"
if [ -n "$receipt_upload_line" ] && [ -n "$audit_line" ] && [ -n "$gh_verify_line" ] && [ "$receipt_upload_line" -gt "$audit_line" ] && [ "$receipt_upload_line" -lt "$gh_verify_line" ]; then
  receipt_paths="$(upload_path_values "$receipt_upload_line")"
  if printf '%s\n' "$receipt_paths" | grep -qx '\${{ runner.temp }}/npm-audit-verified\.json' && printf '%s\n' "$receipt_paths" | grep -qx '\${{ runner.temp }}/slsa-bundle\.json'; then
    ok "provenance receipts upload right after audit, before Sigstore verify, so recovery survives later failures"
  else
    fail "verification upload path block must contain npm-audit-verified.json and slsa-bundle.json"
  fi
else
  fail "audit/SLSA receipts must upload after audit and before the Sigstore verifier"
fi

[ -f skills/flow/runner/attestations.sh ] && ok "attestations.sh present" || fail "missing attestations.sh"
[ -f skills/flow/references/attestations.md ] && ok "attestations.md present" || fail "missing attestations.md"

if [ "$rc" -eq 0 ]; then echo "PASS: release coherence"; else echo "FAIL: release coherence"; fi
exit "$rc"

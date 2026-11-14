#!/usr/bin/env bash
# Offline release coherence (shared SemVer + next prerelease policy).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
pass=0; fail=0
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }

echo "A) offline checker green on repo"
bash "$HERE/../scripts/check-release-coherence.sh" >"$OUT/coh.out" 2>&1
ck 0 $? "coherence exit 0"
grep -q 'PASS: release coherence' "$OUT/coh.out" && ck 0 0 "pass line" || ck 0 1 "pass line"

echo "A2) canonical README targets do not assert publication"
node --input-type=module - "$HERE/.." <<'NODE' >"$OUT/readme-targets.out" 2>&1
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { readFileSync } from 'node:fs';
const root = process.argv[2];
const { getExpectedReadmeTransforms } = await import(pathToFileURL(resolve(root, 'scripts/sync-release.mjs')));
for (const version of ['0.7.15', '0.7.16-next.0']) {
  for (const item of getExpectedReadmeTransforms(version, version)) {
    const source = readFileSync(resolve(root, item.relPath), 'utf8');
    const result = item.transform(source);
    assert.equal(item.transform(result), result, `${item.relPath}: idempotent`);
    assert.ok(result.includes(`**${version}**`), item.relPath);
    assert.ok(result.includes('not a publication receipt') || result.includes('không phải biên nhận đã phát hành'), item.relPath);
    assert.ok(!/\*\*(?:Current GA|GA hiện tại)\*\*/.test(result), item.relPath);
    assert.ok(!new RegExp('`@(?:latest|next)` ' + version.replaceAll('.', '\\.')).test(result), item.relPath);
    assert.ok(result.includes(version.includes('-') ? '`next`' : '`latest`'), item.relPath);
  }
}
NODE
ck 0 $? "stable/prerelease targets are neutral and idempotent in all four READMEs"

echo "B) deliberate skill mirror drift fails"
tmp=$(mktemp -d)
mkdir -p "$tmp/r/skills/flow/runner" "$tmp/r/skills/flow/references" "$tmp/r/.claude-plugin" \
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows" "$tmp/r/docs"
cp "$HERE/../scripts/check-release-coherence.sh" "$tmp/r/scripts/"
cp "$HERE/../docs/release-intent.json" "$HERE/../docs/quality-metrics.md" "$tmp/r/docs/"
cp "$HERE/../skills/flow/SKILL.md" "$tmp/r/skills/flow/"
cp "$HERE/../portable-manifest.json" "$tmp/r/"
cp "$HERE/../npm-wrapper/package.json" "$tmp/r/npm-wrapper/"
cp "$HERE/../npm-wrapper/README.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../npm-wrapper/README_VN.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../CHANGELOG.md" "$tmp/r/"
cp "$HERE/../npm-wrapper/CHANGELOG.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../README.md" "$tmp/r/"
cp "$HERE/../README_VN.md" "$tmp/r/"
cp "$HERE/../tests/manifest.txt" "$tmp/r/tests/"
cp "$HERE/../.github/workflows/publish-npm-wrapper.yml" "$tmp/r/.github/workflows/"
cp "$HERE/../skills/flow/runner/attestations.sh" "$tmp/r/skills/flow/runner/"
cp "$HERE/../skills/flow/references/attestations.md" "$tmp/r/skills/flow/references/"
printf '{\n  "version": "0.0.0-drift"\n}\n' > "$tmp/r/.claude-plugin/plugin.json"
# touch every suite named in the manifest so the suite-existence check is not noise
n=0
while IFS= read -r suite || [ -n "$suite" ]; do
  suite="${suite%$'\r'}"
  case "$suite" in
    ''|\#*) continue ;;
  esac
  n=$((n + 1))
  : > "$tmp/r/tests/$suite"
done < "$tmp/r/tests/manifest.txt"
[ "$n" -gt 0 ] || { echo "  FAIL [stub extract empty]"; fail=$((fail+1)); }
bash "$tmp/r/scripts/check-release-coherence.sh" >"$OUT/coh2.out" 2>&1
ck 1 $? "drift fails"
rm -rf "$tmp"

echo "C) deleting a listed suite fails coherence (not a vacuous OK)"
tmp=$(mktemp -d)
mkdir -p "$tmp/r/skills/flow/runner" "$tmp/r/skills/flow/references" "$tmp/r/.claude-plugin" \
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows" "$tmp/r/docs"
cp "$HERE/../scripts/check-release-coherence.sh" "$tmp/r/scripts/"
cp "$HERE/../docs/release-intent.json" "$HERE/../docs/quality-metrics.md" "$tmp/r/docs/"
cp "$HERE/../skills/flow/SKILL.md" "$tmp/r/skills/flow/"
cp "$HERE/../portable-manifest.json" "$tmp/r/"
cp "$HERE/../.claude-plugin/plugin.json" "$tmp/r/.claude-plugin/"
cp "$HERE/../npm-wrapper/package.json" "$tmp/r/npm-wrapper/"
cp "$HERE/../npm-wrapper/README.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../npm-wrapper/README_VN.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../CHANGELOG.md" "$tmp/r/"
cp "$HERE/../npm-wrapper/CHANGELOG.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../README.md" "$tmp/r/"
cp "$HERE/../README_VN.md" "$tmp/r/"
cp "$HERE/../tests/manifest.txt" "$tmp/r/tests/"
cp "$HERE/../.github/workflows/publish-npm-wrapper.yml" "$tmp/r/.github/workflows/"
cp "$HERE/../skills/flow/runner/attestations.sh" "$tmp/r/skills/flow/runner/"
cp "$HERE/../skills/flow/references/attestations.md" "$tmp/r/skills/flow/references/"
n=0
while IFS= read -r suite || [ -n "$suite" ]; do
  suite="${suite%$'\r'}"
  case "$suite" in
    ''|\#*) continue ;;
  esac
  n=$((n + 1))
  : > "$tmp/r/tests/$suite"
done < "$tmp/r/tests/manifest.txt"
rm -f "$tmp/r/tests/test_flow_runner.sh"
bash "$tmp/r/scripts/check-release-coherence.sh" >"$OUT/coh3.out" 2>&1
ck 1 $? "missing listed suite fails"
grep -q 'manifest suite missing: test_flow_runner.sh' "$OUT/coh3.out" && ck 0 0 "names the missing suite" || ck 0 1 "names the missing suite"
rm -rf "$tmp"

echo "D) empty registry extract fails coherence"
tmp=$(mktemp -d)
mkdir -p "$tmp/r/skills/flow/runner" "$tmp/r/skills/flow/references" "$tmp/r/.claude-plugin" \
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows" "$tmp/r/docs"
cp "$HERE/../scripts/check-release-coherence.sh" "$tmp/r/scripts/"
cp "$HERE/../docs/release-intent.json" "$HERE/../docs/quality-metrics.md" "$tmp/r/docs/"
cp "$HERE/../skills/flow/SKILL.md" "$tmp/r/skills/flow/"
cp "$HERE/../portable-manifest.json" "$tmp/r/"
cp "$HERE/../.claude-plugin/plugin.json" "$tmp/r/.claude-plugin/"
cp "$HERE/../npm-wrapper/package.json" "$tmp/r/npm-wrapper/"
cp "$HERE/../README.md" "$tmp/r/"
cp "$HERE/../README_VN.md" "$tmp/r/"
cp "$HERE/../npm-wrapper/README.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../npm-wrapper/README_VN.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../CHANGELOG.md" "$tmp/r/"
cp "$HERE/../npm-wrapper/CHANGELOG.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../.github/workflows/publish-npm-wrapper.yml" "$tmp/r/.github/workflows/"
cp "$HERE/../skills/flow/runner/attestations.sh" "$tmp/r/skills/flow/runner/"
cp "$HERE/../skills/flow/references/attestations.md" "$tmp/r/skills/flow/references/"
printf '# comment only\n\n' > "$tmp/r/tests/manifest.txt"
bash "$tmp/r/scripts/check-release-coherence.sh" >"$OUT/coh4.out" 2>&1
ck 1 $? "empty registry fails"
grep -q 'empty suite registry' "$OUT/coh4.out" && ck 0 0 "empty-registry message" || ck 0 1 "empty-registry message"
rm -rf "$tmp"

echo "E) deliberate npm-wrapper/README.md drift fails coherence"
tmp=$(mktemp -d)
mkdir -p "$tmp/r/skills/flow/runner" "$tmp/r/skills/flow/references" "$tmp/r/.claude-plugin" \
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows" "$tmp/r/docs"
cp "$HERE/../scripts/check-release-coherence.sh" "$tmp/r/scripts/"
cp "$HERE/../docs/release-intent.json" "$HERE/../docs/quality-metrics.md" "$tmp/r/docs/"
cp "$HERE/../skills/flow/SKILL.md" "$tmp/r/skills/flow/"
cp "$HERE/../skills/flow/runner/flow.sh" "$tmp/r/skills/flow/runner/"
cp "$HERE/../portable-manifest.json" "$tmp/r/"
cp "$HERE/../.claude-plugin/plugin.json" "$tmp/r/.claude-plugin/"
cp "$HERE/../npm-wrapper/package.json" "$tmp/r/npm-wrapper/"
cp "$HERE/../npm-wrapper/README.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../npm-wrapper/README_VN.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../CHANGELOG.md" "$tmp/r/"
cp "$HERE/../npm-wrapper/CHANGELOG.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../README.md" "$tmp/r/"
cp "$HERE/../README_VN.md" "$tmp/r/"
cp "$HERE/../tests/manifest.txt" "$tmp/r/tests/"
cp "$HERE/../.github/workflows/publish-npm-wrapper.yml" "$tmp/r/.github/workflows/"
cp "$HERE/../skills/flow/runner/attestations.sh" "$tmp/r/skills/flow/runner/"
cp "$HERE/../skills/flow/references/attestations.md" "$tmp/r/skills/flow/references/"
printf '# @manhquy/flow-skill\n\n| **Current GA** | **0.0.0-drift** — ships skill product **v0.0.0** |\n' > "$tmp/r/npm-wrapper/README.md"
n=0
while IFS= read -r suite || [ -n "$suite" ]; do
  suite="${suite%$'\r'}"
  case "$suite" in
    ''|\#*) continue ;;
  esac
  n=$((n + 1))
  : > "$tmp/r/tests/$suite"
done < "$tmp/r/tests/manifest.txt"
bash "$tmp/r/scripts/check-release-coherence.sh" >"$OUT/coh5.out" 2>&1
ck 1 $? "npm-wrapper readme drift fails"
grep -q 'npm-wrapper/README.md does not match current versions' "$OUT/coh5.out" && ck 0 0 "detects npm-wrapper readme drift" || ck 0 1 "detects npm-wrapper readme drift"
rm -rf "$tmp"

echo "F) deleting npm-wrapper/README_VN.md fails coherence"
tmp=$(mktemp -d)
mkdir -p "$tmp/r/skills/flow/runner" "$tmp/r/skills/flow/references" "$tmp/r/.claude-plugin" \
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows" "$tmp/r/docs"
cp "$HERE/../scripts/check-release-coherence.sh" "$tmp/r/scripts/"
cp "$HERE/../docs/release-intent.json" "$HERE/../docs/quality-metrics.md" "$tmp/r/docs/"
cp "$HERE/../skills/flow/SKILL.md" "$tmp/r/skills/flow/"
cp "$HERE/../skills/flow/runner/flow.sh" "$tmp/r/skills/flow/runner/"
cp "$HERE/../portable-manifest.json" "$tmp/r/"
cp "$HERE/../.claude-plugin/plugin.json" "$tmp/r/.claude-plugin/"
cp "$HERE/../npm-wrapper/package.json" "$tmp/r/npm-wrapper/"
cp "$HERE/../npm-wrapper/README.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../CHANGELOG.md" "$tmp/r/"
cp "$HERE/../npm-wrapper/CHANGELOG.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../README.md" "$tmp/r/"
cp "$HERE/../README_VN.md" "$tmp/r/"
cp "$HERE/../tests/manifest.txt" "$tmp/r/tests/"
cp "$HERE/../.github/workflows/publish-npm-wrapper.yml" "$tmp/r/.github/workflows/"
cp "$HERE/../skills/flow/runner/attestations.sh" "$tmp/r/skills/flow/runner/"
cp "$HERE/../skills/flow/references/attestations.md" "$tmp/r/skills/flow/references/"
n=0
while IFS= read -r suite || [ -n "$suite" ]; do
  suite="${suite%$'\r'}"
  case "$suite" in
    ''|\#*) continue ;;
  esac
  n=$((n + 1))
  : > "$tmp/r/tests/$suite"
done < "$tmp/r/tests/manifest.txt"
bash "$tmp/r/scripts/check-release-coherence.sh" >"$OUT/coh6.out" 2>&1
ck 1 $? "missing npm-wrapper/README_VN.md fails"
grep -q 'missing npm-wrapper/README_VN.md' "$OUT/coh6.out" && ck 0 0 "names the missing file" || ck 0 1 "names the missing file"
rm -rf "$tmp"

echo "G) publisher workflow ordering gate: audit after smoke fails (hollow/sound pair)"
tmp=$(mktemp -d)
mkdir -p "$tmp/r/skills/flow/runner" "$tmp/r/skills/flow/references" "$tmp/r/.claude-plugin" \
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows" "$tmp/r/docs"
cp "$HERE/../scripts/check-release-coherence.sh" "$tmp/r/scripts/"
cp "$HERE/../docs/release-intent.json" "$HERE/../docs/quality-metrics.md" "$tmp/r/docs/"
cp "$HERE/../skills/flow/SKILL.md" "$tmp/r/skills/flow/"
cp "$HERE/../skills/flow/runner/flow.sh" "$tmp/r/skills/flow/runner/"
cp "$HERE/../skills/flow/runner/attestations.sh" "$tmp/r/skills/flow/runner/"
cp "$HERE/../skills/flow/references/attestations.md" "$tmp/r/skills/flow/references/"
cp "$HERE/../portable-manifest.json" "$tmp/r/"
cp "$HERE/../.claude-plugin/plugin.json" "$tmp/r/.claude-plugin/"
cp "$HERE/../npm-wrapper/package.json" "$tmp/r/npm-wrapper/"
cp "$HERE/../npm-wrapper/README.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../npm-wrapper/README_VN.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../CHANGELOG.md" "$tmp/r/"
cp "$HERE/../npm-wrapper/CHANGELOG.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../README.md" "$tmp/r/"
cp "$HERE/../README_VN.md" "$tmp/r/"
cp "$HERE/../tests/manifest.txt" "$tmp/r/tests/"
cp "$HERE/../.github/workflows/publish-npm-wrapper.yml" "$tmp/r/.github/workflows/"
cp "$HERE/../scripts/release-workflow.mjs" "$tmp/r/scripts/"
# populate every manifest-listed suite so suite presence is not a second failure source
while IFS= read -r suite || [ -n "$suite" ]; do
  suite="${suite%$'\r'}"
  case "$suite" in ''|\#*) continue ;; esac
  : > "$tmp/r/tests/$suite"
done < "$tmp/r/tests/manifest.txt"
# sound half: current workflow passes the FULL coherence run, not just one grep
bash "$tmp/r/scripts/check-release-coherence.sh" >"$tmp/coh7a.out" 2>&1
ck 0 $? "sound: real workflow passes full coherence run"
grep -q 'provenance receipts upload right after audit' "$tmp/coh7a.out" && ck 0 0 "sound: ordering gate asserts audit-then-upload-then-verifier" || ck 0 1 "sound: ordering gate asserts audit-then-upload-then-verifier"


# Hollow package receipt: removing only release-artifact.json from npm-package upload must fail.
cp "$tmp/r/.github/workflows/publish-npm-wrapper.yml" "$tmp/r/.github/workflows/publish-npm-wrapper.original.yml"
python3 - "$tmp/r/.github/workflows/publish-npm-wrapper.yml" <<'PYEOF'
import sys
p=sys.argv[1]; t=open(p).read(); marker='          name: npm-package-${{ github.run_id }}-${{ github.run_attempt }}'
i=t.index(marker); j=t.index('      - name:', i+len(marker))
block=t[i:j].replace('            ${{ runner.temp }}/release-artifact.json\n','')
assert block != t[i:j]
open(p,'w').write(t[:i]+block+t[j:])
PYEOF
bash "$tmp/r/scripts/check-release-coherence.sh" >"$tmp/coh7meta.out" 2>&1
ck 1 $? "hollow: missing release-artifact.json upload fails"
grep -q 'package upload path block must retain both' "$tmp/coh7meta.out" && ck 0 0 "names missing package receipt" || ck 0 1 "names missing package receipt"
cp "$tmp/r/.github/workflows/publish-npm-wrapper.original.yml" "$tmp/r/.github/workflows/publish-npm-wrapper.yml"
python3 - "$tmp/r/.github/workflows/publish-npm-wrapper.yml" <<'PYEOF'
import re, sys
p=sys.argv[1]; t=open(p).read()
m=re.search(r'(name: npm-package-.*?\n[ ]+path:\s*\|\n)(.*?)(?=^[ ]+if-no-files-found:)', t, re.S|re.M)
assert m, 'package upload path block missing'
paths=m.group(2)
assert '${{ runner.temp }}/*.tgz' in paths and '${{ runner.temp }}/release-artifact.json' in paths
paths=paths.replace('            ${{ runner.temp }}/release-artifact.json\n', '            # omitted release-artifact.json\n')
t=t[:m.start(2)]+paths+t[m.end(2):]
open(p,'w').write(t)
PYEOF
bash "$tmp/r/scripts/check-release-coherence.sh" >"$tmp/coh7comment.out" 2>&1
ck 1 $? "hollow: comment-only package metadata is not treated as uploaded"
grep -q 'package upload path block must retain both' "$tmp/coh7comment.out" && ck 0 0 "rejects commented-out metadata path" || ck 0 1 "rejects commented-out metadata path"
cp "$tmp/r/.github/workflows/publish-npm-wrapper.original.yml" "$tmp/r/.github/workflows/publish-npm-wrapper.yml"
# hollow half: move the install-smoke step before the audit step; ONLY the ordering gate flips
python3 - "$tmp/r/.github/workflows/publish-npm-wrapper.yml" <<'PYEOF'
import re, sys
path = sys.argv[1]
text = open(path).read()
smoke = re.search(r'(      - name: Verify registry integrity and installed package\n(?:        .*\n|\n)*?        run: .*\n)', text)
audit = re.search(r'(      - name: Audit target-only npm signatures and export verified SLSA bundle\n)', text)
if not smoke or not audit:
    sys.exit(3)
text = text.replace(smoke.group(1), '', 1)
text = text.replace(audit.group(1), smoke.group(1) + audit.group(1), 1)
open(path, 'w').write(text)
PYEOF
bash "$tmp/r/scripts/check-release-coherence.sh" >"$tmp/coh7.out" 2>&1
ck 1 $? "hollow: audit-after-smoke ordering fails coherence"
grep -q 'publisher must run npm publish before the signature audit' "$tmp/coh7.out" && ck 0 0 "names the ordering violation" || ck 0 1 "names the ordering violation"

# Hollow trust boundary: independently mutate each checkout and require the exact sound contract first.
cp "$tmp/r/.github/workflows/publish-npm-wrapper.original.yml" "$tmp/r/.github/workflows/publish-npm-wrapper.yml"
bash "$tmp/r/scripts/check-release-coherence.sh" >"$tmp/coh7restored.out" 2>&1
ck 0 $? "sound: restored publisher workflow passes before checkout hollows"
python3 - "$tmp/r/.github/workflows/publish-npm-wrapper.yml" eligibility <<'PYEOF'
import re, sys
p, job = sys.argv[1:]
t = open(p).read()
jobs = list(re.finditer(r'(?m)^  [A-Za-z][\w-]*:\s*$', t))
idx = next(i for i, match in enumerate(jobs) if match.group().strip() == f'{job}:')
start = jobs[idx].end()
end = jobs[idx + 1].start() if idx + 1 < len(jobs) else len(t)
section = t[start:end]
old = '          ref: ${{ github.sha }}'
assert section.count(old) == 1
section = section.replace(old, '          ref: ${{ inputs.expected_sha }}', 1)
open(p, 'w').write(t[:start] + section + t[end:])
PYEOF
bash "$tmp/r/scripts/check-release-coherence.sh" >"$tmp/coh7eligibility.out" 2>&1
ck 1 $? "hollow: caller-selected eligibility checkout fails coherence"
grep -q 'publisher must checkout github.sha for both jobs' "$tmp/coh7eligibility.out" && ck 0 0 "names untrusted eligibility checkout" || ck 0 1 "names untrusted eligibility checkout"
ck 1 "$(grep '^FAIL:' "$tmp/coh7eligibility.out" | grep -vc '^FAIL: release coherence$')" "eligibility hollow fails only the trust check"

cp "$tmp/r/.github/workflows/publish-npm-wrapper.original.yml" "$tmp/r/.github/workflows/publish-npm-wrapper.yml"
bash "$tmp/r/scripts/check-release-coherence.sh" >"$tmp/coh7publish-restored.out" 2>&1
ck 0 $? "sound: restored publisher workflow passes before publish hollow"
python3 - "$tmp/r/.github/workflows/publish-npm-wrapper.yml" publish <<'PYEOF'
import re, sys
p, job = sys.argv[1:]
t = open(p).read()
jobs = list(re.finditer(r'(?m)^  [A-Za-z][\w-]*:\s*$', t))
idx = next(i for i, match in enumerate(jobs) if match.group().strip() == f'{job}:')
start = jobs[idx].end()
end = jobs[idx + 1].start() if idx + 1 < len(jobs) else len(t)
section = t[start:end]
old = '          ref: ${{ github.sha }}'
assert section.count(old) == 1
section = section.replace(old, '          ref: ${{ inputs.expected_sha }}', 1)
open(p, 'w').write(t[:start] + section + t[end:])
PYEOF
bash "$tmp/r/scripts/check-release-coherence.sh" >"$tmp/coh7publish.out" 2>&1
ck 1 $? "hollow: caller-selected publish checkout fails coherence"
grep -q 'publisher must checkout github.sha for both jobs' "$tmp/coh7publish.out" && ck 0 0 "names untrusted publish checkout" || ck 0 1 "names untrusted publish checkout"
ck 1 "$(grep '^FAIL:' "$tmp/coh7publish.out" | grep -vc '^FAIL: release coherence$')" "publish hollow fails only the trust check"
cp "$tmp/r/.github/workflows/publish-npm-wrapper.original.yml" "$tmp/r/.github/workflows/publish-npm-wrapper.yml"
bash "$tmp/r/scripts/check-release-coherence.sh" >"$tmp/coh7final-restored.out" 2>&1
ck 0 $? "sound: restored publisher workflow passes after checkout hollows"

echo "H) preflight selects stable/latest and prerelease/next without registry writes"
fixture="$OUT/preflight"
mkdir -p "$fixture/scripts" "$fixture/bin" "$fixture/skills/flow/runner" \
  "$fixture/skills/flow/harness" "$fixture/npm-wrapper/skills/flow" \
  "$fixture/npm-wrapper/bin" "$fixture/.claude-plugin"
cp "$HERE/../scripts/release-preflight.sh" "$fixture/scripts/"
# Isolate unrelated gates; execute the real preflight with real JSON parsing.
for check in check-release-coherence check-doc-budgets check-i18n-pairs; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture/scripts/$check.sh"
done
printf '#!/usr/bin/env bash\necho READY\n' > "$fixture/skills/flow/runner/flow.sh"
printf 'version: 1.0.0\n' > "$fixture/skills/flow/SKILL.md"
cp "$fixture/skills/flow/SKILL.md" "$fixture/npm-wrapper/skills/flow/"
printf '{"version":"1.0.0"}\n' > "$fixture/portable-manifest.json"
cp "$fixture/portable-manifest.json" "$fixture/.claude-plugin/plugin.json"
printf '{}\n' > "$fixture/.claude-plugin/marketplace.json"
printf '# fixture module\n' > "$fixture/skills/flow/harness/flow_harness.py"
cat > "$fixture/npm-wrapper/bin/cli.mjs" <<'JS'
import fs from 'node:fs';
const {version} = JSON.parse(fs.readFileSync(new URL('../package.json', import.meta.url)));
console.log(`flow-skill v${version} (ships skill v${version})`);
JS
cat > "$fixture/bin/npm" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$NPM_CALLS"
if [ "$*" != 'view @manhquy/flow-skill dist-tags --json' ]; then
  echo 'unexpected npm operation' >&2
  exit 99
fi
printf '%s\n' '{"latest":"2.0.0","next":"2.1.0-next.1","rc":"0.0.1-rc.1"}'
SH
chmod +x "$fixture/bin/npm"
for version in 2.0.0 2.1.0-next.1; do
  channel=latest
  case "$version" in *-*) channel=next ;; esac
  printf '{"version":"%s"}\n' "$version" > "$fixture/npm-wrapper/package.json"
  printf 'version: %s\n' "$version" > "$fixture/skills/flow/SKILL.md"
  cp "$fixture/skills/flow/SKILL.md" "$fixture/npm-wrapper/skills/flow/"
  printf '{"version":"%s"}\n' "$version" > "$fixture/portable-manifest.json"
  cp "$fixture/portable-manifest.json" "$fixture/.claude-plugin/plugin.json"
  log="$OUT/preflight-$channel.out"
  PATH="$fixture/bin:$PATH" NPM_CALLS="$OUT/npm-$channel.calls" \
    bash "$fixture/scripts/release-preflight.sh" > "$log" 2>&1
  ck 0 $? "$channel preflight exits successfully"
  grep -q "OK: local package.json matches dist-tag $channel" "$log" && ck 0 0 "$channel matches selected channel" || ck 0 1 "$channel matches selected channel"
  grep -Eq 'WARN:.*(rc|latest|promot|tag push)|matches dist-tag rc' "$log" && ck 0 1 "$channel has no legacy channel warning" || ck 0 0 "$channel has no legacy channel warning"
  grep -Fq 'PREFLIGHT PASS — next: bash scripts/release.sh --dry-run; then bash scripts/release.sh --yes only after owner-authorized gates' "$log" && ck 0 0 "$channel canonical next step" || ck 0 1 "$channel canonical next step"
  ck 'view @manhquy/flow-skill dist-tags --json' "$(cat "$OUT/npm-$channel.calls")" "$channel only reads registry through fake npm"

done
printf '{"version":"9.9.9"}\n' > "$fixture/npm-wrapper/package.json"
inequality_rc=0
PATH="$fixture/bin:$PATH" NPM_CALLS="$OUT/npm-inequality.calls" \
  bash "$fixture/scripts/release-preflight.sh" > "$OUT/preflight-inequality.out" 2>&1 || inequality_rc=$?
ck 1 "$inequality_rc" "preflight refuses unequal skill and npm versions"
grep -Fq 'must share one SemVer' "$OUT/preflight-inequality.out" && ck 0 0 "preflight explains one-SemVer refusal" || ck 0 1 "preflight explains one-SemVer refusal"
printf '{"version":"%s"}\n' "$version" > "$fixture/npm-wrapper/package.json"

echo "H2) preflight skips below-floor python3 and accepts supported python fallback"
shim="$OUT/python-fallback-bin"
mkdir -p "$shim"
cat > "$shim/python3" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "-c" ]; then
  case "$2" in
    *sys.version_info*) exit 1 ;;
  esac
fi
exit 1
SH
cat > "$shim/python" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "-c" ]; then
  case "$2" in
    *'sys.version_info[:2] >= (3,7)'*) exit 0 ;;
    *'print("%d.%d"%sys.version_info[:2])'*) echo 3.7; exit 0 ;;
  esac
elif [ "${1:-}" = "--version" ]; then
  echo 'Python 3.7.0'; exit 0
elif [ "${1:-}" = "-m" ] && [ "${2:-}" = "py_compile" ]; then
  exit 0
elif [[ "$*" == *"flow_harness.py graph lint"* ]]; then
  exit 0
fi
exit 0
SH
chmod +x "$shim/python3" "$shim/python"
fallback_log="$OUT/preflight-python-fallback.out"
fallback_rc=0
PATH="$shim:$fixture/bin:$PATH" NPM_CALLS="$OUT/npm-fallback.calls" \
  bash "$fixture/scripts/release-preflight.sh" >"$fallback_log" 2>&1 || fallback_rc=$?
grep -Fq "OK: python 3.7 at $shim/python" "$fallback_log" && ck 0 0 "below-floor python3 skipped in favor of python 3.7" || { ck 0 1 "below-floor python3 skipped in favor of python 3.7"; cat "$fallback_log"; }
grep -q 'PREFLIGHT PASS' "$fallback_log" && ck 0 0 "supported fallback reaches preflight pass" || { ck 0 1 "supported fallback reaches preflight pass"; cat "$fallback_log"; }
echo "I) current operator docs prohibit obsolete authorization paths"
for doc in docs/system-architecture.md npm-wrapper/RELEASE_CHECKLIST.md; do
  source="$HERE/../$doc"
  grep -q 'release-process.md' "$source" && ck 0 0 "$doc links canonical runbook" || ck 0 1 "$doc links canonical runbook"
  grep -Ei 'tag.*triggers.*publish|git push.*npm@|npm dist-tag add|npm config set.*authToken|with required reviewer|must configure required reviewers|approve environment' "$source" > "$OUT/obsolete-doc.out" \
    && ck 0 1 "$doc has no active legacy bypass instructions" || ck 0 0 "$doc has no active legacy bypass instructions"
done

echo "J) offline coherence checks docs/release-intent.json and docs/quality-metrics.md"
tmp=$(mktemp -d)
mkdir -p "$tmp/r/skills/flow/runner" "$tmp/r/skills/flow/references" "$tmp/r/.claude-plugin" \
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows" "$tmp/r/docs"
cp "$HERE/../scripts/check-release-coherence.sh" "$tmp/r/scripts/"
cp "$HERE/../skills/flow/SKILL.md" "$tmp/r/skills/flow/"
cp "$HERE/../skills/flow/runner/flow.sh" "$tmp/r/skills/flow/runner/"
cp "$HERE/../skills/flow/runner/attestations.sh" "$tmp/r/skills/flow/runner/"
cp "$HERE/../skills/flow/references/attestations.md" "$tmp/r/skills/flow/references/"
cp "$HERE/../portable-manifest.json" "$tmp/r/"
cp "$HERE/../.claude-plugin/plugin.json" "$tmp/r/.claude-plugin/"
cp "$HERE/../npm-wrapper/package.json" "$tmp/r/npm-wrapper/"
cp "$HERE/../npm-wrapper/README.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../npm-wrapper/README_VN.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../CHANGELOG.md" "$tmp/r/"
cp "$HERE/../npm-wrapper/CHANGELOG.md" "$tmp/r/npm-wrapper/"
cp "$HERE/../README.md" "$tmp/r/"
cp "$HERE/../README_VN.md" "$tmp/r/"
cp "$HERE/../tests/manifest.txt" "$tmp/r/tests/"
cp "$HERE/../.github/workflows/publish-npm-wrapper.yml" "$tmp/r/.github/workflows/"
cp "$HERE/../scripts/release-workflow.mjs" "$tmp/r/scripts/"
cp "$HERE/../docs/release-intent.json" "$HERE/../docs/quality-metrics.md" "$tmp/r/docs/"
while IFS= read -r suite || [ -n "$suite" ]; do
  suite="${suite%$'\r'}"
  case "$suite" in ''|\#*) continue ;; esac
  : > "$tmp/r/tests/$suite"
done < "$tmp/r/tests/manifest.txt"

cp "$tmp/r/docs/release-intent.json" "$tmp/r/docs/release-intent.orig.json"
printf '{"schema_version":1,"intent":true,"npm_version":"9.9.9","skill_version":"9.9.9","channel":"latest"}\n' > "$tmp/r/docs/release-intent.json"
bash "$tmp/r/scripts/check-release-coherence.sh" >"$OUT/coh-intent-bad.out" 2>&1
ck 1 $? "release-intent.json version mismatch fails offline coherence"
grep -q 'docs/release-intent.json invalid' "$OUT/coh-intent-bad.out" && ck 0 0 "reports release-intent mismatch" || ck 0 1 "reports release-intent mismatch"

cp "$tmp/r/docs/release-intent.orig.json" "$tmp/r/docs/release-intent.json"
cp "$tmp/r/docs/quality-metrics.md" "$tmp/r/docs/quality-metrics.orig.md"
printf '# /flow — quality metrics\n\nCurrent: **skill v0.0.0**, **npm-wrapper v0.0.0**.\n' > "$tmp/r/docs/quality-metrics.md"
bash "$tmp/r/scripts/check-release-coherence.sh" >"$OUT/coh-qm-bad.out" 2>&1
ck 1 $? "quality-metrics.md version mismatch fails offline coherence"
grep -q 'docs/quality-metrics.md top section' "$OUT/coh-qm-bad.out" && ck 0 0 "reports quality-metrics mismatch" || ck 0 1 "reports quality-metrics mismatch"

# Trailing period on version in quality-metrics.md passes, while 1.0.10 / 1.0.1.2 / 1.0.1-rc.1 fail.
cur_v="$(sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$tmp/r/npm-wrapper/package.json" | head -1)"
printf '# /flow — quality metrics\n\nCurrent: **skill v%s.** and npm-wrapper v%s.\n' "$cur_v" "$cur_v" > "$tmp/r/docs/quality-metrics.md"
bash "$tmp/r/scripts/check-release-coherence.sh" >"$OUT/coh-qm-period.out" 2>&1
ck 0 $? "quality-metrics.md version followed by trailing period passes"
for bad_suffix in "${cur_v}0" "${cur_v}.2" "${cur_v}-rc.1"; do
  printf '# /flow — quality metrics\n\nCurrent: **skill v%s** and npm-wrapper v%s\n' "$bad_suffix" "$bad_suffix" > "$tmp/r/docs/quality-metrics.md"
  bash "$tmp/r/scripts/check-release-coherence.sh" >"$OUT/coh-qm-suffix.out" 2>&1
  ck 1 $? "quality-metrics.md rejects $bad_suffix when expecting $cur_v"
done

# Quality-metrics top must reject build metadata suffix like +old
printf '# /flow — quality metrics\n\nCurrent: **skill v%s+old**, **npm-wrapper v%s+old**\n' "$cur_v" "$cur_v" > "$tmp/r/docs/quality-metrics.md"
bash "$tmp/r/scripts/check-release-coherence.sh" >"$OUT/coh-qm-plus.out" 2>&1
ck 1 $? "quality-metrics.md rejects +old build metadata suffix"

# Genuine Python-only fallback path (hide node safely in temp PATH; never mutate installed tools).
cp "$tmp/r/docs/quality-metrics.orig.md" "$tmp/r/docs/quality-metrics.md"
cp "$tmp/r/docs/release-intent.orig.json" "$tmp/r/docs/release-intent.json"
pyonly_bin="$OUT/pyonly-bin"
mkdir -p "$pyonly_bin"
for tool in sh bash sed grep awk head tr cut sha256sum shasum dirname basename cat python3; do
  tp="$(type -P "$tool" 2>/dev/null || true)"
  if [ -n "$tp" ] && [ -x "$tp" ]; then
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$tp" > "$pyonly_bin/$tool"
    chmod +x "$pyonly_bin/$tool"
  fi
done
if [ -x "$pyonly_bin/python3" ]; then
  PATH="$pyonly_bin" bash "$tmp/r/scripts/check-release-coherence.sh" >"$OUT/coh-pyonly-ok.out" 2>&1
  ck 0 $? "python-only fallback passes on valid checkout when node is absent"
  grep -q 'SyntaxError' "$OUT/coh-pyonly-ok.out" && ck 0 1 "python-only fallback has no SyntaxError" || ck 0 0 "python-only fallback has no SyntaxError"

  printf '{"schema_version":true,"intent":true,"npm_version":"%s","skill_version":"%s","channel":"latest"}\n' "$cur_v" "$cur_v" > "$tmp/r/docs/release-intent.json"
  PATH="$pyonly_bin" bash "$tmp/r/scripts/check-release-coherence.sh" >"$OUT/coh-pyonly-bad.out" 2>&1
  ck 1 $? "python-only fallback rejects boolean schema_version: true"
  grep -q 'SyntaxError' "$OUT/coh-pyonly-bad.out" && ck 0 1 "python-only error path has no SyntaxError" || ck 0 0 "python-only error path has no SyntaxError"
  grep -q 'docs/release-intent.json invalid' "$OUT/coh-pyonly-bad.out" && ck 0 0 "python-only reports release-intent invalid" || ck 0 1 "python-only reports release-intent invalid"

  # Python-only fallback must also reject missing skill_version when intent is true (Node parity)
  printf '{"schema_version":1,"intent":true,"npm_version":"%s","channel":"latest"}\n' "$cur_v" > "$tmp/r/docs/release-intent.json"
  PATH="$pyonly_bin" bash "$tmp/r/scripts/check-release-coherence.sh" >"$OUT/coh-pyonly-noskill.out" 2>&1
  ck 1 $? "python-only fallback rejects missing skill_version key when intent=true"
  grep -q 'skill_version mismatch' "$OUT/coh-pyonly-noskill.out" && ck 0 0 "python-only reports skill_version mismatch on missing key" || ck 0 1 "python-only reports skill_version mismatch on missing key"
fi
rm -rf "$tmp"

echo "K) --strict-published fail-closed 6-axis post-publish gate (mocked npm/gh + local git origin)"
strict_root="$OUT/strict"
strict_origin="$strict_root/origin.git"
strict_repo="$strict_root/repo"
strict_bin="$strict_root/bin"
mkdir -p "$strict_origin" "$strict_repo/scripts" "$strict_repo/docs" "$strict_repo/skills/flow/runner" \
  "$strict_repo/skills/flow/harness" "$strict_repo/npm-wrapper/scripts" "$strict_repo/npm-wrapper/bin" \
  "$strict_repo/npm-wrapper/skills/flow" "$strict_repo/.claude-plugin" "$strict_bin"
git -c init.defaultBranch=master init --bare -q "$strict_origin"
git -c init.defaultBranch=master init -q "$strict_repo"
git -C "$strict_repo" config user.email "test@example.com"
git -C "$strict_repo" config user.name "Test Runner"
git -C "$strict_repo" remote add origin "file://$strict_origin"

cp "$HERE/../scripts/release-preflight.sh" "$HERE/../scripts/check-release-live.mjs" "$strict_repo/scripts/"
cp "$HERE/../npm-wrapper/scripts/semver.mjs" "$strict_repo/npm-wrapper/scripts/"
for check in check-release-coherence check-doc-budgets check-i18n-pairs; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$strict_repo/scripts/$check.sh"
  chmod +x "$strict_repo/scripts/$check.sh"
done
printf '#!/usr/bin/env bash\necho READY\n' > "$strict_repo/skills/flow/runner/flow.sh"
chmod +x "$strict_repo/skills/flow/runner/flow.sh"
printf '# fixture\n' > "$strict_repo/skills/flow/harness/flow_harness.py"
printf 'version: "2.0.0"\n' > "$strict_repo/skills/flow/SKILL.md"
cp "$strict_repo/skills/flow/SKILL.md" "$strict_repo/npm-wrapper/skills/flow/"
printf '{"version":"2.0.0"}\n' > "$strict_repo/portable-manifest.json"
cp "$strict_repo/portable-manifest.json" "$strict_repo/.claude-plugin/plugin.json"
printf '{"version":"2.0.0"}\n' > "$strict_repo/npm-wrapper/package.json"
printf '{}\n' > "$strict_repo/.claude-plugin/marketplace.json"
cat > "$strict_repo/npm-wrapper/bin/cli.mjs" <<'JS'
import fs from 'node:fs';
const { version } = JSON.parse(fs.readFileSync(new URL('../package.json', import.meta.url)));
console.log(`flow-skill v${version} (ships skill v${version})`);
JS
printf '{"schema_version":1,"intent":true,"npm_version":"2.0.0","skill_version":"2.0.0","channel":"latest"}\n' > "$strict_repo/docs/release-intent.json"
printf '# /flow — quality metrics\n\nCurrent: **skill v2.0.0**, **npm-wrapper v2.0.0**.\n' > "$strict_repo/docs/quality-metrics.md"
printf '# Changelog\n\n## [2.0.0] - 2026-11-13\n- release 2.0.0\n' > "$strict_repo/CHANGELOG.md"
cp "$strict_repo/CHANGELOG.md" "$strict_repo/npm-wrapper/CHANGELOG.md"
printf 'Publication status verified 2026-11-13: GitHub skill release v2.0.0 (2026-11-13) and npm installer 2.0.0 (2026-11-13); registry `latest` is 2.0.0.\n' > "$strict_repo/README.md"
printf 'Bản phát hành đã xác minh ngày 2026-11-13: GitHub phát hành skill v2.0.0 (2026-11-13) và npm installer 2.0.0 (2026-11-13); registry xác nhận `latest` là 2.0.0.\n' > "$strict_repo/README_VN.md"
cp "$strict_repo/README.md" "$strict_repo/npm-wrapper/README.md"
cp "$strict_repo/README_VN.md" "$strict_repo/npm-wrapper/README_VN.md"

git -C "$strict_repo" add -A
git -C "$strict_repo" commit -qm "release 2.0.0"
git -C "$strict_repo" push -q origin master
git -C "$strict_repo" tag "npm@2.0.0"
git -C "$strict_repo" tag "v2.0.0"
git -C "$strict_repo" push -q origin "npm@2.0.0" "v2.0.0"

cat > "$strict_bin/npm" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"dist-tags"*)
    printf '{"latest":"%s","next":"0.7.1-next.0"}\n' "${FAKE_NPM_LATEST:-2.0.0}"
    ;;
  *"dist.attestations.provenance"*)
    if [ "${FAKE_NPM_PROV:-ok}" = "missing" ]; then
      printf 'null\n'
    else
      printf '{"predicateType":"https://slsa.dev/provenance/v1"}\n'
    fi
    ;;
  *)
    echo "unexpected npm call: $*" >&2
    exit 99
    ;;
esac
SH
cat > "$strict_bin/gh" <<'SH'
#!/usr/bin/env bash
if [ "${FAKE_GH_RELEASE:-ok}" = "missing" ]; then
  echo "release not found" >&2
  exit 1
fi
printf '{"tagName":"v2.0.0","isDraft":false,"isPrerelease":false}\n'
SH
cat > "$strict_bin/npm.cmd" <<'CMD'
@bash "%~dp0npm" %*
CMD
cat > "$strict_bin/gh.cmd" <<'CMD'
@bash "%~dp0gh" %*
CMD
chmod +x "$strict_bin/npm" "$strict_bin/gh" "$strict_bin/npm.cmd" "$strict_bin/gh.cmd"
REAL_GIT="$(command -v git)"
cat > "$strict_bin/git" <<SH
#!/usr/bin/env bash
if [ "\${FAKE_GIT_STATUS:-}" = "128" ] && [ "\$1" = "status" ]; then
  echo "fatal: fake git status error" >&2
  exit 128
fi
if [ "\${FAKE_GIT_SHOW:-}" = "128" ] && [ "\$1" = "show" ]; then
  echo "fatal: fake git show error" >&2
  exit 128
fi
if [ "\${FAKE_GIT_LSTREE:-}" = "128" ] && [ "\$1" = "ls-tree" ]; then
  echo "fatal: fake git ls-tree error" >&2
  exit 128
fi
exec "$REAL_GIT" "\$@"
SH
cat > "$strict_bin/git.cmd" <<'CMD'
@bash "%~dp0git" %*
CMD
chmod +x "$strict_bin/git" "$strict_bin/git.cmd"

strict_pass_rc=0
PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-pass.out" 2>&1 || strict_pass_rc=$?
ck 0 "$strict_pass_rc" "--strict-published passes when all 6 axes match"
grep -q 'PREFLIGHT PASS — strict published coherence verified across all 6 axes' "$OUT/strict-pass.out" && ck 0 0 "--strict-published reports post-publish PREFLIGHT PASS without ship prompt" || ck 0 1 "--strict-published reports post-publish PREFLIGHT PASS without ship prompt"

strict_nogh_rc=0
PATH="$strict_bin:$PATH" FAKE_GH_RELEASE=missing bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-nogh.out" 2>&1 || strict_nogh_rc=$?
ck 1 "$strict_nogh_rc" "--strict-published fails when GitHub Release missing"
grep -q 'GitHub Release v2.0.0 missing' "$OUT/strict-nogh.out" && ck 0 0 "reports missing GitHub Release" || ck 0 1 "reports missing GitHub Release"

git -C "$strict_origin" tag -d "v2.0.0" >/dev/null
strict_notag_rc=0
PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-notag.out" 2>&1 || strict_notag_rc=$?
ck 1 "$strict_notag_rc" "--strict-published fails when remote skill tag missing"
grep -q 'remote tag v2.0.0 missing on origin' "$OUT/strict-notag.out" && ck 0 0 "reports missing remote tag" || ck 0 1 "reports missing remote tag"
git -C "$strict_repo" push -q origin "v2.0.0"

strict_npm_rc=0
PATH="$strict_bin:$PATH" FAKE_NPM_LATEST=1.9.9 bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-npm.out" 2>&1 || strict_npm_rc=$?
ck 1 "$strict_npm_rc" "--strict-published fails when npm dist-tag drifts"
grep -q "npm dist-tag 'latest' is '1.9.9', expected '2.0.0'" "$OUT/strict-npm.out" && ck 0 0 "reports npm dist-tag mismatch" || ck 0 1 "reports npm dist-tag mismatch"

strict_noprov_rc=0
PATH="$strict_bin:$PATH" FAKE_NPM_PROV=missing bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-noprov.out" 2>&1 || strict_noprov_rc=$?
ck 1 "$strict_noprov_rc" "--strict-published fails when npm provenance missing"
grep -q 'lacks dist.attestations.provenance' "$OUT/strict-noprov.out" && ck 0 0 "reports missing provenance" || ck 0 1 "reports missing provenance"

printf 'Publication status verified 2026-10-30: GitHub skill release v1.9.9 (2026-10-24) and npm installer 1.9.9 (2026-10-25); registry `latest` is 1.9.9.\n' > "$strict_repo/README.md"
git -C "$strict_repo" add README.md
git -C "$strict_repo" commit -qm "stale readme"
git -C "$strict_repo" tag -f "npm@2.0.0" >/dev/null
git -C "$strict_repo" tag -f "v2.0.0" >/dev/null
git -C "$strict_repo" push -qf origin "npm@2.0.0" "v2.0.0"
strict_readme_rc=0
PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-readme.out" 2>&1 || strict_readme_rc=$?
ck 1 "$strict_readme_rc" "--strict-published fails when README cites older version"
grep -q 'still cites older version' "$OUT/strict-readme.out" && ck 0 0 "reports stale README publication status" || ck 0 1 "reports stale README publication status"

# Duplicate publication-status line: updated first line + stale second line must FAIL.
printf 'Publication status verified 2026-11-13: GitHub skill release v2.0.0 (2026-11-13) and npm installer 2.0.0 (2026-11-13); registry `latest` is 2.0.0.\nPublication status verified 2026-10-30: GitHub skill release v1.9.9 (2026-10-24) and npm installer 1.9.9 (2026-10-25); registry `latest` is 1.9.9.\n' > "$strict_repo/README.md"
git -C "$strict_repo" add README.md
git -C "$strict_repo" commit -qm "dup stale readme"
git -C "$strict_repo" tag -f "npm@2.0.0" >/dev/null
git -C "$strict_repo" tag -f "v2.0.0" >/dev/null
git -C "$strict_repo" push -qf origin "npm@2.0.0" "v2.0.0"
strict_dup_rc=0
PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-dup.out" 2>&1 || strict_dup_rc=$?
ck 1 "$strict_dup_rc" "--strict-published fails on duplicate stale publication-status line"
grep -q 'duplicate publication-status declarations' "$OUT/strict-dup.out" && ck 0 0 "reports duplicate publication-status declarations" || ck 0 1 "reports duplicate publication-status declarations"

# Restore README.md cleanly; test missing root CHANGELOG.md heading & npm-wrapper/CHANGELOG.md heading.
printf 'Publication status verified 2026-11-13: GitHub skill release v2.0.0 (2026-11-13) and npm installer 2.0.0 (2026-11-13); registry `latest` is 2.0.0.\n' > "$strict_repo/README.md"
printf '# Changelog\n\n## [1.0.0] - 2026-10-25\n- old\n' > "$strict_repo/CHANGELOG.md"
git -C "$strict_repo" add README.md CHANGELOG.md
git -C "$strict_repo" commit -qm "missing root changelog heading"
git -C "$strict_repo" tag -f "npm@2.0.0" >/dev/null
git -C "$strict_repo" tag -f "v2.0.0" >/dev/null
git -C "$strict_repo" push -qf origin "npm@2.0.0" "v2.0.0"
strict_cl_rc=0
PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-cl.out" 2>&1 || strict_cl_rc=$?
ck 1 "$strict_cl_rc" "--strict-published fails when CHANGELOG.md lacks 2.0.0 heading"
grep -q 'CHANGELOG.md missing heading for 2.0.0' "$OUT/strict-cl.out" && ck 0 0 "reports missing root CHANGELOG heading" || ck 0 1 "reports missing root CHANGELOG heading"

printf '# Changelog\n\n## [2.0.0] - 2026-11-13\n- release 2.0.0\n' > "$strict_repo/CHANGELOG.md"
printf '# Changelog\n\n## [1.0.0] - 2026-10-25\n- old\n' > "$strict_repo/npm-wrapper/CHANGELOG.md"
git -C "$strict_repo" add CHANGELOG.md npm-wrapper/CHANGELOG.md
git -C "$strict_repo" commit -qm "missing wrapper changelog heading"
git -C "$strict_repo" tag -f "npm@2.0.0" >/dev/null
git -C "$strict_repo" tag -f "v2.0.0" >/dev/null
git -C "$strict_repo" push -qf origin "npm@2.0.0" "v2.0.0"
strict_wcl_rc=0
PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-wcl.out" 2>&1 || strict_wcl_rc=$?
ck 1 "$strict_wcl_rc" "--strict-published fails when npm-wrapper/CHANGELOG.md lacks 2.0.0 heading"
grep -q 'npm-wrapper/CHANGELOG.md missing heading for 2.0.0' "$OUT/strict-wcl.out" && ck 0 0 "reports missing wrapper CHANGELOG heading" || ck 0 1 "reports missing wrapper CHANGELOG heading"

# Restore CHANGELOGs; test tags pointing to wrong HEAD SHA (both behind HEAD, and one tag diverging).
cp "$strict_repo/CHANGELOG.md" "$strict_repo/npm-wrapper/CHANGELOG.md"
git -C "$strict_repo" add npm-wrapper/CHANGELOG.md
git -C "$strict_repo" commit -qm "advance HEAD past old tags"
strict_oldtag_rc=0
PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-oldtag.out" 2>&1 || strict_oldtag_rc=$?
ck 1 "$strict_oldtag_rc" "--strict-published fails when remote tags point to wrong HEAD SHA"
grep -q '!= local HEAD' "$OUT/strict-oldtag.out" && ck 0 0 "reports remote tag != local HEAD" || ck 0 1 "reports remote tag != local HEAD"

git -C "$strict_repo" tag -f "npm@2.0.0" >/dev/null
git -C "$strict_repo" push -qf origin "npm@2.0.0"
strict_difftag_rc=0
PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-difftag.out" 2>&1 || strict_difftag_rc=$?
ck 1 "$strict_difftag_rc" "--strict-published fails when v2.0.0 differs from npm@2.0.0"
grep -q 'remote tag v2.0.0 .* != npm@2.0.0' "$OUT/strict-difftag.out" && ck 0 0 "reports skill tag mismatch against npm tag" || ck 0 1 "reports skill tag mismatch against npm tag"

git -C "$strict_repo" tag -f "v2.0.0" >/dev/null
git -C "$strict_repo" push -qf origin "v2.0.0"

printf '# /flow — quality metrics\n\nCurrent: **skill v1.9.9**, **npm-wrapper v1.9.9**.\n' > "$strict_repo/docs/quality-metrics.md"
git -C "$strict_repo" add docs/quality-metrics.md
git -C "$strict_repo" commit -qm "stale qm"
git -C "$strict_repo" tag -f "npm@2.0.0" >/dev/null
git -C "$strict_repo" tag -f "v2.0.0" >/dev/null
git -C "$strict_repo" push -qf origin "npm@2.0.0" "v2.0.0"
strict_qm_rc=0
PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-qm.out" 2>&1 || strict_qm_rc=$?
ck 1 "$strict_qm_rc" "--strict-published fails when quality-metrics.md mismatches"
grep -q 'docs/quality-metrics.md' "$OUT/strict-qm.out" && ck 0 0 "reports quality-metrics mismatch" || ck 0 1 "reports quality-metrics mismatch"

printf '# /flow — quality metrics\n\nCurrent: **skill v2.0.0.**, **npm-wrapper v2.0.0.**\n' > "$strict_repo/docs/quality-metrics.md"
git -C "$strict_repo" add docs/quality-metrics.md
git -C "$strict_repo" commit -qm "restore clean 2.0.0"
git -C "$strict_repo" tag -f "npm@2.0.0" >/dev/null
git -C "$strict_repo" tag -f "v2.0.0" >/dev/null
git -C "$strict_repo" push -qf origin "npm@2.0.0" "v2.0.0"
strict_final_rc=0
PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-final.out" 2>&1 || strict_final_rc=$?
ck 0 "$strict_final_rc" "--strict-published passes again after restoring all 6 axes (with trailing period)"

# Negative test: uncommitted dirty change in release doc (README) must fail-closed under --strict-published
printf "\n<!-- uncommitted dirty edit -->\n" >> "$strict_repo/README.md"
strict_dirty_rc=0
PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-dirty.out" 2>&1 || strict_dirty_rc=$?
ck 1 "$strict_dirty_rc" "--strict-published fails when release doc has uncommitted dirty changes"
grep -q "working tree dirty for release docs: M README.md" "$OUT/strict-dirty.out" && ck 0 0 "reports dirty working tree on release docs" || ck 0 1 "reports dirty working tree on release docs"
git -C "$strict_repo" checkout -q -- README.md

# Negative test: git status failure (exit 128) must fail-closed under --strict-published
strict_status128_rc=0
FAKE_GIT_STATUS=128 PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-status128.out" 2>&1 || strict_status128_rc=$?
ck 1 "$strict_status128_rc" "--strict-published fails when git status exits 128"
grep -q 'git status failed with exit 128' "$OUT/strict-status128.out" && ck 0 0 "reports git status failure" || ck 0 1 "reports git status failure"

# Negative test: git show failure (exit 128) must fail-closed without working tree fallback
strict_show128_rc=0
FAKE_GIT_SHOW=128 PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-show128.out" 2>&1 || strict_show128_rc=$?
ck 1 "$strict_show128_rc" "--strict-published fails when git show exits 128 without working tree fallback"
grep -q 'git show HEAD:.* failed with exit 128' "$OUT/strict-show128.out" && ck 0 0 "reports git show failure" || ck 0 1 "reports git show failure"

# Negative test: deleting npm-wrapper/README_VN.md in working tree must be caught by git status
rm -f "$strict_repo/npm-wrapper/README_VN.md"
strict_del_vn_rc=0
PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-del-vn.out" 2>&1 || strict_del_vn_rc=$?
ck 1 "$strict_del_vn_rc" "--strict-published fails when npm-wrapper/README_VN.md is deleted in working tree"
grep -q 'working tree dirty for release docs:.*D npm-wrapper/README_VN.md' "$OUT/strict-del-vn.out" && ck 0 0 "reports deleted release doc in working tree" || ck 0 1 "reports deleted release doc in working tree"
git -C "$strict_repo" checkout -q -- npm-wrapper/README_VN.md

# Negative test: git ls-tree failure (exit 128) must fail-closed under --strict-published
strict_lstree128_rc=0
FAKE_GIT_LSTREE=128 PATH="$strict_bin:$PATH" bash "$strict_repo/scripts/release-preflight.sh" --strict-published >"$OUT/strict-lstree128.out" 2>&1 || strict_lstree128_rc=$?
ck 1 "$strict_lstree128_rc" "--strict-published fails when git ls-tree exits 128"
grep -q 'git ls-tree failed with exit 128' "$OUT/strict-lstree128.out" && ck 0 0 "reports git ls-tree failure" || ck 0 1 "reports git ls-tree failure"

echo "P) contributor docs never describe separate release/version axes"
contrib_file="$HERE/../CONTRIBUTING.md"
dispatch_file="$HERE/../skills/flow/references/command-dispatch.md"
if [ ! -r "$contrib_file" ]; then
  echo "  FAIL [CONTRIBUTING.md missing or unreadable]"
  fail=$((fail + 1))
elif tr -s '[:space:]' ' ' < "$contrib_file" | grep -q 'separate release axes'; then
  echo "  FAIL [CONTRIBUTING.md contains stale 'separate release axes']"
  fail=$((fail + 1))
else
  echo "  ok   [CONTRIBUTING.md has no 'separate release axes']"
  pass=$((pass + 1))
fi
if [ ! -r "$dispatch_file" ]; then
  echo "  FAIL [command-dispatch.md missing or unreadable]"
  fail=$((fail + 1))
elif tr -s '[:space:]' ' ' < "$dispatch_file" | grep -q 'remain separate version axes'; then
  echo "  FAIL [skills/flow/references/command-dispatch.md contains stale 'remain separate version axes']"
  fail=$((fail + 1))
else
  echo "  ok   [skills/flow/references/command-dispatch.md has no 'remain separate version axes']"
  pass=$((pass + 1))
fi

# Negative test: original multiline wrapped paragraph must FAIL the guard when restored
neg_dispatch="$(mktemp)"
printf 'The skill product and npm installer remain separate\nversion axes; an npm installer pin restores bytes\n' > "$neg_dispatch"
if tr -s '[:space:]' ' ' < "$neg_dispatch" | grep -q 'remain separate version axes'; then
  echo "  ok   [negative guard: wrapped 'remain separate\\nversion axes' correctly detected]"
  pass=$((pass + 1))
else
  echo "  FAIL [negative guard: wrapped 'remain separate\\nversion axes' was missed]"
  fail=$((fail + 1))
fi
rm -f "$neg_dispatch"


echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

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
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows"
cp "$HERE/../scripts/check-release-coherence.sh" "$tmp/r/scripts/"
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
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows"
cp "$HERE/../scripts/check-release-coherence.sh" "$tmp/r/scripts/"
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
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows"
cp "$HERE/../scripts/check-release-coherence.sh" "$tmp/r/scripts/"
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
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows"
cp "$HERE/../scripts/check-release-coherence.sh" "$tmp/r/scripts/"
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
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows"
cp "$HERE/../scripts/check-release-coherence.sh" "$tmp/r/scripts/"
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
  "$tmp/r/npm-wrapper" "$tmp/r/tests" "$tmp/r/scripts" "$tmp/r/.github/workflows"
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

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

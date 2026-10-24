#!/usr/bin/env bash
# Test suite for scripts/sync-release.mjs (hardened README checks, prerelease protection, tag suppression).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
portable_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    find "$1" -type f -exec sha256sum {} + 2>/dev/null | sort
  else
    find "$1" -type f -exec shasum -a 256 {} + 2>/dev/null | sort
  fi
}
winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
nodepath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

# Clones start from committed HEAD; overlay all release metadata under test.
copy_release_metadata() {
  cp "$ROOT/npm-wrapper/package.json" "$ROOT/npm-wrapper/CHANGELOG.md" "$ROOT/npm-wrapper/README.md" "$ROOT/npm-wrapper/README_VN.md" "$tmp/r/npm-wrapper/"
  cp "$ROOT/README.md" "$ROOT/README_VN.md" "$tmp/r/"
  cp "$ROOT/scripts/check-release-coherence.sh" "$tmp/r/scripts/"
  git -C "$tmp/r" add npm-wrapper/package.json npm-wrapper/CHANGELOG.md npm-wrapper/README.md npm-wrapper/README_VN.md README.md README_VN.md scripts/check-release-coherence.sh
}
echo "A) sync-release --check exits 0 on current repository"
node "$(winpath "$ROOT/scripts/sync-release.mjs")" --check >/tmp/sync_check.out 2>&1
ck 0 $? "sync-release --check exit code"
grep -q "PASS: All release surfaces coherent" /tmp/sync_check.out && ck 0 0 "reported PASS line" || ck 0 1 "reported PASS line"
grep -q 'Unified version (npm_v === skill_v)' /tmp/sync_check.out && ck 0 0 "shared SemVer equality check visible" || ck 0 1 "shared SemVer equality check visible"

echo "B) --check is strictly read-only"
before_status="$(git -C "$ROOT" status --porcelain scripts/ npm-wrapper/ README* skills/ .claude-plugin/ portable-manifest.json CHANGELOG*)"
node "$(winpath "$ROOT/scripts/sync-release.mjs")" --check >/dev/null 2>&1
after_status="$(git -C "$ROOT" status --porcelain scripts/ npm-wrapper/ README* skills/ .claude-plugin/ portable-manifest.json CHANGELOG*)"
[ "$before_status" = "$after_status" ] && ck 0 0 "working tree identical before and after --check" || ck 0 1 "working tree identical before and after --check"

echo "C) deliberate table row drift fails --check with exit 1"
tmp=$(mktemp -d)
mkdir -p "$tmp/r/skills/flow/runner" "$tmp/r/.claude-plugin" "$tmp/r/npm-wrapper" "$tmp/r/scripts"
cp "$ROOT/scripts/sync-release.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-dispatch-response.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-provenance.mjs" "$ROOT/scripts/verify-attestation-with-gh.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-run-artifact.mjs" "$tmp/r/scripts/"
mkdir -p "$tmp/r/npm-wrapper/scripts"
cp "$ROOT/npm-wrapper/scripts/semver.mjs" "$tmp/r/npm-wrapper/scripts/"
cp "$ROOT/skills/flow/SKILL.md" "$tmp/r/skills/flow/"
cp "$ROOT/skills/flow/runner/flow.sh" "$tmp/r/skills/flow/runner/"
cp "$ROOT/portable-manifest.json" "$tmp/r/"
cp "$ROOT/.claude-plugin/plugin.json" "$tmp/r/.claude-plugin/"
cp "$ROOT/npm-wrapper/package.json" "$tmp/r/npm-wrapper/"
cp "$ROOT/npm-wrapper/README.md" "$tmp/r/npm-wrapper/"
cp "$ROOT/npm-wrapper/README_VN.md" "$tmp/r/npm-wrapper/"
cp "$ROOT/README.md" "$tmp/r/"
cp "$ROOT/README_VN.md" "$tmp/r/"
cp "$ROOT/CHANGELOG.md" "$tmp/r/"
cp "$ROOT/npm-wrapper/CHANGELOG.md" "$tmp/r/npm-wrapper/"

# Deliberate drift in npm-wrapper/README.md
printf '| **Current GA** | **9.9.9** — ships skill product **v0.0.1** |\n' > "$tmp/r/npm-wrapper/README.md"
node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --check >/tmp/sync_c.out 2>&1
ck 1 $? "drift fails --check"
grep -q "FAIL: Release coherence check failed" /tmp/sync_c.out && ck 0 0 "reports failure message" || ck 0 1 "reports failure message"
grep -q "ROW MISMATCH" /tmp/sync_c.out && ck 0 0 "detects row mismatch" || ck 0 1 "detects row mismatch"
rm -rf "$tmp"

echo "D) missing README file fails --check with exit 1"
tmp=$(mktemp -d)
mkdir -p "$tmp/r/skills/flow/runner" "$tmp/r/.claude-plugin" "$tmp/r/npm-wrapper" "$tmp/r/scripts"
cp "$ROOT/scripts/sync-release.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-dispatch-response.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-provenance.mjs" "$ROOT/scripts/verify-attestation-with-gh.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-run-artifact.mjs" "$tmp/r/scripts/"
mkdir -p "$tmp/r/npm-wrapper/scripts"
cp "$ROOT/npm-wrapper/scripts/semver.mjs" "$tmp/r/npm-wrapper/scripts/"
cp "$ROOT/skills/flow/SKILL.md" "$tmp/r/skills/flow/"
cp "$ROOT/skills/flow/runner/flow.sh" "$tmp/r/skills/flow/runner/"
cp "$ROOT/portable-manifest.json" "$tmp/r/"
cp "$ROOT/.claude-plugin/plugin.json" "$tmp/r/.claude-plugin/"
cp "$ROOT/npm-wrapper/package.json" "$tmp/r/npm-wrapper/"
cp "$ROOT/npm-wrapper/README.md" "$tmp/r/npm-wrapper/"
# Intentionally omit npm-wrapper/README_VN.md
cp "$ROOT/README.md" "$tmp/r/"
cp "$ROOT/README_VN.md" "$tmp/r/"
cp "$ROOT/CHANGELOG.md" "$tmp/r/"
cp "$ROOT/npm-wrapper/CHANGELOG.md" "$tmp/r/npm-wrapper/"

node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --check >/tmp/sync_d.out 2>&1
ck 1 $? "missing README fails --check"
grep -q "FILE MISSING" /tmp/sync_d.out && ck 0 0 "reports FILE MISSING" || ck 0 1 "reports FILE MISSING"
rm -rf "$tmp"

echo "E) --sync describes prerelease target without publication claims"
tmp=$(mktemp -d)
mkdir -p "$tmp/r/skills/flow/runner" "$tmp/r/.claude-plugin" "$tmp/r/npm-wrapper/scripts" "$tmp/r/scripts"
cp "$ROOT/scripts/sync-release.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-dispatch-response.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-provenance.mjs" "$ROOT/scripts/verify-attestation-with-gh.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-run-artifact.mjs" "$tmp/r/scripts/"
mkdir -p "$tmp/r/npm-wrapper/scripts"
cp "$ROOT/npm-wrapper/scripts/semver.mjs" "$tmp/r/npm-wrapper/scripts/"
cp "$ROOT/skills/flow/SKILL.md" "$tmp/r/skills/flow/"
cp "$ROOT/skills/flow/runner/flow.sh" "$tmp/r/skills/flow/runner/"
cp "$ROOT/portable-manifest.json" "$tmp/r/"
cp "$ROOT/.claude-plugin/plugin.json" "$tmp/r/.claude-plugin/"
cp "$ROOT/npm-wrapper/package.json" "$tmp/r/npm-wrapper/"
cp "$ROOT/npm-wrapper/scripts/sync.mjs" "$tmp/r/npm-wrapper/scripts/"
cp "$ROOT/npm-wrapper/README.md" "$tmp/r/npm-wrapper/"
cp "$ROOT/npm-wrapper/README_VN.md" "$tmp/r/npm-wrapper/"
cp "$ROOT/README.md" "$tmp/r/"
cp "$ROOT/README_VN.md" "$tmp/r/"
cp "$ROOT/CHANGELOG.md" "$tmp/r/"
cp "$ROOT/npm-wrapper/CHANGELOG.md" "$tmp/r/npm-wrapper/"
cp -r "$ROOT/skills/flow" "$tmp/r/skills/"

# Set prerelease version in npm-wrapper/package.json
base_npm_v=$(node -e 'const p = process.argv[1]; console.log(require(p).version)' "$(winpath "$tmp/r/npm-wrapper/package.json")")
base_skill_v=$(node -e 'const fs = require("node:fs"); const m = fs.readFileSync(process.argv[1], "utf8").match(/version:\s*"([^"]+)"/); console.log(m[1])' "$(winpath "$tmp/r/skills/flow/SKILL.md")")
prerelease_v="${base_npm_v}-next.0"
node -e '
  const fs = require("node:fs");
  const p = process.argv[1];
  const pkg = JSON.parse(fs.readFileSync(p, "utf8"));
  pkg.version = process.argv[2];
  fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n");
' "$(winpath "$tmp/r/npm-wrapper/package.json")" "$prerelease_v"
node --input-type=module - "$(winpath "$tmp/r")" "$prerelease_v" <<'NODE'
import fs from 'node:fs';
const [root, version] = process.argv.slice(2);
const skill = `${root}/skills/flow/SKILL.md`;
fs.writeFileSync(skill, fs.readFileSync(skill, 'utf8').replace(/version:\s*"[^"]+"/, `version: "${version}"`));
for (const rel of ['.claude-plugin/plugin.json', 'portable-manifest.json']) {
  const file = `${root}/${rel}`;
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  data.version = version;
  fs.writeFileSync(file, JSON.stringify(data, null, 2) + '\n');
}
const changelog = `${root}/CHANGELOG.md`;
fs.writeFileSync(changelog, `## [${version}]\n\n- Prerelease fixture.\n\n` + fs.readFileSync(changelog, 'utf8'));
NODE
# Add changelog entry for the prerelease in npm-wrapper/CHANGELOG.md
node -e '
  const fs = require("node:fs");
  const p = process.argv[1];
  const v = process.argv[2];
  fs.writeFileSync(p, "## [" + v + "] - 2026-10-15\n\n- Pre-release test.\n\n" + fs.readFileSync(p, "utf8"));
' "$(winpath "$tmp/r/npm-wrapper/CHANGELOG.md")" "$prerelease_v"

node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --sync >/tmp/sync_e.out 2>&1
ck 0 $? "--sync exits 0 with prerelease"

# Both locales describe the target, not an inferred registry GA value.
grep -q "Release target.*${prerelease_v}.*not a publication receipt" "$tmp/r/npm-wrapper/README.md"
ck 0 $? "npm-wrapper/README.md has neutral prerelease target"
grep -q "Mục tiêu phát hành.*${prerelease_v}.*không phải biên nhận đã phát hành" "$tmp/r/npm-wrapper/README_VN.md"
ck 0 $? "npm-wrapper/README_VN.md has neutral prerelease target"
grep -q 'Current GA\|GA hiện tại' "$tmp/r/npm-wrapper/README.md" "$tmp/r/npm-wrapper/README_VN.md"
ck 1 $? "no inferred current GA rows"
node -e 'const fs=require("node:fs");const p=process.argv[1];const data=JSON.parse(fs.readFileSync(p));data.version="9.9.9";fs.writeFileSync(p,JSON.stringify(data,null,2)+"\n");' "$(winpath "$tmp/r/npm-wrapper/package.json")"
node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --sync >/tmp/sync_mirror.out 2>&1
ck 0 $? "canonical skill version repairs npm version drift"
repaired_v=$(node -e 'console.log(require(process.argv[1]).version)' "$(winpath "$tmp/r/npm-wrapper/package.json")")
ck "$prerelease_v" "$repaired_v" "package version mirrored from SKILL.md"

rm -rf "$tmp"

echo "F) existing tags suppress tag creation instructions and report metadata repair"
tmp=$(mktemp -d)
mkdir -p "$tmp/r/skills/flow/runner" "$tmp/r/.claude-plugin" "$tmp/r/npm-wrapper" "$tmp/r/scripts"
cp "$ROOT/scripts/sync-release.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-dispatch-response.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-provenance.mjs" "$ROOT/scripts/verify-attestation-with-gh.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-run-artifact.mjs" "$tmp/r/scripts/"
mkdir -p "$tmp/r/npm-wrapper/scripts"
cp "$ROOT/npm-wrapper/scripts/semver.mjs" "$tmp/r/npm-wrapper/scripts/"
cp "$ROOT/skills/flow/SKILL.md" "$tmp/r/skills/flow/"
cp "$ROOT/skills/flow/runner/flow.sh" "$tmp/r/skills/flow/runner/"
cp "$ROOT/portable-manifest.json" "$tmp/r/"
cp "$ROOT/.claude-plugin/plugin.json" "$tmp/r/.claude-plugin/"
cp "$ROOT/npm-wrapper/package.json" "$tmp/r/npm-wrapper/"
cp "$ROOT/npm-wrapper/README.md" "$tmp/r/npm-wrapper/"
cp "$ROOT/npm-wrapper/README_VN.md" "$tmp/r/npm-wrapper/"
cp "$ROOT/README.md" "$tmp/r/"
cp "$ROOT/README_VN.md" "$tmp/r/"
cp "$ROOT/CHANGELOG.md" "$tmp/r/"
cp "$ROOT/npm-wrapper/CHANGELOG.md" "$tmp/r/npm-wrapper/"
git -C "$tmp/r" init -q
git -C "$tmp/r" add -A
git -C "$tmp/r" -c user.email=test@test -c user.name=test commit -qm init
test_npm_v=$(node -e 'const p = process.argv[1]; console.log(require(p).version)' "$(winpath "$tmp/r/npm-wrapper/package.json")")
test_skill_v=$(node -e 'const fs = require("node:fs"); const m = fs.readFileSync(process.argv[1], "utf8").match(/version:\s*"([^"]+)"/); console.log(m[1])' "$(winpath "$tmp/r/skills/flow/SKILL.md")")
git -C "$tmp/r" tag "npm@$test_npm_v"
git -C "$tmp/r" tag "v$test_skill_v"

node --input-type=module - "$(nodepath "$tmp/r/scripts/sync-release.mjs")" "$(winpath "$tmp/r")" "v$test_skill_v" <<'NODE'
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { appendFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const [modulePath, cwd, tag] = process.argv.slice(2);
const { verifyExistingSkillTag } = await import(pathToFileURL(modulePath));
assert.equal(verifyExistingSkillTag(tag, cwd).ok, false, 'offline fails closed');
const origin = `${cwd}-origin.git`;
execFileSync('git', ['init', '--bare', '-q', origin]);
execFileSync('git', ['remote', 'add', 'origin', origin], { cwd });
assert.equal(verifyExistingSkillTag(tag, cwd).ok, false, 'remote missing fails closed');
execFileSync('git', ['push', '-q', 'origin', `refs/tags/${tag}`], { cwd });
const same = verifyExistingSkillTag(tag, cwd);
assert.equal(same.ok, true);
assert.match(same.reason, /skipping skill tag creation/);
appendFileSync(`${cwd}/skills/flow/SKILL.md`, '\nfixture changed subtree\n');
execFileSync('git', ['add', 'skills'], { cwd });
execFileSync('git', ['-c', 'user.email=test@test', '-c', 'user.name=test', 'commit', '-qm', 'fixture changed subtree'], { cwd });
assert.equal(verifyExistingSkillTag(tag, cwd).ok, false);
execFileSync('git', ['tag', 'v-remote-different'], { cwd });
execFileSync('git', ['push', '-q', 'origin', 'refs/tags/v-remote-different'], { cwd });
assert.equal(verifyExistingSkillTag('v-missing', cwd).ok, false);
execFileSync('git', ['revert', '--no-edit', 'HEAD'], { cwd, env: { ...process.env, GIT_COMMITTER_NAME: 'test', GIT_COMMITTER_EMAIL: 'test@test' } });
assert.equal(verifyExistingSkillTag('v-remote-different', cwd).ok, false, 'remote different subtree fails closed despite matching old local tag');
NODE
ck 0 $? "skill tag reuse skips identical subtree and fails closed on changed or unavailable subtree"

node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --instructions >/tmp/sync_f.out 2>&1
ck 0 $? "sync-release --instructions exit code"
grep -q "Both release tags already exist. This operation was metadata repair / synchronization, not a new release." /tmp/sync_f.out && ck 0 0 "reports metadata repair note" || ck 0 1 "reports metadata repair note"
grep -q "Git tag npm@$test_npm_v ALREADY exists" /tmp/sync_f.out && ck 0 0 "reports ALREADY exists for npm tag" || ck 0 1 "reports ALREADY exists for npm tag"
grep -q "Skipping npm tag command" /tmp/sync_f.out && ck 0 0 "skips npm tag command" || ck 0 1 "skips npm tag command"
grep -q "Git tag v$test_skill_v ALREADY exists" /tmp/sync_f.out && ck 0 0 "reports ALREADY exists for skill tag" || ck 0 1 "reports ALREADY exists for skill tag"
grep -q "Skipping skill tag command" /tmp/sync_f.out && ck 0 0 "skips skill tag command" || ck 0 1 "skips skill tag command"
grep -q "git tag npm@" /tmp/sync_f.out
ck 1 $? "does not emit git tag npm@"
grep -q "git tag v" /tmp/sync_f.out
ck 1 $? "does not emit git tag v"
grep -q "git push origin npm@" /tmp/sync_f.out
ck 1 $? "does not emit git push origin npm@"
grep -q "git push origin v" /tmp/sync_f.out
ck 1 $? "does not emit git push origin v"
rm -rf "$tmp"

echo "G) unconfirmed remote tag lookup suppresses git tag commands"
tmp=$(mktemp -d)
mkdir -p "$tmp/r/skills/flow/runner" "$tmp/r/.claude-plugin" "$tmp/r/npm-wrapper" "$tmp/r/scripts"
cp "$ROOT/scripts/sync-release.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-dispatch-response.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-provenance.mjs" "$ROOT/scripts/verify-attestation-with-gh.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-run-artifact.mjs" "$tmp/r/scripts/"
mkdir -p "$tmp/r/npm-wrapper/scripts"
cp "$ROOT/npm-wrapper/scripts/semver.mjs" "$tmp/r/npm-wrapper/scripts/"
cp "$ROOT/skills/flow/SKILL.md" "$tmp/r/skills/flow/"
cp "$ROOT/skills/flow/runner/flow.sh" "$tmp/r/skills/flow/runner/"
cp "$ROOT/portable-manifest.json" "$tmp/r/"
cp "$ROOT/.claude-plugin/plugin.json" "$tmp/r/.claude-plugin/"
cp "$ROOT/npm-wrapper/package.json" "$tmp/r/npm-wrapper/"
cp "$ROOT/npm-wrapper/README.md" "$tmp/r/npm-wrapper/"
cp "$ROOT/npm-wrapper/README_VN.md" "$tmp/r/npm-wrapper/"
cp "$ROOT/README.md" "$tmp/r/"
cp "$ROOT/README_VN.md" "$tmp/r/"
cp "$ROOT/CHANGELOG.md" "$tmp/r/"
cp "$ROOT/npm-wrapper/CHANGELOG.md" "$tmp/r/npm-wrapper/"
git -C "$tmp/r" init -q
git -C "$tmp/r" add -A
git -C "$tmp/r" -c user.email=test@test -c user.name=test commit -qm init
git -C "$tmp/r" remote add origin /dev/null/nonexistent

node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --instructions >/tmp/sync_g.out 2>&1
ck 0 $? "sync-release --instructions exit code with unreachable remote"
grep -q "Tag creation commands suppressed for safety" /tmp/sync_g.out && ck 0 0 "reports suppression warning" || ck 0 1 "reports suppression warning"
grep -q "git tag npm@" /tmp/sync_g.out
ck 1 $? "does not emit git tag npm@"
grep -q "git tag v" /tmp/sync_g.out
ck 1 $? "does not emit git tag v"
grep -q "git push origin npm@" /tmp/sync_g.out
ck 1 $? "does not emit git push origin npm@"
grep -q "git push origin v" /tmp/sync_g.out
ck 1 $? "does not emit git push origin v"
rm -rf "$tmp"

echo "H) --ship --dry-run is strictly non-mutating (recursive tree hash)"
tmp=$(mktemp -d)
git clone -q "$ROOT" "$tmp/r"
git -C "$tmp/r" config user.email "test@example.com"
git -C "$tmp/r" config user.name "Test Runner"
cp "$ROOT/scripts/sync-release.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-dispatch-response.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-provenance.mjs" "$ROOT/scripts/verify-attestation-with-gh.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-run-artifact.mjs" "$tmp/r/scripts/"
cp "$ROOT/npm-wrapper/scripts/semver.mjs" "$tmp/r/npm-wrapper/scripts/"
mkdir -p "$tmp/r/docs"
cp "$ROOT/docs/release-intent.json" "$tmp/r/docs/"
copy_release_metadata
git -C "$tmp/r" add scripts/ docs/release-intent.json
commit_err=$(git -C "$tmp/r" commit -qm "sync scripts" 2>&1) || {
  if ! git -C "$tmp/r" diff --cached --quiet; then
    echo "FAIL: git commit failed for scripts/: $commit_err" >&2
    exit 1
  fi
}
if [ -d "$ROOT/npm-wrapper/node_modules" ]; then
  ln -s "$ROOT/npm-wrapper/node_modules" "$tmp/r/npm-wrapper/node_modules" || {
    echo "FAIL: failed to symlink $ROOT/npm-wrapper/node_modules to $tmp/r/npm-wrapper/node_modules" >&2
    exit 1
  }
fi

before_tree_hash="$(portable_hash "$tmp/r")"
before_head="$(git -C "$tmp/r" rev-parse HEAD)"
before_tags="$(git -C "$tmp/r" tag -l)"

# PYTHONDONTWRITEBYTECODE: the v1 runner imports its python harness during
# preflight, which would drop __pycache__ into the clone; that interpreter
# artifact is not a sync-release mutation and must not fail the hash guard.
PYTHONDONTWRITEBYTECODE=1 node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship --dry-run >/tmp/sync_h.out 2>&1
ck 0 $? "--ship --dry-run exits 0"
grep -q "DRY-RUN SUCCESS" /tmp/sync_h.out && ck 0 0 "reports DRY-RUN SUCCESS" || ck 0 1 "reports DRY-RUN SUCCESS"

after_tree_hash="$(portable_hash "$tmp/r")"
[ "$before_tree_hash" = "$after_tree_hash" ] && ck 0 0 "recursive tree hash unchanged" || ck 0 1 "recursive tree hash changed"
[ "$before_head" = "$(git -C "$tmp/r" rev-parse HEAD)" ] && ck 0 0 "HEAD unchanged" || ck 0 1 "HEAD changed"
[ "$before_tags" = "$(git -C "$tmp/r" tag -l)" ] && ck 0 0 "tags unchanged" || ck 0 1 "tags changed"

# I) forced battery failure in dry-run: tree hash still unchanged
# README.md budget is 900 words (~317 used): append enough filler to breach it so
# check-doc-budgets.sh (a read-only battery step) fails, while release-surface
# coherence (tables, i18n HEAD-blob hashes) stays green.
yes "# budget breach" | head -700 >> "$tmp/r/README.md"
after_edit_tree_hash="$(portable_hash "$tmp/r")"
PYTHONDONTWRITEBYTECODE=1 node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship --dry-run >/tmp/sync_i.out 2>&1
ck 1 $? "dry-run fails on battery failure"
after_i_tree_hash="$(portable_hash "$tmp/r")"
[ "$after_edit_tree_hash" = "$after_i_tree_hash" ] && ck 0 0 "tree hash unchanged on failure" || ck 0 1 "tree hash changed on failure"
rm -rf "$tmp"

echo "J) fail-closed unconfirmed remote tag check aborts atomically before mutations"
tmp=$(mktemp -d)
git clone --no-tags -q "$ROOT" "$tmp/r"
git -C "$tmp/r" config user.email "test@example.com"
git -C "$tmp/r" config user.name "Test Runner"
git -C "$tmp/r" checkout -B master >/dev/null 2>&1 || true
cp "$ROOT/scripts/sync-release.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-dispatch-response.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-run-artifact.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-provenance.mjs" "$ROOT/scripts/verify-attestation-with-gh.mjs" "$tmp/r/scripts/"
cp "$ROOT/npm-wrapper/scripts/semver.mjs" "$tmp/r/npm-wrapper/scripts/"
mkdir -p "$tmp/r/docs"
cp "$ROOT/docs/release-intent.json" "$tmp/r/docs/"
node -e 'const fs=require("node:fs");const p=process.argv[1];const intent=JSON.parse(fs.readFileSync(p));intent.intent=false;fs.writeFileSync(p,JSON.stringify(intent));' "$(winpath "$tmp/r/docs/release-intent.json")"
before_noop_head="$(git -C "$tmp/r" rev-parse HEAD)"
before_noop_status="$(git -C "$tmp/r" status --porcelain)"
bash "$tmp/r/scripts/release.sh" --yes > "$tmp/noop.out" 2>&1
ck 0 $? 'release.sh --yes exits successfully for intent:false'
grep -q 'NO-OP: release intent is false' "$tmp/noop.out" && ck 0 0 'disabled intent reported as no-op' || ck 0 1 'disabled intent reported as no-op'
[ "$before_noop_head" = "$(git -C "$tmp/r" rev-parse HEAD)" ] && ck 0 0 'no-op leaves HEAD unchanged' || ck 0 1 'no-op leaves HEAD unchanged'
[ "$before_noop_status" = "$(git -C "$tmp/r" status --porcelain)" ] && ck 0 0 'no-op leaves worktree unchanged' || ck 0 1 'no-op leaves worktree unchanged'
[ -z "$(git -C "$tmp/r" tag -l)" ] && ck 0 0 'no-op creates no tags' || ck 0 1 'no-op creates no tags'
node -e 'const fs=require("node:fs");const p=process.argv[1];const intent=JSON.parse(fs.readFileSync(p));intent.intent=true;fs.writeFileSync(p,JSON.stringify(intent));' "$(winpath "$tmp/r/docs/release-intent.json")"
git -C "$tmp/r" add scripts/ docs/release-intent.json
commit_err=$(git -C "$tmp/r" commit -qm "sync scripts" 2>&1) || {
  if ! git -C "$tmp/r" diff --cached --quiet; then
    echo "FAIL: git commit failed for scripts/: $commit_err" >&2
    exit 1
  fi
}
if [ -d "$ROOT/npm-wrapper/node_modules" ]; then
  ln -s "$ROOT/npm-wrapper/node_modules" "$tmp/r/npm-wrapper/node_modules" || {
    echo "FAIL: failed to symlink $ROOT/npm-wrapper/node_modules to $tmp/r/npm-wrapper/node_modules" >&2
    exit 1
  }
fi
git -C "$tmp/r" config url."/dev/null/nonexistent".insteadOf "https://github.com/manhquydev/flow-skill.git"
git -C "$tmp/r" remote set-url origin "https://github.com/manhquydev/flow-skill.git"

before_j_head="$(git -C "$tmp/r" rev-parse HEAD)"
before_j_status="$(git -C "$tmp/r" status --porcelain)"

node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship --yes >/tmp/sync_j.out 2>&1
ck 1 $? "sync-release --ship --yes exits 1 on unconfirmed remote"
grep -q "Remote tag status could not be confirmed with origin" /tmp/sync_j.out && ck 0 0 "reports unconfirmed remote error" || ck 0 1 "reports unconfirmed remote error"
after_j_tags="$(git -C "$tmp/r" tag -l)"
[ -z "$after_j_tags" ] && ck 0 0 "zero tags created" || ck 0 1 "zero tags created"
after_j_head="$(git -C "$tmp/r" rev-parse HEAD)"
[ "$before_j_head" = "$after_j_head" ] && ck 0 0 "zero commits made" || ck 0 1 "zero commits made"
after_j_status="$(git -C "$tmp/r" status --porcelain)"
[ "$before_j_status" = "$after_j_status" ] && ck 0 0 "working tree 100% clean, zero writes" || ck 0 1 "working tree 100% clean, zero writes"
rm -rf "$tmp"

echo "K) gh release integration branches with mocked gh and fail-closed release view errors"
tmp=$(mktemp -d)
git clone --bare --no-tags -q "$ROOT" "$tmp/origin.git"
git clone --no-tags -q "$tmp/origin.git" "$tmp/r"
git -C "$tmp/r" config user.email "test@example.com"
git -C "$tmp/r" config user.name "Test Runner"
checkout_err=$(git -C "$tmp/r" checkout -B master 2>&1) || {
  echo "FAIL: could not check out master in Case K fixture: $checkout_err" >&2
  exit 1
}
cp "$ROOT/scripts/sync-release.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-dispatch-response.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-provenance.mjs" "$ROOT/scripts/verify-attestation-with-gh.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release-run-artifact.mjs" "$tmp/r/scripts/"
cp "$ROOT/scripts/release.sh" "$tmp/r/scripts/"
cp "$ROOT/npm-wrapper/scripts/semver.mjs" "$tmp/r/npm-wrapper/scripts/"
cp "$ROOT/.github/workflows/publish-npm-wrapper.yml" "$tmp/r/.github/workflows/"
mkdir -p "$tmp/r/npm-wrapper/scripts"
cp "$ROOT/scripts/release-eligibility.mjs" "$ROOT/scripts/release-workflow.mjs" "$tmp/r/scripts/"
cp "$ROOT/npm-wrapper/scripts/semver.mjs" "$tmp/r/npm-wrapper/scripts/"
mkdir -p "$tmp/r/docs"
cp "$ROOT/docs/release-intent.json" "$tmp/r/docs/"
copy_release_metadata
node -e 'const fs=require("node:fs");const p=process.argv[1];const intent=JSON.parse(fs.readFileSync(p));intent.intent=true;fs.writeFileSync(p,JSON.stringify(intent));' "$(winpath "$tmp/r/docs/release-intent.json")"
cp "$ROOT/scripts/check-release-coherence.sh" "$tmp/r/scripts/"
git -C "$tmp/r" add scripts/ .github/workflows/publish-npm-wrapper.yml npm-wrapper/scripts/semver.mjs docs/release-intent.json
commit_err=$(git -C "$tmp/r" commit -qm "sync scripts" 2>&1) || {
  if ! git -C "$tmp/r" diff --cached --quiet; then
    echo "FAIL: git commit failed for scripts/: $commit_err" >&2
    exit 1
  fi
}
git -C "$tmp/r" push -q origin master
git -C "$tmp/r" config url."file://$tmp/origin.git".insteadOf "https://github.com/manhquydev/flow-skill.git"
git -C "$tmp/r" remote set-url origin "https://github.com/manhquydev/flow-skill.git"
git -C "$tmp/r" remote set-url --push origin "https://github.com/manhquydev/flow-skill.git"
if [ -d "$ROOT/npm-wrapper/node_modules" ]; then
  ln -s "$ROOT/npm-wrapper/node_modules" "$tmp/r/npm-wrapper/node_modules" || {
    echo "FAIL: failed to symlink $ROOT/npm-wrapper/node_modules to $tmp/r/npm-wrapper/node_modules" >&2
    exit 1
  }
fi

k_skill_v=$(node -e 'const fs = require("node:fs"); const m = fs.readFileSync(process.argv[1], "utf8").match(/version:\s*"([^"]+)"/); console.log(m[1])' "$(winpath "$tmp/r/skills/flow/SKILL.md")")
k_npm_v=$(node -e 'const p = process.argv[1]; console.log(require(p).version)' "$(winpath "$tmp/r/npm-wrapper/package.json")")
clean_k_tags() {
  if [ -n "${k_npm_v:-}" ]; then
    git -C "$tmp/origin.git" tag -d "npm@$k_npm_v" >/dev/null 2>&1 || true
    git -C "$tmp/r" tag -d "npm@$k_npm_v" >/dev/null 2>&1 || true
  fi
  if [ -n "${k_skill_v:-}" ]; then
    git -C "$tmp/origin.git" tag -d "v$k_skill_v" >/dev/null 2>&1 || true
    git -C "$tmp/r" tag -d "v$k_skill_v" >/dev/null 2>&1 || true
  fi
  for t in $(git -C "$tmp/origin.git" tag -l | tr -d '\r'); do
    git -C "$tmp/origin.git" tag -d "$t" >/dev/null 2>&1 || true
  done
  for t in $(git -C "$tmp/r" tag -l | tr -d '\r'); do
    git -C "$tmp/r" tag -d "$t" >/dev/null 2>&1 || true
  done
  [ -z "$(git -C "$tmp/origin.git" tag -l)" ] || { echo "FAIL: origin tags remain after clean_k_tags" >&2; exit 1; }
  [ -z "$(git -C "$tmp/r" tag -l)" ] || { echo "FAIL: local tags remain after clean_k_tags" >&2; exit 1; }
}
clean_k_tags

dumped_k_files=""
ck_k() {
  local expected="$1" got="$2" label="$3" outfile="${4:-}" rc="${5:-unknown}"
  if [ "$expected" = "$got" ]; then
    echo "  ok   [$label]"
    pass=$((pass+1))
  else
    echo "  FAIL [$label] expected=$expected got=$got (exit code: $rc)"
    fail=$((fail+1))
    if [ -n "$outfile" ] && [ -f "$outfile" ]; then
      case " $dumped_k_files " in
        *" $outfile "*) ;;
        *)
          dumped_k_files="$dumped_k_files $outfile"
          echo "=== Captured output ($outfile) [rc=$rc] ==="
          cat "$outfile"
          echo "=== End captured output ==="
          grep -E "FAIL: Verification step|Aborting" "$outfile" | tail -5 || true
          ;;
      esac
    fi
  fi
}
mock_bin="$tmp/bin"
mkdir -p "$mock_bin"
cat > "$mock_bin/gh" << "EOF"
#!/usr/bin/env bash
mode="${GH_MOCK_MODE:-exists}"
ci_app="${GH_MOCK_CI_APP:-github-actions}"
env_protection="${GH_MOCK_ENV_PROTECTION:-approved}"
actor_mode="${GH_MOCK_ACTOR_MODE:-valid}"
if [ "$1" = "--version" ]; then
  printf 'gh version %s\n' "${GH_MOCK_VERSION:-2.68.0}"
  exit 0
fi
if [ "$1" = "attestation" ] && [ "$2" = "verify" ] && [ "$3" = "--help" ]; then
  printf '%s\n' '--bundle --digest-alg --repo --signer-workflow --source-ref --source-digest'
  exit 0
fi

if [ "$1" = "api" ]; then
  if { [ "${GH_MOCK_DISPATCH_MODE:-}" = "skip-publish" ] || [ "${GH_MOCK_DISPATCH_MODE:-}" = "publish-success" ]; } && [ "$2" = "-X" ] && [ "$3" = "POST" ]; then
    request_body="$(cat)"
    node -e 'const fs=require("fs");fs.writeFileSync(process.argv[1],process.argv[2]);' "$GH_MOCK_STATE_FILE" "$request_body"
    printf '{"workflow_run_id":777,"run_url":"https://api.github.com/repos/manhquydev/flow-skill/actions/runs/777"}\n'
    exit 0
  fi
  case "$2" in
    user) if [ "$actor_mode" = "invalid" ]; then printf 'not-numeric\n'; else printf '12345\n'; fi; exit 0 ;;
    */actions/runs/777/jobs*)
      node -e 'console.log(JSON.stringify({total_count:2,jobs:[{run_id:777,run_attempt:1,name:"eligibility",status:"completed",conclusion:"success"},{run_id:777,run_attempt:1,name:"publish",status:"completed",conclusion:process.env.GH_MOCK_PUBLISH_CONCLUSION||"success"}]}));'
      exit 0
      ;;
    */actions/runs/777)
      node -e 'const i=JSON.parse(require("fs").readFileSync(process.env.GH_MOCK_STATE_FILE,"utf8")).inputs;console.log(JSON.stringify({id:777,actor:{id:12345},head_sha:i.expected_sha,path:".github/workflows/publish-npm-wrapper.yml",event:"workflow_dispatch",display_title:`Publisher ${i.expected_sha} ${i.expected_version} ${i.dispatch_id}`,status:"completed",conclusion:"success",run_attempt:1}));'
      exit 0
      ;;
    *commits/*/check-runs*)
      head_sha=$(echo "$2" | sed -n 's|.*/commits/\([^/]*\)/check-runs.*|\1|p')
      cat << JSON
{"check_runs":[{"id":1,"name":"all-checks-passed","head_sha":"$head_sha","status":"completed","conclusion":"success","app":{"slug":"$ci_app"}}]}
JSON
      exit 0
      ;;
    *environments/npm-publish/deployment-branch-policies*)
      if [ "$env_protection" = "wrong" ]; then
        printf '{"branch_policies":[{"type":"tag","name":"npm@*"}]}\n'
      else
        printf '{"branch_policies":[{"type":"branch","name":"master"}]}\n'
      fi
      exit 0
      ;;
    *environments/npm-publish*)
      if [ "$env_protection" = "error" ]; then echo "gh: Not Found (HTTP 404)" >&2; exit 1; fi
      printf '{"name":"npm-publish","deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true},"protection_rules":[]}\n'
      exit 0
      ;;
  esac

if [ "$1" = "run" ] && [ "$2" = "watch" ]; then
  exit 0
fi
fi

if [ "$1" = "release" ] && [ "$2" = "view" ]; then
  if [ "$mode" = "exists" ]; then
    echo "{\"tagName\":\"$3\"}"
    exit 0
  elif [ "$mode" = "auth_error" ]; then
    echo "HTTP 401: Bad credentials (mock auth failure)" >&2
    exit 1
  else
    echo "release not found" >&2
    exit 1
  fi
fi
if [ "$1" = "release" ] && [ "$2" = "create" ]; then
  if [ "$mode" = "create_fail" ]; then
    echo "mock gh release create error" >&2
    exit 1
  else
    echo "https://github.com/manhquydev/flow-skill/releases/tag/$3"
    exit 0
  fi
fi
exit 0
EOF
chmod +x "$mock_bin/gh"
cat > "$mock_bin/gh.cmd" << "EOF"
@bash "%~dp0gh" %*
EOF

# Incapable host tooling must be rejected before either live or dry-run dispatch.
for capability_mode in --yes --dry-run; do
  capability_state="$tmp/capability-state.json"
  GH_MOCK_VERSION="2.46.0" GH_MOCK_DISPATCH_MODE="publish-success" GH_MOCK_STATE_FILE="$capability_state" PATH="$mock_bin:$PATH" node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship "$capability_mode" > "$tmp/capability.out" 2>&1
  capability_rc=$?
  ck_k 1 "$capability_rc" "old gh refuses $capability_mode before dispatch" "$tmp/capability.out" "$capability_rc"
  grep -q 'controller must provision a project-local portable gh' "$tmp/capability.out" && ck_k 0 0 'actionable portable gh requirement' || ck_k 0 1 'actionable portable gh requirement'
  [ ! -e "$capability_state" ] && ck_k 0 0 'zero dispatches with old gh' || ck_k 0 1 'zero dispatches with old gh'
done

# K1: missing dispatch receipt fails closed; the workflow's own eligibility fixtures cover the disabled latch.
GH_MOCK_MODE="exists" PATH="$mock_bin:$PATH" node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship --yes > "$tmp/k1.out" 2>&1
k1_rc=$?
ck_k 1 $k1_rc "K1: live release refuses dispatch without exact workflow run receipt" "$tmp/k1.out" $k1_rc
grep -q "workflow dispatch returned no run details" "$tmp/k1.out" && ck_k 0 0 "K1: missing run receipt is the refusal reason" "$tmp/k1.out" $k1_rc || ck_k 0 1 "K1: missing run receipt is the refusal reason" "$tmp/k1.out" $k1_rc
[ -z "$(git -C "$tmp/r" tag -l)" ] && ck_k 0 0 "K1: no local tags without verified publisher run" || ck_k 0 1 "K1: no local tags without verified publisher run"

clean_k_tags
# K2: overall success cannot authorize tags when the live publish job was skipped.
GH_MOCK_DISPATCH_MODE="skip-publish" GH_MOCK_PUBLISH_CONCLUSION="skipped" GH_MOCK_STATE_FILE="$tmp/k2-state.json" PATH="$mock_bin:$PATH" node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship --yes > "$tmp/k2.out" 2>&1
k2_rc=$?
ck_k 1 $k2_rc "K2: skipped live publish job blocks release tagging" "$tmp/k2.out" $k2_rc
grep -q "publisher publish job conclusion must be success" "$tmp/k2.out" && ck_k 0 0 "K2: skipped publish outcome is the refusal reason" "$tmp/k2.out" $k2_rc || ck_k 0 1 "K2: skipped publish outcome is the refusal reason" "$tmp/k2.out" $k2_rc
[ -z "$(git -C "$tmp/r" tag -l)" ] && ck_k 0 0 "K2: no tags created when publish was skipped" || ck_k 0 1 "K2: no tags created when publish was skipped"

clean_k_tags
# K3: successful publish outcome without retained verification receipts must fail closed before tags.
GH_MOCK_DISPATCH_MODE="publish-success" GH_MOCK_PUBLISH_CONCLUSION="success" GH_MOCK_STATE_FILE="$tmp/k3-state.json" PATH="$mock_bin:$PATH" node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship --yes > "$tmp/k3.out" 2>&1
k3_rc=$?
ck_k 1 $k3_rc "K3: publish run without retained artifact cannot be finalized" "$tmp/k3.out" $k3_rc
grep -q "release-artifact.json" "$tmp/k3.out" && ck_k 0 0 "K3: missing artifact receipt blocks promotion" "$tmp/k3.out" $k3_rc || ck_k 0 1 "K3: missing artifact receipt blocks promotion" "$tmp/k3.out" $k3_rc
[ -z "$(git -C "$tmp/r" tag -l)" ] && ck_k 0 0 "K3: no tags created without retained verification artifact" || ck_k 0 1 "K3: no tags created without retained verification artifact"

clean_k_tags
# K4: malformed authenticated actor identity refuses before dispatch.
GH_MOCK_ACTOR_MODE="invalid" PATH="$mock_bin:$PATH" node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship --yes > "$tmp/k4.out" 2>&1
k4_rc=$?
ck_k 1 $k4_rc "K4: sync-release refuses malformed authenticated actor ID" "$tmp/k4.out" $k4_rc
grep -q "did not return a valid authenticated actor ID" "$tmp/k4.out" && ck_k 0 0 "K4: actor validation is the refusal reason" "$tmp/k4.out" $k4_rc || ck_k 0 1 "K4: actor validation is the refusal reason" "$tmp/k4.out" $k4_rc
[ -z "$(git -C "$tmp/r" tag -l)" ] && ck_k 0 0 "K4: no local tags without valid actor identity" || ck_k 0 1 "K4: no local tags without valid actor identity"

clean_k_tags
# Test K5: Spoofed CI check app (e.g. app slug "malicious-bot" instead of "github-actions") fails closed:
GH_MOCK_CI_APP="malicious-bot" PATH="$mock_bin:$PATH" node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship --yes > "$tmp/k5.out" 2>&1
k5_rc=$?
ck_k 1 $k5_rc "K5: sync-release exits 1 when CI check run app is not github-actions" "$tmp/k5.out" $k5_rc
grep -q "expected authoritative \"github-actions\"" "$tmp/k5.out" && ck_k 0 0 "K5: output flags non-authoritative app slug" "$tmp/k5.out" $k5_rc || ck_k 0 1 "K5: output flags non-authoritative app slug" "$tmp/k5.out" $k5_rc
grep -q "RELEASE SHIP SUCCESSFUL" "$tmp/k5.out"
ck_k 1 $? "K5: output does NOT contain 'RELEASE SHIP SUCCESSFUL'" "$tmp/k5.out" $k5_rc
grep -qE "Git tag .* already exists" "$tmp/k5.out"
ck_k 1 $? "K5: output does NOT contain 'Git tag already exists'" "$tmp/k5.out" $k5_rc
[ -z "$(git -C "$tmp/r" tag -l "npm@$k_npm_v")" ] && ck_k 0 0 "K5: zero tags created on CI app spoof" || ck_k 0 1 "K5: zero tags created on CI app spoof"

clean_k_tags
# Test K6: master-only deployment policy permits exactly branch master; tag rules fail closed.
GH_MOCK_ENV_PROTECTION="wrong" PATH="$mock_bin:$PATH" node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship --yes > "$tmp/k6.out" 2>&1
k6_rc=$?
ck_k 1 $k6_rc "K6: rejects tag deployment policy before tags" "$tmp/k6.out" $k6_rc
grep -q "allow exactly branch master" "$tmp/k6.out" && ck_k 0 0 "K6: reports exact master-only requirement" "$tmp/k6.out" $k6_rc || ck_k 0 1 "K6: reports exact master-only requirement" "$tmp/k6.out" $k6_rc
[ -z "$(git -C "$tmp/r" tag -l "npm@$k_npm_v")" ] && ck_k 0 0 "K6: zero tags created when deployment policy is wrong" || ck_k 0 1 "K6: zero tags created when deployment policy is wrong"


clean_k_tags
# Test K8: Non-canonical repository remote URL refuses promotion fail-closed before any commit/tag/push:
git -C "$tmp/r" config url."file://$tmp/origin.git".insteadOf "https://github.com/other-org/malicious-repo.git"
git -C "$tmp/r" remote set-url origin "https://github.com/other-org/malicious-repo.git"
PATH="$mock_bin:$PATH" node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship --yes > "$tmp/k8.out" 2>&1
k8_rc=$?
ck_k 1 $k8_rc "K8: sync-release exits 1 on non-canonical repository remote" "$tmp/k8.out" $k8_rc
grep -q "not an accepted canonical repository URL" "$tmp/k8.out" && ck_k 0 0 "K8: output reports non-canonical remote error" "$tmp/k8.out" $k8_rc || ck_k 0 1 "K8: output reports non-canonical remote error" "$tmp/k8.out" $k8_rc
grep -q "RELEASE SHIP SUCCESSFUL" "$tmp/k8.out"
ck_k 1 $? "K8: output does NOT contain 'RELEASE SHIP SUCCESSFUL'" "$tmp/k8.out" $k8_rc
[ -z "$(git -C "$tmp/r" tag -l "npm@$k_npm_v")" ] && ck_k 0 0 "K8: zero tags created on wrong remote" || ck_k 0 1 "K8: zero tags created on wrong remote"

clean_k_tags
# Test K9: Credential-bearing or invalid remote origin fails closed before any tag/push without leaking credentials in output:
git -C "$tmp/r" remote set-url origin "https://user:SECRET_SENTINEL@invalid.example/manhquydev/flow-skill.git"
PATH="$mock_bin:$PATH" node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship --yes > "$tmp/k9.out" 2>&1
k9_rc=$?
ck_k 1 $k9_rc "K9: sync-release exits 1 on credential-bearing remote at evil host" "$tmp/k9.out" $k9_rc
grep -q "not an accepted canonical repository URL" "$tmp/k9.out" && ck_k 0 0 "K9: output reports sanitized canonical remote error" "$tmp/k9.out" $k9_rc || ck_k 0 1 "K9: output reports sanitized canonical remote error" "$tmp/k9.out" $k9_rc
grep -q "SECRET_SENTINEL" "$tmp/k9.out"
ck_k 1 $? "K9: output has ZERO occurrence of SECRET_SENTINEL (no credential leak)" "$tmp/k9.out" $k9_rc
grep -q "RELEASE SHIP SUCCESSFUL" "$tmp/k9.out"
ck_k 1 $? "K9: output does NOT contain 'RELEASE SHIP SUCCESSFUL'" "$tmp/k9.out" $k9_rc
[ -z "$(git -C "$tmp/r" tag -l "npm@$k_npm_v")" ] && ck_k 0 0 "K9: zero tags created on credential-bearing remote" || ck_k 0 1 "K9: zero tags created on credential-bearing remote"
[ -z "$(git -C "$tmp/origin.git" tag -l "npm@$k_npm_v")" ] && ck_k 0 0 "K9: zero remote tags pushed on credential-bearing remote" || ck_k 0 1 "K9: zero remote tags pushed on credential-bearing remote"

clean_k_tags
# Test K10: Lookalike evil host with unanchored github.com path fails closed before any tag/push without leaking URL:
git -C "$tmp/r" remote set-url origin "https://evil.example/github.com/manhquydev/flow-skill"
PATH="$mock_bin:$PATH" node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship --yes > "$tmp/k10.out" 2>&1
k10_rc=$?
ck_k 1 $k10_rc "K10: sync-release exits 1 on lookalike host with embedded github.com path" "$tmp/k10.out" $k10_rc
grep -q "not an accepted canonical repository URL" "$tmp/k10.out" && ck_k 0 0 "K10: output reports sanitized canonical remote error" "$tmp/k10.out" $k10_rc || ck_k 0 1 "K10: output reports sanitized canonical remote error" "$tmp/k10.out" $k10_rc
grep -q "evil.example" "$tmp/k10.out"
ck_k 1 $? "K10: output has ZERO occurrence of evil.example (never prints raw URL)" "$tmp/k10.out" $k10_rc
grep -q "RELEASE SHIP SUCCESSFUL" "$tmp/k10.out"
ck_k 1 $? "K10: output does NOT contain 'RELEASE SHIP SUCCESSFUL'" "$tmp/k10.out" $k10_rc
[ -z "$(git -C "$tmp/r" tag -l "npm@$k_npm_v")" ] && ck_k 0 0 "K10: zero tags created on lookalike remote" || ck_k 0 1 "K10: zero tags created on lookalike remote"
[ -z "$(git -C "$tmp/origin.git" tag -l "npm@$k_npm_v")" ] && ck_k 0 0 "K10: zero remote tags pushed on lookalike remote" || ck_k 0 1 "K10: zero remote tags pushed on lookalike remote"
git -C "$tmp/r" remote set-url origin "https://github.com/manhquydev/flow-skill.git"
git -C "$tmp/r" config --unset url."file://$tmp/origin.git".insteadOf "https://github.com/other-org/malicious-repo.git" || true
git -C "$tmp/r" config url."file://$tmp/origin.git".insteadOf "https://github.com/manhquydev/flow-skill.git"
test "$(git -C "$tmp/r" remote get-url --push origin)" = "file://$tmp/origin.git" || { echo "FAIL: Case K push URL is not the local bare origin" >&2; exit 1; }

# K11/K12: real workflow CLI and installed-package smoke; only process/transport
# boundaries are fixtures. Never launch npm publish, live gh, or a network push.
# A preload keeps this boundary identical on Windows (including direct gh spawns).
node --input-type=module - "$(winpath "$tmp/r")" "$k_npm_v" "$k_skill_v" << 'EOF'
import fs from 'node:fs';
import path from 'node:path';
const [repo, version, skillVersion] = process.argv.slice(2);
fs.writeFileSync(path.join(repo, 'docs/release-intent.json'), JSON.stringify({ schema_version: 1, intent: true, npm_version: version, skill_version: skillVersion, channel: version.includes('-') ? 'next' : 'latest', compatibility: 'backwards-compatible', security_rights_expanded: false }, null, 2) + '\n');
EOF
git -C "$tmp/r" add docs/release-intent.json
git -C "$tmp/r" commit -qm 'test: activate exact consumer release intent' || exit 1
git -C "$tmp/r" push -q origin master || exit 1
cat > "$tmp/consumer-boundary.cjs" << 'EOF'
const cp = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { syncBuiltinESMExports } = require('node:module');
const root = fs.realpathSync(process.env.K_CONSUMER_ROOT);
// Unrelated Node programs in the real preflight battery retain their own boundaries.
if (!['sync-release.mjs', 'release-workflow.mjs', 'verify-attestation-with-gh.mjs', 'smoke.mjs'].includes(path.basename(process.argv[1] || ''))) return;
const repo = path.join(root, 'r');
const store = path.join(root, 'retained');
const trace = path.join(root, 'consumer-trace.jsonl');
const stateFile = path.join(root, 'consumer-state.json');
const exec = cp.execFileSync;
const spawn = cp.spawnSync;
const log = (event, data = {}) => fs.appendFileSync(trace, JSON.stringify({ event, ...data }) + '\n');
const state = () => JSON.parse(fs.readFileSync(stateFile, 'utf8'));
const result = (stdout, status = 0, stderr = '') => ({ stdout, stderr, status, signal: null });
const json = value => JSON.stringify(value);
const sha = () => exec('git', ['rev-parse', 'HEAD'], { cwd: repo, encoding: 'utf8' }).trim();
const workflow = (command, args, env) => {
  log(command);
  return exec(process.execPath, [path.join(repo, 'scripts/release-workflow.mjs'), command, ...args], {
    cwd: repo, encoding: 'utf8', env: { ...process.env, ...env },
  });
};
function registry(args, options) {
  const s = state();
  assert.equal(args[0], 'view');
  const spec = args[1], field = args[2];
  assert.ok(spec === '@manhquy/flow-skill' || spec === `@manhquy/flow-skill@${s.version}`);
  const explicit = args.find(a => a.startsWith('--registry='));
  if (args.includes('--json') && field !== 'dist.attestations.provenance') assert.equal(explicit, '--registry=https://registry.npmjs.org/');
  else assert.equal(options.env?.npm_config_registry, 'https://registry.npmjs.org/');
  log('registry', { spec, field, registry: 'https://registry.npmjs.org/', published: s.published, afterSmoke: !!s.afterSmoke });
  if (!s.published && field === 'version') return result('', 1, 'npm ERR! E404 Not Found');
  let value;
  if (field === 'version') value = s.version;
  else if (field === 'dist.integrity') value = s.integrity;
  else if (field === 'dist-tags') value = { [s.channel]: s.published && !(s.afterSmoke && process.env.K_CONSUMER_HOLLOW === 'channel-drift') ? s.version : '0.0.1' };
  else if (field === 'dist.attestations.provenance') value = { predicateType: 'https://slsa.dev/provenance/v1' };
  else throw new Error(`Unexpected npm view field: ${field}`);
  return result(args.includes('--json') ? json(value) : `${value}\n`);
}
function gh(args, options) {
  const s = state();
  if (args[0] === '--version') return 'gh version 2.68.0\n';
  if (args[0] === 'attestation') {
    if (args[2] === '--help') return '--bundle --digest-alg --repo --signer-workflow --source-ref --source-digest';
    assert.equal(args[1], 'verify');
    assert.equal(crypto.createHash('sha512').update(fs.readFileSync(args[2])).digest('base64'), s.integrity.slice(7));
    for (const [flag, value] of Object.entries({ '--digest-alg': 'sha512', '--repo': 'manhquydev/flow-skill', '--signer-workflow': 'manhquydev/flow-skill/.github/workflows/publish-npm-wrapper.yml', '--source-ref': 'refs/heads/master', '--source-digest': s.sha, '--format': 'json' })) assert.equal(args[args.indexOf(flag) + 1], value);
    assert.deepEqual(JSON.parse(fs.readFileSync(args[args.indexOf('--bundle') + 1], 'utf8')), s.statement);
    log('attestation', { sha: s.sha, integrity: s.integrity });
    return json([{ verificationResult: { statement: s.statement } }]);
  }
  if (args[0] === 'run' && args[1] === 'watch') { assert.equal(args[2], '777'); return ''; }
  if (args[0] === 'run' && args[1] === 'download') {
    assert.equal(args[2], '777');
    const name = args[args.indexOf('--name') + 1];
    const dest = args[args.indexOf('--dir') + 1];
    assert.ok(['npm-package-777-1', 'npm-verification-777-1'].includes(name));
    for (const file of name.startsWith('npm-package') ? [s.name, 'release-artifact.json'] : ['npm-audit-verified.json', 'slsa-bundle.json']) fs.copyFileSync(path.join(store, file), path.join(dest, file));
    log('download', { name }); return '';
  }
  if (args[0] === 'release') {
    assert.equal(args[2], `v${s.skillVersion}`);
    const releaseCase = process.env.K_CONSUMER_HOLLOW;
    if (args[1] === 'view') {
      log('release-view');
      if (releaseCase === 'release-exists') return json({ tagName: args[2] });
      const diagnostics = {
        'release-crlf': 'release not found\r\n',
        'release-auth': 'HTTP 401: Bad credentials (mock auth failure)',
        'release-forbidden': 'HTTP 403: Forbidden (mock permission failure)',
        'release-http404': 'HTTP 404: Not Found (mock API failure)',
        'release-http500': 'HTTP 500: Internal Server Error (mock API failure)',
        'release-network': 'error connecting to api.github.com: mock connection reset',
        'release-empty': '',
        'release-unexpected': 'could not find release (mock unexpected diagnostic)',
      };
      const stderr = diagnostics[releaseCase] ?? 'release not found\n';
      const e = new Error(`mock gh release view failed: ${stderr}`);
      e.status = 1; e.stderr = Buffer.from(stderr); throw e;
    }
    assert.equal(args[1], 'create');
    // Record before refusing so even a caught fixture error exposes the side effect.
    log('release');
    assert.ok(['sound', 'release-crlf'].includes(releaseCase), `Unexpected gh release create in ${releaseCase}`);
    return '';
  }
  assert.equal(args[0], 'api');
  const endpoint = args[1];
  const ci = { id: 888, workflow_id: 295237428, path: '.github/workflows/ci.yml', head_sha: s.sha, head_branch: 'master', event: 'push', status: 'completed', conclusion: 'success', run_attempt: 1 };
  if (args.includes('POST')) {
    const request = JSON.parse(options.input);
    assert.equal(request.ref, 'master');
    const i = request.inputs;
    assert.equal(i.mode, 'publish'); assert.equal(i.expected_sha, sha());
    assert.equal(i.expected_version, s.version); assert.equal(i.expected_actor_id, '12345');
    assert.match(i.dispatch_id, /^[0-9a-f-]{36}$/);
    s.request = request; fs.writeFileSync(stateFile, json(s)); log('dispatch', request);
    const env = { MODE: 'publish', EXPECTED_SHA: s.sha, GITHUB_SHA: s.sha, EXPECTED_VERSION: s.version, GITHUB_REF: 'refs/heads/master', GITHUB_REPOSITORY: 'manhquydev/flow-skill', ACTOR_ID: '12345', EXPECTED_ACTOR_ID: i.expected_actor_id, DISPATCH_ID: i.dispatch_id, FLOW_AUTOPUBLISH_ENABLED: 'true', GITHUB_RUN_ID: '777', GITHUB_RUN_ATTEMPT: '1', ARTIFACT_DIR: store };
    workflow('eligibility', [], env);
    exec(process.execPath, [path.join(repo, 'npm-wrapper/scripts/sync.mjs')], { cwd: path.join(repo, 'npm-wrapper'), env: process.env });
    const packed = spawn('npm', ['pack', '--offline', '--ignore-scripts', '--json', '--pack-destination', store], { cwd: path.join(repo, 'npm-wrapper'), encoding: 'utf8', shell: process.platform === 'win32', env: { ...process.env, NODE_OPTIONS: '' }, timeout: 120000 });
    assert.equal(packed.status, 0, packed.stderr);
    assert.equal(JSON.parse(packed.stdout)[0].filename, s.name);
    workflow('record-artifact', [store, s.version], env);
    workflow('prepublish', [], env);
    const metadata = JSON.parse(fs.readFileSync(path.join(store, 'release-artifact.json'), 'utf8'));
    assert.deepEqual(metadata, { name: s.name, version: s.version, sha: s.sha, integrity: metadata.integrity, workflowRunId: '777', workflowRunAttempt: '1' });
    s.integrity = metadata.integrity;
    const slsa = 'https://slsa.dev/provenance/v1';
    const publish = 'https://github.com/npm/attestation/tree/main/specs/publish/v0.1';
    s.statement = { predicateType: slsa, subject: [{ name: `@manhquy/flow-skill@${s.version}`, digest: { sha512: Buffer.from(s.integrity.slice(7), 'base64').toString('hex') } }], predicate: { buildDefinition: { externalParameters: { workflow: { repository: 'https://github.com/manhquydev/flow-skill', path: '.github/workflows/publish-npm-wrapper.yml', ref: 'refs/heads/master' } }, resolvedDependencies: [{ digest: { gitCommit: s.sha } }] } } };
    const bundle = statement => ({ predicateType: statement.predicateType, bundle: { dsseEnvelope: { payloadType: 'application/vnd.in-toto+json', payload: Buffer.from(json(statement)).toString('base64'), signatures: [{ sig: 'fixture-transport-not-a-live-signature' }] } } });
    fs.writeFileSync(path.join(store, 'npm-audit-verified.json'), json({ verified: [{ name: '@manhquy/flow-skill', version: s.version, registry: 'https://registry.npmjs.org/', attestationBundles: [bundle(s.statement), bundle({ predicateType: publish })] }], invalid: [], missing: [] }));
    fs.writeFileSync(path.join(store, 'slsa-bundle.json'), json(s.statement));
    s.published = true; fs.writeFileSync(stateFile, json(s));
    return json({ workflow_run_id: 777, run_url: 'https://api.github.com/repos/manhquydev/flow-skill/actions/runs/777' });
  }
  if (endpoint.endsWith('/deployment-branch-policies')) return json({ branch_policies: [{ type: 'branch', name: 'master' }] });
  if (endpoint.endsWith('/environments/npm-publish')) return json({ deployment_branch_policy: { protected_branches: false, custom_branch_policies: true } });
  if (endpoint === 'user') return '12345\n';
  if (endpoint.endsWith('/git/ref/heads/master')) return json({ object: { sha: s.sha } });
  if (endpoint.includes('/pulls?')) return json([{ merged_at: '2026-10-19T00:00:00Z', merge_commit_sha: s.sha, base: { ref: 'master', repo: { full_name: 'manhquydev/flow-skill' } } }]);
  if (endpoint.includes('/actions/workflows/295237428/runs?')) return json({ total_count: 1, workflow_runs: [ci] });
  if (endpoint.endsWith('/actions/runs/888')) return json(ci);
  if (endpoint.includes('/actions/runs/888/jobs?')) return json({ total_count: 1, jobs: [{ name: 'all-checks-passed', run_id: 888, run_attempt: 1, status: 'completed', conclusion: 'success' }] });
  if (endpoint.includes('/check-runs?')) return json({ check_runs: [{ id: 1, name: 'all-checks-passed', head_sha: s.sha, status: 'completed', conclusion: 'success', app: { slug: 'github-actions' } }] });
  if (endpoint.endsWith('/actions/runs/777')) return json({ id: 777, actor: { id: 12345 }, head_sha: s.sha, path: '.github/workflows/publish-npm-wrapper.yml', event: 'workflow_dispatch', display_title: `Publisher ${s.sha} ${s.version} ${s.request.inputs.dispatch_id}`, status: 'completed', conclusion: 'success', run_attempt: 1 });
  if (endpoint.includes('/actions/runs/777/jobs?')) return json({ total_count: 2, jobs: ['eligibility', 'publish'].map(name => ({ name, run_id: 777, run_attempt: 1, status: 'completed', conclusion: 'success' })) });
  throw new Error(`Unrecognized gh boundary: ${json(args)}`);
}
cp.spawnSync = function(command, args, options = {}) {
  if (command === 'npm') return registry(args, options);
  if (command === 'npx') {
    const s = state();
    assert.deepEqual(args.slice(0, 3), ['--yes', `--package=@manhquy/flow-skill@${s.version}`, 'flow-skill']);
    assert.equal(options.env.npm_config_registry, 'https://registry.npmjs.org/');
    const installed = path.join(root, 'consumer-package');
    if (!fs.existsSync(path.join(installed, 'package/package.json'))) {
      fs.mkdirSync(installed, { recursive: true });
      exec('tar', ['-xzf', s.name, '-C', '../consumer-package'], { cwd: store });
      const pkg = JSON.parse(fs.readFileSync(path.join(installed, 'package/package.json'), 'utf8'));
      assert.equal(pkg.name, '@manhquy/flow-skill'); assert.equal(pkg.version, s.version);
    }
    log('consumer', { args: args.slice(3), integrity: s.integrity });
    // Replace only npx retrieval, not the CLI, installation, receipts, or smoke assertions.
    return spawn(process.execPath, [path.join(installed, 'package/bin/cli.mjs'), ...args.slice(3)], { ...options, shell: false, timeout: 30000 });
  }
  throw new Error(`Unexpected spawn boundary: ${command}`);
};
cp.execFileSync = function(command, args, options = {}) {
  if (command === 'gh') return gh(args, options);
  if (command === 'cmd.exe' && args[2]?.startsWith('gh ')) return gh((args[2].match(/"[^"]*"|[^ ]+/g) || []).slice(1).map(a => a.replace(/^"|"$/g, '')), options);
  if (command === 'git' && ['push', 'tag'].includes(args[0]) && !(args[0] === 'tag' && args[1] === '-l')) {
    const s = state(); assert.equal(s.afterSmoke, true);
    const events = fs.readFileSync(trace, 'utf8').trim().split('\n').map(JSON.parse);
    assert.deepEqual(events.filter(e => e.event === 'registry' && e.afterSmoke).map(e => e.field), ['version', 'dist.integrity', 'dist-tags']);
    assert.notEqual(process.env.K_CONSUMER_HOLLOW, 'channel-drift');
    if (args[0] === 'push') {
      assert.deepEqual(args.slice(0, 4), ['push', '--atomic', 'origin', 'master']);
      assert.equal(exec('git', ['remote', 'get-url', '--push', 'origin'], { cwd: repo, encoding: 'utf8' }).trim(), process.env.K_LOCAL_ORIGIN);
    }
    log(args[0], { args });
  }
  const smoke = command === process.execPath && args[0] === path.join(repo, 'npm-wrapper/scripts/smoke.mjs');
  if (smoke) log('smoke-start');
  const output = exec(command, args, options);
  if (smoke) { const s = state(); s.afterSmoke = true; fs.writeFileSync(stateFile, json(s)); log('smoke-end'); }
  return output;
};
syncBuiltinESMExports();
EOF

for consumer_case in sound release-crlf channel-drift release-exists release-auth release-forbidden release-http404 release-http500 release-network release-empty release-unexpected; do
  clean_k_tags
  rm -rf "$tmp/retained" "$tmp/consumer-package"
  mkdir -p "$tmp/retained" "$tmp/smoke-tmp"
  : > "$tmp/consumer-trace.jsonl"
  K_CONSUMER_ROOT="$(winpath "$tmp")" node --input-type=module - "$k_npm_v" "$k_skill_v" << 'EOF'
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
const root = process.env.K_CONSUMER_ROOT;
const version = process.argv[2];
fs.writeFileSync(path.join(root, 'consumer-state.json'), JSON.stringify({ version, skillVersion: process.argv[3], channel: version.includes('-') ? 'next' : 'latest', sha: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: path.join(root, 'r'), encoding: 'utf8' }).trim(), name: `manhquy-flow-skill-${version}.tgz`, published: false }));
EOF
  K_CONSUMER_ROOT="$(winpath "$tmp")" K_LOCAL_ORIGIN="file://$tmp/origin.git" K_CONSUMER_HOLLOW="$consumer_case" NODE_OPTIONS="--require=\"$(nodepath "$tmp/consumer-boundary.cjs")\"" PATH="$mock_bin:$PATH" node "$(winpath "$tmp/r/scripts/sync-release.mjs")" --ship --yes > "$tmp/consumer-$consumer_case.out" 2>&1
  consumer_rc=$?
  expected_rc=1
  case "$consumer_case" in sound|release-crlf) expected_rc=0 ;; esac
  ck_k "$expected_rc" "$consumer_rc" "K consumer $consumer_case: actual release CLI outcome" "$tmp/consumer-$consumer_case.out" "$consumer_rc"
  K_CONSUMER_ROOT="$(winpath "$tmp")" node --input-type=module - "$consumer_case" << 'EOF'
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
const root = process.env.K_CONSUMER_ROOT;
const s = JSON.parse(fs.readFileSync(path.join(root, 'consumer-state.json'), 'utf8'));
const events = fs.readFileSync(path.join(root, 'consumer-trace.jsonl'), 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
const flow = events.filter(e => ['dispatch', 'eligibility', 'record-artifact', 'prepublish', 'download', 'attestation', 'smoke-start', 'smoke-end', 'tag', 'push', 'release'].includes(e.event)).map(e => e.event);
const prefix = ['dispatch', 'eligibility', 'record-artifact', 'prepublish', 'download', 'download', 'attestation', 'smoke-start', 'smoke-end'];
const releaseCase = process.argv[2];
const reachedRelease = releaseCase !== 'channel-drift';
const finalized = [...prefix, 'tag', 'tag', 'push'];
assert.deepEqual(flow, ['sound', 'release-crlf'].includes(releaseCase) ? [...finalized, 'release'] : reachedRelease ? finalized : prefix);
assert.equal(events.filter(e => e.event === 'release-view').length, reachedRelease ? 1 : 0);
assert.equal(events.filter(e => e.event === 'release').length, ['sound', 'release-crlf'].includes(releaseCase) ? 1 : 0, 'exact gh release create invocation count');
assert.equal(events.filter(e => e.event === 'consumer').length, 6);
assert.deepEqual(events.filter(e => e.event === 'registry' && e.afterSmoke).map(e => e.field), ['version', 'dist.integrity', 'dist-tags']);
for (const e of events.filter(e => e.event === 'registry')) assert.equal(e.registry, 'https://registry.npmjs.org/');
for (const directory of [path.join(root, 'r'), path.join(root, 'origin.git')]) {
  const git = args => execFileSync('git', args, { cwd: directory, encoding: 'utf8' }).trim();
  const tags = git(['tag', '-l']).split(/\r?\n/).filter(Boolean).sort();
  assert.deepEqual(tags, reachedRelease ? [`npm@${s.version}`, `v${s.skillVersion}`].sort() : []);
  for (const tag of tags) assert.equal(git(['rev-parse', `${tag}^{commit}`]), s.sha);
}
EOF
  ck_k 0 "$?" "K consumer $consumer_case: exact identity, consumer count, finalization order and local refs" "$tmp/consumer-$consumer_case.out" "$consumer_rc"
  if [ "$consumer_case" = channel-drift ]; then
    grep -q 'channel no longer points to the retained release version' "$tmp/consumer-$consumer_case.out"
    ck_k 0 "$?" 'K consumer hollow: channel changes only after real smoke; no tags' "$tmp/consumer-$consumer_case.out" "$consumer_rc"
  elif [ "$consumer_case" = sound ]; then
    grep -q 'RELEASE SHIP SUCCESSFUL' "$tmp/consumer-$consumer_case.out"
    ck_k 0 "$?" 'K release absence: exact canonical diagnostic permits create and success' "$tmp/consumer-$consumer_case.out" "$consumer_rc"
  elif [ "$consumer_case" = release-crlf ]; then
    grep -q 'RELEASE SHIP SUCCESSFUL' "$tmp/consumer-$consumer_case.out"
    ck_k 0 "$?" 'K release absence accepts canonical CRLF diagnostic and creates release' "$tmp/consumer-$consumer_case.out" "$consumer_rc"
  else
    case "$consumer_case" in
      release-exists) release_diagnostic="GitHub Release v$k_skill_v already exists" ;;
      release-auth) release_diagnostic='HTTP 401: Bad credentials (mock auth failure)' ;;
      release-forbidden) release_diagnostic='HTTP 403: Forbidden (mock permission failure)' ;;
      release-http404) release_diagnostic='HTTP 404: Not Found (mock API failure)' ;;
      release-http500) release_diagnostic='HTTP 500: Internal Server Error (mock API failure)' ;;
      release-network) release_diagnostic='error connecting to api.github.com: mock connection reset' ;;
      release-empty) release_diagnostic='mock gh release view failed:' ;;
      release-unexpected) release_diagnostic='could not find release (mock unexpected diagnostic)' ;;
    esac
    grep -Fq "$release_diagnostic" "$tmp/consumer-$consumer_case.out"
    ck_k 0 "$?" "K $consumer_case: original refusal diagnostic retained" "$tmp/consumer-$consumer_case.out" "$consumer_rc"
    grep -q 'RELEASE SHIP SUCCESSFUL' "$tmp/consumer-$consumer_case.out"
    ck_k 1 "$?" "K $consumer_case: no release success message" "$tmp/consumer-$consumer_case.out" "$consumer_rc"
  fi
done
clean_k_tags
rm -rf "$tmp"

echo "L) npm spawn helper regression: battery must invoke node, never npm.cmd"
# Windows Node 22 refuses execFileSync of a .cmd (spawnSync EINVAL). Assert the exported
# helpers resolve to process.execPath and never reference npm.cmd, and that importing the
# module does not execute the CLI (main() is guarded by the pathToFileURL entry check).
tmp_l=$(mktemp -d)
L_IMPORTER="$tmp_l/importer.mjs"
cat > "$L_IMPORTER" << 'EOF'
import { pathToFileURL } from 'node:url';
const target = pathToFileURL(process.argv[2]).href;
const mod = await import(target);
const assert = (await import('node:assert')).strict;
assert.equal(mod.npmSpawnHelper().cmd, process.execPath, 'sync helper argv[0] must be process.execPath');
assert.equal(mod.npmTestHelper().cmd, process.execPath, 'test helper argv[0] must be process.execPath');
const all = JSON.stringify([mod.npmSpawnHelper(), mod.npmTestHelper()]);
assert.ok(!all.includes('npm.cmd'), 'no helper may reference npm.cmd');
assert.ok(all.includes('scripts/sync.mjs'), 'sync step must run node scripts/sync.mjs');
assert.ok(all.includes('--test'), 'test step must run node --test');
assert.ok(mod.npmTestHelper().args.includes('test/smoke-policy.test.mjs'), 'test helper must include the smoke-policy test registered by npm test');
assert.equal(typeof mod.buildWin32GhCommandLine, 'function', 'buildWin32GhCommandLine must be exported');
const plainCmd = mod.buildWin32GhCommandLine(['release', 'view', 'v0.34.4', '--json', 'tagName']);
assert.equal(plainCmd, 'gh release view v0.34.4 --json tagName', 'plain args must stay unquoted');
assert.ok(plainCmd.startsWith('gh '), 'cmdline must start with bare gh and space');
assert.ok(!plainCmd.startsWith('"gh"'), 'bare gh token must never be quoted');
const quotedCmd = mod.buildWin32GhCommandLine(['release', 'create', 'v0.34.4', '--title', 'v0.34.4 (rc & test)', '--notes-file', 'CHANGELOG.md']);
assert.ok(quotedCmd.includes('"v0.34.4 (rc & test)"'), 'args with spaces or metacharacters must be quoted');
console.log('HELPERS OK');
EOF
node "$(winpath "$L_IMPORTER")" "$(winpath "$ROOT/scripts/sync-release.mjs")" > "$tmp_l/l.out" 2>&1
l_rc=$?
ck 0 $l_rc "npm spawn helper uses node (no npm.cmd); import does not run CLI"
if [ "$l_rc" -ne 0 ]; then
  cat "$tmp_l/l.out" >&2
fi
if grep -q "HELPERS OK" "$tmp_l/l.out"; then
  ck 0 0 "helper assertions executed"
else
  ck 0 1 "helper assertions executed"
  cat "$tmp_l/l.out" >&2
fi
rm -rf "$tmp_l"

echo "M) CLI entry guard symlink regression: symlinked script must execute main()"
# On macOS, /var/folders is a symlink to /private/var/folders. If the direct-run guard
# compares raw URLs without realpathSync, main() silently no-ops (exit 0, empty output).
# Assert that executing sync-release.mjs via a symlinked path runs main() and prints output.
tmp_m=$(mktemp -d)
sym_script="$tmp_m/sym_sync_release.mjs"
ln -s "$ROOT/scripts/sync-release.mjs" "$sym_script"
if [ ! -L "$sym_script" ]; then
  echo "  skip [M: platform cannot create symlinks (ln -s created a copy); macOS/Linux symlink alias regression asserted there]"
else
  m_target="$(winpath "$sym_script")"
  node "$m_target" --check > "$tmp_m/m.out" 2>&1
  m_rc=$?

  ck 0 $m_rc "symlinked sync-release --check exits 0"
  [ "$m_rc" -ne 0 ] && cat "$tmp_m/m.out" >&2
  [ -s "$tmp_m/m.out" ] && ck 0 0 "symlinked invocation stdout is non-empty (not a silent exit)" || { ck 0 1 "symlinked invocation stdout is non-empty (not a silent exit)"; cat "$tmp_m/m.out" >&2; }
  grep -q "PASS: All release surfaces coherent" "$tmp_m/m.out" && ck 0 0 "symlinked invocation runs main() and reports PASS" || { ck 0 1 "symlinked invocation runs main() and reports PASS"; cat "$tmp_m/m.out" >&2; }
fi
rm -rf "$tmp_m"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1

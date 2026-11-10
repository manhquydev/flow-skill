// v0.23 M3 (red-team finding): scripts/sync.mjs used to bake an absolute local filesystem path
// into skills-manifest.json's `source` field — and that file ships inside the published npm
// tarball (package.json `files:`), leaking local machine layout + being non-reproducible across
// dev machines/CI. Assert the emitted `source` is repo-relative, never absolute.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  cpSync,
  existsSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const pkgRoot = resolve(__dirname, '..');
const syncScript = resolve(pkgRoot, 'scripts', 'sync.mjs');
const manifestPath = resolve(pkgRoot, 'skills-manifest.json');

test('npm run sync emits a repo-relative (not absolute) manifest source path', () => {
  const r = spawnSync(process.execPath, [syncScript], { cwd: pkgRoot, encoding: 'utf8' });
  assert.equal(r.status, 0, `sync.mjs failed: ${r.stderr}`);
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  // Absolute POSIX (leading '/') or Windows (drive letter 'X:\' or 'X:/') paths are rejected.
  assert.doesNotMatch(manifest.source, /^\/|^[A-Za-z]:[\\/]/);
  assert.equal(manifest.source, '../skills/flow');
});

function writeTree(root, files) {
  for (const [rel, body] of Object.entries(files)) {
    const p = join(root, rel);
    mkdirSync(join(p, '..'), { recursive: true });
    writeFileSync(p, body);
  }
}

function runCompare(extracted, repo) {
  return spawnSync(process.execPath, [syncScript, '--compare', extracted, repo], {
    cwd: pkgRoot,
    encoding: 'utf8',
  });
}

test('--compare matching trees exits 0 and does not run the copy body', () => {
  const baseTmp = realpathSync(tmpdir());
  const extracted = mkdtempSync(join(baseTmp, 'sync-cmp-a-'));
  const repo = mkdtempSync(join(baseTmp, 'sync-cmp-b-'));
  const files = { 'SKILL.md': '# skill\n', 'runner/flow.sh': '#!/bin/bash\n' };
  writeTree(extracted, files);
  writeTree(repo, files);
  const canary = resolve(pkgRoot, 'skills', 'flow', '.compare-canary-test');
  mkdirSync(resolve(pkgRoot, 'skills', 'flow'), { recursive: true });
  writeFileSync(canary, 'keep');
  try {
    const r = runCompare(extracted, repo);
    assert.equal(r.status, 0, `compare failed: ${r.stderr}\n${r.stdout}`);
    assert.match(r.stdout, /compare OK/);
    assert.equal(readFileSync(canary, 'utf8'), 'keep');
  } finally {
    rmSync(canary, { force: true });
    rmSync(extracted, { recursive: true, force: true });
    rmSync(repo, { recursive: true, force: true });
  }
});

test('--compare fails on a 1-byte content drift', () => {
  const baseTmp = realpathSync(tmpdir());
  const extracted = mkdtempSync(join(baseTmp, 'sync-cmp-d-'));
  const repo = mkdtempSync(join(baseTmp, 'sync-cmp-e-'));
  writeTree(extracted, { 'SKILL.md': '# skill\n', 'a.txt': 'hello\n' });
  writeTree(repo, { 'SKILL.md': '# skill\n', 'a.txt': 'hallo\n' });
  try {
    const r = runCompare(extracted, repo);
    assert.equal(r.status, 1);
    assert.match(r.stderr, /content drift: a\.txt/);
  } finally {
    rmSync(extracted, { recursive: true, force: true });
    rmSync(repo, { recursive: true, force: true });
  }
});

test('--compare ignores eval/replay in the repo tree (shouldShip twin)', () => {
  const baseTmp = realpathSync(tmpdir());
  const extracted = mkdtempSync(join(baseTmp, 'sync-cmp-r-'));
  const repo = mkdtempSync(join(baseTmp, 'sync-cmp-s-'));
  writeTree(extracted, { 'SKILL.md': '# skill\n', 'runner/flow.sh': '#!/bin/bash\n' });
  writeTree(repo, {
    'SKILL.md': '# skill\n',
    'runner/flow.sh': '#!/bin/bash\n',
    'eval/replay/meta': 'nonce=x\n',
  });
  try {
    const r = runCompare(extracted, repo);
    assert.equal(r.status, 0, `compare failed: ${r.stderr}\n${r.stdout}`);
    assert.match(r.stdout, /compare OK/);
  } finally {
    rmSync(extracted, { recursive: true, force: true });
    rmSync(repo, { recursive: true, force: true });
  }
});

test('--compare without two paths usage-exits 2 and does not copy', () => {
  const canary = resolve(pkgRoot, 'skills', 'flow', '.compare-canary-test');
  mkdirSync(resolve(pkgRoot, 'skills', 'flow'), { recursive: true });
  writeFileSync(canary, 'keep');
  try {
    const r = spawnSync(process.execPath, [syncScript, '--compare'], {
      cwd: pkgRoot,
      encoding: 'utf8',
    });
    assert.equal(r.status, 2);
    assert.match(r.stderr, /usage: sync\.mjs --compare/);
    assert.equal(readFileSync(canary, 'utf8'), 'keep');
  } finally {
    rmSync(canary, { force: true });
  }
});

// T1: sync.mjs generates .widelai/rules/flowskill.md deterministically from the
// repo's multi-home rule map. Re-running must produce byte-identical output.
test('sync.mjs generates .widelai/rules/flowskill.md deterministically from repo sources', () => {
  const rulesPath = resolve(pkgRoot, '.widelai', 'rules', 'flowskill.md');
  const r1 = spawnSync(process.execPath, [syncScript], { cwd: pkgRoot, encoding: 'utf8' });
  assert.equal(r1.status, 0, `sync.mjs failed: ${r1.stderr}`);
  const first = readFileSync(rulesPath, 'utf8');
  assert.match(first, /GENERATED — do not edit by hand/);
  assert.match(first, /Branch per card/);
  assert.match(first, /One card = one worktree/);
  assert.match(first, /bash 3\.2-safe/);
  assert.match(first, /flow-attestation\/v1/);
  assert.match(first, /verify-chain/);
  assert.match(first, /warning-only/);
  assert.doesNotMatch(first, /Both must agree/);
  assert.doesNotMatch(first, /flow-cost\/v1/);
  assert.doesNotMatch(first, /BLOCKED/);
  const r2 = spawnSync(process.execPath, [syncScript], { cwd: pkgRoot, encoding: 'utf8' });
  assert.equal(r2.status, 0, `sync.mjs re-run failed: ${r2.stderr}`);
  assert.equal(readFileSync(rulesPath, 'utf8'), first, 'regeneration must be byte-identical');
});

// T1 follow-up: a partial tree (the sync-release fixtures copy only a
// subset: no AGENTS.md / CONTRIBUTING.md) must NOT crash sync.mjs. The
// rules file is skipped with a loud warning and sync still exits 0.
test('sync.mjs skips widelai rules with a warning (exit 0) in a partial tree without AGENTS.md', () => {
  const baseTmp = realpathSync(tmpdir());
  const parent = mkdtempSync(join(baseTmp, 'sync-partial-'));
  try {
    cpSync(resolve(pkgRoot, '..', 'skills'), join(parent, 'skills'), { recursive: true });
    cpSync(resolve(pkgRoot, '..', 'portable-manifest.json'), join(parent, 'portable-manifest.json'));
    cpSync(pkgRoot, join(parent, 'npm-wrapper'), {
      recursive: true,
      filter: (src) => !src.endsWith(`${sep}.widelai`) && !src.endsWith(`${sep}skills`),
    });
    const partialSync = join(parent, 'npm-wrapper', 'scripts', 'sync.mjs');
    const r = spawnSync(process.execPath, [partialSync], {
      cwd: join(parent, 'npm-wrapper'),
      encoding: 'utf8',
    });
    assert.equal(r.status, 0, `sync.mjs failed in partial tree: ${r.stderr}`);
    assert.match(`${r.stdout}\n${r.stderr}`, /widelai rules skipped/);
    assert.equal(
      existsSync(join(parent, 'npm-wrapper', '.widelai', 'rules', 'flowskill.md')),
      false,
      'no rules file may be written from a partial tree',
    );
  } finally {
    rmSync(parent, { recursive: true, force: true });
  }
});

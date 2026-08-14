// v0.23 M3 (red-team finding): scripts/sync.mjs used to bake an absolute local filesystem path
// into skills-manifest.json's `source` field — and that file ships inside the published npm
// tarball (package.json `files:`), leaking local machine layout + being non-reproducible across
// dev machines/CI. Assert the emitted `source` is repo-relative, never absolute.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
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
  const extracted = mkdtempSync(join(tmpdir(), 'sync-cmp-a-'));
  const repo = mkdtempSync(join(tmpdir(), 'sync-cmp-b-'));
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
  const extracted = mkdtempSync(join(tmpdir(), 'sync-cmp-d-'));
  const repo = mkdtempSync(join(tmpdir(), 'sync-cmp-e-'));
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

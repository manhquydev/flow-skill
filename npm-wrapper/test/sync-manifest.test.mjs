// v0.23 M3 (red-team finding): scripts/sync.mjs used to bake an absolute local filesystem path
// into skills-manifest.json's `source` field — and that file ships inside the published npm
// tarball (package.json `files:`), leaking local machine layout + being non-reproducible across
// dev machines/CI. Assert the emitted `source` is repo-relative, never absolute.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

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

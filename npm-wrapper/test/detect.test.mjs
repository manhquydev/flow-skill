import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { defaultSelection, detectAll } from '../src/detect.mjs';

function fakeHome(prefix) {
  return mkdtempSync(join(tmpdir(), `flow-detect-home-${prefix}-`));
}

test('empty home: only Claude is in default selection (alwaysInclude)', () => {
  const home = fakeHome('empty');
  const entries = detectAll({ home });
  const claude = entries.find((e) => e.name === 'claude');
  const codex = entries.find((e) => e.name === 'codex');
  const antigravity = entries.find((e) => e.name === 'antigravity');

  assert.equal(claude.detected, false, '.claude not present so not detected');
  assert.equal(claude.alwaysInclude, true);
  assert.equal(codex.detected, false);
  assert.equal(antigravity.detected, false);

  const defaults = defaultSelection(entries);
  assert.deepEqual(defaults, ['claude']);
});

test('~/.claude present: claude is both detected and alwaysInclude', () => {
  const home = fakeHome('claude');
  mkdirSync(join(home, '.claude'), { recursive: true });
  const entries = detectAll({ home });
  const claude = entries.find((e) => e.name === 'claude');
  assert.equal(claude.detected, true);
  assert.equal(defaultSelection(entries).includes('claude'), true);
});

test('~/.codex/skills present: codex detected', () => {
  const home = fakeHome('codex');
  mkdirSync(join(home, '.codex', 'skills'), { recursive: true });
  const entries = detectAll({ home });
  const codex = entries.find((e) => e.name === 'codex');
  assert.equal(codex.detected, true);
  const defaults = defaultSelection(entries);
  assert.equal(defaults.includes('codex'), true);
  // Claude still in default via alwaysInclude
  assert.equal(defaults.includes('claude'), true);
});

test('~/.gemini alone (no subdir markers) does NOT trigger antigravity detection', () => {
  // Guards against the false-positive with Google Gemini CLI which also uses ~/.gemini.
  const home = fakeHome('gemini-bare');
  mkdirSync(join(home, '.gemini'), { recursive: true });
  writeFileSync(join(home, '.gemini', 'settings.json'), '{}');
  const entries = detectAll({ home });
  const antigravity = entries.find((e) => e.name === 'antigravity');
  assert.equal(antigravity.detected, false, '~/.gemini alone must not trigger antigravity');
});

test('~/.gemini/antigravity-cli present: antigravity detected', () => {
  const home = fakeHome('antigravity-cli');
  mkdirSync(join(home, '.gemini', 'antigravity-cli'), { recursive: true });
  const entries = detectAll({ home });
  const antigravity = entries.find((e) => e.name === 'antigravity');
  assert.equal(antigravity.detected, true);
});

test('~/.gemini/config/skills present: antigravity detected', () => {
  const home = fakeHome('antigravity-ide');
  mkdirSync(join(home, '.gemini', 'config', 'skills'), { recursive: true });
  const entries = detectAll({ home });
  const antigravity = entries.find((e) => e.name === 'antigravity');
  assert.equal(antigravity.detected, true);
});

// v0.23 — Cursor target. Red-team C1: a bare `.cursor` marker would false-positive on EVERY
// Cursor user (the dir holds unrelated editor config too), silently auto-installing flow under
// `--yes` (defaultSelection includes any `detected` target). The marker must be the skills
// subdir specifically — mirrors the antigravity `~/.gemini` bare-dir guard above. Confirmed real
// path via a live probe on this machine: `~/.cursor/skills/<name>` is what Cursor's own tooling
// actually populates (observed a real `find-skills` symlink there pointing at
// `~/.agents/skills/find-skills`), not assumed from documentation alone.
test('bare ~/.cursor (no skills subdir) does NOT trigger cursor detection', () => {
  const home = fakeHome('cursor-bare');
  mkdirSync(join(home, '.cursor'), { recursive: true });
  writeFileSync(join(home, '.cursor', 'argv.json'), '{}');
  const entries = detectAll({ home });
  const cursor = entries.find((e) => e.name === 'cursor');
  assert.ok(cursor, 'cursor target must be registered in TARGETS');
  assert.equal(cursor.detected, false, '~/.cursor alone (editor config, no skills subdir) must not trigger cursor detection');
});

test('~/.cursor/skills present: cursor detected, dest is ~/.cursor/skills/flow', () => {
  const home = fakeHome('cursor-skills');
  mkdirSync(join(home, '.cursor', 'skills'), { recursive: true });
  const entries = detectAll({ home });
  const cursor = entries.find((e) => e.name === 'cursor');
  assert.equal(cursor.detected, true);
  assert.equal(cursor.dests.length, 1);
  assert.equal(cursor.dests[0], join(home, '.cursor', 'skills', 'flow'));
});

test('dests are resolved against the given home', () => {
  const home = fakeHome('dests');
  const entries = detectAll({ home });
  const claude = entries.find((e) => e.name === 'claude');
  // We only assert the dest anchors at the provided home; separator normalization is out of scope
  // (constants uses ~/... POSIX form, so on Windows the dest ends with mixed separators — a
  // future patch could `path.normalize` in detect.mjs, but consumers use these as strings and
  // both bash and PowerShell tolerate mixed separators).
  assert.equal(
    claude.dests[0].startsWith(home),
    true,
    `claude dest ${claude.dests[0]} must start with ${home}`
  );
  const antigravity = entries.find((e) => e.name === 'antigravity');
  assert.equal(antigravity.dests.length, 2);
  assert.equal(antigravity.dests.every((d) => d.startsWith(home)), true);
});

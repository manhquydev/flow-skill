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

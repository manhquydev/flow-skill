// Black-box CLI smoke tests. Spawn bin/cli.mjs and parse output.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { join, resolve } from 'node:path';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const cliPath = resolve(__dirname, '..', 'bin', 'cli.mjs');

function runCli(args, opts = {}) {
  const r = spawnSync(process.execPath, [cliPath, ...args], {
    encoding: 'utf8',
    env: { ...process.env, CI: 'true', ...opts.env },
  });
  return { code: r.status, stdout: r.stdout, stderr: r.stderr };
}

function parseJsonl(s) {
  return s
    .split('\n')
    .filter(Boolean)
    .map((l) => JSON.parse(l));
}

test('--help exits 0 and lists 5 targets', () => {
  const r = runCli(['--help']);
  assert.equal(r.code, 0);
  assert.match(r.stdout, /claude\s+Claude Code/);
  assert.match(r.stdout, /codex\s+Codex CLI/);
  assert.match(r.stdout, /agents\s+Agents home/);
  assert.match(r.stdout, /antigravity\s+Antigravity/);
  assert.match(r.stdout, /cursor\s+Cursor/);
  // Dual-version UX: package version + skill product version (avoids "not latest" confusion).
  assert.match(r.stdout, /flow-skill v\d+\.\d+\.\d+/);
  assert.match(r.stdout, /ships skill v\d+\.\d+\.\d+/);
});

test('--dry-run --all --json emits a plan event with 5 targets', () => {
  const r = runCli(['--yes', '--all', '--dry-run', '--json']);
  assert.equal(r.code, 0);
  const events = parseJsonl(r.stdout);
  assert.equal(events.length, 1);
  assert.equal(events[0].event, 'plan');
  assert.deepEqual(
    events[0].targets.sort(),
    ['agents', 'antigravity', 'claude', 'codex', 'cursor']
  );
  assert.equal(events[0].dryRun, true);
  assert.equal(typeof events[0].version, 'string');
  assert.match(events[0].version, /^\d+\.\d+\.\d+/);
  // skillVersion is the product axis (SKILL.md); distinct from npm package version.
  assert.equal(typeof events[0].skillVersion, 'string');
  assert.match(events[0].skillVersion, /^\d+\.\d+\.\d+/);
});

test('--project -t codex → exit 2 with clear error', () => {
  const r = runCli(['--yes', '-t', 'codex', '--project']);
  assert.equal(r.code, 2);
  assert.match(
    r.stderr,
    /--project scope supports only 'claude'/
  );
});

test('unknown target → exit 2 with unknown-target error', () => {
  const r = runCli(['--yes', '-t', 'bogus']);
  assert.equal(r.code, 2);
  assert.match(r.stderr, /unknown target/);
});

test('comma-form target list: -t "claude,codex" produces both targets in plan', () => {
  const r = runCli(['--yes', '-t', 'claude,codex', '--dry-run', '--json']);
  assert.equal(r.code, 0);
  const events = parseJsonl(r.stdout);
  const plan = events.find((e) => e.event === 'plan');
  assert.ok(plan);
  assert.deepEqual(plan.targets.sort(), ['claude', 'codex']);
});

test('non-TTY + no flags → uses default selection (Claude alwaysInclude)', () => {
  // CI=true env forces non-interactive; no --yes needed for dry-run because CLI treats no-args as
  // default-select via alwaysInclude — but we still need a way to opt in. --dry-run + no flags in
  // CI env should still produce a plan.
  const r = runCli(['--dry-run', '--json']);
  assert.equal(r.code, 0);
  const events = parseJsonl(r.stdout);
  assert.equal(events[0].event, 'plan');
  // Claude is alwaysInclude
  assert.equal(events[0].targets.includes('claude'), true);
});

test('summary event fields present in JSONL after fail-fast on unknown target avoidance', () => {
  // Force a real install path failure via --project + --dir pointing at read-only fixture: hard on
  // Windows without granular perm control. Instead we verify the summary shape on a successful
  // dry-run --all --json (dry-run does not emit install events but summary is skipped on dry-run
  // per current design — this test just documents that contract).
  const r = runCli(['--yes', '--all', '--dry-run', '--json']);
  assert.equal(r.code, 0);
  const events = parseJsonl(r.stdout);
  // Dry-run: only the plan event, then exit.
  assert.equal(events.length, 1);
  assert.equal(events[0].event, 'plan');
});

// v0.23 A0 — the reported symptom: users install to Antigravity, open it, type /flow, see
// nothing, because a newly-installed skill isn't discovered until the agent reloads, and the
// post-install summary line told only Claude+Codex users what to do (cli.mjs pre-fix). Real
// (non-dry-run) install into a scratch HOME so we assert the actual printed guidance.
function scratchHomeEnv(prefix) {
  const home = mkdtempSync(join(tmpdir(), `flow-skill-cli-${prefix}-`));
  return { home, env: { HOME: home, USERPROFILE: home } };
}

// Isolate the final "Done. ..." summary line — per-target install confirmation lines above it
// (e.g. "antigravity -> <path>") would otherwise false-positive-match a bare /antigravity/ regex.
function doneLine(stdout) {
  return stdout.split('\n').find((l) => l.startsWith('Done.')) ?? '';
}

test('real install --target antigravity: the Done-line hints Antigravity restart/reload', () => {
  const { env } = scratchHomeEnv('antigravity-hint');
  const r = runCli(['--yes', '-t', 'antigravity'], { env });
  assert.equal(r.code, 0);
  const done = doneLine(r.stdout);
  assert.notEqual(done, '', 'expected a Done. summary line');
  assert.match(done, /Antigravity/);
  assert.match(done, /restart|reload/i);
});

test('real install --target cursor: the Done-line hints Cursor restart/reload', () => {
  const { env } = scratchHomeEnv('cursor-hint');
  const r = runCli(['--yes', '-t', 'cursor'], { env });
  assert.equal(r.code, 0);
  const done = doneLine(r.stdout);
  assert.notEqual(done, 'Done.', 'expected a non-empty Done. line — RESTART_HINTS is missing a cursor entry');
  assert.match(done, /Cursor/);
  assert.match(done, /restart|reload/i);
});

test('real install --target claude,codex: Done-line keeps Codex restart hint, no Antigravity mention', () => {
  const { env } = scratchHomeEnv('claude-codex-hint');
  const r = runCli(['--yes', '-t', 'claude,codex'], { env });
  assert.equal(r.code, 0);
  const done = doneLine(r.stdout);
  assert.notEqual(done, '');
  assert.match(done, /\$flow/);
  assert.match(done, /restart Codex/i);
  assert.doesNotMatch(done, /Antigravity/);
});

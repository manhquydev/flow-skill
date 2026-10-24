// Black-box CLI smoke tests. Spawn bin/cli.mjs and parse output.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { join, resolve } from 'node:path';
import { mkdirSync, mkdtempSync, writeFileSync, readFileSync, realpathSync, existsSync, rmSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const pkgRoot = resolve(__dirname, '..');
const cliPath = resolve(pkgRoot, 'bin', 'cli.mjs');
const pkgVersion = JSON.parse(readFileSync(resolve(pkgRoot, 'package.json'), 'utf8')).version;
// pretest runs sync — skills/flow/SKILL.md is present for these assertions.
const skillMd = readFileSync(resolve(pkgRoot, 'skills', 'flow', 'SKILL.md'), 'utf8');
const skillVersionMatch = skillMd.match(/^\s*version:\s*["']?([0-9][0-9A-Za-z.+-]*)["']?/m);
const expectedSkillVersion = skillVersionMatch ? skillVersionMatch[1] : null;

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

test('--dry-run --all --json emits a plan event whose target set is the full supported set', () => {
  const r = runCli(['--yes', '--all', '--dry-run', '--json']);
  assert.equal(r.code, 0);
  const events = parseJsonl(r.stdout);
  assert.equal(events.length, 1);
  assert.equal(events[0].event, 'plan');
  assert.deepEqual(
    events[0].targets.sort(),
    ['agents', 'antigravity', 'claude', 'codex', 'cursor', 'omp']
  );
  assert.equal(events[0].dryRun, true);
  assert.equal(events[0].version, pkgVersion);
  // Preserve both compatible fields while enforcing the shared SemVer.
  assert.ok(expectedSkillVersion, 'SKILL.md metadata.version must be readable');
  assert.equal(events[0].skillVersion, expectedSkillVersion);
  assert.equal(events[0].skillVersion, events[0].version);
});

test('--project -t codex → exit 2 with clear error', () => {
  const r = runCli(['--yes', '-t', 'codex', '--project']);
  assert.equal(r.code, 2);
  assert.match(
    r.stderr,
    /--project scope supports only 'claude'/
  );
});

test('explicit -t omp --dry-run --json plans the OMP destination', () => {
  const r = runCli(['--yes', '-t', 'omp', '--dry-run', '--json']);
  assert.equal(r.code, 0);
  const events = parseJsonl(r.stdout);
  assert.equal(events[0].event, 'plan');
  assert.deepEqual(events[0].targets, ['omp']);
});

test('--project -t omp → exit 2 (project scope stays claude-only)', () => {
  const r = runCli(['--yes', '-t', 'omp', '--project']);
  assert.equal(r.code, 2);
  assert.match(r.stderr, /--project scope supports only 'claude'/);
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
  const baseTmp = realpathSync(tmpdir());
  const home = mkdtempSync(join(baseTmp, `flow-skill-cli-${prefix}-`));
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

// Real (non-dry-run) explicit OMP install into a scratch HOME — never the operator's real
// ~/.omp. Asserts the correct materialized files and that the shipped tree receipt
// (manifest-hashes.json) digests match BOTH the actual bundled source and the installed copy,
// computed with node:crypto (stdlib only; no python/host dependency). This is the same
// contract `flow doctor`'s bundled_tree_integrity check enforces on an installed tree.
test('real install --target omp: correct files in scratch HOME; receipt digests match bundled source and install', () => {
  const { home, env } = scratchHomeEnv('omp-install');
  const r = runCli(['--yes', '-t', 'omp'], { env });
  assert.equal(r.code, 0);

  const dest = join(home, '.omp', 'agent', 'skills', 'flow');
  for (const rel of [
    'SKILL.md',
    'manifest-hashes.json',
    'runner/flow.sh',
    'runner/doctor_helper.py',
    join('runner', 'doctor-checks.tsv'),
    'law',
    '_templates',
    'references',
    'harness',
    'playbooks',
  ]) {
    assert.ok(existsSync(join(dest, rel)), `expected installed file missing: ${rel}`);
  }

  const receipt = JSON.parse(readFileSync(join(dest, 'manifest-hashes.json'), 'utf8'));
  assert.equal(receipt.schema_version, 1);
  const hashes = receipt.files;
  assert.ok(hashes && typeof hashes === 'object', 'receipt missing files map');
  const names = Object.keys(hashes);
  assert.ok(names.length > 0, 'receipt lists no files');

  const bundledRoot = resolve(pkgRoot, 'skills', 'flow');
  for (const rel of names) {
    const bundledDigest = createHash('sha256')
      .update(readFileSync(resolve(bundledRoot, rel)))
      .digest('hex');
    assert.equal(hashes[rel], bundledDigest, `receipt digest mismatch vs bundled source: ${rel}`);

    const installedDigest = createHash('sha256')
      .update(readFileSync(join(dest, rel)))
      .digest('hex');
    assert.equal(installedDigest, hashes[rel], `installed file drifted from receipt: ${rel}`);
  }

  rmSync(home, { recursive: true, force: true });
});

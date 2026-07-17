#!/usr/bin/env node
// Post-publish smoke test. Run against a live version on the npm registry:
//   node scripts/smoke.mjs 0.1.0-rc.2
// Verifies:
//   1. The version exists on the registry.
//   2. Its dist.attestations.provenance is populated (SLSA L2).
//   3. `npx @manhquy/flow-skill@<version> --help` runs and exits 0.
//   4. `--yes --all --dry-run --json` returns valid JSONL with the expected schema.
//   5. Installing into a scratch $HOME materializes the expected 6 subdirs + SKILL.md.
//
// Not part of the tarball (scripts/ is not in package.json "files"); this file lives at
// scripts/smoke.mjs in the dev tree only.
//
// CRITICAL: all `npx` invocations use a dedicated empty temp cwd. Running smoke from
// npm-wrapper/ (same package name as the published package) makes npx resolve the local
// workspace instead of the registry — that false-failed Nightly every night with
// `flow-skill: not found` even when the published package was healthy.

import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const PKG = '@manhquy/flow-skill';
const BIN = 'flow-skill';
const version = process.argv[2];

if (!version) {
  console.error(`usage: node scripts/smoke.mjs <version>  (e.g. 0.1.0-rc.2)`);
  process.exit(2);
}

// Reject anything but a strict semver — this script uses `shell: true` on Windows to find
// `npm.cmd`, so any argv character that has meaning to cmd.exe (`&`, `|`, `>`, etc.) could
// be interpolated into the spawned command line. Validate before we touch the shell.
if (!/^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$/.test(version)) {
  console.error(`invalid semver: ${version}`);
  process.exit(2);
}

// Empty cwd so local monorepo package.json never shadows registry resolution.
const npxCwd = mkdtempSync(join(tmpdir(), 'flow-smoke-npx-'));

function run(cmd, args, opts = {}) {
  console.log(`\n$ ${cmd} ${args.join(' ')}`);
  // Always use the empty temp cwd — never process.cwd() (npm-wrapper shadows the package).
  const r = spawnSync(cmd, args, {
    encoding: 'utf8',
    shell: process.platform === 'win32',
    cwd: npxCwd,
    env: opts.env ?? process.env,
  });
  if (r.stdout) process.stdout.write(r.stdout);
  if (r.stderr) process.stderr.write(r.stderr);
  return r;
}

function fail(msg) {
  try {
    rmSync(npxCwd, { recursive: true, force: true });
  } catch {
    /* ignore */
  }
  console.error(`\nSMOKE FAIL: ${msg}`);
  process.exit(1);
}

// Prefer explicit bin form — more reliable across npm 10/11 than bare `npx @scope/pkg args`
// when a same-named workspace package might exist on the ancestor path.
function npxArgs(extra) {
  return ['--yes', `--package=${PKG}@${version}`, BIN, ...extra];
}

// 1. version exists (registry query — cwd irrelevant)
const view = run('npm', ['view', `${PKG}@${version}`, 'version']);
if (view.status !== 0 || view.stdout.trim() !== version) {
  fail(`${PKG}@${version} not found on the registry`);
}

// 2. provenance — warn only, not fail. rc.1 was published manually to bootstrap
// Trusted Publisher registration; it carries no attestation by design. rc.2+ (via CI)
// must have provenance; the nightly workflow is the ongoing guard.
const prov = run('npm', ['view', `${PKG}@${version}`, 'dist.attestations.provenance']);
if (prov.status !== 0 || !prov.stdout.trim()) {
  console.warn(
    '  WARN: no provenance attestation on this version (expected for rc.1 bootstrap; rc.2+ must have)'
  );
} else {
  console.log('  provenance: present');
}

// 3. --help
const help = run('npx', npxArgs(['--help']));
if (help.status !== 0) fail('--help exited non-zero');

// 4. dry-run --json
const json = run('npx', npxArgs(['--yes', '--all', '--dry-run', '--json']), {
  env: { ...process.env, CI: 'true' },
});
if (json.status !== 0) fail('dry-run --json exited non-zero');
const events = json.stdout
  .trim()
  .split('\n')
  .filter(Boolean)
  .map((l) => JSON.parse(l));
const plan = events.find((e) => e.event === 'plan');
if (!plan) fail('no plan event emitted');
if (!plan.dryRun) fail('plan event missing dryRun:true');
if (!Array.isArray(plan.targets) || !plan.targets.includes('claude')) {
  fail('plan event does not include claude target');
}
console.log('  --json plan event OK');

// 5. install into scratch HOME
const scratchHome = mkdtempSync(join(tmpdir(), 'flow-smoke-home-'));
console.log(`  scratch HOME: ${scratchHome}`);
try {
  const install = run('npx', npxArgs(['--yes', '-t', 'claude']), {
    env: { ...process.env, HOME: scratchHome, USERPROFILE: scratchHome, CI: 'true' },
  });
  if (install.status !== 0) fail('install into scratch HOME exited non-zero');

  const dest = join(scratchHome, '.claude', 'skills', 'flow');
  if (!existsSync(join(dest, 'SKILL.md'))) fail('SKILL.md missing at ' + dest);
  // Aligned with SECURITY.md § What the installer WILL do — the 6 cleanup subdirs from
  // install.sh:25 that the installer owns. `eval/` ships but is not in the ownership
  // contract, so we do not assert it here.
  for (const sub of ['runner', '_templates', 'law', 'references', 'harness', 'playbooks']) {
    if (!existsSync(join(dest, sub))) fail(`expected subdir missing: ${sub}`);
  }
  console.log('  scratch install populated 6 owned subdirs + SKILL.md');

  rmSync(scratchHome, { recursive: true, force: true });
} catch (err) {
  console.error(`  scratch HOME preserved for inspection: ${scratchHome}`);
  throw err;
} finally {
  try {
    rmSync(npxCwd, { recursive: true, force: true });
  } catch {
    /* ignore */
  }
}

console.log(`\nSMOKE OK: ${PKG}@${version} is healthy on the registry.`);

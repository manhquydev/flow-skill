#!/usr/bin/env node
// Post-publish smoke test. Run against a live version on the npm registry:
//   node scripts/smoke.mjs 0.1.0-rc.2
// Verifies:
//   1. The version exists on the registry.
//   2. Its dist.attestations.provenance declares the SLSA v1 predicate (metadata only).
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
import { realpathSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { supportsReceiptAndOmp } from './semver.mjs';
import { assertProvenanceResult, canonicalSmokeTempBase } from './smoke-policy.mjs';

const PKG = '@manhquy/flow-skill';
const BIN = 'flow-skill';
const RECEIPT_NAME_MIRROR = 'manifest-hashes.json';
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
const tempBase = canonicalSmokeTempBase();
const npxCwd = mkdtempSync(join(tempBase, 'flow-smoke-npx-'));

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

// 2. provenance — absence or query failure is fatal for policy-gated releases.
const prov = run('npm', ['view', `${PKG}@${version}`, 'dist.attestations.provenance', '--json']);
try {
  assertProvenanceResult(prov.status, prov.stdout, PKG, version);
} catch (error) {
  fail(error.message);
}
console.log('  provenance: SLSA v1 metadata present (cryptographic verification is separate)');

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
const scratchHome = mkdtempSync(join(tempBase, 'flow-smoke-home-'));
console.log(`  scratch HOME: ${scratchHome}`);
try {
  const install = run('npx', npxArgs(['--yes', '-t', 'claude']), {
    env: { ...process.env, HOME: scratchHome, USERPROFILE: scratchHome, CI: 'true' },
  });
  if (install.status !== 0) fail('install into scratch HOME exited non-zero');

  const dest = join(scratchHome, '.claude', 'skills', 'flow');
  if (!existsSync(join(dest, 'SKILL.md'))) fail('SKILL.md missing at ' + dest);
  if (supportsReceiptAndOmp(version)) {
    if (!existsSync(join(dest, RECEIPT_NAME_MIRROR))) fail('ownership receipt missing at ' + dest);
  }
  // The shipped tree materializes these 6 asset subdirs plus adapter-hooks/eval as shipped;
  // upgrade freshness is governed by the ownership receipt (manifest-hashes.json), verified
  // below, not by directory deletion.
  for (const sub of ['runner', '_templates', 'law', 'references', 'harness', 'playbooks']) {
    if (!existsSync(join(dest, sub))) fail(`expected subdir missing: ${sub}`);
  }
  console.log('  scratch install populated 6 owned subdirs + SKILL.md');

  if (!supportsReceiptAndOmp(version)) {
    console.log(
      `  skipping ownership receipt and OMP assertions (unsupported on legacy ${version} < 0.7.8)`
    );
  } else {
    // 6. explicit OMP install into a fresh scratch HOME — materialization at the genuine
    //    skills home `.omp/agent/skills/flow` (never the operator's real ~/.omp), plus a
    //    stdlib self-check that the shipped receipt digests match the installed files.
    const ompHome = mkdtempSync(join(tempBase, 'flow-smoke-omp-home-'));
    try {
      const ompInstall = run('npx', npxArgs(['--yes', '-t', 'omp']), {
        env: { ...process.env, HOME: ompHome, USERPROFILE: ompHome, CI: 'true' },
      });
      if (ompInstall.status !== 0) fail('explicit --target omp install exited non-zero');
      const ompDest = join(ompHome, '.omp', 'agent', 'skills', 'flow');
      if (!existsSync(join(ompDest, 'SKILL.md'))) fail('SKILL.md missing at ' + ompDest);
      if (!existsSync(join(ompDest, 'manifest-hashes.json'))) {
        fail('manifest-hashes.json missing at ' + ompDest);
      }
      for (const sub of ['runner', '_templates', 'law', 'references', 'harness', 'playbooks']) {
        if (!existsSync(join(ompDest, sub))) fail(`omp install: expected subdir missing: ${sub}`);
      }
      const receipt = JSON.parse(readFileSync(join(ompDest, RECEIPT_NAME_MIRROR), 'utf8'));
      if (receipt.schema_version !== 1 || !receipt.files) fail('omp receipt malformed');
      for (const [rel, digest] of Object.entries(receipt.files)) {
        const actual = createHash('sha256').update(readFileSync(join(ompDest, rel))).digest('hex');
        if (actual !== digest) fail(`omp installed file drifted from receipt: ${rel}`);
      }
      console.log('  omp scratch install materialized; receipt digests verified');
    } finally {
      rmSync(ompHome, { recursive: true, force: true });
    }

    // 7. OMP detection boundary in a scratch HOME: bare `~/.omp` (runtime state only) must not
    //    auto-select omp; creating the genuine skills dir must.
    const bareEnv = { ...process.env, HOME: scratchHome, USERPROFILE: scratchHome, CI: 'true' };
    mkdirSync(join(scratchHome, '.omp', 'logs'), { recursive: true });
    const bareRun = run('npx', npxArgs(['--yes', '--dry-run', '--json']), { env: bareEnv });
    if (bareRun.status !== 0) fail('bare-.omp dry-run exited non-zero');
    const barePlan = bareRun.stdout
      .trim()
      .split('\n')
      .filter(Boolean)
      .map((l) => JSON.parse(l))
      .find((e) => e.event === 'plan');
    if (!barePlan) fail('bare-.omp run emitted no plan event');
    if (barePlan.targets.includes('omp')) {
      fail('bare ~/.omp must NOT auto-detect the omp target');
    }
    mkdirSync(join(scratchHome, '.omp', 'agent', 'skills'), { recursive: true });
    const genuineRun = run('npx', npxArgs(['--yes', '--dry-run', '--json']), { env: bareEnv });
    if (genuineRun.status !== 0) fail('genuine-skills dry-run exited non-zero');
    const genuinePlan = genuineRun.stdout
      .trim()
      .split('\n')
      .filter(Boolean)
      .map((l) => JSON.parse(l))
      .find((e) => e.event === 'plan');
    if (!genuinePlan || !genuinePlan.targets.includes('omp')) {
      fail('genuine ~/.omp/agent/skills must auto-detect the omp target');
    }
    console.log('  omp detection boundary OK (bare .omp no / genuine skills dir yes)');
  }

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

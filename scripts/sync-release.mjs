#!/usr/bin/env node
/**
 * scripts/sync-release.mjs
 *
 * Unified release synchronization & coherence tool for flow-skill.
 *
 * Inspects and validates unified release coherence across skill and npm channels,
 * synchronizes documentation tables, re-materializes bundled assets, and prints
 * exact release/tag commands.
 *
 * Usage:
 *   node scripts/sync-release.mjs [--check]
 *   node scripts/sync-release.mjs --sync
 */

import { readFileSync, writeFileSync, existsSync, realpathSync, mkdtempSync, mkdirSync, rmSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { tmpdir } from 'node:os';
import { createHash, randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';

import { publisherRunIdFromDispatch, publisherWatchArgs, publisherWatchTimeoutError, verifyPublisherJobs } from './release-dispatch-response.mjs';
import { PUBLIC_NPM_REGISTRY, readNpmRegistryJson, verifyPostPublishFinalization, verifyRunArtifact, verifyRegistryChannel } from './release-run-artifact.mjs';
import { assertGhAttestationCapability } from './verify-attestation-with-gh.mjs';
const __dirname = dirname(realpathSync(fileURLToPath(import.meta.url)));
const repoRoot = resolve(__dirname, '..');

function escapeRegExp(string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function getSkillVersion() {
  const p = join(repoRoot, 'skills', 'flow', 'SKILL.md');
  if (!existsSync(p)) return null;
  const content = readFileSync(p, 'utf8');
  const m = content.match(/^[ \t]*version:[ \t]*"?([0-9][.0-9A-Za-z-]*)"?/m);
  return m ? m[1] : null;
}

function getPluginVersion() {
  const p = join(repoRoot, '.claude-plugin', 'plugin.json');
  if (!existsSync(p)) return null;
  try {
    const json = JSON.parse(readFileSync(p, 'utf8'));
    return json.version || null;
  } catch {
    return null;
  }
}

function getPortableVersion() {
  const p = join(repoRoot, 'portable-manifest.json');
  if (!existsSync(p)) return null;
  try {
    const json = JSON.parse(readFileSync(p, 'utf8'));
    return json.version || null;
  } catch {
    return null;
  }
}

function getNpmVersion() {
  const p = join(repoRoot, 'npm-wrapper', 'package.json');
  if (!existsSync(p)) return null;
  try {
    const json = JSON.parse(readFileSync(p, 'utf8'));
    return json.version || null;
  } catch {
    return null;
  }
}

function getRunnerHashes() {
  const runnerPath = join(repoRoot, 'skills', 'flow', 'runner', 'flow.sh');
  const manifestPath = join(repoRoot, 'portable-manifest.json');
  let liveHash = null;
  let manifestHash = null;

  if (existsSync(runnerPath)) {
    const bytes = readFileSync(runnerPath);
    liveHash = createHash('sha256').update(bytes).digest('hex');
  }

  if (existsSync(manifestPath)) {
    try {
      const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
      manifestHash = manifest.hashes?.['skills/flow/runner/flow.sh'] || null;
    } catch {
      manifestHash = null;
    }
  }

  return { liveHash, manifestHash };
}

function runChecks() {
  const skill_v = getSkillVersion();
  const plugin_v = getPluginVersion();
  const portable_v = getPortableVersion();
  const npm_v = getNpmVersion();
  const { liveHash, manifestHash } = getRunnerHashes();

  const results = [];

  // 1. Skill version in SKILL.md
  results.push({
    surface: 'Skill version (skills/flow/SKILL.md)',
    expected: 'Valid semver',
    actual: skill_v || 'MISSING',
    pass: Boolean(skill_v),
  });

  // 2. Mirror version in .claude-plugin/plugin.json
  results.push({
    surface: 'Plugin mirror (.claude-plugin/plugin.json)',
    expected: skill_v || 'N/A',
    actual: plugin_v || 'MISSING',
    pass: Boolean(skill_v && plugin_v && skill_v === plugin_v),
  });

  // 3. Mirror version in portable-manifest.json
  results.push({
    surface: 'Portable manifest mirror (portable-manifest.json)',
    expected: skill_v || 'N/A',
    actual: portable_v || 'MISSING',
    pass: Boolean(skill_v && portable_v && skill_v === portable_v),
  });

  // 4. npm version in npm-wrapper/package.json
  results.push({
    surface: 'npm package version (npm-wrapper/package.json)',
    expected: 'Valid semver',
    actual: npm_v || 'MISSING',
    pass: Boolean(npm_v),
  });

  // 5. Unified version (npm_v === skill_v)
  const unifiedVersion = Boolean(skill_v && npm_v && skill_v === npm_v);
  results.push({
    surface: 'Unified version (npm_v === skill_v)',
    expected: 'npm_v === skill_v',
    actual: skill_v && npm_v ? `${npm_v} ${unifiedVersion ? '===' : '!=='} ${skill_v}` : 'N/A',
    pass: unifiedVersion,
  });

  // 6. SHA-256 runner hash of skills/flow/runner/flow.sh vs portable-manifest.json
  const hashMatches = Boolean(liveHash && manifestHash && liveHash === manifestHash);
  results.push({
    surface: 'Runner SHA-256 (flow.sh vs portable-manifest)',
    expected: manifestHash ? manifestHash.slice(0, 12) + '...' : 'Present in manifest',
    actual: liveHash ? (hashMatches ? liveHash.slice(0, 12) + '... (matches)' : liveHash.slice(0, 12) + '... (mismatch)') : 'MISSING',
    pass: hashMatches,
  });

  // README versions describe repository release targets, never registry publication.
  for (const item of getExpectedReadmeTransforms(skill_v, npm_v)) {
    const fullPath = join(repoRoot, item.relPath);
    const text = existsSync(fullPath) ? readFileSync(fullPath, 'utf8') : null;
    const expected = item.transform(item.relPath.startsWith('npm-wrapper/')
      ? (item.relPath.endsWith('_VN.md') ? '| **Mục tiêu phát hành** |\n' : '| **Release target** |\n')
      : '| **Skill product** |\n| **npm installer** |\n');
    const rowsPresent = text !== null && expected.trim().split('\n').every(row => text.split(/\r?\n/).includes(row));
    results.push({
      surface: `${item.relPath} release target rows`,
      expected: `Release target: skill v${skill_v}, npm ${npm_v} (not a publication receipt)`,
      actual: text === null ? 'FILE MISSING' : (item.transform(text) === text ? 'Checked canonical target rows' : 'ROW MISMATCH'),
      pass: Boolean(rowsPresent && skill_v && npm_v && item.transform(text) === text),
    });
  }

  // 11. Entry for skill version in CHANGELOG.md
  const changelogPath = join(repoRoot, 'CHANGELOG.md');
  let changelogHasSkill = false;
  if (existsSync(changelogPath) && skill_v) {
    const text = readFileSync(changelogPath, 'utf8');
    changelogHasSkill = new RegExp(`^##\\s+\\[?${escapeRegExp(skill_v)}\\]?`, 'm').test(text);
  }
  results.push({
    surface: 'CHANGELOG.md entry for skill version',
    expected: skill_v ? `## [${skill_v}]` : 'N/A',
    actual: changelogHasSkill ? 'Found' : 'MISSING',
    pass: changelogHasSkill,
  });

  // 12. Entry for npm version in npm-wrapper/CHANGELOG.md
  const wrapperChangelogPath = join(repoRoot, 'npm-wrapper', 'CHANGELOG.md');
  let wrapperChangelogHasNpm = false;
  if (existsSync(wrapperChangelogPath) && npm_v) {
    const text = readFileSync(wrapperChangelogPath, 'utf8');
    wrapperChangelogHasNpm = new RegExp(`^##\\s+\\[?${escapeRegExp(npm_v)}\\]?`, 'm').test(text);
  }
  results.push({
    surface: 'npm-wrapper/CHANGELOG.md entry for npm version',
    expected: npm_v ? `## [${npm_v}]` : 'N/A',
    actual: wrapperChangelogHasNpm ? 'Found' : 'MISSING',
    pass: wrapperChangelogHasNpm,
  });

  return {
    skill_v,
    npm_v,
    results,
    allPass: results.every(r => r.pass),
  };
}

function formatDiagnosticTable(results) {
  const rows = results.map(r => [
    r.surface,
    r.expected,
    r.actual,
    r.pass ? 'PASS' : 'FAIL',
  ]);

  const headers = ['Surface / Check', 'Expected', 'Observed', 'Status'];
  const colWidths = [
    Math.max(headers[0].length, ...rows.map(r => r[0].length)),
    Math.max(headers[1].length, ...rows.map(r => r[1].length)),
    Math.max(headers[2].length, ...rows.map(r => r[2].length)),
    Math.max(headers[3].length, ...rows.map(r => r[3].length)),
  ];

  const pad = (str, len) => str + ' '.repeat(Math.max(0, len - str.length));
  const sep = colWidths.map(w => '-'.repeat(w)).join('  ');
  const headerLine = headers.map((h, i) => pad(h, colWidths[i])).join('  ');

  const lines = [
    '',
    '=== Release Coherence Diagnostic Table ===',
    headerLine,
    sep,
  ];
  for (const row of rows) {
    lines.push(row.map((cell, i) => pad(cell, colWidths[i])).join('  '));
  }
  lines.push(sep);
  return lines.join('\n');
}

export function getExpectedReadmeTransforms(skill_v, npm_v) {
  const channel = npm_v && npm_v.includes('-') ? 'next' : 'latest';
  return [
    {
      relPath: 'npm-wrapper/README.md',
      transform: (content) => content.replace(
        /^[ \t]*\|\s*\*\*(?:Current GA|Release target)\*\*\s*\|[^\r\n]*/m,
        `| **Release target** | npm **${npm_v}** / skill **v${skill_v}** — intended channel \`${channel}\`; not a publication receipt |`
      ).replace(/^[ \t]*\|\s*\*\*Prerelease\*\*\s*\|[^\r\n]*\r?\n?/m, ''),
    },
    {
      relPath: 'npm-wrapper/README_VN.md',
      transform: (content) => content.replace(
        /^[ \t]*\|\s*\*\*(?:GA hiện tại|Mục tiêu phát hành)\*\*\s*\|[^\r\n]*/m,
        `| **Mục tiêu phát hành** | npm **${npm_v}** / skill **v${skill_v}** — kênh dự kiến \`${channel}\`; không phải biên nhận đã phát hành |`
      ).replace(/^[ \t]*\|\s*\*\*(?:Bản thử nghiệm|Prerelease)\*\*\s*\|[^\r\n]*\r?\n?/m, ''),
    },
    {
      relPath: 'README.md',
      transform: (content) => content.replace(
        /^[ \t]*\|\s*\*\*Skill product\*\*\s*\|[^\r\n]*/m,
        `| **Skill product** | Release target **v${skill_v}** (not a publication receipt) |`
      ).replace(
        /^[ \t]*\|\s*\*\*npm installer\*\*\s*\|[^\r\n]*/m,
        `| **npm installer** | [\`@manhquy/flow-skill\`](https://www.npmjs.com/package/@manhquy/flow-skill) — release target **${npm_v}**, intended channel \`${channel}\` (not a publication receipt) |`
      ),
    },
    {
      relPath: 'README_VN.md',
      transform: (content) => content.replace(
        /^[ \t]*\|\s*\*\*Skill product\*\*\s*\|[^\r\n]*/m,
        `| **Skill product** | Mục tiêu phát hành **v${skill_v}** (không phải biên nhận đã phát hành) |`
      ).replace(
        /^[ \t]*\|\s*\*\*npm installer\*\*\s*\|[^\r\n]*/m,
        `| **npm installer** | [\`@manhquy/flow-skill\`](https://www.npmjs.com/package/@manhquy/flow-skill) — mục tiêu phát hành **${npm_v}**, kênh dự kiến \`${channel}\` (không phải biên nhận đã phát hành) |`
      ),
    },
  ];
}

function syncRelease(skill_v, npm_v) {
  const packagePath = join(repoRoot, 'npm-wrapper/package.json');
  const manifest = JSON.parse(readFileSync(packagePath, 'utf8'));
  if (manifest.version !== skill_v) {
    manifest.version = skill_v;
    writeFileSync(packagePath, JSON.stringify(manifest, null, 2) + '\n');
  }
  npm_v = skill_v;
  console.log(`\nSynchronizing release surfaces for skill v${skill_v} and npm ${npm_v}...`);
  for (const item of getExpectedReadmeTransforms(skill_v, npm_v)) {
    const fullPath = join(repoRoot, item.relPath);
    if (!existsSync(fullPath)) continue;
    const current = readFileSync(fullPath, 'utf8');
    const updated = item.transform(current);
    if (updated !== current) {
      writeFileSync(fullPath, updated, 'utf8');
    }
    console.log(`✓ Synchronized ${item.relPath}`);
  }

  console.log('\nRunning npm-wrapper sync inside npm-wrapper...');
  execFileSync(
    npmSpawnHelper().cmd,
    npmSpawnHelper().args,
    {
      cwd: join(repoRoot, 'npm-wrapper'),
      stdio: 'inherit',
    }
  );
  console.log('✓ Re-materialized skills/flow and updated manifest-hashes.json');
}

// Resolve the interpreter and args for spawning npm-wrapper lifecycle scripts directly
// via node, avoiding `npm.cmd` — Node 22 on Windows refuses execFileSync of a .cmd
// (spawnSync EINVAL). Matches npm-wrapper/package.json scripts ("sync": "node scripts/sync.mjs",
// "test": "node --test --test-concurrency=1 test/...").
export function npmSpawnHelper() {
  return {
    cmd: process.execPath,
    args: ['scripts/sync.mjs'],
    // cwd must be repoRoot/npm-wrapper
  };
}

export function npmTestHelper() {
  return {
    cmd: process.execPath,
    args: ['--test', '--test-concurrency=1', 'test/installer.test.mjs', 'test/detect.test.mjs', 'test/cli.test.mjs', 'test/lock-atomicity.test.mjs', 'test/sync-manifest.test.mjs', 'test/semver.test.mjs', 'test/smoke-policy.test.mjs'],
    // Mirrors npm-wrapper/package.json test; pretest is invoked via npmSpawnHelper().
  };
}

export function buildWin32GhCommandLine(args) {
  const quoteArg = (a) => {
    const s = String(a);
    if (/[\s&<>()@^|"]/.test(s)) {
      return `"${s.replace(/"/g, '""')}"`;
    }
    return s;
  };
  return ['gh', ...args.map(quoteArg)].join(' ');
}

function execGh(args, options = {}) {
  if (process.platform === 'win32') {
    // Windows: Node execFileSync('gh') bypasses PATHEXT when looking up extensionless
    // commands, skipping a mock `gh.cmd` in PATH and locating system `gh.exe` instead.
    // Wrap through cmd.exe /d /c without /s, leaving bare `gh` unquoted so cmd.exe
    // searches PATH. The mock wins because its directory is first on PATH, and
    // cmd.exe searches that directory with PATHEXT. Quote only arguments with spaces/metachars.
    const cmdLine = buildWin32GhCommandLine(args);
    return execFileSync('cmd.exe', ['/d', '/c', cmdLine], options);
  }
  return execFileSync('gh', args, options);
}
function verifyPublishedRun(runId, runAttempt, npmVersion, expectedSha) {
  const tempDir = mkdtempSync(join(tmpdir(), 'flow-release-run-'));
  const packageDir = join(tempDir, 'package');
  const evidenceDir = join(tempDir, 'evidence');
  try {
    mkdirSync(packageDir, { recursive: true });
    mkdirSync(evidenceDir, { recursive: true });
    execGh(['run', 'download', String(runId), '--name', `npm-package-${runId}-${runAttempt}`, '--dir', packageDir], { cwd: repoRoot, stdio: 'inherit', timeout: 120000 });
    execGh(['run', 'download', String(runId), '--name', `npm-verification-${runId}-${runAttempt}`, '--dir', evidenceDir], { cwd: repoRoot, stdio: 'inherit', timeout: 120000 });
    const { tarball, integrity } = verifyRunArtifact(packageDir, evidenceDir, { runId, runAttempt, version: npmVersion, sha: expectedSha });
    verifyRegistryChannel({ version: npmVersion, integrity, versionValue: npmViewJson(`@manhquy/flow-skill@${npmVersion}`, 'version'), integrityValue: npmViewJson(`@manhquy/flow-skill@${npmVersion}`, 'dist.integrity'), distTags: npmViewJson('@manhquy/flow-skill', 'dist-tags') });
    verifyPostPublishFinalization({
      version: npmVersion,
      integrity,
      verifyAttestation: () => execFileSync(process.execPath, [join(repoRoot, 'scripts/verify-attestation-with-gh.mjs'), tarball, join(evidenceDir, 'slsa-bundle.json'), 'manhquydev', 'flow-skill', '.github/workflows/publish-npm-wrapper.yml', 'refs/heads/master', expectedSha], { cwd: repoRoot, stdio: 'inherit', timeout: 120000 }),
      smoke: () => execFileSync(process.execPath, [join(repoRoot, 'npm-wrapper/scripts/smoke.mjs'), npmVersion], { cwd: repoRoot, stdio: 'inherit', timeout: 15 * 60 * 1000, env: { ...process.env, npm_config_registry: PUBLIC_NPM_REGISTRY } }),
      readRegistry: () => ({
        versionValue: npmViewJson(`@manhquy/flow-skill@${npmVersion}`, 'version'),
        integrityValue: npmViewJson(`@manhquy/flow-skill@${npmVersion}`, 'dist.integrity'),
        distTags: npmViewJson('@manhquy/flow-skill', 'dist-tags'),
      }),
    });
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
}

function npmViewJson(spec, field) {
  try {
    return readNpmRegistryJson(spec, field, { cwd: repoRoot });
  } catch (error) {
    throw new Error(`could not query current public registry ${field}: ${error.message}`);
  }
}


function gitTagExists(tagName) {
  try {
    const out = execFileSync('git', ['tag', '-l', tagName], {
      cwd: repoRoot,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    if (out.split(/\r?\n/).filter(Boolean).includes(tagName)) {
      return { exists: true, source: 'local' };
    }
  } catch {
    // local check failed
  }
  try {
    const out = execFileSync('git', ['ls-remote', '--tags', 'origin', `refs/tags/${tagName}`], {
      cwd: repoRoot,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    return { exists: out.length > 0, source: 'remote' };
  } catch {
    return { exists: false, source: 'unconfirmed' };
  }
}

export function verifyExistingSkillTag(tagName, cwd = repoRoot) {
  try {
    const tree = (ref) => execFileSync('git', ['rev-parse', '--verify', `${ref}:skills`], {
      cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    const ref = `refs/tags/${tagName}`;
    const options = { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] };
    const remote = execFileSync('git', ['ls-remote', '--tags', 'origin', ref], options).trim().split(/\s+/);
    if (!/^[a-f0-9]{40,64}$/.test(remote[0]) || remote[1] !== ref) throw new Error('remote skill tag unavailable');
    execFileSync('git', ['fetch', '--no-tags', '--no-write-fetch-head', 'origin', ref], options);
    const confirmed = execFileSync('git', ['ls-remote', '--tags', 'origin', ref], options).trim().split(/\s+/);
    if (confirmed[0] !== remote[0] || confirmed[1] !== ref) throw new Error('remote skill tag moved');
    const tagTree = tree(`${remote[0]}^{commit}`);
    const headTree = tree('HEAD');
    if (tagTree && tagTree === headTree) return { ok: true, reason: `Existing skill tag ${tagName} has identical skills/ subtree ${headTree}; skipping skill tag creation.` };
  } catch {
    // Missing tag objects or subtree hashes cannot authorize reuse.
  }
  return { ok: false, reason: `Skill tag ${tagName} differs from HEAD or its skills/ subtree hash is unavailable; bump to the next common version.` };
}

function printReleaseInstructions(skill_v, npm_v) {
  const npmTag = `npm@${npm_v}`;
  const skillTag = `v${skill_v}`;
  const npmCheck = gitTagExists(npmTag);
  const skillCheck = gitTagExists(skillTag);

  console.log(`
================================================================================
Release Instructions (Unified Version Channels)
================================================================================
Skill Product: v${skill_v}
npm Package:   ${npm_v}
`);

  if (npmCheck.exists && skillCheck.exists) {
    console.log(`[NOTE] Both release tags already exist. This operation was metadata repair / synchronization, not a new release.\n`);
  }

  console.log('1. Channel 1 — npm installer release (triggers npm publish workflow):');
  if (npmCheck.exists) {
    console.log(`   [INFO] Git tag ${npmTag} ALREADY exists (${npmCheck.source}). Skipping npm tag command.`);
  } else if (npmCheck.source === 'unconfirmed') {
    console.log(`   [WARN] Remote tag check for ${npmTag} unconfirmed (remote inaccessible). Tag creation commands suppressed for safety; verify remote tags manually.`);
  } else {
    console.log(`   git tag ${npmTag}`);
    console.log(`   git push origin ${npmTag}`);
  }

  console.log('\n2. Channel 2 — Skill product release (GitHub Release / tags):');
  if (skillCheck.exists) {
    console.log(`   [INFO] Git tag ${skillTag} ALREADY exists (${skillCheck.source}). Skipping skill tag command.`);
  } else if (skillCheck.source === 'unconfirmed') {
    console.log(`   [WARN] Remote tag check for ${skillTag} unconfirmed (remote inaccessible). Tag creation commands suppressed for safety; verify remote tags manually.`);
  } else {
    console.log(`   git tag ${skillTag}`);
    console.log(`   git push origin ${skillTag}`);
  }

  console.log(`
Commit recommendation:
   git add skills/flow/SKILL.md .claude-plugin/plugin.json portable-manifest.json \\
     npm-wrapper/package.json npm-wrapper/skills/ README.md README_VN.md \\
     npm-wrapper/README.md npm-wrapper/README_VN.md CHANGELOG.md npm-wrapper/CHANGELOG.md
   git commit -m "chore(release): v${skill_v} / npm@${npm_v}"
   git push origin master
================================================================================
`);
}


function getWorkingTreeStatus() {
  const out = execFileSync('git', ['status', '--porcelain'], {
    cwd: repoRoot,
    encoding: 'utf8',
  });
  if (!out.trim()) return [];
  return out.split(/\r?\n/).filter(Boolean).map(line => {
    const match = line.match(/^(.{2})\s+(.*)$/);
    const status = match ? match[1] : line.slice(0, 2);
    let p = match ? match[2].trim() : line.slice(3).trim();
    if (p.includes(' -> ')) {
      p = p.split(' -> ').pop().trim();
    }
    if (p.startsWith('"') && p.endsWith('"')) {
      p = p.slice(1, -1);
    }
    p = p.replace(/\\/g, '/');
    return { status, path: p };
  });
}

function getCurrentBranch() {
  try {
    return execFileSync('git', ['branch', '--show-current'], { cwd: repoRoot, encoding: 'utf8' }).trim();
  } catch {
    return '';
  }
}

function getLocalHeadSha() {
  try {
    return execFileSync('git', ['rev-parse', 'HEAD'], { cwd: repoRoot, encoding: 'utf8' }).trim();
  } catch {
    return '';
  }
}

function getRemoteMasterSha() {
  try {
    const out = execFileSync('git', ['ls-remote', 'origin', 'refs/heads/master'], {
      cwd: repoRoot,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
    if (!out) return null;
    const match = out.match(/^([0-9a-f]{40})\s+refs\/heads\/master/);
    return match ? match[1] : null;
  } catch (err) {
    const rawStderr = err.stderr ? err.stderr.toString().trim() : '';
    const sanitized = (rawStderr || err.message || '').replace(/([a-zA-Z][a-zA-Z0-9+.-]*:\/\/)[^@/\s]+@/g, '$1***@');
    return { error: sanitized };
  }
}
const CANONICAL_REPO_OWNER = 'manhquydev';
const CANONICAL_REPO_NAME = 'flow-skill';

const CANONICAL_REMOTE_URL_PATTERNS = [
  /^https:\/\/github\.com\/manhquydev\/flow-skill(?:\.git)?$/,
  /^git@github\.com:manhquydev\/flow-skill(?:\.git)?$/,
  /^ssh:\/\/git@github\.com\/manhquydev\/flow-skill(?:\.git)?$/,
];

function getRepoCoordinates() {
  const getUrls = (configKey) => {
    try {
      const out = execFileSync('git', ['config', '--get-all', configKey], {
        cwd: repoRoot,
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      }).trim();
      if (out) return out.split(/\r?\n/).map(s => s.trim()).filter(Boolean);
    } catch {
      // not configured
    }
    return [];
  };

  let fetchUrls = getUrls('remote.origin.url');
  if (fetchUrls.length === 0) {
    try {
      const out = execFileSync('git', ['remote', 'get-url', 'origin'], {
        cwd: repoRoot,
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      }).trim();
      if (out) fetchUrls = [out];
    } catch {
      // unreadable
    }
  }

  let pushUrls = getUrls('remote.origin.pushurl');
  if (pushUrls.length === 0) {
    pushUrls = fetchUrls;
  }

  if (fetchUrls.length === 0 && pushUrls.length === 0) {
    return { ok: false, reason: 'Remote origin URL could not be determined from git config or git remote.' };
  }

  for (const url of fetchUrls) {
    if (!CANONICAL_REMOTE_URL_PATTERNS.some(p => p.test(url))) {
      return {
        ok: false,
        reason: `Remote origin fetch URL is not an accepted canonical repository URL for ${CANONICAL_REPO_OWNER}/${CANONICAL_REPO_NAME}. Expected exact HTTPS, SSH, or git protocol format on github.com without userinfo credentials.`,
      };
    }
  }

  for (const url of pushUrls) {
    if (!CANONICAL_REMOTE_URL_PATTERNS.some(p => p.test(url))) {
      return {
        ok: false,
        reason: `Remote origin push URL is not an accepted canonical repository URL for ${CANONICAL_REPO_OWNER}/${CANONICAL_REPO_NAME}. Expected exact HTTPS, SSH, or git protocol format on github.com without userinfo credentials.`,
      };
    }
  }

  return { ok: true, owner: CANONICAL_REPO_OWNER, repo: CANONICAL_REPO_NAME };
}

function checkCiStatus(headSha) {
  const coords = getRepoCoordinates();
  if (!coords.ok) {
    return { ok: false, reason: coords.reason };
  }
  let data;
  try {
    const out = execGh([
      'api',
      `repos/${coords.owner}/${coords.repo}/commits/${headSha}/check-runs?check_name=all-checks-passed&per_page=100`,
    ], {
      cwd: repoRoot,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    data = JSON.parse(out);
  } catch (err) {
    const stderr = err.stderr ? err.stderr.toString().trim() : '';
    return {
      ok: false,
      reason: `Could not query GitHub Actions check runs via "gh api": ${stderr || err.message}`,
    };
  }

  const checkRuns = (data && Array.isArray(data.check_runs)) ? data.check_runs : [];
  const matches = checkRuns.filter(c => c && c.name === 'all-checks-passed');
  if (matches.length === 0) {
    return {
      ok: false,
      reason: `Required check "all-checks-passed" not found for commit ${headSha} (evaluated ${checkRuns.length} check run(s) from GitHub API).`,
    };
  }
  matches.sort((a, b) => (b.id || 0) - (a.id || 0));
  const check = matches[0];
  if (check.head_sha !== headSha) {
    return {
      ok: false,
      reason: `Check run head_sha (${check.head_sha}) does not match HEAD (${headSha}).`,
    };
  }
  if (check.app?.slug !== 'github-actions') {
    return {
      ok: false,
      reason: `Check run "all-checks-passed" was created by app "${check.app?.slug || 'unknown'}", expected authoritative "github-actions".`,
    };
  }
  if (check.status !== 'completed') {
    return {
      ok: false,
      reason: `Check run "all-checks-passed" is not completed (current status: "${check.status}").`,
    };
  }
  if (check.conclusion !== 'success') {
    return {
      ok: false,
      reason: `Check run "all-checks-passed" conclusion is "${check.conclusion}" (expected "success").`,
    };
  }
  return { ok: true, check };
}

function checkNpmPublishEnvironmentPolicy() {
  const coords = getRepoCoordinates();
  if (!coords.ok) return { ok: false, reason: coords.reason };
  try {
    const data = JSON.parse(execGh(['api', `repos/${coords.owner}/${coords.repo}/environments/npm-publish`], { cwd: repoRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }));
    const policy = data?.deployment_branch_policy;
    if (!policy || policy.protected_branches !== false || policy.custom_branch_policies !== true) return { ok: false, reason: 'npm-publish must use selected custom branch policies, not protected-branches or unrestricted deployment.' };
    const result = JSON.parse(execGh(['api', `repos/${coords.owner}/${coords.repo}/environments/npm-publish/deployment-branch-policies`], { cwd: repoRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }));
    if (!Array.isArray(result.branch_policies) || result.branch_policies.length !== 1 || result.branch_policies[0].type !== 'branch' || result.branch_policies[0].name !== 'master') return { ok: false, reason: 'npm-publish must allow exactly branch master and no tag/wildcard deployment rules.' };
    return { ok: true, rule: result.branch_policies[0] };
  } catch (err) {
    return { ok: false, reason: `Could not verify npm-publish master-only deployment policy: ${err.stderr?.toString().trim() || err.message}` };
  }
}



function dispatchPublisher(headSha, npmVersion, isDryRun) {
  const coords = getRepoCoordinates();
  if (!coords.ok) throw new Error(coords.reason);
  try {
    assertGhAttestationCapability({ run: args => execGh(args, { cwd: repoRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 15000 }) });
  } catch (error) {
    throw new Error(`Pre-publish gh capability check failed: ${error.message}. The controller must provision a project-local portable gh >=2.68.0 with the required attestation verify options on PATH before dispatch; do not upgrade global host tooling.`);
  }
  const actorId = execGh(['api', 'user', '--jq', '.id'], { cwd: repoRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  if (!/^\d+$/.test(actorId)) throw new Error('GitHub CLI did not return a valid authenticated actor ID.');
  const dispatchId = randomUUID();
  const requestBody = JSON.stringify({ ref: 'master', return_run_details: true, inputs: { mode: isDryRun ? 'dry-run' : 'publish', expected_sha: headSha, expected_version: npmVersion, dispatch_id: dispatchId, expected_actor_id: actorId } });
  const response = execGh(['api', '-X', 'POST', '-H', 'Accept: application/vnd.github+json', '-H', 'X-GitHub-Api-Version: 2022-11-28', `repos/${coords.owner}/${coords.repo}/actions/workflows/publish-npm-wrapper.yml/dispatches`, '--input', '-'], { cwd: repoRoot, input: requestBody, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
  const runId = String(publisherRunIdFromDispatch(response, coords.owner, coords.repo));
  try {
    execGh(publisherWatchArgs(runId), { cwd: repoRoot, stdio: 'inherit', timeout: 45 * 60 * 1000 });
  } catch (error) {
    let cancelRequested = false;
    if (error.code === 'ETIMEDOUT') {
      try { execGh(['run', 'cancel', runId], { cwd: repoRoot, stdio: ['ignore', 'pipe', 'pipe'], timeout: 15000 }); cancelRequested = true; } catch {}
    }
    throw publisherWatchTimeoutError(error, runId, 45, cancelRequested);
  }
  const finalRun = JSON.parse(execGh(['api', `repos/${coords.owner}/${coords.repo}/actions/runs/${runId}`], { cwd: repoRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }));
  const expectedTitle = `Publisher ${headSha} ${npmVersion} ${dispatchId}`;
  if (finalRun.id !== Number(runId) || String(finalRun.actor?.id) !== actorId || finalRun.head_sha !== headSha || finalRun.path !== '.github/workflows/publish-npm-wrapper.yml' || finalRun.event !== 'workflow_dispatch' || finalRun.display_title !== expectedTitle || finalRun.status !== 'completed' || finalRun.conclusion !== 'success' || !Number.isInteger(finalRun.run_attempt)) throw new Error('Returned publisher run did not complete successfully for exact actor/SHA/version/dispatch UUID.');
  const jobs = JSON.parse(execGh(['api', `repos/${coords.owner}/${coords.repo}/actions/runs/${runId}/jobs?filter=latest&per_page=100`], { cwd: repoRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }));
  verifyPublisherJobs(jobs, Number(runId), finalRun.run_attempt, isDryRun);
  return { id: Number(runId), runAttempt: finalRun.run_attempt };
}

function checkSyncNonDrift(skill_v, npm_v) {
  const drifts = [];
  for (const item of getExpectedReadmeTransforms(skill_v, npm_v)) {
    const fullPath = join(repoRoot, item.relPath);
    if (!existsSync(fullPath)) continue;
    const current = readFileSync(fullPath, 'utf8');
    const expected = item.transform(current);
    if (current !== expected) {
      drifts.push(item.relPath);
    }
  }
  const bundledSkills = join(repoRoot, 'npm-wrapper', 'skills', 'flow');
  if (existsSync(bundledSkills)) {
    try {
      execFileSync(
        process.execPath,
        [
          join(repoRoot, 'npm-wrapper', 'scripts', 'sync.mjs'),
          '--compare',
          bundledSkills,
          join(repoRoot, 'skills', 'flow'),
        ],
        { cwd: repoRoot, stdio: ['ignore', 'pipe', 'pipe'] }
      );
    } catch {
      drifts.push('npm-wrapper/skills/flow (bundled assets drift from skills/flow)');
    }
  }

  return drifts;
}

function shipRelease({ isDryRun = false, isYes = false } = {}) {
  const intent = JSON.parse(readFileSync(join(repoRoot, 'docs/release-intent.json'), 'utf8'));
  if (isYes && !isDryRun && intent.intent === false) {
    console.log('NO-OP: release intent is false; no dispatch, publish, tags, or ref changes.');
    return;
  }
  const hasSkillRelease = intent.intent === true && intent.skill_version !== null;
  // If neither --dry-run nor --yes is specified:
  // Print planned release actions and exit 0 immediately with ZERO file modifications, ZERO writes!
  if (!isYes && !isDryRun) {
    const skill_v = getSkillVersion();
    const npm_v = getNpmVersion();
    const npmTag = npm_v ? `npm@${npm_v}` : 'npm@<unknown>';
    const skillTag = hasSkillRelease ? `v${intent.skill_version}` : null;
    const npmTagStatus = npm_v ? gitTagExists(npmTag) : { exists: false, source: 'unknown' };
    const skillTagStatus = hasSkillRelease ? gitTagExists(skillTag) : { exists: false, source: 'not-selected' };

    console.log(`
================================================================================
RELEASE PROMOTION CONFIRMATION REQUIRED
================================================================================
Planned promotion of pre-prepared, CI-verified master HEAD:
  Skill version: ${hasSkillRelease ? `v${intent.skill_version}` : 'unchanged (no skill release)'}
  npm version:   ${npm_v ?? 'MISSING'}
  Tags:
    - ${npmTag} ${npmTagStatus.exists ? `(already exists: ${npmTagStatus.source})` : '(new tag to create)'}
    ${hasSkillRelease ? `- ${skillTag} ${skillTagStatus.exists ? `(already exists: ${skillTagStatus.source})` : '(new tag to create)'}` : '- no skill tag changes'}
  Branch:
    - master -> origin/master

Confirmation flag (--yes / -y) was not provided. Live promotion, tag creation,
and pushing are paused for safety.

To preview release readiness without mutations:
  node scripts/sync-release.mjs --ship --dry-run
  bash scripts/release.sh --dry-run

To execute release promotion live, re-run with --yes:
  node scripts/sync-release.mjs --ship --yes
  bash scripts/release.sh --yes
================================================================================
`);
    process.exit(0);
  }

  console.log(`\n================================================================================`);
  console.log(`Starting Flow Skill Release Promotion${isDryRun ? ' (DRY-RUN)' : ''}`);
  console.log(`================================================================================\n`);

  // 1. Strict working tree and index cleanliness gate (no release-file exception)
  console.log('Step 1/8: Checking working tree and index status...');
  const statusFiles = getWorkingTreeStatus();
  if (statusFiles.length > 0) {
    if (!isDryRun) {
      console.error(`\nFAIL: Working tree contains uncommitted or untracked changes (${statusFiles.length} file(s)). Release promotion requires a completely clean working tree and index.`);
      for (const f of statusFiles) {
        console.error(`  ${f.status} ${f.path}`);
      }
      process.exit(1);
    } else {
      console.log('[WARN] Working tree contains uncommitted or untracked changes (non-mutating --dry-run continues):');
      for (const f of statusFiles) {
        console.log(`  ${f.status} ${f.path}`);
      }
    }
  } else {
    console.log('✓ Working tree and index are 100% clean.');
  }

  // 2. Read versions and changelogs
  console.log('\nStep 2/8: Reading release versions...');
  const skill_v = getSkillVersion();
  const npm_v = getNpmVersion();
  if (!skill_v || !npm_v) { console.error('FAIL: Skill/npm version metadata is missing.'); process.exit(1); }
  console.log(`${hasSkillRelease ? `✓ Skill product release: v${intent.skill_version}` : '✓ Skill product axis unchanged.'}`);
  console.log(`✓ npm package version: ${npm_v}`);

  console.log('\nStep 3/8: Validating selected-axis CHANGELOG entries...');
  const wrapperChangelogPath = join(repoRoot, 'npm-wrapper', 'CHANGELOG.md');
  if (!existsSync(wrapperChangelogPath) || !new RegExp(`^##\\s+\\[?${escapeRegExp(npm_v)}\\]?`, 'm').test(readFileSync(wrapperChangelogPath, 'utf8'))) {
    console.error(`FAIL: npm-wrapper/CHANGELOG.md is missing an entry for npm version ${npm_v}`);
    process.exit(1);
  }
  if (hasSkillRelease) {
    const changelogPath = join(repoRoot, 'CHANGELOG.md');
    if (!existsSync(changelogPath) || !new RegExp(`^##\\s+\\[?${escapeRegExp(intent.skill_version)}\\]?`, 'm').test(readFileSync(changelogPath, 'utf8'))) {
      console.error(`FAIL: CHANGELOG.md is missing an entry for skill version v${intent.skill_version}`);
      process.exit(1);
    }
  }
  console.log('✓ CHANGELOG entries exist for selected release axes.');

  // 3. Branch gate
  console.log('\nStep 4/8: Verifying branch status and release tag preconditions...');
  const currentBranch = getCurrentBranch();
  if (currentBranch !== 'master') {
    if (!isDryRun) {
      console.error(`\nFAIL: Current branch is "${currentBranch || 'detached'}", must be "master" for release promotion.`);
      process.exit(1);
    } else {
      console.log(`[WARN] Current branch is "${currentBranch || 'detached'}" (release promotion requires "master").`);
    }
  } else {
    console.log('✓ Current branch is "master".');
  }

  const coords = getRepoCoordinates();
  if (!coords.ok) {
    if (!isDryRun) {
      console.error(`\nFAIL: Remote origin repository validation failed: ${coords.reason}`);
      process.exit(1);
    } else {
      console.log(`[WARN] Remote origin repository validation: ${coords.reason}`);
    }
  } else {
    console.log(`✓ Remote origin verified canonical (${coords.owner}/${coords.repo}).`);
  }
  const npmTag = `npm@${npm_v}`;
  const skillTag = hasSkillRelease ? `v${intent.skill_version}` : null;
  const npmTagStatus = gitTagExists(npmTag);
  const skillTagStatus = hasSkillRelease ? gitTagExists(skillTag) : { exists: false, source: 'not-selected' };

  if (npmTagStatus.source === 'unconfirmed' || (hasSkillRelease && skillTagStatus.source === 'unconfirmed')) {
    if (!isDryRun) {
      console.error('\nFAIL: Remote tag status could not be confirmed with origin (network failure, authentication error, or remote inaccessible).');
      console.error('Aborting before any actions to ensure safety.');
      process.exit(1);
    } else {
      console.log('[WARN] Remote tag status could not be confirmed with origin.');
    }
  }

  if (npmTagStatus.exists) {
    if (!isDryRun) {
      console.error(`\nFAIL: Git tag ${npmTag} already exists (${npmTagStatus.source}). Refusing release promotion.`);
      process.exit(1);
    } else {
      console.log(`[WARN] Git tag ${npmTag} already exists (${npmTagStatus.source}).`);
    }
  }

  if (hasSkillRelease && skillTagStatus.exists) {
    const reuse = verifyExistingSkillTag(skillTag);
    if (!reuse.ok) {
      console.error(`\nFAIL: ${reuse.reason}`);
      process.exit(1);
    }
    console.log(`✓ ${reuse.reason}`);
  }
  if (!npmTagStatus.exists && (!hasSkillRelease || !skillTagStatus.exists) && npmTagStatus.source !== 'unconfirmed' && (!hasSkillRelease || skillTagStatus.source !== 'unconfirmed')) {
    console.log(hasSkillRelease ? `✓ Release tags ${npmTag} and ${skillTag} do not exist locally or remotely.` : `✓ Release tag ${npmTag} does not exist locally or remotely.`);
  }

  const localHead = getLocalHeadSha();
  if (!localHead) {
    console.error('\nFAIL: Could not determine local HEAD commit SHA.');
    process.exit(1);
  }

  const remoteMaster = getRemoteMasterSha();
  if (remoteMaster && typeof remoteMaster === 'object' && remoteMaster.error) {
    if (!isDryRun) {
      console.error(`\nFAIL: Could not query remote origin/master from origin: ${remoteMaster.error}`);
      console.error('Release promotion requires a verified live connection to origin.');
      process.exit(1);
    } else {
      console.log(`[WARN] Could not query remote origin/master: ${remoteMaster.error}`);
    }
  } else if (!remoteMaster) {
    if (!isDryRun) {
      console.error('\nFAIL: Remote origin/master does not exist on origin.');
      process.exit(1);
    } else {
      console.log('[WARN] Remote origin/master does not exist on origin.');
    }
  } else if (remoteMaster !== localHead) {
    if (!isDryRun) {
      console.error(`\nFAIL: Local HEAD (${localHead}) does not match remote origin/master (${remoteMaster}). Release promotion must run on the exact commit merged and pushed to origin/master.`);
      process.exit(1);
    } else {
      console.log(`[WARN] Local HEAD (${localHead}) does not match remote origin/master (${remoteMaster}).`);
    }
  } else {
    console.log(`✓ Local HEAD matches live remote origin/master (${localHead.slice(0, 12)}).`);
  }

  // 4. Coherence and sync non-drift gate
  console.log('\nStep 5/8: Verifying release surface coherence and non-drift...');
  const checkState = runChecks();
  if (!checkState.allPass) {
    console.error(formatDiagnosticTable(checkState.results));
    console.error('\nFAIL: Release surfaces show drift. Complete release preparation in PR before promotion.');
    process.exit(1);
  }
  console.log('✓ Release surfaces coherent.');

  const drifts = checkSyncNonDrift(skill_v, npm_v);
  if (drifts.length > 0) {
    console.error(`\nFAIL: Synchronization would modify product files: ${drifts.join(', ')}.`);
    console.error('Run "node scripts/sync-release.mjs --sync" and commit in PR before release promotion.');
    process.exit(1);
  }
  console.log('✓ Synchronization non-drift verified (no README or bundled skill modifications).');

  console.log('Verifying committed i18n pair hashes...');
  try {
    execFileSync('bash', ['scripts/check-i18n-pairs.sh', 'verify'], {
      cwd: repoRoot,
      stdio: 'inherit',
    });
    console.log('✓ Committed i18n pair hashes verified against docs/i18n-pairs.txt.');
  } catch (err) {
    console.error('\nFAIL: i18n pair verification failed. Ensure documentation pairs are synchronized and committed in PR.');
    process.exit(err.status ?? 1);
  }

  // 6. GitHub Actions exact-HEAD CI status gate
  console.log(`\nStep 7/8: Verifying GitHub Actions CI status for HEAD (${localHead ? localHead.slice(0, 12) : 'unknown'})...`);
  let ciVerifiedInDryRun = false;
  if (localHead) {
    const ciResult = checkCiStatus(localHead);
    if (!isDryRun) {
      if (!ciResult.ok) {
        console.error(`\nFAIL: GitHub Actions CI verification failed: ${ciResult.reason}`);
        console.error('Release promotion requires a completed, successful "all-checks-passed" CI run on exact HEAD.');
        process.exit(1);
      }
      console.log(`✓ GitHub Actions check "all-checks-passed" verified (status: ${ciResult.check.status}, conclusion: ${ciResult.check.conclusion}).`);
    } else {
      if (ciResult.ok) {
        console.log(`✓ GitHub Actions check "all-checks-passed" verified (status: ${ciResult.check.status}, conclusion: ${ciResult.check.conclusion}).`);
        ciVerifiedInDryRun = true;
      } else {
        console.log(`[WARN] GitHub Actions CI status unverified in dry-run: ${ciResult.reason}`);
        ciVerifiedInDryRun = false;
      }
    }
  }

  // 7. Verification battery (read-only verification of release coherence, doc budgets, and rules)
  console.log('\nStep 8/8: Running verification battery...');
  const battery = [
    { name: 'check-release-coherence', cmd: 'bash', args: ['scripts/check-release-coherence.sh'] },
    { name: 'check-doc-budgets', cmd: 'bash', args: ['scripts/check-doc-budgets.sh'] },
    { name: 'test_doc_budgets', cmd: 'bash', args: ['tests/test_doc_budgets.sh'] },
    { name: 'test_flow_rules', cmd: 'bash', args: ['tests/test_flow_rules.sh'] },
    { name: 'test_release_coherence', cmd: 'bash', args: ['tests/test_release_coherence.sh'] },
  ];
  const dryRunFailures = [];
  for (const step of battery) {
    console.log(`\n>>> Running ${step.name}...`);
    try {
      execFileSync(step.cmd, step.args, {
        cwd: step.cwd ? join(repoRoot, step.cwd) : repoRoot,
        stdio: 'inherit',
        env: isDryRun ? { ...process.env, FLOW_LOG_DISABLE: '1' } : process.env,
      });
      console.log(`✓ ${step.name} PASSED`);
    } catch (err) {
      if (isDryRun) {
        dryRunFailures.push({ name: step.name, status: err.status ?? 1 });
        console.error(`✗ ${step.name} FAILED (exit code ${err.status ?? 1}); continuing dry-run battery.`);
      } else {
        console.error(`\nFAIL: Verification step "${step.name}" failed (exit code ${err.status ?? 1}). Aborting release.`);
        process.exit(err.status ?? 1);
      }
    }
  }

  if (isDryRun && dryRunFailures.length > 0) {
    for (const failure of dryRunFailures) {
      console.error(`FAIL: Verification step "${failure.name}" failed (exit code ${failure.status}).`);
    }
    console.error(`\nFAIL: ${dryRunFailures.length} verification step(s) failed during dry-run battery.`);
    process.exit(1);
  }

  if (isDryRun) {
    const envDryRun = checkNpmPublishEnvironmentPolicy();
    if (envDryRun.ok) console.log('✓ Environment "npm-publish" is restricted to exactly master.');
    else console.log(`[WARN] Environment master-only policy unverified: ${envDryRun.reason}`);
    if (ciVerifiedInDryRun && envDryRun.ok) {
      const publisherRun = dispatchPublisher(localHead, npm_v, true);
      console.log(`✓ Publisher dry-run ${publisherRun.id} completed for ${localHead}; no tags or publish were performed.`);
    } else {
      console.log('\nDRY-RUN SUCCESS: local verification battery passed; publisher dry-run skipped because exact CI or environment policy is unavailable.\n');
    }
    process.exit(0);
  }

  // Immediate pre-tag race recheck
  const preTagRemote = getRemoteMasterSha();
  if (preTagRemote && typeof preTagRemote === 'object' && preTagRemote.error) {
    console.error(`\nFAIL: Could not re-verify remote origin/master: ${preTagRemote.error}`);
    process.exit(1);
  }
  if (preTagRemote !== localHead) {
    console.error(`\nFAIL: Remote origin/master moved from ${localHead} to ${preTagRemote}. Aborting promotion.`);
    process.exit(1);
  }
  const preTagNpmStatus = gitTagExists(npmTag);
  const preTagSkillStatus = hasSkillRelease ? gitTagExists(skillTag) : { exists: false, source: 'not-selected' };
  if (preTagNpmStatus.exists || preTagNpmStatus.source === 'unconfirmed' || (hasSkillRelease && preTagSkillStatus.source === 'unconfirmed')) {
    console.error('\nFAIL: npm tag exists or selected release tag status is unconfirmed. Refusing promotion.');
    process.exit(1);
  }
  if (hasSkillRelease && preTagSkillStatus.exists) {
    const reuse = verifyExistingSkillTag(skillTag);
    if (!reuse.ok) { console.error(`\nFAIL: ${reuse.reason}`); process.exit(1); }
    console.log(`✓ ${reuse.reason}`);
  }

  console.log('\nVerifying exact master-only npm-publish environment policy...');
  const envResult = checkNpmPublishEnvironmentPolicy();
  if (!envResult.ok) { console.error(`\nFAIL: ${envResult.reason}`); process.exit(1); }
  console.log('✓ npm-publish permits exactly branch master.');
  const publisherWorkflow = readFileSync(join(repoRoot, '.github/workflows/publish-npm-wrapper.yml'), 'utf8');
  if (publisherWorkflow.includes('push:\n    tags:') || !publisherWorkflow.includes("vars.FLOW_AUTOPUBLISH_ENABLED == 'true'") || !publisherWorkflow.includes('environment: npm-publish') || !publisherWorkflow.includes('id-token: write')) {
    console.error('\nFAIL: Publisher workflow lacks the no-tag/default-off/environment/OIDC contract.'); process.exit(1);
  }
  console.log('✓ Publisher workflow contract is present (no tag trigger, default-off live latch).');

  const publisherRun = dispatchPublisher(localHead, npm_v, false);
  verifyPublishedRun(publisherRun.id, publisherRun.runAttempt, npm_v, localHead);
  console.log(`✓ Publisher workflow run ${publisherRun.id} completed, registry/provenance verified, and installer smoke passed for ${localHead}.`);

  console.log('\n================================================================================');
  console.log('Tagging Release');
  console.log('================================================================================\n');
  if (hasSkillRelease && preTagSkillStatus.exists) {
    const reuse = verifyExistingSkillTag(skillTag);
    if (!reuse.ok) { console.error(`\nFAIL: ${reuse.reason}`); process.exit(1); }
    console.log(`✓ ${reuse.reason}`);
  }

  const releaseTags = [npmTag];
  console.log(`Creating git tag ${npmTag}...`);
  execFileSync('git', ['tag', npmTag], { cwd: repoRoot, stdio: 'inherit' });
  if (hasSkillRelease && !preTagSkillStatus.exists) {
    releaseTags.push(skillTag);
    console.log(`Creating git tag ${skillTag}...`);
    execFileSync('git', ['tag', skillTag], { cwd: repoRoot, stdio: 'inherit' });
  }
  try {
    execFileSync('git', ['push', '--atomic', 'origin', 'master', ...releaseTags], { cwd: repoRoot, stdio: 'inherit' });
  } catch (err) {
    console.error(`\nFAIL: Atomic push to origin failed (exit code ${err.status ?? 1}).`);
    const remoteStates = releaseTags.map(gitTagExists);
    if (remoteStates.every(state => !state.exists && state.source !== 'unconfirmed')) {
      for (const tag of releaseTags) execFileSync('git', ['tag', '-d', tag], { cwd: repoRoot, stdio: ['ignore', 'pipe', 'ignore'] });
    } else {
      console.error('[WARN] Remote tag state is partial or unconfirmed; preserve local refs and require owner reconciliation.');
    }
    process.exit(err.status ?? 1);
  }
  if (hasSkillRelease && !preTagSkillStatus.exists) {
    let releaseExists = false;
    try {
      const viewOut = execGh(['release', 'view', skillTag, '--json', 'tagName'], { cwd: repoRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
      releaseExists = Boolean(viewOut);
    } catch (err) {
      const stderr = err.stderr ? err.stderr.toString() : '';
      // gh's absent-release diagnostic is exact; API/transport errors must fail closed.
      if (stderr.replace(/\r?\n$/, '') !== 'release not found') throw err;
    }
    if (releaseExists) throw new Error(`GitHub Release ${skillTag} already exists after new skill tag push; stop for owner reconciliation.`);
    execGh(['release', 'create', skillTag, '--title', `v${intent.skill_version}`, '--notes-file', 'CHANGELOG.md'], { cwd: repoRoot, stdio: 'inherit' });
  }

  const tagSummary = hasSkillRelease ? `${npmTag}, ${skillTag}` : npmTag;
  console.log(`
================================================================================
RELEASE SHIP SUCCESSFUL
================================================================================
${hasSkillRelease ? `Skill Product: v${intent.skill_version}\n` : ''}npm Package:   ${npm_v}

Publisher run verified; registry integrity, provenance and installed smoke passed before ref creation.
Pushed to origin:
  Branch: master
  Tags:   ${tagSummary}
================================================================================
`);
}

function main() {
  const args = process.argv.slice(2);
  const isShip = args.includes('--ship');
  const isDryRun = args.includes('--dry-run');
  const isYes = args.includes('--yes') || args.includes('-y');
  const isSync = args.includes('--sync');
  const isInstructions = args.includes('--instructions');
  const isCheck = args.includes('--check') || (!isShip && !isSync && !isInstructions);
  const isHelp = args.includes('--help') || args.includes('-h');

  if (isHelp) {
    console.log(`Usage: node scripts/sync-release.mjs [--check | --sync | --instructions | --ship [--dry-run] [--yes]]

Options:
  --check         Validate release coherence across all versions, manifests, readmes, and changelogs (default)
  --sync          Synchronize documentation tables across README files, trigger npm-wrapper sync, and verify
  --instructions  Print release instructions and tag status for current versions without modifying files
  --ship          Release promotion: verify clean master HEAD, CI status, run battery, tag, and push
  --reconcile     Verify-only with retained package/receipt dirs and exact SHA/run identity; never publishes or repairs refs
  --dry-run       When used with --ship, run full validation checks without modifying files, tagging, or pushing
  --yes, -y       Confirm live tag creation and pushing when executing --ship
  --help          Show this help message
`);
    process.exit(0);
  }

  if (isShip) {
    shipRelease({ isDryRun, isYes });
    return;
  }

  if (isInstructions) {
    const skill_v = getSkillVersion();
    const npm_v = getNpmVersion();
    if (!skill_v) {
      console.error('FAIL: Missing skill version in skills/flow/SKILL.md');
      process.exit(1);
    }
    if (!npm_v) {
      console.error('FAIL: Missing npm version in npm-wrapper/package.json');
      process.exit(1);
    }
    printReleaseInstructions(skill_v, npm_v);
    process.exit(0);
  }
  if (args.includes('--reconcile')) {
    const [packageDirectory, evidenceDirectory, expectedSha, expectedRunId, expectedRunAttempt] = args.slice(args.indexOf('--reconcile') + 1);
    if (!packageDirectory || !evidenceDirectory || !expectedSha || !/^\d+$/.test(expectedRunId || '') || !/^\d+$/.test(expectedRunAttempt || '')) {
      console.error('Usage: node scripts/sync-release.mjs --reconcile <package-artifact-dir> <verification-artifact-dir> <full-sha> <publisher-run-id> <publisher-run-attempt>');
      process.exit(2);
    }
    // The verifier owns its bounded registry retries; do not cut them short here.
    execFileSync(process.execPath, [join(repoRoot, 'scripts/release-workflow.mjs'), 'reconcile', packageDirectory, evidenceDirectory, expectedSha], { cwd: repoRoot, env: { ...process.env, EXPECTED_RUN_ID: expectedRunId, EXPECTED_RUN_ATTEMPT: expectedRunAttempt }, stdio: 'inherit' });
    return;
  }
  if (isSync) {
    const skill_v = getSkillVersion();
    const npm_v = skill_v;
    if (!skill_v) { console.error('FAIL: Missing skill version in skills/flow/SKILL.md'); process.exit(1); }
    if (!npm_v) { console.error('FAIL: Missing npm version in npm-wrapper/package.json'); process.exit(1); }
    syncRelease(skill_v, npm_v);

    console.log('\nRe-running verification check after synchronization:');
    const checkState = runChecks();
    console.log(formatDiagnosticTable(checkState.results));

    if (!checkState.allPass) {
      console.error('\nFAIL: Release surfaces still show drift after synchronization.');
      process.exit(1);
    }

    printReleaseInstructions(skill_v, npm_v);
    console.log('SUCCESS: All release surfaces are synchronized and coherent.\n');
    process.exit(0);
  }

  // Default: --check
  const checkState = runChecks();
  console.log(formatDiagnosticTable(checkState.results));

  if (!checkState.allPass) {
    const failedCount = checkState.results.filter(r => !r.pass).length;
    console.error(`\nFAIL: Release coherence check failed (${failedCount} drift(s) detected).`);
    console.error('Tip: Run "node scripts/sync-release.mjs --sync" to synchronize README tables and npm-wrapper assets.\n');
    process.exit(1);
  }

  console.log(`\nPASS: All release surfaces coherent (skill v${checkState.skill_v}, npm ${checkState.npm_v}).\n`);
  process.exit(0);
}

// Run the CLI only when executed directly (not when imported for helpers/tests).
// Both sides must use realpathSync so symlink aliases (such as macOS /var -> /private/var)
// do not cause a false-negative mismatch between Node's import.meta.url (physical) and
// process.argv[1] (caller spelling). Fall back to pathToFileURL URL compare only if realpath throws.
function isCliEntry() {
  if (!process.argv[1]) return false;
  try {
    const thisPath = realpathSync(fileURLToPath(import.meta.url));
    const entryPath = realpathSync(process.argv[1]);
    return thisPath === entryPath;
  } catch {
    return import.meta.url === pathToFileURL(process.argv[1]).href;
  }
}

if (isCliEntry()) {
  main();
}

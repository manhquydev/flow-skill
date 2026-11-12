import { verifyNpmVerifiedOutput } from './release-provenance.mjs';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseSemver } from '../npm-wrapper/scripts/semver.mjs';

export function artifactTarballPath(packageDirectory, name) {
  if (typeof name !== 'string' || !name.trim() || name === '.' || name === '..' || /[/\\\0]/.test(name)) throw new Error('artifact name must be a non-empty basename');
  return join(packageDirectory, name);
}

export function verifyRunArtifact(packageDirectory, evidenceDirectory, { runId, runAttempt, version, sha }) {
  const metadata = JSON.parse(readFileSync(join(packageDirectory, 'release-artifact.json'), 'utf8'));
  const tarball = artifactTarballPath(packageDirectory, metadata.name);
  const integrity = `sha512-${createHash('sha512').update(readFileSync(tarball)).digest('base64')}`;
  if (metadata.version !== version || metadata.sha !== sha || metadata.integrity !== integrity || String(metadata.workflowRunId) !== String(runId) || Number(metadata.workflowRunAttempt) !== runAttempt) {
    throw new Error('downloaded publisher artifact does not match exact release SHA/version/run attempt');
  }
  const report = JSON.parse(readFileSync(join(evidenceDirectory, 'npm-audit-verified.json'), 'utf8'));
  const verified = verifyNpmVerifiedOutput(report, {
    packageName: '@manhquy/flow-skill', version, integrity,
    repository: 'https://github.com/manhquydev/flow-skill',
    workflowPath: '.github/workflows/publish-npm-wrapper.yml',
    ref: 'refs/heads/master', commit: sha,
  });
  return { tarball, integrity, verified };
}


export const PUBLIC_NPM_REGISTRY = 'https://registry.npmjs.org/';

const registryRetryDelays = [0, 5000, 15000];
const waitForRegistryRetry = delay => { if (delay) Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, delay); };

export function readNpmRegistryJson(spec, fields, { run = spawnSync, wait = waitForRegistryRetry, cwd, platform = process.platform } = {}) {
  let lastError;
  for (const delay of registryRetryDelays) {
    wait(delay);
    const fieldArgs = Array.isArray(fields) ? fields : [fields];
    const result = run('npm', ['view', spec, ...fieldArgs, '--json', `--registry=${PUBLIC_NPM_REGISTRY}`], {
      cwd, encoding: 'utf8', shell: platform === 'win32', timeout: 30000, maxBuffer: 8 * 1024 * 1024,
    });
    if (!result.error && result.status === 0) {
      try { return JSON.parse(result.stdout); }
      catch { throw new Error(`public npm registry returned invalid JSON for ${fieldArgs.join(', ')}`); }
    }
    const text = `${result.stderr || ''} ${result.error?.message || ''} ${result.status ?? ''}`;
    const error = new Error(`public npm registry query failed: ${text.trim()}`);
    if (/\bE404\b|404 Not Found|is not in this registry/i.test(text)) {
      error.code = 'E404';
      throw error;
    }
    if (!/\bE429\b|429 Too Many Requests|\bE5\d\d\b|HTTP 50[0-4]|timed out|ETIMEDOUT|ECONNRESET|ENOTFOUND|EAI_AGAIN/i.test(text)) throw error;
    lastError = error;
  }
  throw new Error(`public npm registry remains unavailable after bounded retries: ${lastError?.message || 'unknown error'}`);
}

export function verifyPostPublishFinalization({ version, integrity, verifyAttestation, smoke, readRegistry }) {
  verifyAttestation();
  smoke();
  return verifyRegistryChannel({ version, integrity, ...readRegistry() });
}
export function verifyRegistryChannel({ version, integrity, versionValue, integrityValue, distTags }) {
  const channel = parseSemver(version)?.prerelease ? 'next' : 'latest';
  if (versionValue !== version) throw new Error('current registry version differs from the retained release version');
  if (integrityValue !== integrity) throw new Error('current registry integrity differs from the retained artifact');
  if (!distTags || typeof distTags !== 'object' || distTags[channel] !== version) throw new Error(`current registry ${channel} channel no longer points to the retained release version`);
  return channel;
}

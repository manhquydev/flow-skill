import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { PUBLIC_NPM_REGISTRY, readNpmRegistryJson, verifyPostPublishFinalization, verifyRegistryChannel, verifyRunArtifact } from '../scripts/release-run-artifact.mjs';
import { reconcile } from '../scripts/release-workflow.mjs';

const sha = 'a'.repeat(40);
const version = '0.7.11';
const integrity = 'sha512-fD3SNLE/ghyfA9SNbxiQfkIfpcTAcrDuPRdgNl942S2WcQfYmS7lbtz6Uj5HbVuzYEqIyhaK24xWvep2CVwS7g==';
const digest = Buffer.from(integrity.slice('sha512-'.length), 'base64').toString('hex');
const statement = {
  predicateType: 'https://slsa.dev/provenance/v1',
  subject: [{ name: `pkg:npm/%40manhquy/flow-skill@${version}`, digest: { sha512: digest } }],
  predicate: { buildDefinition: {
    externalParameters: { workflow: { repository: 'https://github.com/manhquydev/flow-skill', path: '.github/workflows/publish-npm-wrapper.yml', ref: 'refs/heads/master' } },
    resolvedDependencies: [{ digest: { gitCommit: sha } }],
  } },
};
const report = { invalid: [], missing: [], verified: [{ name: '@manhquy/flow-skill', version, registry: 'https://registry.npmjs.org/', attestationBundles: [
  { predicateType: 'https://github.com/npm/attestation/tree/main/specs/publish/v0.1', bundle: { dsseEnvelope: { payloadType: 'application/vnd.in-toto+json', payload: Buffer.from(JSON.stringify({ predicateType: 'https://github.com/npm/attestation/tree/main/specs/publish/v0.1' })).toString('base64'), signatures: [{ sig: 'npm-signature' }] } } },
  { predicateType: 'https://slsa.dev/provenance/v1', bundle: { dsseEnvelope: { payloadType: 'application/vnd.in-toto+json', payload: Buffer.from(JSON.stringify(statement)).toString('base64'), signatures: [{ sig: 'npm-signature' }] } } },
]}] };

function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'flow-run-artifact-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const bytes = Buffer.from('exact published package bytes');
  const name = 'manhquy-flow-skill-0.7.11.tgz';
  const actualIntegrity = `sha512-${createHash('sha512').update(bytes).digest('base64')}`;
  writeFileSync(join(dir, name), bytes);
  writeFileSync(join(dir, 'release-artifact.json'), JSON.stringify({ name, version, sha, integrity: actualIntegrity, workflowRunId: '777', workflowRunAttempt: 2 }));
  writeFileSync(join(dir, 'npm-audit-verified.json'), JSON.stringify(report));
  return dir;
}

test('verifies exact run artifact and target-only npm evidence', t => {
  const dir = fixture(t);
  const metadata = JSON.parse(readFileSync(join(dir, 'release-artifact.json'), 'utf8'));
  const actual = `sha512-${createHash('sha512').update(readFileSync(join(dir, metadata.name))).digest('base64')}`;
  const validStatement = structuredClone(statement);
  validStatement.subject[0].digest.sha512 = Buffer.from(actual.slice('sha512-'.length), 'base64').toString('hex');
  const validReport = structuredClone(report);
  validReport.verified[0].attestationBundles[1].bundle.dsseEnvelope.payload = Buffer.from(JSON.stringify(validStatement)).toString('base64');
  writeFileSync(join(dir, 'npm-audit-verified.json'), JSON.stringify(validReport));
  assert.equal(verifyRunArtifact(dir, dir, { runId: 777, runAttempt: 2, version, sha }).integrity, actual);
});

test('rejects mismatched publisher attempt and source evidence', t => {
  const dir = fixture(t);
  assert.throws(() => verifyRunArtifact(dir, dir, { runId: 777, runAttempt: 1, version, sha }), /run attempt/);
  const invalidReport = structuredClone(report);
  invalidReport.invalid.push({ name: '@manhquy/flow-skill' });
  writeFileSync(join(dir, 'npm-audit-verified.json'), JSON.stringify(invalidReport));
  assert.throws(() => verifyRunArtifact(dir, dir, { runId: 777, runAttempt: 2, version, sha }), /invalid or missing/);
});

test('rejects untrusted artifact paths before reading any tarball', t => {
  const dir = fixture(t);
  const metadataPath = join(dir, 'release-artifact.json');
  const metadata = JSON.parse(readFileSync(metadataPath, 'utf8'));
  for (const name of ['../outside.tgz', '..\\outside.tgz', '/tmp/outside.tgz', 'sub/package.tgz', '', ' ', '.', '..', null, 42, 'bad\0name']) {
    writeFileSync(metadataPath, JSON.stringify({ ...metadata, name }));
    assert.throws(() => verifyRunArtifact(dir, dir, { runId: 777, runAttempt: 2, version, sha }), /non-empty basename/);
  }
});

test('recovery reads intent and manifest at retained SHA and accepts branch release hints only after tag verification', t => {
  const dir = fixture(t);
  const metadata = JSON.parse(readFileSync(join(dir, 'release-artifact.json'), 'utf8'));
  const validReport = structuredClone(report);
  const validStatement = structuredClone(statement);
  validStatement.subject[0].digest.sha512 = Buffer.from(metadata.integrity.slice(7), 'base64').toString('hex');
  validReport.verified[0].attestationBundles[1].bundle.dsseEnvelope.payload = Buffer.from(JSON.stringify(validStatement)).toString('base64');
  writeFileSync(join(dir, 'npm-audit-verified.json'), JSON.stringify(validReport));
  let skillVersion = '0.25.0'; let releaseTag = 'v0.25.0'; let tagSha = sha;
  const skillObject = 'b'.repeat(40); const skillTree = 'd'.repeat(40);
  let skillFailure = null; let skillReads = 0;
  const skillCommands = [];
  const expectedSkillCommands = [
    ['ls-remote', '--tags', 'origin', 'refs/tags/v0.25.0'],
    ['fetch', '--no-tags', '--no-write-fetch-head', 'origin', 'refs/tags/v0.25.0'],
    ['ls-remote', '--tags', 'origin', 'refs/tags/v0.25.0'],
    ['rev-parse', '--verify', `${skillObject}^{commit}:skills`],
    ['rev-parse', '--verify', `${sha}:skills`],
  ];
  const checkedTags = []; const releaseCalls = []; const npmCalls = []; const attestationCalls = [];
  const io = {
    readFileSync,
    git: args => {
      if (args[0] === 'show') {
        if (args[1] === `${sha}:npm-wrapper/package.json`) return JSON.stringify({ name: '@manhquy/flow-skill', version });
        assert.equal(args[1], `${sha}:docs/release-intent.json`);
        return JSON.stringify({ schema_version: 1, intent: true, npm_version: version, skill_version: skillVersion });
      }
      if (args[0] === 'rev-parse' && args[1] !== '--verify') { checkedTags.push(args[1]); return tagSha; }
      if (args[0] === 'ls-remote' && args.length === 5) {
        return `${skillObject}\t${args[3]}\n${tagSha}\t${args[4]}`;
      }
      skillCommands.push(args);
      assert.deepEqual(args, expectedSkillCommands[skillCommands.length - 1]);
      if (args[0] === 'ls-remote') {
        skillReads++;
        if (skillFailure === 'missing') return '';
        return `${skillFailure === 'moved' && skillReads === 2 ? 'c'.repeat(40) : skillObject}\t${args[3]}`;
      }
      if (args[0] === 'fetch') {
        if (skillFailure === 'fetch') throw new Error('fixture fetch unavailable');
        return '';
      }
      if (skillFailure === 'unavailable') throw new Error('fixture tree unavailable');
      return skillFailure === 'different' && args[2] === `${sha}:skills` ? 'e'.repeat(40) : skillTree;
    },
    gh: path => {
      assert.deepEqual(skillCommands, expectedSkillCommands, 'stable origin ref, fetch and equal retained subtree must be verified before accepting branch release hint');
      releaseCalls.push(path);
      return { tag_name: releaseTag, target_commitish: 'master' };
    },
    npmView: (spec, fields) => { npmCalls.push({ spec, fields }); return { present: true, value: fields[0] === 'version' ? version : fields[0] === 'dist.integrity' ? metadata.integrity : { latest: version } }; },
    verifyWithGhAttestation: options => { attestationCalls.push(options); assert.equal(options.sourceSha, sha); return []; },
  };
  reconcile(dir, dir, sha, 777, 2, io);
  assert.deepEqual(npmCalls, [
    { spec: `@manhquy/flow-skill@${version}`, fields: ['version'] },
    { spec: `@manhquy/flow-skill@${version}`, fields: ['dist.integrity'] },
    { spec: '@manhquy/flow-skill', fields: ['dist-tags'] },
  ]);
  assert.equal(attestationCalls.length, 1);
  assert.deepEqual(attestationCalls[0], {
    artifact: join(dir, metadata.name), bundle: join(dir, 'slsa-bundle.json'),
    owner: 'manhquydev', repository: 'flow-skill', workflow: '.github/workflows/publish-npm-wrapper.yml',
    sourceRef: 'refs/heads/master', sourceSha: sha,
  });
  assert.deepEqual(checkedTags, [`npm@${version}^{commit}`]);
  assert.deepEqual(skillCommands, expectedSkillCommands);
  assert.equal(releaseCalls.length, 1);
  releaseTag = 'v9.9.9';
  skillCommands.length = 0; skillReads = 0;
  assert.throws(() => reconcile(dir, dir, sha, 777, 2, io), /Release tag does not match/);
  releaseTag = 'v0.25.0'; tagSha = 'c'.repeat(40);
  assert.throws(() => reconcile(dir, dir, sha, 777, 2, io), /does not resolve exactly/);
  tagSha = sha;
  for (const [failure, message] of [
    ['missing', /remote skill tag unavailable/],
    ['fetch', /fixture fetch unavailable/],
    ['moved', /remote skill tag moved/],
    ['unavailable', /fixture tree unavailable/],
    ['different', /subtree differs/],
  ]) {
    skillFailure = failure; skillReads = 0; skillCommands.length = 0; releaseCalls.length = 0;
    assert.throws(() => reconcile(dir, dir, sha, 777, 2, io), message);
    assert.equal(releaseCalls.length, 0, `${failure} must refuse before reading branch release hints`);
  }
  skillFailure = null;
  tagSha = sha; skillVersion = null; checkedTags.length = 0; releaseCalls.length = 0;
  reconcile(dir, dir, sha, 777, 2, io);
  assert.deepEqual(checkedTags, [`npm@${version}^{commit}`]);
  assert.equal(releaseCalls.length, 0);
});

test('client rejects registry version, integrity or channel changes after publisher run', () => {
  const valid = { version: '1.0.0', integrity: 'sha512-exact', versionValue: '1.0.0', integrityValue: 'sha512-exact', distTags: { latest: '1.0.0' } };
  assert.equal(verifyRegistryChannel(valid), 'latest');
  assert.throws(() => verifyRegistryChannel({ ...valid, distTags: { latest: '1.0.1' } }), /channel no longer points/);
  assert.throws(() => verifyRegistryChannel({ ...valid, versionValue: '1.0.1' }), /registry version differs/);
  assert.throws(() => verifyRegistryChannel({ ...valid, integrityValue: 'sha512-moved' }), /registry integrity differs/);
  const prerelease = { ...valid, version: '1.2.3-rc.1', versionValue: '1.2.3-rc.1', distTags: { latest: '1.0.0', next: '1.2.3-rc.1' } };
  assert.equal(verifyRegistryChannel(prerelease), 'next');
  assert.throws(() => verifyRegistryChannel({ ...prerelease, distTags: { ...prerelease.distTags, next: '1.2.3-rc.2' } }), /channel no longer points/);
});

test('registry reads pin public npm, bound subprocesses and retry transient errors', () => {
  let captured;
  const result = readNpmRegistryJson('@manhquy/flow-skill@1.0.0', 'version', {
    cwd: '/clean/repo',
    platform: 'linux',
    run: (command, args, options) => {
      captured = { command, args, options };
      return { status: 0, stdout: '"1.0.0"\n', stderr: '' };
    },
  });
  assert.equal(result, '1.0.0');
  assert.equal(captured.command, 'npm');
  assert.ok(captured.args.includes(`--registry=${PUBLIC_NPM_REGISTRY}`));
  assert.equal(captured.options.cwd, '/clean/repo');
  assert.equal(captured.options.timeout, 30000);
  assert.throws(() => readNpmRegistryJson('@manhquy/flow-skill', 'dist-tags', {
    run: () => ({ status: 1, stdout: '', stderr: 'E403 Forbidden' }),
  }), /public npm registry query failed/);
  let attempts = 0; const waits = [];
  const retried = readNpmRegistryJson('@manhquy/flow-skill@1.0.0', 'version', {
    wait: delay => waits.push(delay),
    run: () => ++attempts === 1
      ? { status: 1, stdout: '', stderr: 'E503 Service Unavailable' }
      : { status: 0, stdout: '"1.0.0"', stderr: '' },
  });
  assert.equal(retried, '1.0.0');
  assert.equal(attempts, 2);
  assert.deepEqual(waits, [0, 5000]);
  assert.throws(() => readNpmRegistryJson('@manhquy/flow-skill@1.0.0', 'version', {
    wait: () => {}, run: () => ({ status: 1, stderr: 'E404 Not Found' }),
  }), error => error.code === 'E404');

  let exhaustedAttempts = 0; const exhaustedWaits = [];
  assert.throws(() => readNpmRegistryJson('@manhquy/flow-skill@1.0.0', 'version', {
    wait: delay => exhaustedWaits.push(delay),
    run: () => { exhaustedAttempts++; return { status: 1, stderr: 'E503 Service Unavailable' }; },
  }), /remains unavailable after bounded retries/);
  assert.equal(exhaustedAttempts, 3);
  assert.deepEqual(exhaustedWaits, [0, 5000, 15000]);
});

test('post-publish finalization rechecks the registry after attestation and smoke', () => {
  const calls = [];
  const channel = verifyPostPublishFinalization({
    version: '1.2.3-rc.1',
    integrity: 'sha512-exact',
    verifyAttestation: () => calls.push('attestation'),
    smoke: () => calls.push('smoke'),
    readRegistry: () => {
      calls.push('registry');
      return { versionValue: '1.2.3-rc.1', integrityValue: 'sha512-exact', distTags: { latest: '1.0.0', next: '1.2.3-rc.1' } };
    },
  });
  assert.deepEqual(calls, ['attestation', 'smoke', 'registry']);
  assert.equal(channel, 'next');
  calls.length = 0;
  assert.throws(() => verifyPostPublishFinalization({
    version: '1.2.3-rc.1', integrity: 'sha512-exact',
    verifyAttestation: () => calls.push('attestation'),
    smoke: () => calls.push('smoke'),
    readRegistry: () => {
      calls.push('registry');
      return { versionValue: '1.2.3-rc.1', integrityValue: 'sha512-exact', distTags: { latest: '1.0.0', next: '1.2.3-rc.2' } };
    },
  }), /channel no longer points/);
  assert.deepEqual(calls, ['attestation', 'smoke', 'registry']);
});

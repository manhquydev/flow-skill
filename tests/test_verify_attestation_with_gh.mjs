import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyWithGhAttestation } from '../scripts/verify-attestation-with-gh.mjs';

const expected = {
  artifact: '/tmp/package.tgz', bundle: '/tmp/slsa.json', owner: 'manhquydev', repository: 'flow-skill',
  workflow: '.github/workflows/publish-npm-wrapper.yml', sourceRef: 'refs/heads/master', sourceSha: 'a'.repeat(40),
};
const statement = {
  verificationResult: { statement: {
    predicateType: 'https://slsa.dev/provenance/v1',
    predicate: { buildDefinition: { externalParameters: { workflow: {
      repository: 'https://github.com/manhquydev/flow-skill',
      path: '.github/workflows/publish-npm-wrapper.yml', ref: 'refs/heads/master',
    } }, resolvedDependencies: [{ digest: { gitCommit: expected.sourceSha } }] } },
  } },
};
const requiredHelp = '--bundle --digest-alg --repo --signer-workflow --source-ref --source-digest';

test('verifies exact repo, workflow, ref and commit with supported gh', () => {
  const calls = [];
  const run = args => {
    calls.push(args);
    if (args[0] === '--version') return 'gh version 2.68.0 (2026-01-01)';
    if (args.at(-1) === '--help') return requiredHelp;
    assert.deepEqual(args, ['attestation', 'verify', expected.artifact, '--bundle', expected.bundle, '--digest-alg', 'sha512', '--repo', 'manhquydev/flow-skill', '--signer-workflow', 'manhquydev/flow-skill/.github/workflows/publish-npm-wrapper.yml', '--source-ref', expected.sourceRef, '--source-digest', expected.sourceSha, '--format', 'json']);
    return JSON.stringify([statement]);
  };
  assert.deepEqual(verifyWithGhAttestation({ ...expected, run }), [statement]);
  assert.equal(calls.length, 3);
});

test('fails closed on old gh, missing options, empty or mismatched statements', () => {
  assert.throws(() => verifyWithGhAttestation({ ...expected, run: () => 'gh version 2.46.0' }), /gh >=2.68.0/);
  let step = 0;
  assert.throws(() => verifyWithGhAttestation({ ...expected, run: () => ++step === 1 ? 'gh version 2.68.0' : '--bundle' }), /lacks required option/);
  const mismatches = ['repository', 'path', 'ref', 'commit'].map(field => {
    const mismatch = structuredClone(statement);
    const build = mismatch.verificationResult.statement.predicate.buildDefinition;
    if (field === 'commit') build.resolvedDependencies[0].digest.gitCommit = 'b'.repeat(40);
    else build.externalParameters.workflow[field] = 'wrong';
    return JSON.stringify([mismatch]);
  });
  for (const output of ['[]', ...mismatches]) {
    let call = 0;
    const run = args => {
      call += 1;
      if (call === 1) return 'gh version 2.68.0';
      if (call === 2) return requiredHelp;
      return output;
    };
    assert.throws(() => verifyWithGhAttestation({ ...expected, run }));
  }
});

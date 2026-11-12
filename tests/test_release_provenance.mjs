import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyNpmVerifiedOutput } from '../scripts/release-provenance.mjs';
import { verifyTargetAuditOutput, npmAttestationUrl, retryable, waitForSlsaBundle, runTargetAudit, DEFAULT_PROPAGATION_WAITS, DEFAULT_AUDIT_DELAYS } from '../scripts/npm-attestation-audit.mjs';

const expected = { packageName: '@manhquy/flow-skill', version: '0.7.11', integrity: 'sha512-fD3SNLE/ghyfA9SNbxiQfkIfpcTAcrDuPRdgNl942S2WcQfYmS7lbtz6Uj5HbVuzYEqIyhaK24xWvep2CVwS7g==', repository: 'https://github.com/manhquydev/flow-skill', workflowPath: '.github/workflows/publish-npm-wrapper.yml', ref: 'refs/tags/npm@0.7.11', commit: 'e69171c115a0cb120331e489a39c3298711f4204' };
const digest = Buffer.from(expected.integrity.slice('sha512-'.length), 'base64').toString('hex');
const statement = { predicateType: 'https://slsa.dev/provenance/v1', subject: [{ name: 'pkg:npm/%40manhquy/flow-skill@0.7.11', digest: { sha512: digest } }], predicate: { buildDefinition: { externalParameters: { workflow: { repository: expected.repository, path: expected.workflowPath, ref: expected.ref } }, resolvedDependencies: [{ digest: { gitCommit: expected.commit } }] } } };
const report = { invalid: [], missing: [], verified: [{ name: expected.packageName, version: expected.version, registry: 'https://registry.npmjs.org/', attestationBundles: [{ predicateType: 'https://github.com/npm/attestation/tree/main/specs/publish/v0.1', bundle: { dsseEnvelope: { payloadType: 'application/vnd.in-toto+json', payload: Buffer.from(JSON.stringify({ predicateType: 'https://github.com/npm/attestation/tree/main/specs/publish/v0.1' })).toString('base64'), signatures: [{ sig: 'npm-verified-signature' }] } } }, { predicateType: 'https://slsa.dev/provenance/v1', bundle: { dsseEnvelope: { payloadType: 'application/vnd.in-toto+json', payload: Buffer.from(JSON.stringify(statement)).toString('base64'), signatures: [{ sig: 'npm-verified-signature' }] } } }] }] };

test('checks source and digest policy after npm signature verification', () => {
  assert.equal(verifyNpmVerifiedOutput(report, expected).commit, expected.commit);
  assert.equal(verifyTargetAuditOutput(report, expected).workflowPath, expected.workflowPath);
});

test('rejects invalid/missing signatures and every source/digest mismatch', () => {
  for (const field of ['repo', 'workflow', 'ref', 'commit', 'digest']) {
    const bad = structuredClone(report);
    const payload = JSON.parse(Buffer.from(bad.verified[0].attestationBundles[1].bundle.dsseEnvelope.payload, 'base64'));
    if (field === 'repo') payload.predicate.buildDefinition.externalParameters.workflow.repository = 'https://github.com/evil/repo';
    if (field === 'workflow') payload.predicate.buildDefinition.externalParameters.workflow.path = '.github/workflows/other.yml';
    if (field === 'ref') payload.predicate.buildDefinition.externalParameters.workflow.ref = 'refs/heads/other';
    if (field === 'commit') payload.predicate.buildDefinition.resolvedDependencies[0].digest.gitCommit = '1111111111111111111111111111111111111111';
    if (field === 'digest') payload.subject[0].digest.sha512 = '00'.repeat(64);
    bad.verified[0].attestationBundles[1].bundle.dsseEnvelope.payload = Buffer.from(JSON.stringify(payload)).toString('base64');
    if (field === 'repo' || field === 'workflow' || field === 'ref' || field === 'commit' || field === 'digest') assert.throws(() => verifyNpmVerifiedOutput(bad, expected));
  }
  for (const field of ['invalid', 'missing']) {
    const badSignatureReport = structuredClone(report); badSignatureReport[field].push({ name: expected.packageName });
    assert.throws(() => verifyNpmVerifiedOutput(badSignatureReport, expected), /invalid or missing/);
  }
});

test('scoped npm attestation URL keeps scope marker literal and encodes separator once', () => {
  assert.equal(npmAttestationUrl('@manhquy/flow-skill', '0.8.0'), 'https://registry.npmjs.org/-/npm/v1/attestations/@manhquy%2fflow-skill@0.8.0');
  assert.equal(npmAttestationUrl('left-pad', '1.3.0'), 'https://registry.npmjs.org/-/npm/v1/attestations/left-pad@1.3.0');
});

test('rejects relabelled or duplicated signed SLSA as npm publish attestation', () => {
  for (const duplicate of [false, true]) {
    const bad = structuredClone(report);
    if (duplicate) {
      bad.verified[0].attestationBundles.push(structuredClone(bad.verified[0].attestationBundles[1]));
    } else {
      const relabelled = structuredClone(bad.verified[0].attestationBundles[1]);
      relabelled.predicateType = bad.verified[0].attestationBundles[0].predicateType;
      bad.verified[0].attestationBundles[0] = relabelled;
    }
    assert.throws(() => verifyNpmVerifiedOutput(bad, expected), /expected exactly one verified npm publish attestation/);
  }
});

test('propagation exhaustion stays below eleven minutes including requests and is never retried by audit', () => {
  let requests = 0; let audits = 0; const waits = []; const requestTimeouts = [];
  assert.throws(() => runTargetAudit(expected, {
    waitForBundle: options => waitForSlsaBundle(options, {
      run: (command, args) => {
        requests++;
        assert.equal(command, 'curl');
        assert.equal(args.filter(arg => arg === '--max-time').length, 1);
        const timeout = args[args.indexOf('--max-time') + 1];
        assert.equal(timeout, '5', `request ${requests} must cap total HTTP time at 5s`);
        requestTimeouts.push(Number(timeout) * 1000);
        return '{}\n404';
      }, wait: delay => waits.push(delay),
    }),
    audit: () => { audits++; }, wait: () => assert.fail('outer retry must not run'),
  }), /bounded propagation retries \(last HTTP 404\)/);
  assert.equal(requests, 22);
  assert.equal(audits, 0);
  assert.equal(waits.reduce((sum, delay) => sum + delay, 0), 540000);
  assert.deepEqual(waits, DEFAULT_PROPAGATION_WAITS);
  assert.equal(requestTimeouts.length, 22);
  const propagationBoundMs = waits.reduce((sum, delay) => sum + delay, 0)
    + requestTimeouts.reduce((sum, timeout) => sum + timeout, 0);
  assert.equal(propagationBoundMs, 650000);
  assert.ok(propagationBoundMs <= 11 * 60000, 'waits plus HTTP time must fit within eleven minutes');
  assert.ok(20 * 60000 - propagationBoundMs >= 9 * 60000, 'propagation must leave at least nine minutes of nominal headroom, excluding other steps sharing the job budget');
});

test('simulates repeated HTTP 404 then valid SLSA response after >120s simulated time', () => {
  let requests = 0; const waits = [];
  waitForSlsaBundle(expected, {
    run: () => {
      requests++;
      // First 8 attempts (cumulative wait reaches 120s): registry returns HTTP 404
      if (requests <= 8) return '{}\n404';
      // Attempt 9 (cumulative wait reaches 150s > 120s): returns 200 but WITHOUT SLSA bundle
      if (requests === 9) {
        return JSON.stringify({
          attestations: [{ predicateType: 'https://github.com/npm/attestation/tree/main/specs/publish/v0.1', bundle: {} }],
        }) + '\n200';
      }
      // Attempt 10 (cumulative wait reaches 180s > 120s): returns valid SLSA bundle
      return JSON.stringify({
        attestations: [{ predicateType: statement.predicateType, bundle: { dsseEnvelope: {} } }],
      }) + '\n200';
    },
    wait: delay => waits.push(delay),
  });
  assert.equal(requests, 10);
  const totalSimulatedMs = waits.reduce((sum, delay) => sum + delay, 0);
  assert.equal(totalSimulatedMs, 180000);
  assert.ok(totalSimulatedMs > 120000, 'simulated wait must exceed 120s before valid matching bundle');
});

test('permanent 4xx fails immediately without retrying in propagation and audit', () => {
  for (const status of [400, 401, 403, 405, 410]) {
    let requests = 0;
    assert.throws(
      () => waitForSlsaBundle(expected, { wait: () => {}, run: () => { requests++; return `{}\n${status}`; } }),
      new RegExp(`npm attestation endpoint failed non-retryably: HTTP ${status}`)
    );
    assert.equal(requests, 1, `HTTP ${status} must fail on attempt 1 without retry`);
  }
  for (const text of ['E403', 'invalid signature', 'identity/integrity mismatch']) {
    let attempts = 0;
    assert.throws(
      () => runTargetAudit(expected, { waitForBundle: () => {}, wait: () => {}, audit: () => { attempts++; throw new Error(text); } }),
      new RegExp(text)
    );
    assert.equal(attempts, 1, `${text} must fail on attempt 1 without retry`);
  }
});

test('transient network/429/5xx errors in propagation remain retryable until success', () => {
  for (const status of [429, 500, 502, 503, 504]) {
    let requests = 0;
    waitForSlsaBundle(expected, {
      wait: () => {},
      run: () => {
        if (++requests === 1) return `{}\n${status}`;
        return JSON.stringify({ attestations: [{ predicateType: statement.predicateType, bundle: {} }] }) + '\n200';
      },
    });
    assert.equal(requests, 2, `HTTP ${status} in propagation must retry and succeed`);
  }
  for (const text of ['curl: (28) Operation timed out', 'curl: (56) Recv failure', 'ETIMEDOUT', 'ECONNRESET']) {
    let requests = 0;
    waitForSlsaBundle(expected, {
      wait: () => {},
      run: () => {
        if (++requests === 1) throw new Error(text);
        return JSON.stringify({ attestations: [{ predicateType: statement.predicateType, bundle: {} }] }) + '\n200';
      },
    });
    assert.equal(requests, 2, `${text} in propagation must retry and succeed`);
  }
});

test('transient audit failures retry while permanent failures fail closed and outer audit is separately bounded', () => {
  for (const text of ['E500', 'E501', 'E502', 'E503', 'E504', 'ETIMEDOUT', 'ESOCKETTIMEDOUT', 'ECONNRESET', 'EAI_AGAIN']) {
    assert.equal(retryable(new Error(text)), true, text);
    let attempts = 0;
    assert.deepEqual(runTargetAudit(expected, {
      waitForBundle: () => {},
      wait: () => {},
      audit: () => {
        if (++attempts === 1) throw new Error(text);
        return { report: {} };
      },
    }), { report: {} });
    assert.equal(attempts, 2);
  }

  // Outer audit retry exhaustion is bounded to 9 attempts (120s), and waitForBundle is called exactly once
  let bundleCalls = 0;
  let auditCalls = 0;
  const auditWaits = [];
  assert.throws(
    () => runTargetAudit(expected, {
      waitForBundle: () => { bundleCalls++; },
      audit: () => { auditCalls++; throw new Error('E503 Service Unavailable'); },
      wait: delay => auditWaits.push(delay),
    }),
    /E503 Service Unavailable/
  );
  assert.equal(bundleCalls, 1, 'waitForBundle must be called exactly once (no unbounded outer nesting)');
  assert.equal(auditCalls, 9, 'outer audit retry must be bounded to 9 attempts');
  assert.equal(auditWaits.reduce((sum, delay) => sum + delay, 0), 120000, 'outer audit wait must be bounded to 120s');
  assert.deepEqual(auditWaits, DEFAULT_AUDIT_DELAYS);
});

test('custom waits and delays can be injected into propagation and audit', () => {
  let requests = 0; const customWaits = [0, 50, 100]; const recordedWaits = [];
  assert.throws(() => waitForSlsaBundle(expected, {
    waits: customWaits,
    run: () => { requests++; return '{}\n404'; },
    wait: delay => recordedWaits.push(delay),
  }), /bounded propagation retries/);
  assert.equal(requests, 3);
  assert.deepEqual(recordedWaits, customWaits);

  let audits = 0; const customDelays = [0, 25]; const recordedDelays = [];
  assert.throws(() => runTargetAudit(expected, {
    waitForBundle: () => {},
    delays: customDelays,
    audit: () => { audits++; throw new Error('E500'); },
    wait: delay => recordedDelays.push(delay),
  }), /E500/);
  assert.equal(audits, 2);
  assert.deepEqual(recordedDelays, customDelays);
});

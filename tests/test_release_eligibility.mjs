import { checkRequest, npmView, verifyExistingTag, RELEASE_CONSTANTS, requireUnpublishedVersion, selectChannelBaseline, selectAuthoritativeJob, selectAuthoritativeRun, selectMergedMasterPr } from '../scripts/release-workflow.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { compareVersions, evaluateRelease } from '../scripts/release-eligibility.mjs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

test('skill reconciliation checks stable origin content against retained revision', async () => {
  const { verifyExistingSkillTag } = await import('../scripts/release-workflow.mjs');
  const object = 'a'.repeat(40);
  const run = (different = false, missing = false, moved = false) => {
    let reads = 0;
    return args => {
      if (args[0] === 'ls-remote') return missing ? '' : `${moved && reads++ ? 'b'.repeat(40) : object}\trefs/tags/v1.0.0`;
      if (args[0] === 'fetch') return '';
      if (args[0] === 'rev-parse') {
        assert.ok(!args.at(-1).startsWith('HEAD'));
        return args.at(-1) === 'retained:skills' && different ? 'different' : 'same-tree';
      }
      assert.fail(`unexpected git command ${args}`);
    };
  };
  assert.doesNotThrow(() => verifyExistingSkillTag('v1.0.0', 'retained', run()));
  assert.throws(() => verifyExistingSkillTag('v1.0.0', 'retained', run(true)), /subtree differs/);
  assert.throws(() => verifyExistingSkillTag('v1.0.0', 'retained', run(false, true)), /unavailable/);
  assert.throws(() => verifyExistingSkillTag('v1.0.0', 'retained', run(false, false, true)), /moved/);
});
const base = () => ({
  mode: 'workflow_run', phase: 'eligibility',
  expected: { workflowId: 123, workflowPath: '.github/workflows/ci.yml', publisherWorkflowPath: '.github/workflows/publish-npm-wrapper.yml', masterSha: 'abc123', repository: 'owner/repo' },
  run: { workflowId: 123, workflowPath: '.github/workflows/ci.yml', event: 'push', branch: 'master', conclusion: 'success', id: 88, attempt: 2, latestAttempt: 2, headSha: 'abc123', authoritativeJob: { name: 'all-checks-passed', app: 'github-actions', conclusion: 'success' } },
  pullRequest: { merged: true, baseRepo: 'owner/repo', baseBranch: 'master', headSha: 'abc123' },
  release: { intent: true, npmVersion: '0.8.0', skillVersion: '0.8.0', channel: 'latest', npmChangelog: true, skillChangelog: true },
  artifact: { integrity: 'sha512-test', commit: 'abc123', workflowRunId: 88, workflowRunAttempt: 2 },
  registry: { state: 'absent', error: 'E404', channelVersion: '0.7.11' },
  currentMasterSha: 'abc123', autopublishEnabled: true,
});

test('returns eligible only for exact current successful CI, PR and release intent', () => {
  assert.equal(evaluateRelease(base()).decision, 'eligible');
});

test('manual dispatch is always dry-run and never eligible for publishing', () => {
  assert.equal(evaluateRelease({ mode: 'dispatch', dispatchMode: 'dry-run' }).decision, 'dry-run');
  assert.equal(evaluateRelease({ mode: 'dispatch', dispatchMode: 'publish' }).decision, 'refuse');
});

test('rejects wrong workflow/event/branch, stale master, old attempt, and failed authoritative job', () => {
  for (const mutate of [s => { s.run.workflowId = 999; }, s => { s.run.event = 'pull_request'; }, s => { s.run.branch = 'feature'; }, s => { s.expected.masterSha = 'newsha'; }, s => { s.run.latestAttempt = 3; }, s => { s.run.authoritativeJob.conclusion = 'failure'; }]) {
    const snapshot = base(); mutate(snapshot); assert.equal(evaluateRelease(snapshot).decision, 'refuse');
  }
});

test('requires merged PR targeting this repository master and same SHA', () => {
  for (const field of ['merged', 'baseRepo', 'baseBranch', 'headSha']) {
    const snapshot = base(); snapshot.pullRequest[field] = field === 'merged' ? false : 'wrong';
    assert.equal(evaluateRelease(snapshot).decision, 'refuse');
  }
});

test('no committed release intent is a no-op; malformed dual-axis intent refuses', () => {
  const absent = base(); absent.release.intent = false;
  assert.equal(evaluateRelease(absent).decision, 'noop-no-release-intent');
  for (const bad of [{ ...base().release, channel: 'next' }, { ...base().release, npmChangelog: false }, { ...base().release, skillChangelog: false }]) {
    const snapshot = base(); snapshot.release = bad; assert.equal(evaluateRelease(snapshot).decision, 'refuse');
  }
});

test('fails closed on unknown registry, non-E404 absence, and API errors', () => {
  for (const registry of [null, { state: 'absent', error: 'E403' }, { state: 'unknown', error: 'timeout' }]) {
    const snapshot = base(); snapshot.registry = registry; assert.equal(evaluateRelease(snapshot).decision, 'refuse');
  }
});

test('requires artifact identity bound to exact publisher run at publish boundary', () => {
  for (const field of ['commit', 'workflowRunId', 'workflowRunAttempt', 'integrity']) {
    const snapshot = base();
    snapshot.phase = 'publish';
    snapshot.publisherRunId = 9001;
    snapshot.publisherRunAttempt = 2;
    snapshot.artifact = { integrity: 'sha512-test', commit: 'abc123', workflowRunId: 9001, workflowRunAttempt: 2 };
    snapshot.prepublishMasterSha = 'abc123';
    snapshot.prepublishRegistryState = 'absent';
    snapshot.artifact[field] = field === 'integrity' ? '' : -1;
    assert.equal(evaluateRelease(snapshot).decision, 'refuse');
  }
  const good = base();
  good.phase = 'publish';
  good.publisherRunId = 9001;
  good.publisherRunAttempt = 2;
  good.artifact = { integrity: 'sha512-test', commit: 'abc123', workflowRunId: 9001, workflowRunAttempt: 2 };
  good.prepublishMasterSha = 'abc123';
  good.prepublishRegistryState = 'absent';
  assert.equal(evaluateRelease(good).decision, 'publish');
});

test('publish artifact run ID and attempt must match exact publisher attempt', () => {
  const snapshot = base();
  snapshot.phase = 'publish';
  snapshot.publisherRunId = 9001;
  snapshot.publisherRunAttempt = 3;
  snapshot.artifact = { integrity: 'sha512-test', commit: 'abc123', workflowRunId: 9001, workflowRunAttempt: 3 };
  snapshot.prepublishMasterSha = 'abc123';
  snapshot.prepublishRegistryState = 'absent';
  assert.equal(evaluateRelease(snapshot).decision, 'publish');
  snapshot.artifact.workflowRunId = '9001';
  assert.equal(evaluateRelease(snapshot).decision, 'refuse');
  snapshot.artifact.workflowRunId = 9001;
  snapshot.artifact.workflowRunAttempt = 2;
  assert.equal(evaluateRelease(snapshot).decision, 'refuse');
});

test('existing versions reconcile only in verify-only mode and exact identity', () => {
  const existing = base(); existing.phase = 'reconcile';
  existing.artifact = { integrity: 'sha512-test' };
  existing.reconciliation = { verified: true, expectedSha: 'abc123' };
  existing.registry = { state: 'present', integrity: 'sha512-test', channel: 'latest', tagTarget: 'abc123', releaseTarget: 'abc123', provenance: { repository: 'owner/repo', workflowPath: '.github/workflows/publish-npm-wrapper.yml', commit: 'abc123', integrity: 'sha512-test' } };
  assert.equal(evaluateRelease(existing).decision, 'already-published-exact-match');
  for (const key of ['integrity', 'channel', 'tagTarget', 'releaseTarget']) {
    const bad = structuredClone(existing); bad.registry[key] = 'wrong'; assert.equal(evaluateRelease(bad).decision, 'refuse');
  }
  const badProv = structuredClone(existing); badProv.registry.provenance.workflowPath = '.github/workflows/ci.yml';
  assert.equal(evaluateRelease(badProv).decision, 'refuse');
  const unauthorized = structuredClone(existing); unauthorized.phase = 'eligibility';
  assert.equal(evaluateRelease(unauthorized).decision, 'refuse');
  const noVerification = structuredClone(existing); noVerification.reconciliation.verified = false;
  assert.equal(evaluateRelease(noVerification).decision, 'refuse');
});

test('refuses downgrade, master movement, registry race and disabled publishing', () => {
  for (const mutate of [s => { s.release.npmVersion = '0.7.10'; }, s => { s.currentMasterSha = 'newsha'; }, s => { s.autopublishEnabled = false; }, s => { s.registry.channelVersion = '0.9.0'; }]) {
    const snapshot = base(); mutate(snapshot); assert.equal(evaluateRelease(snapshot).decision, 'refuse');
  }
  const race = base(); race.phase = 'publish'; race.prepublishMasterSha = 'newsha'; race.prepublishRegistryState = 'absent';
  assert.equal(evaluateRelease(race).decision, 'refuse');
});

test('uses audited strict SemVer precedence, including numeric precision and hyphenated prerelease IDs', () => {
  for (const [left, right] of [['1.0.0', '1.0.0-rc.9'], ['1.0.0-rc.10', '1.0.0-rc.9'], ['1.0.0-alpha-beta.1', '1.0.0-alpha-beta'], ['9007199254740993.0.0', '9007199254740992.0.0']]) {
    assert.equal(compareVersions(left, right), 1);
  }
  assert.equal(compareVersions('1.0.0-01', '1.0.0-1'), null);
});

test('selects exact real GitHub workflow-run, completed job, and merged PR response shapes', () => {
  const run = { id: 88, workflow_id: RELEASE_CONSTANTS.ciWorkflowId, path: RELEASE_CONSTANTS.ciWorkflowPath, head_sha: 'abc', head_branch: 'master', event: 'push', run_attempt: 2 };
  assert.deepEqual(selectAuthoritativeRun([run, { ...run, id: 89, head_sha: 'other' }], 'abc'), run);
  const jobs = [{ name: 'bash-suite (ubuntu-latest)', run_id: 88, run_attempt: 2, status: 'completed', conclusion: 'success' }, { name: 'all-checks-passed', run_id: 88, run_attempt: 2, status: 'completed', conclusion: 'success' }];
  assert.deepEqual(selectAuthoritativeJob(jobs, run), jobs[1]);
  const prs = [{ merged_at: '2026-10-19T00:00:00Z', merge_commit_sha: 'abc', base: { ref: 'master', repo: { full_name: 'owner/repo' } } }];
  assert.deepEqual(selectMergedMasterPr(prs, 'abc', 'owner/repo'), prs[0]);
});

test('rejects wrong workflow/path/SHA, old attempts, duplicate checks, and wrong PR base', () => {
  const run = { id: 88, workflow_id: RELEASE_CONSTANTS.ciWorkflowId, path: RELEASE_CONSTANTS.ciWorkflowPath, head_sha: 'abc', head_branch: 'master', event: 'push', run_attempt: 3 };
  assert.equal(selectAuthoritativeRun([{ ...run, path: '.github/workflows/old.yml' }], 'abc'), null);
  assert.equal(selectAuthoritativeJob([{ name: 'all-checks-passed', run_id: 88, run_attempt: 2, status: 'completed', conclusion: 'success' }], run), null);
  const check = { name: 'all-checks-passed', run_id: 88, run_attempt: 3, status: 'completed', conclusion: 'success' };
  assert.equal(selectAuthoritativeJob([check, check], run), null);
  assert.equal(selectMergedMasterPr([{ merged_at: 'yes', merge_commit_sha: 'abc', base: { ref: 'other', repo: { full_name: 'owner/repo' } } }], 'abc', 'owner/repo'), null);
});

test('exact registry version must be absent by explicit E404; existing immutable versions block eligibility', () => {
  assert.equal(requireUnpublishedVersion('0.8.0', () => ({ present: false, error: 'E404' })), undefined);
  assert.throws(() => requireUnpublishedVersion('0.8.0', () => ({ present: true, value: '0.8.0' })), /already exists.*Never republish/);
  for (const result of [{ present: false, error: 'E403' }, { present: false, error: 'timeout' }, { present: false }]) {
    assert.throws(() => requireUnpublishedVersion('0.8.0', () => result), /not proven by E404/);
  }
});

test('initial prereleases compare against latest until next exists, then use next', () => {
  assert.equal(selectChannelBaseline('next', { latest: '0.7.11' }), '0.7.11');
  assert.equal(selectChannelBaseline('next', { latest: '0.7.11', next: '0.8.0-beta.1' }), '0.8.0-beta.1');
  assert.equal(selectChannelBaseline('latest', { latest: '0.7.11', next: '0.9.0-beta.1' }), '0.7.11');
  assert.equal(selectChannelBaseline('next', {}), null);
});

test('publish phase binds exact artifact to publisher run, separate from CI run', () => {
  const snapshot = base();
  snapshot.phase = 'publish';
  snapshot.publisherRunId = 9001;
  snapshot.publisherRunAttempt = 3;
  snapshot.artifact = { integrity: 'sha512-test', commit: 'abc123', workflowRunId: 9001, workflowRunAttempt: 3 };
  snapshot.prepublishMasterSha = 'abc123';
  snapshot.prepublishRegistryState = 'absent';
  assert.equal(evaluateRelease(snapshot).decision, 'publish');
  snapshot.artifact.workflowRunId = '9001';
  assert.equal(evaluateRelease(snapshot).decision, 'refuse');
  snapshot.artifact.workflowRunId = 9001;
  snapshot.artifact.workflowRunAttempt = 2;
  assert.equal(evaluateRelease(snapshot).decision, 'refuse');
});

test('new intent requires matching present versions; legacy null remains readable in reconciliation', () => {
  const snapshot = base();
  snapshot.release.skillVersion = null;
  snapshot.release.skillChangelog = false;
  assert.equal(evaluateRelease(snapshot).reason, 'invalid-unified-release-intent');
  snapshot.phase = 'reconcile';
  assert.notEqual(evaluateRelease(snapshot).reason, 'invalid-unified-release-intent');
  snapshot.release.skillVersion = '9.9.9';
  assert.equal(evaluateRelease(snapshot).reason, 'invalid-unified-release-intent');
});

test('workflow publish snapshot forwards the observed prepublish registry state', t => {
  const oldEnv = { ...process.env };
  t.after(() => { process.env = oldEnv; });
  Object.assign(process.env, { GITHUB_REF: 'refs/heads/master', ACTOR_ID: '7', EXPECTED_ACTOR_ID: '7', FLOW_AUTOPUBLISH_ENABLED: 'true', DISPATCH_ID: '12345678-1234-1234-1234-123456789abc' });
  delete process.env.GITHUB_OUTPUT;
  const sha = 'a'.repeat(40); const version = '0.8.0';
  process.env.GITHUB_SHA = sha;
  const repository = process.env.GITHUB_REPOSITORY || RELEASE_CONSTANTS.repository;
  const run = { id: 88, workflow_id: RELEASE_CONSTANTS.ciWorkflowId, path: RELEASE_CONSTANTS.ciWorkflowPath, head_sha: sha, head_branch: 'master', event: 'push', run_attempt: 2, status: 'completed', conclusion: 'success' };
  const io = {
    gh: path => {
      if (path.endsWith('/git/ref/heads/master')) return { object: { sha } };
      if (path.includes('/pulls?')) return [{ merged_at: 'today', merge_commit_sha: sha, base: { ref: 'master', repo: { full_name: repository } } }];
      if (path.includes('/runs?')) return { total_count: 1, workflow_runs: [run] };
      if (path.includes('/jobs?')) return { total_count: 1, jobs: [{ name: 'all-checks-passed', run_id: 88, run_attempt: 2, status: 'completed', conclusion: 'success' }] };
      if (path.endsWith('/runs/88')) return run;
      assert.fail(`unexpected API ${path}`);
    },
    git: args => { assert.deepEqual(args, ['rev-parse', 'HEAD']); return sha; },
    pkg: () => ({ name: RELEASE_CONSTANTS.package, version }), skillVersion: () => version, changelogHeading: () => true,
    readFileSync: () => JSON.stringify({ schema_version: 1, intent: true, npm_version: version, skill_version: version, channel: 'latest', compatibility: 'backwards-compatible', security_rights_expanded: false }),
    npmView: (_spec, fields) => fields[0] === 'dist-tags' ? { present: true, value: { latest: '0.7.11' } } : { present: false, error: 'E404' },
  };
  const request = { mode: 'publish', phase: 'publish', sha, version, publisherRunId: 9001, publisherRunAttempt: 2, artifact: { integrity: 'sha512-test', commit: sha, workflowRunId: 9001, workflowRunAttempt: 2 }, prepublishMasterSha: sha, prepublishRegistry: { state: 'absent', error: 'E404', channelVersion: '0.7.11' } };
  assert.equal(checkRequest(request, io).decision, 'publish');
  let untrustedBoundaryCalls = 0;
  process.env.GITHUB_SHA = 'b'.repeat(40);
  const untrustedIo = Object.fromEntries(Object.entries(io).map(([key, value]) => [key, (...args) => { untrustedBoundaryCalls++; return value(...args); }]));
  assert.throws(() => checkRequest(request, untrustedIo), /trusted workflow-selected commit/);
  assert.equal(untrustedBoundaryCalls, 0);
  process.env.GITHUB_SHA = sha;
  for (const dispatchId of ['', '-'.repeat(36), 'a'.repeat(36), 'not-a-uuid']) {
    process.env.DISPATCH_ID = dispatchId;
    assert.throws(() => checkRequest(request, untrustedIo), /dispatch correlation ID must be a UUID/);
  }
  assert.equal(untrustedBoundaryCalls, 0);
  process.env.DISPATCH_ID = '12345678-1234-1234-1234-123456789abc';
  process.env.EXPECTED_ACTOR_ID = '8';
  assert.throws(() => checkRequest(request, untrustedIo), /actor ID/);
  assert.equal(untrustedBoundaryCalls, 0);
  process.env.EXPECTED_ACTOR_ID = '7';
  assert.throws(() => checkRequest({ ...request, prepublishRegistry: null }, io), /prepublish-state-changed/);
  assert.throws(() => checkRequest({ ...request, prepublishRegistry: { state: 'unknown' } }, io), /release refused/);
});

test('breaking release intent requires a committed owner decision record and proceeds with a valid one', t => {
  const oldEnv = { ...process.env };
  t.after(() => { process.env = oldEnv; });
  Object.assign(process.env, { GITHUB_REF: 'refs/heads/master', ACTOR_ID: '7', EXPECTED_ACTOR_ID: '7', FLOW_AUTOPUBLISH_ENABLED: 'true', DISPATCH_ID: '12345678-1234-1234-1234-123456789abc' });
  delete process.env.GITHUB_OUTPUT;
  const sha = 'a'.repeat(40); const version = '0.8.0';
  process.env.GITHUB_SHA = sha;
  const repository = process.env.GITHUB_REPOSITORY || RELEASE_CONSTANTS.repository;
  const run = { id: 88, workflow_id: RELEASE_CONSTANTS.ciWorkflowId, path: RELEASE_CONSTANTS.ciWorkflowPath, head_sha: sha, head_branch: 'master', event: 'push', run_attempt: 2, status: 'completed', conclusion: 'success' };
  const breakingIntent = JSON.stringify({ schema_version: 1, intent: true, npm_version: version, skill_version: version, channel: 'latest', compatibility: 'breaking', security_rights_expanded: false });
  const validAuth = JSON.stringify({ schema_version: 1, authorized_by: 'owner', decision: 'v1 breaking axes authorized', decision_record: 'docs/release-owner-decision-v1.md', authorized_versions: { npm: version, skill: version }, compatibility: 'breaking', security_rights_expanded: false, acceptance_evidence: ['https://github.com/manhquydev/flow-skill/pull/87'] });
  const makeIo = authBody => ({
    gh: path => {
      if (path.endsWith('/git/ref/heads/master')) return { object: { sha } };
      if (path.includes('/pulls?')) return [{ merged_at: 'today', merge_commit_sha: sha, base: { ref: 'master', repo: { full_name: repository } } }];
      if (path.includes('/runs?')) return { total_count: 1, workflow_runs: [run] };
      if (path.includes('/jobs?')) return { total_count: 1, jobs: [{ name: 'all-checks-passed', run_id: 88, run_attempt: 2, status: 'completed', conclusion: 'success' }] };
      if (path.endsWith('/runs/88')) return run;
      assert.fail(`unexpected API ${path}`);
    },
    git: args => { assert.deepEqual(args, ['rev-parse', 'HEAD']); return sha; },
    pkg: () => ({ name: RELEASE_CONSTANTS.package, version }), skillVersion: () => version, changelogHeading: () => true,
    readFileSync: path => {
      const normalized = String(path).replaceAll('\\', '/');
      if (normalized.endsWith('docs/release-intent.json')) return breakingIntent;
      if (normalized.endsWith('docs/release-owner-authorization.json')) { if (authBody === null) throw new Error('ENOENT'); return authBody; }
      if (normalized.endsWith('docs/release-owner-decision-v1.md')) return '# Accepted v1 outcome contract';
      assert.fail(`unexpected read ${path}`);
    },
    npmView: (_spec, fields) => fields[0] === 'dist-tags' ? { present: true, value: { latest: '0.7.11' } } : { present: false, error: 'E404' },
  });
  const request = { mode: 'publish', phase: 'publish', sha, version, publisherRunId: 9001, publisherRunAttempt: 2, artifact: { integrity: 'sha512-test', commit: sha, workflowRunId: 9001, workflowRunAttempt: 2 }, prepublishMasterSha: sha, prepublishRegistry: { state: 'absent', error: 'E404', channelVersion: '0.7.11' } };
  assert.throws(() => checkRequest(request, makeIo(null)), /owner decision record/);
  for (const bad of [JSON.stringify({ schema_version: 1, authorized_by: 'controller', decision: 'self', acceptance_evidence: ['x'] }), JSON.stringify({ schema_version: 1, authorized_by: 'owner', decision: '', acceptance_evidence: ['x'] }), JSON.stringify({ schema_version: 1, authorized_by: 'owner', decision: 'ok', acceptance_evidence: [] }), JSON.stringify({ schema_version: 2, authorized_by: 'owner', decision: 'ok', acceptance_evidence: ['x'] }), 'not-json']) {
    assert.throws(() => checkRequest(request, makeIo(bad)), /owner decision record/);
  }
  const scoped = base => JSON.stringify({ schema_version: 1, authorized_by: 'owner', decision: 'ok', decision_record: 'docs/release-owner-decision-v1.md', authorized_versions: { npm: version, skill: null }, compatibility: 'breaking', security_rights_expanded: false, acceptance_evidence: ['x'], ...base });
  const wrong = (authPatch, intentPatch) => {
    const io = makeIo(scoped(authPatch || {}));
    if (intentPatch) {
      const intent = JSON.parse(breakingIntent); Object.assign(intent, intentPatch);
      if (intentPatch.skill_version) io.skillVersion = () => intentPatch.skill_version;
      const original = io.readFileSync;
      io.readFileSync = path => String(path).replaceAll('\\', '/').endsWith('docs/release-intent.json') ? JSON.stringify(intent) : original(path);
    }
    assert.throws(() => checkRequest(request, io), /owner decision record/);
  };
  wrong({ authorized_versions: { npm: '0.9.0', skill: null } });
  wrong({ authorized_versions: { npm: version, skill: null } }, { skill_version: '9.9.9' });
  wrong({}, { security_rights_expanded: true });
  wrong({ compatibility: 'backwards-compatible' });
  wrong({ decision_record: 'docs/missing-record.md' });
  wrong({ authorized_versions: { npm: version, skill: '0.25.0' } });
  assert.equal(checkRequest(request, makeIo(validAuth)).decision, 'publish');
});

test('default registry adapter pins public npm and preserves exact E404 semantics', () => {
  let captured;
  assert.deepEqual(npmView('@manhquy/flow-skill', ['dist-tags'], (command, args, options) => {
    captured = { command, args, options };
    return { status: 0, stdout: '{"latest":"0.7.11"}', stderr: '' };
  }), { present: true, value: { latest: '0.7.11' } });
  assert.equal(captured.command, 'npm');
  assert.deepEqual(captured.args, ['view', '@manhquy/flow-skill', 'dist-tags', '--json', '--registry=https://registry.npmjs.org/']);
  assert.equal(captured.options.cwd, resolve(dirname(fileURLToPath(import.meta.url)), '..'));
  assert.equal(captured.options.timeout, 30000);
  assert.deepEqual(npmView('@manhquy/flow-skill@1.0.0', ['version'], () => ({ status: 1, stderr: 'E404 Not Found' })), { present: false, error: 'E404' });
  assert.throws(() => npmView('@manhquy/flow-skill', ['dist-tags'], () => ({ status: 1, stderr: 'E403 Forbidden' })), /registry lookup failed closed/);
});

test('remote tag verification peels annotated tags and preserves lightweight tags', () => {
  const sha = 'a'.repeat(40); const object = 'b'.repeat(40); const ref = 'refs/tags/npm@0.8.0';
  for (const remote of [`${sha}\t${ref}`, `${object}\t${ref}\n${sha}\t${ref}^{}`]) {
    verifyExistingTag('npm@0.8.0', sha, args => {
      if (args[0] === 'rev-parse') return sha;
      assert.deepEqual(args, ['ls-remote', '--tags', 'origin', ref, `${ref}^{}`]); return remote;
    });
  }
  for (const remote of ['', `${sha}\t${ref}\n${object}\t${ref}^{}`, `${object}\t${ref}`]) {
    assert.throws(() => verifyExistingTag('npm@0.8.0', sha, args => args[0] === 'rev-parse' ? sha : remote), /does not resolve exactly/);
  }
});

import { compareSemver, parseSemver } from '../npm-wrapper/scripts/semver.mjs';

const REFUSAL = 'refuse';

function refuse(reason) {
  return { decision: REFUSAL, reason };
}

export function compareVersions(left, right) {
  if (!parseSemver(left) || !parseSemver(right)) return null;
  return compareSemver(left, right);
}

function validRun(run, expected) {
  return run && run.workflowId === expected.workflowId
    && run.workflowPath === expected.workflowPath
    && run.event === 'push' && run.branch === 'master'
    && run.conclusion === 'success'
    && Number.isInteger(run.id) && Number.isInteger(run.attempt)
    && run.headSha === expected.masterSha
    && run.authoritativeJob?.name === 'all-checks-passed'
    && run.authoritativeJob?.app === 'github-actions'
    && run.authoritativeJob?.conclusion === 'success'
    && run.latestAttempt === run.attempt;
}

/** Pure fail-closed evaluator. All API acquisition and completeness checks belong in the adapter. */
export function evaluateRelease(snapshot) {
  if (!snapshot || typeof snapshot !== 'object') return refuse('invalid-snapshot');
  if (snapshot.mode === 'dispatch' && snapshot.dispatchMode === 'dry-run') return { decision: 'dry-run', reason: 'manual-dispatch-is-never-live' };
  if (snapshot.mode !== 'workflow_run') return refuse('unsupported-entrypoint');
  const { run, expected, pullRequest, release, registry } = snapshot;
  if (!expected || !expected.workflowId || !expected.workflowPath || !expected.masterSha || !expected.publisherWorkflowPath) return refuse('missing-authoritative-identity');
  if (!validRun(run, expected)) return refuse('triggering-ci-run-not-authoritative-current-success');
  if (!pullRequest || pullRequest.merged !== true || pullRequest.baseRepo !== expected.repository || pullRequest.baseBranch !== 'master' || pullRequest.headSha !== run.headSha) return refuse('no-matching-merged-master-pr');
  if (release?.intent === false) return { decision: 'noop-no-release-intent', reason: 'no-committed-release-intent' };
  if (!release || !parseSemver(release.npmVersion) || (release.skillVersion !== null && (!parseSemver(release.skillVersion) || release.skillVersion !== release.npmVersion)) || (release.skillVersion === null && snapshot.phase !== 'reconcile') || !release.npmChangelog || (release.skillVersion !== null && !release.skillChangelog)) return refuse('invalid-unified-release-intent');
  const channel = parseSemver(release.npmVersion).prerelease ? 'next' : 'latest';
  if (release.channel !== channel) return refuse('channel-does-not-match-version');
  if (!registry || !['absent', 'present'].includes(registry.state)) return refuse('registry-state-unknown');
  if (registry.state === 'present') {
    if (snapshot.phase !== 'reconcile') return refuse('existing-version-requires-verify-only-reconciliation');
    if (!snapshot.reconciliation?.verified || snapshot.reconciliation?.expectedSha !== run.headSha) return refuse('existing-version-reconciliation-not-verified');
    const artifact = snapshot.artifact;
    if (!artifact?.integrity || !registry.integrity || registry.integrity !== artifact.integrity) return refuse('existing-version-integrity-mismatch');
    if (!registry.provenance || registry.provenance.repository !== expected.repository || registry.provenance.workflowPath !== expected.publisherWorkflowPath || registry.provenance.commit !== run.headSha || registry.provenance.integrity !== artifact.integrity) return refuse('existing-version-provenance-mismatch');
    if (registry.channel !== channel || registry.tagTarget !== run.headSha || registry.releaseTarget !== run.headSha) return refuse('existing-version-release-state-mismatch');
    return { decision: 'already-published-exact-match', reason: 'immutable-version-fully-reconciled' };
  }
  if (registry.error !== 'E404') return refuse('registry-absence-not-proven-by-e404');
  if (!registry.channelVersion) return refuse('channel-version-unavailable');
  const order = compareVersions(release.npmVersion, registry.channelVersion);
  if (order === null || order <= 0) return refuse('candidate-not-monotonic-for-channel');
  if (snapshot.currentMasterSha !== run.headSha) return refuse('master-stale');
  if (snapshot.phase === 'dry-run') return { decision: 'dry-run', reason: 'release-gates-checked-without-authorizing-publish', channel };
  if (snapshot.autopublishEnabled !== true) return refuse('autopublish-disabled');
  if (snapshot.phase === 'eligibility') return { decision: 'eligible', reason: 'all-prepublish-gates-passed', channel };
  if (snapshot.phase !== 'publish' || !snapshot.artifact?.integrity || snapshot.artifact.commit !== run.headSha || snapshot.artifact.workflowRunId !== snapshot.publisherRunId || snapshot.artifact.workflowRunAttempt !== snapshot.publisherRunAttempt) return refuse('packed-artifact-identity-mismatch');
  if (snapshot.prepublishMasterSha !== run.headSha || snapshot.prepublishRegistryState !== 'absent') return refuse('prepublish-state-changed');
  return { decision: 'publish', reason: 'all-release-gates-passed', channel };
}

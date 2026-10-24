import { pathToFileURL, fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { realpathSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { compareSemver, parseSemver } from '../npm-wrapper/scripts/semver.mjs';
import { evaluateRelease } from './release-eligibility.mjs';
import { verifyNpmVerifiedOutput } from './release-provenance.mjs';
import { verifyWithGhAttestation } from './verify-attestation-with-gh.mjs';
import { artifactTarballPath, PUBLIC_NPM_REGISTRY, readNpmRegistryJson } from './release-run-artifact.mjs';
export const RELEASE_CONSTANTS = Object.freeze({ repository: 'manhquydev/flow-skill', ciWorkflowId: 295237428, ciWorkflowPath: '.github/workflows/ci.yml', publisherWorkflowPath: '.github/workflows/publish-npm-wrapper.yml', package: '@manhquy/flow-skill' });
const { ciWorkflowId: CI_WORKFLOW_ID, ciWorkflowPath: CI_WORKFLOW_PATH, publisherWorkflowPath: PUBLISHER_PATH, package: PACKAGE } = RELEASE_CONSTANTS;
const REPO = process.env.GITHUB_REPOSITORY || RELEASE_CONSTANTS.repository;
const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');

export function selectAuthoritativeRun(runs, sha) {
  if (!Array.isArray(runs)) throw new Error('workflow_runs is not an array');
  return runs.filter(run => run.workflow_id === CI_WORKFLOW_ID && run.path === CI_WORKFLOW_PATH && run.head_sha === sha && run.head_branch === 'master' && run.event === 'push').sort((a, b) => b.id - a.id)[0] || null;
}
export function selectAuthoritativeJob(jobs, run) {
  if (!Array.isArray(jobs)) throw new Error('jobs is not an array');
  const matches = jobs.filter(job => job.name === 'all-checks-passed' && job.run_id === run.id && job.run_attempt === run.run_attempt && job.status === 'completed' && job.conclusion === 'success');
  return matches.length === 1 ? matches[0] : null;
}
export function selectMergedMasterPr(prs, sha, repository) {
  if (!Array.isArray(prs)) throw new Error('pull requests response must be an array');
  return prs.find(pr => pr.merged_at && pr.merge_commit_sha === sha && pr.base?.repo?.full_name?.toLowerCase() === repository.toLowerCase() && pr.base.ref === 'master') || null;
}

function gh(path) { return JSON.parse(execFileSync('gh', ['api', path], { encoding: 'utf8', env: process.env, maxBuffer: 8 * 1024 * 1024 })); }
function git(args) { return execFileSync('git', args, { cwd: repoRoot, encoding: 'utf8' }).trim(); }
function pkg() { return JSON.parse(readFileSync(join(repoRoot, 'npm-wrapper/package.json'), 'utf8')); }
function output(values) { if (process.env.GITHUB_OUTPUT) writeFileSync(process.env.GITHUB_OUTPUT, `${Object.entries(values).map(([k, v]) => `${k}=${v}`).join('\n')}\n`, { flag: 'a' }); }
function apiArray(path, key, request = gh) {
  const result = request(path);
  const values = Array.isArray(result) ? result : result?.[key];
  if (!Array.isArray(values)) throw new Error(`API response has no complete ${key || 'array'}: ${path}`);
  if (!Array.isArray(result) && Number.isInteger(result.total_count) && values.length < result.total_count) throw new Error(`API response is paginated/incomplete: ${path}`);
  return values;
}
export function npmView(spec, fields, run) {
  try {
    return { present: true, value: readNpmRegistryJson(spec, fields, { cwd: repoRoot, ...(run ? { run } : {}) }) };
  } catch (error) {
    if (error.code === 'E404') return { present: false, error: 'E404' };
    throw new Error(`npm registry lookup failed closed: ${error.message}`);
  }
}
function skillVersion() { return readFileSync(join(repoRoot, 'skills/flow/SKILL.md'), 'utf8').match(/^\s+version:\s*["']?([^"'\s]+)["']?\s*$/m)?.[1] || null; }
function changelogHeading(path, version) {
  const escaped = version.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`^##\\s+(?:\\[${escaped}\\]|${escaped})(?:\\s|$)`, 'm').test(readFileSync(join(repoRoot, path), 'utf8'));
}
export function requireUnpublishedVersion(version, lookup = npmView) {
  const result = lookup(`${PACKAGE}@${version}`, ['version']);
  if (result?.present === true) throw new Error(`version ${version} already exists; recovery is verify-only and requires a retained exact artifact and complete SLSA/tag/release reconciliation. Never republish.`);
  if (result?.present !== false || result.error !== 'E404') throw new Error(`registry absence for ${version} was not proven by E404`);
}

export function selectChannelBaseline(channel, distTags) {
  if (!distTags || typeof distTags !== 'object' || Array.isArray(distTags)) return null;
  if (channel === 'latest') return distTags.latest || null;
  if (channel === 'next') return distTags.next || distTags.latest || null;
  return null;
}
const workflowIO = { gh, git, pkg, skillVersion, changelogHeading, npmView, readFileSync, verifyWithGhAttestation };
export function checkRequest({ mode, sha, version, phase = mode === 'publish' ? 'eligibility' : 'dry-run', publisherRunId = null, publisherRunAttempt = null, artifact = null, prepublishMasterSha = null, prepublishRegistry = null }, { gh, git, pkg, skillVersion, changelogHeading, npmView, readFileSync } = workflowIO) {
  if (process.env.GITHUB_REF !== 'refs/heads/master') throw new Error('publisher dispatch ref must be master');
  if (!/^\d+$/.test(process.env.ACTOR_ID || '') || !/^\d+$/.test(process.env.EXPECTED_ACTOR_ID || '') || process.env.ACTOR_ID !== process.env.EXPECTED_ACTOR_ID) throw new Error('workflow actor ID does not match the dispatch caller correlation ID');
  if (mode === 'publish' && process.env.FLOW_AUTOPUBLISH_ENABLED !== 'true') throw new Error('live publishing is disabled until controller activation');
  if (!/^[0-9a-f]{40}$/i.test(sha)) throw new Error('expected SHA must be a full Git object ID');
  if (!/^[0-9a-f]{40}$/i.test(process.env.GITHUB_SHA || '') || process.env.GITHUB_SHA !== sha) throw new Error('expected SHA differs from the trusted workflow-selected commit');
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(process.env.DISPATCH_ID || '')) throw new Error('dispatch correlation ID must be a UUID');
  const currentSha = gh(`repos/${REPO}/git/ref/heads/master`).object?.sha;
  if (currentSha !== sha || git(['rev-parse', 'HEAD']) !== sha) throw new Error('expected SHA is not current remote and checked-out master');
  const manifest = pkg();
  if (manifest.name !== PACKAGE || manifest.version !== version || !parseSemver(version)) throw new Error('expected package identity/version differs from checked-out manifest');
  const prs = apiArray(`repos/${REPO}/commits/${sha}/pulls?per_page=100`, 'pulls', gh);
  const pr = selectMergedMasterPr(prs, sha, REPO);
  if (!pr) throw new Error('exact SHA has no merged PR targeting this repository master');
  const skill = skillVersion();
  if (!skill || !parseSemver(skill)) throw new Error('skill version is missing or invalid');
  const intent = JSON.parse(readFileSync(join(repoRoot, 'docs/release-intent.json'), 'utf8'));
  if (intent.schema_version !== 1) throw new Error('release intent schema is unsupported');
  if (!intent.intent) {
    if (mode === 'dry-run' && intent.intent === false && intent.npm_version === null && intent.skill_version === null && intent.channel === null && intent.compatibility === null && intent.security_rights_expanded === null) {
      console.log(JSON.stringify({ decision: 'noop-no-release-intent', sha, reason: 'release intent is inactive; no publish attempted' }, null, 2));
      output({ eligible: 'false', version, channel: 'none' }); return;
    }
    throw new Error('release intent is inactive or malformed');
  }
  if (intent.npm_version !== version || (intent.skill_version !== null && intent.skill_version !== skill) || !['backwards-compatible', 'breaking'].includes(intent.compatibility) || typeof intent.security_rights_expanded !== 'boolean' || intent.channel !== (parseSemver(version).prerelease ? 'next' : 'latest')) throw new Error('release intent metadata does not match this exact commit/version');
  if (!changelogHeading('npm-wrapper/CHANGELOG.md', version) || (intent.skill_version !== null && !changelogHeading('CHANGELOG.md', intent.skill_version))) throw new Error('release intent requires exact changelog headings for each selected version axis');
  if (intent.compatibility === 'breaking' || intent.security_rights_expanded) {
    let auth = null;
    try { auth = JSON.parse(readFileSync(join(repoRoot, 'docs/release-owner-authorization.json'), 'utf8')); } catch { auth = null; }
    const evidence = auth && Array.isArray(auth.acceptance_evidence) ? auth.acceptance_evidence : [];
    let recordOk = false;
    try { readFileSync(join(repoRoot, auth && auth.decision_record), 'utf8'); recordOk = typeof (auth && auth.decision_record) === 'string'; } catch { recordOk = false; }
    const axes = auth && auth.authorized_versions;
    const axesOk = !!axes && typeof axes === 'object' && !Array.isArray(axes)
      && axes.npm === version
      && axes.skill === intent.skill_version;
    if (!auth || auth.schema_version !== 1 || auth.authorized_by !== 'owner' || typeof auth.decision !== 'string' || !auth.decision.trim()
      || evidence.length === 0 || !evidence.every(entry => typeof entry === 'string' && entry.trim())
      || auth.compatibility !== intent.compatibility || auth.security_rights_expanded !== intent.security_rights_expanded
      || !recordOk || !axesOk) {
      throw new Error('breaking or security-rights-expanding release requires a committed owner decision record bound to this exact release (docs/release-owner-authorization.json)');
    }
  }
  const list = gh(`repos/${REPO}/actions/workflows/${CI_WORKFLOW_ID}/runs?head_sha=${sha}&branch=master&event=push&per_page=100`);
  if (!Array.isArray(list.workflow_runs) || list.workflow_runs.length < list.total_count) throw new Error('CI workflow run list incomplete or paginated');
  const run = selectAuthoritativeRun(list.workflow_runs, sha);
  if (!run) throw new Error('no authoritative CI run for exact master SHA');
  const liveRun = gh(`repos/${REPO}/actions/runs/${run.id}`);
  if (liveRun.workflow_id !== CI_WORKFLOW_ID || liveRun.path !== CI_WORKFLOW_PATH || liveRun.head_sha !== sha || liveRun.event !== 'push' || liveRun.head_branch !== 'master' || liveRun.status !== 'completed' || liveRun.conclusion !== 'success' || liveRun.run_attempt !== run.run_attempt) throw new Error('latest authoritative CI attempt is not successful');
  const jobs = gh(`repos/${REPO}/actions/runs/${run.id}/jobs?filter=latest&per_page=100`);
  if (!Array.isArray(jobs.jobs) || jobs.jobs.length < jobs.total_count) throw new Error('CI job response incomplete');
  const job = selectAuthoritativeJob(jobs.jobs, { id: run.id, run_attempt: liveRun.run_attempt });
  if (!job) throw new Error('exact CI run lacks one complete successful all-checks-passed job');
  const channel = intent.channel;
  const tags = npmView(PACKAGE, ['dist-tags']);
  const latestVersion = selectChannelBaseline(channel, tags.value);
  requireUnpublishedVersion(version, npmView);
  const decision = evaluateRelease({
    mode: 'workflow_run', phase,
    expected: { workflowId: CI_WORKFLOW_ID, workflowPath: CI_WORKFLOW_PATH, publisherWorkflowPath: PUBLISHER_PATH, masterSha: sha, repository: REPO },
    run: { workflowId: CI_WORKFLOW_ID, workflowPath: CI_WORKFLOW_PATH, event: liveRun.event, branch: liveRun.head_branch, conclusion: liveRun.conclusion, id: liveRun.id, attempt: liveRun.run_attempt, latestAttempt: liveRun.run_attempt, headSha: liveRun.head_sha, authoritativeJob: { name: 'all-checks-passed', app: 'github-actions', conclusion: job.conclusion } },
    pullRequest: { merged: true, baseRepo: pr.base.repo.full_name, baseBranch: pr.base.ref, headSha: sha },
    release: { intent: true, npmVersion: version, skillVersion: intent.skill_version, channel, npmChangelog: true, skillChangelog: intent.skill_version === null ? false : true },
    registry: prepublishRegistry || { state: 'absent', error: 'E404', channelVersion: latestVersion },
    currentMasterSha: currentSha, autopublishEnabled: process.env.FLOW_AUTOPUBLISH_ENABLED === 'true',
    publisherRunId, publisherRunAttempt, artifact, prepublishMasterSha, prepublishRegistryState: prepublishRegistry?.state,
  });
  if (decision.decision === 'dry-run') {
    console.log(JSON.stringify({ ...decision, sha, version, skillVersion: skill, ciRun: run.id, attempt: liveRun.run_attempt }, null, 2));
    output({ eligible: 'false', version, channel }); return decision;
  }
  if (decision.decision === 'publish') {
    console.log(JSON.stringify({ ...decision, sha, version, skillVersion: skill, ciRun: run.id, attempt: liveRun.run_attempt }, null, 2));
    return decision;
  }
  if (decision.decision === 'eligible') {
    output({ eligible: 'true', version, channel });
    console.log(JSON.stringify({ ...decision, sha, version, skillVersion: skill, ciRun: run.id, attempt: liveRun.run_attempt }, null, 2));
    return decision;
  }
  throw new Error(`release refused (${decision.decision}): ${decision.reason}`);
}
function recordArtifact(directory, version) {
  const manifest = pkg();
  if (manifest.version !== version) throw new Error('artifact version differs from package manifest');
  const name = `${manifest.name.replace('@', '').replace('/', '-')}-${version}.tgz`;
  const bytes = readFileSync(join(directory, name));
  const integrity = `sha512-${createHash('sha512').update(bytes).digest('base64')}`;
  writeFileSync(join(directory, 'release-artifact.json'), JSON.stringify({ name, version, sha: git(['rev-parse', 'HEAD']), integrity, workflowRunId: process.env.GITHUB_RUN_ID, workflowRunAttempt: process.env.GITHUB_RUN_ATTEMPT }, null, 2));
  console.log(JSON.stringify({ name, version, integrity }));
}
function verify(version, expectedSha, metadataPath, bundlePath) {
  const metadata = JSON.parse(readFileSync(metadataPath, 'utf8'));
  const bytes = readFileSync(artifactTarballPath(dirname(metadataPath), metadata.name));
  const localIntegrity = `sha512-${createHash('sha512').update(bytes).digest('base64')}`;
  if (metadata.version !== version || metadata.sha !== expectedSha || metadata.integrity !== localIntegrity || metadata.workflowRunId !== process.env.GITHUB_RUN_ID || metadata.workflowRunAttempt !== process.env.GITHUB_RUN_ATTEMPT) throw new Error('retained artifact identity or SHA-512/run binding mismatch');
  const report = JSON.parse(readFileSync(bundlePath, 'utf8'));
  const verified = verifyNpmVerifiedOutput(report, { packageName: PACKAGE, version, integrity: localIntegrity, repository: `https://github.com/${REPO}`, workflowPath: PUBLISHER_PATH, ref: 'refs/heads/master', commit: expectedSha });
  const registryVersion = npmView(`${PACKAGE}@${version}`, ['version']);
  const registryIntegrity = npmView(`${PACKAGE}@${version}`, ['dist.integrity']);
  if (!registryVersion.present || registryVersion.value !== version || !registryIntegrity.present || registryIntegrity.value !== localIntegrity) throw new Error('published registry version/integrity differs from the exact packed artifact');
  const channel = parseSemver(version).prerelease ? 'next' : 'latest';
  const tags = npmView(PACKAGE, ['dist-tags']);
  if (!tags.present || tags.value?.[channel] !== version) throw new Error(`published ${channel} dist-tag does not point to ${version}`);
  console.log(JSON.stringify({ decision: 'published-artifact-verified', ...verified }));
}
export function reconcile(packageDirectory, evidenceDirectory, expectedSha, expectedRunId, expectedRunAttempt, { gh, git, npmView, readFileSync, verifyWithGhAttestation } = workflowIO) {
  const metadataPath = join(packageDirectory, 'release-artifact.json');
  const metadata = JSON.parse(readFileSync(metadataPath, 'utf8'));
  const bytes = readFileSync(artifactTarballPath(packageDirectory, metadata.name));
  const integrity = `sha512-${createHash('sha512').update(bytes).digest('base64')}`;
  const version = metadata.version;
  const manifest = JSON.parse(git(['show', `${expectedSha}:npm-wrapper/package.json`]));
  if (manifest.name !== PACKAGE || manifest.version !== version || !parseSemver(version) || metadata.sha !== expectedSha || metadata.integrity !== integrity || String(metadata.workflowRunId) !== String(expectedRunId) || Number(metadata.workflowRunAttempt) !== Number(expectedRunAttempt)) throw new Error('retained artifact does not match exact package/version/SHA/publisher run attempt');
  const report = JSON.parse(readFileSync(join(evidenceDirectory, 'npm-audit-verified.json'), 'utf8'));
  const verified = verifyNpmVerifiedOutput(report, { packageName: PACKAGE, version, integrity, repository: `https://github.com/${REPO}`, workflowPath: PUBLISHER_PATH, ref: 'refs/heads/master', commit: expectedSha });
  verifyWithGhAttestation({ artifact: artifactTarballPath(packageDirectory, metadata.name), bundle: join(evidenceDirectory, 'slsa-bundle.json'), owner: 'manhquydev', repository: 'flow-skill', workflow: PUBLISHER_PATH, sourceRef: 'refs/heads/master', sourceSha: expectedSha });
  const channel = parseSemver(version).prerelease ? 'next' : 'latest';
  const registryVersion = npmView(`${PACKAGE}@${version}`, ['version']);
  const registryIntegrity = npmView(`${PACKAGE}@${version}`, ['dist.integrity']);
  const distTags = npmView(PACKAGE, ['dist-tags']);
  if (!registryVersion.present || registryVersion.value !== version || !registryIntegrity.present || registryIntegrity.value !== integrity || !distTags.present || distTags.value?.[channel] !== version) throw new Error('registry version, immutable integrity or channel does not match retained artifact');
  const intent = JSON.parse(git(['show', `${expectedSha}:docs/release-intent.json`]));
  if (intent.schema_version !== 1 || intent.intent !== true || intent.npm_version !== version || (intent.skill_version !== null && !parseSemver(intent.skill_version))) throw new Error('retained release intent does not match exact package/version');
  const npmTag = `npm@${version}`;
  verifyExistingTag(npmTag, expectedSha, git);
  let skillTag = null;
  if (intent.skill_version !== null) {
    skillTag = `v${intent.skill_version}`;
    verifyExistingSkillTag(skillTag, expectedSha, git);
    const release = gh(`repos/${REPO}/releases/tags/${skillTag}`);
    // target_commitish may be a branch hint; the verified remote tag is authoritative.
    if (release.tag_name !== skillTag) throw new Error('GitHub Release tag does not match retained release tag');
  }
  console.log(JSON.stringify({ decision: 'published-artifact-fully-reconciled', npmTag, skillTag, version, channel, sha: expectedSha, runId: Number(expectedRunId), runAttempt: Number(expectedRunAttempt), verified }, null, 2));
}

export function verifyExistingSkillTag(tagName, retainedSha, runGit = git) {
  const ref = `refs/tags/${tagName}`;
  const remoteRef = () => {
    const rows = runGit(['ls-remote', '--tags', 'origin', ref]).trim().split('\n').filter(Boolean).map(line => line.split(/\s+/));
    const object = rows.find(([, name]) => name === ref)?.[0];
    if (!/^[a-f0-9]{40,64}$/.test(object || '')) throw new Error('remote skill tag unavailable');
    return object;
  };
  const object = remoteRef();
  runGit(['fetch', '--no-tags', '--no-write-fetch-head', 'origin', ref]);
  if (remoteRef() !== object) throw new Error('remote skill tag moved during reconciliation');
  const remoteTree = runGit(['rev-parse', '--verify', `${object}^{commit}:skills`]).trim();
  const retainedTree = runGit(['rev-parse', '--verify', `${retainedSha}:skills`]).trim();
  if (!remoteTree || remoteTree !== retainedTree) throw new Error('remote skill tag subtree differs from retained release revision');
}

export function verifyExistingTag(tagName, expectedSha, runGit = git) {
  const local = runGit(['rev-parse', `${tagName}^{commit}`]);
  const ref = `refs/tags/${tagName}`;
  const remoteOut = runGit(['ls-remote', '--tags', 'origin', ref, `${ref}^{}`]);
  const refs = remoteOut.split('\n').filter(Boolean).map(line => line.split(/\s+/));
  const remote = refs.find(([, name]) => name === `${ref}^{}`)?.[0] || refs.find(([, name]) => name === ref)?.[0];
  if (local !== expectedSha || remote !== expectedSha) throw new Error(`existing tag ${tagName} does not resolve exactly to retained release SHA`);
}

function isCliEntry() {
  if (!process.argv[1]) return false;
  try {
    return realpathSync(fileURLToPath(import.meta.url)) === realpathSync(process.argv[1]);
  } catch {
    return import.meta.url === pathToFileURL(process.argv[1]).href;
  }
}

if (isCliEntry()) {
  const [command, arg1, arg2, arg3, arg4] = process.argv.slice(2);
  try {
    if (command === 'eligibility') checkRequest({ mode: process.env.MODE, sha: process.env.EXPECTED_SHA, version: process.env.EXPECTED_VERSION });
    else if (command === 'record-artifact') recordArtifact(arg1, arg2);
    else if (command === 'prepublish') {
      const metadata = JSON.parse(readFileSync(join(process.env.ARTIFACT_DIR, 'release-artifact.json'), 'utf8'));
      const bytes = readFileSync(artifactTarballPath(process.env.ARTIFACT_DIR, metadata.name));
      const integrity = `sha512-${createHash('sha512').update(bytes).digest('base64')}`;
      if (integrity !== metadata.integrity || metadata.sha !== process.env.EXPECTED_SHA || metadata.version !== process.env.EXPECTED_VERSION || metadata.workflowRunId !== process.env.GITHUB_RUN_ID || metadata.workflowRunAttempt !== process.env.GITHUB_RUN_ATTEMPT || process.env.FLOW_AUTOPUBLISH_ENABLED !== 'true') throw new Error('artifact identity, bytes, run or default-off gate mismatch');
      const existing = npmView(`${PACKAGE}@${process.env.EXPECTED_VERSION}`, ['version']);
      if (existing.present || existing.error !== 'E404') throw new Error('prepublish registry version is present or absence is not proven by E404');
      const channel = parseSemver(process.env.EXPECTED_VERSION).prerelease ? 'next' : 'latest';
      const tags = npmView(PACKAGE, ['dist-tags']);
      if (!tags.present || !parseSemver(selectChannelBaseline(channel, tags.value))) throw new Error(`prepublish ${channel} registry baseline is unavailable`);
      const result = checkRequest({ mode: 'publish', sha: process.env.EXPECTED_SHA, version: process.env.EXPECTED_VERSION, phase: 'publish', publisherRunId: Number(process.env.GITHUB_RUN_ID), publisherRunAttempt: Number(process.env.GITHUB_RUN_ATTEMPT), artifact: { integrity, commit: metadata.sha, workflowRunId: Number(metadata.workflowRunId), workflowRunAttempt: Number(metadata.workflowRunAttempt) }, prepublishMasterSha: gh(`repos/${REPO}/git/ref/heads/master`).object?.sha, prepublishRegistry: { state: 'absent', error: 'E404', channelVersion: selectChannelBaseline(channel, tags.value) } });
      if (result?.decision !== 'publish') throw new Error(`publish boundary was not authorized (${result?.decision || 'no decision'})`);
    } else if (command === 'verify') verify(arg1, arg2, arg3, arg4);
    else if (command === 'reconcile') reconcile(arg1, arg2, arg3, process.env.EXPECTED_RUN_ID, process.env.EXPECTED_RUN_ATTEMPT);
    else throw new Error(`unknown command: ${command}`);
  } catch (error) {
    console.error(`FAIL: ${error.message}`); process.exitCode = 1;
  }
}

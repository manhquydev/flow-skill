import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { parseSemver } from '../npm-wrapper/scripts/semver.mjs';


export function assertGhAttestationCapability({ run }) {
  const versionText = run(['--version']);
  const version = versionText.match(/gh version (\d+\.\d+\.\d+)/)?.[1];
  if (!version || !parseSemver(version) || parseSemver(version).major < 2 || parseSemver(version).major === 2 && parseSemver(version).minor < 68) throw new Error('gh >=2.68.0 with attestation verify is required to verify Sigstore trust roots and Rekor inclusion');
  const help = run(['attestation', 'verify', '--help']);
  for (const option of ['--bundle', '--digest-alg', '--repo', '--signer-workflow', '--source-ref', '--source-digest']) if (!help.includes(option)) throw new Error(`installed gh attestation verifier lacks required option ${option}`);
}

export function verifyWithGhAttestation({ artifact, bundle, owner, repository, workflow, sourceRef, sourceSha, digestAlgorithm = 'sha512', run = args => execFileSync('gh', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 16 * 1024 * 1024 }) }) {
  assertGhAttestationCapability({ run });
  const output = run(['attestation', 'verify', artifact, '--bundle', bundle, '--digest-alg', digestAlgorithm, '--repo', `${owner}/${repository}`, '--signer-workflow', `${owner}/${repository}/${workflow}`, '--source-ref', sourceRef, '--source-digest', sourceSha, '--format', 'json']);
  const result = JSON.parse(output);
  if (!Array.isArray(result) || result.length === 0) throw new Error('gh attestation verify returned no verified provenance statements');
  if (!result.some(item => item.verificationResult?.statement?.predicateType === 'https://slsa.dev/provenance/v1' && item.verificationResult?.statement?.predicate?.buildDefinition?.externalParameters?.workflow?.repository === `https://github.com/${owner}/${repository}` && item.verificationResult?.statement?.predicate?.buildDefinition?.externalParameters?.workflow?.path === workflow && item.verificationResult?.statement?.predicate?.buildDefinition?.externalParameters?.workflow?.ref === sourceRef && item.verificationResult?.statement?.predicate?.buildDefinition?.resolvedDependencies?.some(dep => dep.digest?.gitCommit === sourceSha))) throw new Error('verified attestation output does not contain the expected SLSA source identity');
  return result;
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  const [artifact, bundle, owner, repository, workflow, sourceRef, sourceSha] = process.argv.slice(2);
  try { console.log(JSON.stringify(verifyWithGhAttestation({ artifact, bundle, owner, repository, workflow, sourceRef, sourceSha }), null, 2)); }
  catch (error) { console.error(`FAIL: ${error.message}`); process.exitCode = 1; }
}

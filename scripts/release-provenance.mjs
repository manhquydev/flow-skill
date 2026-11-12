import { parseSemver } from '../npm-wrapper/scripts/semver.mjs';

const SLSA_V1 = 'https://slsa.dev/provenance/v1';
const PUBLISH_V01 = 'https://github.com/npm/attestation/tree/main/specs/publish/v0.1';

function decodeStatement(attestation) {
  const bundle = attestation?.bundle;
  const envelope = bundle?.dsseEnvelope;
  if (envelope?.payloadType !== 'application/vnd.in-toto+json' || typeof envelope.payload !== 'string' || !Array.isArray(envelope.signatures) || envelope.signatures.length === 0) throw new Error('npm verified attestation bundle has no signed in-toto DSSE statement');
  let statement;
  try { statement = JSON.parse(Buffer.from(envelope.payload, 'base64').toString('utf8')); }
  catch { throw new Error('npm verified attestation contains invalid base64/JSON statement'); }
  return statement;
}

function digestHex(integrity) {
  const match = /^sha512-([A-Za-z0-9+/]+={0,2})$/.exec(integrity || '');
  if (!match) throw new Error('packed artifact integrity is not SHA-512 SRI');
  const bytes = Buffer.from(match[1], 'base64');
  if (bytes.length !== 64) throw new Error('packed artifact SHA-512 integrity has invalid length');
  return bytes.toString('hex');
}

export function verifyNpmVerifiedOutput(report, { packageName, version, integrity, repository, workflowPath, ref, commit }) {
  if (!report || !Array.isArray(report.verified) || !Array.isArray(report.invalid) || !Array.isArray(report.missing)) throw new Error('npm audit signatures output has invalid schema');
  if (report.invalid.length || report.missing.length) throw new Error('npm audit signatures reports invalid or missing package signatures');
  const matches = report.verified.filter(item => item.name === packageName && item.version === version && item.registry?.replace(/\/$/, '') === 'https://registry.npmjs.org');
  if (matches.length !== 1) throw new Error(`expected one cryptographically verified ${packageName}@${version} from registry.npmjs.org`);
  const digest = digestHex(integrity);
  const statements = matches[0].attestationBundles?.map(bundle => ({ predicateType: bundle.predicateType, statement: decodeStatement(bundle) })) || [];
  const slsa = statements.filter(item => item.predicateType === SLSA_V1 && item.statement?.predicateType === SLSA_V1);
  const npm = statements.filter(item => item.predicateType === PUBLISH_V01 && item.statement?.predicateType === PUBLISH_V01);
  if (slsa.length !== 1 || npm.length !== 1) throw new Error('expected exactly one verified npm publish attestation and one SLSA v1 provenance statement');
  const slsaStatement = slsa[0].statement;
  const subject = slsaStatement.subject?.find(item => item.name === `pkg:npm/${encodeURIComponent(packageName).replace(/%2F/gi, '/') }@${version}` || item.name === `${packageName}@${version}`);
  if (!subject || subject.digest?.sha512 !== digest) throw new Error('SLSA subject name/digest does not match exact package tarball SHA-512');
  const build = slsaStatement.predicate?.buildDefinition;
  const source = build?.externalParameters?.workflow;
  if (source?.repository !== repository || source?.path !== workflowPath || source?.ref !== ref) throw new Error('SLSA workflow source repository/path/ref does not match requested release');
  const commitMatches = build?.resolvedDependencies?.filter(item => item.digest?.gitCommit === commit) || [];
  if (commitMatches.length !== 1) throw new Error('SLSA resolved source commit does not match requested release SHA');
  if (parseSemver(version) === null) throw new Error('verified package version is not SemVer');
  return { packageName, version, integrity, repository: source.repository, workflowPath: source.path, ref: source.ref, commit, attestationCount: statements.length };
}

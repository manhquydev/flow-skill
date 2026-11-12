import { realpathSync } from 'node:fs';
import { tmpdir } from 'node:os';

export function canonicalSmokeTempBase(base = tmpdir(), realpath = realpathSync) {
  return realpath(base);
}
export function assertProvenanceResult(status, stdout, packageName, version) {
  let metadata;
  try {
    metadata = status === 0 && typeof stdout === 'string' ? JSON.parse(stdout) : null;
  } catch {
    metadata = null;
  }
  if (metadata?.predicateType !== 'https://slsa.dev/provenance/v1') {
    throw new Error(`${packageName}@${version} has no SLSA v1 registry provenance metadata`);
  }
  return true;
}

import test from 'node:test';
import assert from 'node:assert/strict';
import { realpathSync, mkdtempSync, mkdirSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { canonicalSmokeTempBase, assertProvenanceResult } from '../scripts/smoke-policy.mjs';
test('smoke temp base resolves symlinked system temp roots before creating installer homes', t => {
  const root = realpathSync(mkdtempSync(join(tmpdir(), 'flow-smoke-temp-policy-')));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const physical = join(root, 'private-temp');
  const alias = join(root, 'var-alias');
  mkdirSync(physical);
  try { symlinkSync(physical, alias, 'dir'); }
  catch (error) {
    if (['EPERM', 'EACCES', 'ENOSYS'].includes(error.code)) return t.skip(`directory symlinks unsupported: ${error.code}`);
    throw error;
  }
  assert.equal(canonicalSmokeTempBase(alias), physical);
  assert.equal(canonicalSmokeTempBase(physical), physical);
});

const packageName = '@manhquy/flow-skill';
const version = '0.8.0';

test('strict smoke policy accepts present provenance metadata', () => {
  assert.equal(assertProvenanceResult(0, '{"predicateType":"https://slsa.dev/provenance/v1"}', packageName, version), true);
});

test('strict smoke policy rejects missing provenance, malformed metadata and failed queries', () => {
  for (const stdout of ['', '  ', 'arbitrary output', '{broken', '{}', '{"attestations":[]}', 'null', '[]', 'true', '"https://slsa.dev/provenance/v1"', '{"predicateType":"https://slsa.dev/provenance/v0.2"}']) {
    assert.throws(() => assertProvenanceResult(0, stdout, packageName, version), /has no SLSA v1 registry provenance metadata/);
  }
  for (const status of [1, null]) {
    assert.throws(() => assertProvenanceResult(status, '{"predicateType":"https://slsa.dev/provenance/v1"}', packageName, version));
  }
});

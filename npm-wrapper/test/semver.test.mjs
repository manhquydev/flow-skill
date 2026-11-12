import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  parseSemver,
  compareSemver,
  supportsReceiptAndOmp,
  RECEIPT_OMP_MIN_VERSION,
} from '../scripts/semver.mjs';

test('parseSemver parses standard SemVer 2.0.0 strings correctly', () => {
  assert.deepEqual(parseSemver('0.7.8'), {
    major: 0,
    minor: 7,
    patch: 8,
    prerelease: null,
    build: null,
  });

  assert.deepEqual(parseSemver('0.7.1-next.0'), {
    major: 0,
    minor: 7,
    patch: 1,
    prerelease: ['next', '0'],
    build: null,
  });

  assert.deepEqual(parseSemver('v1.2.3-rc.1+build.42'), {
    major: 1,
    minor: 2,
    patch: 3,
    prerelease: ['rc', '1'],
    build: ['build', '42'],
  });
  // Valid nonnumeric identifiers and build metadata
  assert.deepEqual(parseSemver('0.7.8-0'), {
    major: 0,
    minor: 7,
    patch: 8,
    prerelease: ['0'],
    build: null,
  });
  assert.deepEqual(parseSemver('0.7.8-rc-1'), {
    major: 0,
    minor: 7,
    patch: 8,
    prerelease: ['rc-1'],
    build: null,
  });
  assert.deepEqual(parseSemver('0.7.8-01a'), {
    major: 0,
    minor: 7,
    patch: 8,
    prerelease: ['01a'],
    build: null,
  });
  assert.deepEqual(parseSemver('0.7.8+01'), {
    major: 0,
    minor: 7,
    patch: 8,
    prerelease: null,
    build: ['01'],
  });
});

test('parseSemver strictly rejects invalid SemVer 2.0.0 strings', () => {
  // Non-strings / empty
  assert.equal(parseSemver(''), null);
  assert.equal(parseSemver(null), null);
  assert.equal(parseSemver(undefined), null);
  assert.equal(parseSemver('not-a-version'), null);
  assert.equal(parseSemver('1.2'), null);
  assert.equal(parseSemver('1.2.3.4'), null);

  // Surrounding whitespace strictly rejected (no trimming)
  assert.equal(parseSemver(' 0.7.8'), null);
  assert.equal(parseSemver('0.7.8 '), null);
  assert.equal(parseSemver(' 0.7.8 '), null);
  assert.equal(parseSemver('\t0.7.8'), null);
  assert.equal(parseSemver('0.7.8\n'), null);
  assert.equal(parseSemver('\r\n0.7.8\r\n'), null);
  // Leading zeroes in core numeric identifiers (major, minor, patch)
  assert.equal(parseSemver('01.2.3'), null);
  assert.equal(parseSemver('1.02.3'), null);
  assert.equal(parseSemver('1.2.03'), null);
  assert.equal(parseSemver('00.1.2'), null);

  // Leading zeroes in numeric prerelease identifiers
  assert.equal(parseSemver('0.7.8-01'), null);
  assert.equal(parseSemver('0.7.8-00'), null);
  assert.equal(parseSemver('0.7.8-beta.01'), null);

  // Malformed / empty prerelease components
  assert.equal(parseSemver('0.7.8-'), null);
  assert.equal(parseSemver('0.7.8-alpha..1'), null);
  assert.equal(parseSemver('0.7.8-alpha.'), null);
  assert.equal(parseSemver('0.7.8-.alpha'), null);

  // Malformed / empty build components
  assert.equal(parseSemver('0.7.8+'), null);
  assert.equal(parseSemver('0.7.8+build..1'), null);
  assert.equal(parseSemver('0.7.8+build.'), null);
  assert.equal(parseSemver('0.7.8+.build'), null);
});

test('compareSemver respects major, minor, and patch precedence', () => {
  assert.equal(compareSemver('1.0.0', '0.9.9'), 1);
  assert.equal(compareSemver('0.9.9', '1.0.0'), -1);
  assert.equal(compareSemver('0.8.0', '0.7.9'), 1);
  assert.equal(compareSemver('0.7.9', '0.8.0'), -1);
  assert.equal(compareSemver('0.7.8', '0.7.7'), 1);
  assert.equal(compareSemver('0.7.7', '0.7.8'), -1);
  assert.equal(compareSemver('0.7.8', '0.7.8'), 0);
});

test('compareSemver gives normal versions higher precedence than prereleases of the same tuple', () => {
  assert.equal(compareSemver('0.7.8', '0.7.8-rc.1'), 1);
  assert.equal(compareSemver('0.7.8-rc.1', '0.7.8'), -1);
  assert.equal(compareSemver('0.7.8', '0.7.8-alpha'), 1);
  assert.equal(compareSemver('0.7.8-0', '0.7.8'), -1);
});

test('compareSemver compares prerelease identifiers per SemVer 2.0.0', () => {
  assert.equal(compareSemver('0.7.8-alpha', '0.7.8-beta'), -1);
  assert.equal(compareSemver('0.7.8-alpha.1', '0.7.8-alpha.2'), -1);
  assert.equal(compareSemver('0.7.8-1', '0.7.8-alpha'), -1); // numeric < non-numeric
  assert.equal(compareSemver('0.7.8-alpha', '0.7.8-alpha.1'), -1); // shorter set < longer set
  assert.equal(compareSemver('0.7.8-rc.1', '0.7.8-rc.1'), 0);
});

test('parseSemver handles large numeric identifiers exceeding MAX_SAFE_INTEGER without precision loss', () => {
  assert.deepEqual(parseSemver('9007199254740993.0.0'), {
    major: 9007199254740993n,
    minor: 0,
    patch: 0,
    prerelease: null,
    build: null,
  });
  assert.deepEqual(parseSemver('0.9007199254740993.0'), {
    major: 0,
    minor: 9007199254740993n,
    patch: 0,
    prerelease: null,
    build: null,
  });
  assert.deepEqual(parseSemver('0.0.9007199254740993'), {
    major: 0,
    minor: 0,
    patch: 9007199254740993n,
    prerelease: null,
    build: null,
  });
});

test('compareSemver preserves ordering for core numeric identifiers exceeding MAX_SAFE_INTEGER', () => {
  // Adjacent values above MAX_SAFE_INTEGER (9007199254740991)
  assert.equal(compareSemver('9007199254740992.0.0', '9007199254740993.0.0'), -1);
  assert.equal(compareSemver('9007199254740993.0.0', '9007199254740992.0.0'), 1);
  assert.equal(compareSemver('9007199254740993.0.0', '9007199254740993.0.0'), 0);
  assert.equal(compareSemver('0.9007199254740992.0', '0.9007199254740993.0'), -1);
  assert.equal(compareSemver('0.9007199254740993.0', '0.9007199254740992.0'), 1);
  assert.equal(compareSemver('0.0.9007199254740992', '0.0.9007199254740993'), -1);
  assert.equal(compareSemver('0.0.9007199254740993', '0.0.9007199254740992'), 1);

  // Differing length arbitrary-precision numbers
  assert.equal(
    compareSemver('10000000000000000000.0.0', '9999999999999999999.0.0'),
    1
  );
  assert.equal(
    compareSemver('9999999999999999999.0.0', '10000000000000000000.0.0'),
    -1
  );
});

test('compareSemver preserves ordering for numeric prerelease identifiers exceeding MAX_SAFE_INTEGER', () => {
  // Adjacent prerelease values above MAX_SAFE_INTEGER
  assert.equal(compareSemver('0.7.8-9007199254740992', '0.7.8-9007199254740993'), -1);
  assert.equal(compareSemver('0.7.8-9007199254740993', '0.7.8-9007199254740992'), 1);
  assert.equal(compareSemver('0.7.8-9007199254740993', '0.7.8-9007199254740993'), 0);
  assert.equal(compareSemver('0.7.8-alpha.9007199254740992', '0.7.8-alpha.9007199254740993'), -1);
  assert.equal(compareSemver('0.7.8-alpha.9007199254740993', '0.7.8-alpha.9007199254740992'), 1);

  // Differing length arbitrary-precision prerelease numbers
  assert.equal(
    compareSemver('0.7.8-10000000000000000000', '0.7.8-9999999999999999999'),
    1
  );
  assert.equal(
    compareSemver('0.7.8-9999999999999999999', '0.7.8-10000000000000000000'),
    -1
  );
});

test('compareSemver ignores build metadata for precedence', () => {
  assert.equal(compareSemver('0.7.8+exp.sha.5114f85', '0.7.8'), 0);
  assert.equal(compareSemver('0.7.8-rc.1+123', '0.7.8-rc.1+456'), 0);
});

test('RECEIPT_OMP_MIN_VERSION constant is 0.7.8', () => {
  assert.equal(RECEIPT_OMP_MIN_VERSION, '0.7.8');
});

test('supportsReceiptAndOmp: stable threshold boundary at 0.7.8', () => {
  assert.equal(supportsReceiptAndOmp('0.7.8'), true);
  assert.equal(supportsReceiptAndOmp('0.7.7'), false);
  assert.equal(supportsReceiptAndOmp('0.7.0'), false);
  assert.equal(supportsReceiptAndOmp('0.6.9'), false);
  assert.equal(supportsReceiptAndOmp('0.1.0'), false);
  assert.equal(supportsReceiptAndOmp('0.7.1-next.0'), false);
});

test('supportsReceiptAndOmp: 0.7.8 prereleases must NOT be assumed to support receipt/OMP', () => {
  assert.equal(supportsReceiptAndOmp('0.7.8-0'), false);
  assert.equal(supportsReceiptAndOmp('0.7.8-alpha'), false);
  assert.equal(supportsReceiptAndOmp('0.7.8-alpha.1'), false);
  assert.equal(supportsReceiptAndOmp('0.7.8-beta'), false);
  assert.equal(supportsReceiptAndOmp('0.7.8-rc.1'), false);
  assert.equal(supportsReceiptAndOmp('0.7.8-next.0'), false);
  assert.equal(supportsReceiptAndOmp('0.7.8-rc.1+build123'), false);
});

test('supportsReceiptAndOmp: 0.7.9 prereleases DO support receipt/OMP', () => {
  assert.equal(supportsReceiptAndOmp('0.7.9-0'), true);
  assert.equal(supportsReceiptAndOmp('0.7.9-alpha'), true);
  assert.equal(supportsReceiptAndOmp('0.7.9-rc.1'), true);
  assert.equal(supportsReceiptAndOmp('0.7.9-next.0'), true);
  assert.equal(supportsReceiptAndOmp('0.7.9-next.1'), true);
  assert.equal(supportsReceiptAndOmp('0.7.9'), true);
});

test('supportsReceiptAndOmp: subsequent versions and prereleases support receipt/OMP', () => {
  assert.equal(supportsReceiptAndOmp('0.8.0-alpha.0'), true);
  assert.equal(supportsReceiptAndOmp('0.8.0'), true);
  assert.equal(supportsReceiptAndOmp('0.8.1'), true);
  assert.equal(supportsReceiptAndOmp('0.10.0'), true);
  assert.equal(supportsReceiptAndOmp('1.0.0-alpha'), true);
  assert.equal(supportsReceiptAndOmp('1.0.0'), true);
  assert.equal(supportsReceiptAndOmp('2.1.3'), true);
});

test('supportsReceiptAndOmp: build metadata behavior is ignored for precedence', () => {
  assert.equal(supportsReceiptAndOmp('0.7.8+build.1'), true);
  assert.equal(supportsReceiptAndOmp('0.7.8+sha.abcdef'), true);
  assert.equal(supportsReceiptAndOmp('0.7.8-alpha.1+build.1'), false);
  assert.equal(supportsReceiptAndOmp('0.7.7+build.1'), false);
  assert.equal(supportsReceiptAndOmp('0.8.0+build.999'), true);
});

test('supportsReceiptAndOmp: invalid and non-semver inputs return false', () => {
  assert.equal(supportsReceiptAndOmp(''), false);
  assert.equal(supportsReceiptAndOmp(null), false);
  assert.equal(supportsReceiptAndOmp(undefined), false);
  assert.equal(supportsReceiptAndOmp('latest'), false);
  assert.equal(supportsReceiptAndOmp('next'), false);
  assert.equal(supportsReceiptAndOmp('invalid.version'), false);
  assert.equal(supportsReceiptAndOmp('01.7.8'), false);
  assert.equal(supportsReceiptAndOmp('0.7.8-01'), false);
  assert.equal(supportsReceiptAndOmp('0.7.8-'), false);
  assert.equal(supportsReceiptAndOmp('0.7.8+'), false);
  assert.equal(supportsReceiptAndOmp(' 0.7.8'), false);
  assert.equal(supportsReceiptAndOmp('0.7.8 '), false);
  assert.equal(supportsReceiptAndOmp('\n0.7.8\n'), false);
});

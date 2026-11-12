// Pure standard-library semver helper for scripts and test harnesses.
// Zero external dependencies.
//
// Minimum version introducing the transactional ownership receipt (manifest-hashes.json)
// and the explicit/autodetected OMP install target (commit 5474907): 0.7.8.
export const RECEIPT_OMP_MIN_VERSION = '0.7.8';

/**
 * Parse a strict SemVer 2.0.0 string with optional leading 'v'.
 *
 * Numeric components whose value exceeds Number.MAX_SAFE_INTEGER are returned
 * as `bigint` (see {@link parseNumeric}), so `major`/`minor`/`patch` are typed
 * `number | bigint`. Note that `JSON.stringify` without a replacer throws
 * `TypeError: Do not know how to serialize a BigInt` when serializing such a
 * descriptor; convert bigints (e.g. via a replacer or `String()`) first.
 *
 * @param {string} v
 * @returns {{ major: number | bigint, minor: number | bigint, patch: number | bigint, prerelease: string[] | null, build: string[] | null } | null}
 */
const SEMVER_RE =
  /^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$/;

function parseNumeric(str) {
  const bi = BigInt(str);
  return bi <= BigInt(Number.MAX_SAFE_INTEGER) ? Number(bi) : bi;
}

export function parseSemver(v) {
  if (typeof v !== 'string') return null;
  // Strict parser: reject surrounding whitespace without trimming.
  const match = v.match(SEMVER_RE);
  if (!match) return null;
  const major = parseNumeric(match[1]);
  const minor = parseNumeric(match[2]);
  const patch = parseNumeric(match[3]);

  let prerelease = null;
  if (match[4] !== undefined) {
    prerelease = match[4].split('.');
    for (const id of prerelease) {
      // Numeric prerelease identifiers MUST NOT include leading zeroes (e.g. '01' is invalid, '0' is valid).
      if (/^\d+$/.test(id) && !/^(0|[1-9]\d*)$/.test(id)) {
        return null;
      }
    }
  }

  const build = match[5] !== undefined ? match[5].split('.') : null;
  return { major, minor, patch, prerelease, build };
}

/**
 * Exact arbitrary-length decimal comparison for core and numeric prerelease IDs.
 * Compares by string length first, then lexical ASCII order (no Number/parseInt precision loss).
 * Valid numeric identifiers in SemVer 2.0.0 have no leading zeros, so length directly reflects magnitude.
 */
function compareNumeric(a, b) {
  const sa = typeof a === 'bigint' ? a.toString() : String(a);
  const sb = typeof b === 'bigint' ? b.toString() : String(b);
  if (sa === sb) return 0;
  if (sa.length !== sb.length) return sa.length > sb.length ? 1 : -1;
  return sa > sb ? 1 : -1;
}

/**
 * Compare two SemVer strings or parsed descriptors per SemVer 2.0.0 precedence rules.
 * Returns -1 if a < b, 0 if a == b, 1 if a > b.
 * Note: build metadata is ignored for precedence.
 *
 * @param {string | object} a
 * @param {string | object} b
 * @returns {number}
 */
export function compareSemver(a, b) {
  const pa = typeof a === 'string' ? parseSemver(a) : a;
  const pb = typeof b === 'string' ? parseSemver(b) : b;
  if (!pa || !pb) throw new Error(`Invalid semver: ${!pa ? a : b}`);

  const diffMajor = compareNumeric(pa.major, pb.major);
  if (diffMajor !== 0) return diffMajor;

  const diffMinor = compareNumeric(pa.minor, pb.minor);
  if (diffMinor !== 0) return diffMinor;

  const diffPatch = compareNumeric(pa.patch, pb.patch);
  if (diffPatch !== 0) return diffPatch;

  // When major, minor, patch are equal:
  // A normal version has greater precedence than a pre-release version.
  if (pa.prerelease === null && pb.prerelease === null) return 0;
  if (pa.prerelease === null && pb.prerelease !== null) return 1;
  if (pa.prerelease !== null && pb.prerelease === null) return -1;

  // Both have pre-release tags: compare identifier by identifier.
  const len = Math.max(pa.prerelease.length, pb.prerelease.length);
  for (let i = 0; i < len; i++) {
    const idA = pa.prerelease[i];
    const idB = pb.prerelease[i];
    if (idA === undefined) return -1; // smaller set has lower precedence
    if (idB === undefined) return 1;
    if (idA === idB) continue;

    const isNumA = /^\d+$/.test(idA);
    const isNumB = /^\d+$/.test(idB);

    if (isNumA && isNumB) {
      const diff = compareNumeric(idA, idB);
      if (diff !== 0) return diff;
      continue;
    }
    // Numeric identifiers always have lower precedence than non-numeric identifiers.
    if (isNumA && !isNumB) return -1;
    if (!isNumA && isNumB) return 1;

    // Lexical ASCII comparison.
    return idA > idB ? 1 : -1;
  }
  return 0;
}

/**
 * Returns true if the package version supports transactional ownership receipt
 * (`manifest-hashes.json`) and the OMP install target.
 *
 * Rules:
 * - Stable 0.7.8 and later versions return true.
 * - 0.7.8 prereleases (e.g. 0.7.8-alpha, 0.7.8-rc.1) must not be assumed to support it (returns false).
 * - 0.7.9 prereleases (e.g. 0.7.9-next.0) and later prereleases do support it (returns true).
 * - Older versions (< 0.7.8, including 0.7.1-next.0) return false.
 *
 * @param {string} version
 * @returns {boolean}
 */
export function supportsReceiptAndOmp(version) {
  const parsed = parseSemver(version);
  if (!parsed) return false;
  return compareSemver(parsed, RECEIPT_OMP_MIN_VERSION) >= 0;
}

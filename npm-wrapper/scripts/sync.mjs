// Dev-only: copy skill content from ../flow/flow-skill/skills/flow into ./skills/flow.
// Ships in dev repo only — excluded from published tarball via `files` allowlist in package.json.
//
// `--compare <extracted> <repo>` is an argv short-circuit BEFORE any copy. It walks both
// trees with the same shouldShip predicate used by the copy filter (Phase 7 will extend
// that one function — do not fork the exclusion list in bash).
import { createHash } from 'node:crypto';
import {
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const pkgRoot = resolve(__dirname, '..');

// Shared copy / completeness / --compare predicate. Keep the copy `filter` a call
// to this function — they are twins. Phase 7 adds eval/replay/ here, not in bash.
function shouldShip(path) {
  const s = path.replace(/\\/g, '/');
  if (s.includes('/__pycache__/') || s.endsWith('/__pycache__')) return false;
  if (s.endsWith('.pyc') || s.endsWith('.pyo')) return false;
  if (s.endsWith('/.DS_Store') || s.endsWith('/Thumbs.db')) return false;
  // Replay fixtures are CI/dev artifacts, not skill content (Phase 7).
  if (s.includes('/eval/replay/') || s.endsWith('/eval/replay')) return false;
  return true;
}

function listFiles(root, acc = [], base = root) {
  for (const entry of readdirSync(root)) {
    const p = join(root, entry);
    if (!shouldShip(p)) continue;
    if (statSync(p).isDirectory()) listFiles(p, acc, base);
    else acc.push(relative(base, p).replace(/\\/g, '/'));
  }
  return acc;
}

function compareTrees(extracted, repo) {
  if (!existsSync(extracted)) {
    console.error(`FAIL: extracted tree missing: ${extracted}`);
    return 1;
  }
  if (!existsSync(repo)) {
    console.error(`FAIL: repo tree missing: ${repo}`);
    return 1;
  }
  if (!existsSync(join(extracted, 'SKILL.md'))) {
    console.error(`FAIL: extracted SKILL.md not found at ${extracted}`);
    return 1;
  }
  if (!existsSync(join(repo, 'SKILL.md'))) {
    console.error(`FAIL: repo SKILL.md not found at ${repo}`);
    return 1;
  }

  // The bundled-only receipt (written by this script at pack time, after the copy) is expected
  // extra in the extracted tree; its contents are verified in pack-rehearsal.sh.
  const RECEIPT = 'manifest-hashes.json';
  const extractedFiles = listFiles(extracted).sort().filter((f) => f !== RECEIPT);
  const repoFiles = listFiles(repo).sort();
  if (extractedFiles.length === 0) {
    console.error(`FAIL: extracted tree has zero shouldShip files: ${extracted}`);
    return 1;
  }

  const extractedSet = new Set(extractedFiles);
  const repoSet = new Set(repoFiles);
  let rc = 0;
  for (const f of repoFiles) {
    if (!extractedSet.has(f)) {
      console.error(`FAIL: missing in tarball: ${f}`);
      rc = 1;
    }
  }
  for (const f of extractedFiles) {
    if (!repoSet.has(f)) {
      console.error(`FAIL: extra in tarball: ${f}`);
      rc = 1;
    }
  }
  for (const f of repoFiles) {
    if (!extractedSet.has(f)) continue;
    const a = readFileSync(join(extracted, f));
    const b = readFileSync(join(repo, f));
    if (Buffer.compare(a, b) !== 0) {
      console.error(`FAIL: content drift: ${f}`);
      rc = 1;
    }
  }
  if (rc === 0) {
    console.log(`compare OK: ${extractedFiles.length} shouldShip files match`);
  }
  return rc;
}

// Argv branch MUST run before rmSync/cpSync. shouldShip is not exported; do not
// add a sibling importer. `node sync.mjs --compare <extracted> <repo>`
const argv = process.argv.slice(2);
if (argv[0] === '--compare') {
  if (!argv[1] || !argv[2] || argv[3]) {
    console.error('usage: sync.mjs --compare <extracted-package/skills/flow> <repo-skills/flow>');
    process.exit(2);
  }
  process.exit(compareTrees(resolve(argv[1]), resolve(argv[2])));
}

// Monorepo layout — the skill source-of-truth lives one level up in the same repo.
// The FLOW_SKILL_SRC env override is still honored for out-of-tree dev checkouts and CI matrix.
const src =
  process.env.FLOW_SKILL_SRC || resolve(pkgRoot, '..', 'skills', 'flow');
const dst = join(pkgRoot, 'skills', 'flow');

if (!existsSync(join(src, 'SKILL.md'))) {
  console.error(`FAIL: source SKILL.md not found at ${src}`);
  console.error(`Hint: set FLOW_SKILL_SRC=<abs-path-to-flow-skill/skills/flow>`);
  process.exit(1);
}

// L23 — reject any symlink in source before we touch dst.
function assertNoSymlinks(root) {
  for (const entry of readdirSync(root)) {
    const p = join(root, entry);
    const st = lstatSync(p);
    if (st.isSymbolicLink()) {
      console.error(`FAIL: symlink detected in source (rejected for security): ${p}`);
      process.exit(1);
    }
    if (st.isDirectory()) assertNoSymlinks(p);
  }
}

console.log(`sync: ${src} -> ${dst}`);
assertNoSymlinks(src);

rmSync(dst, { recursive: true, force: true });
mkdirSync(dirname(dst), { recursive: true });
cpSync(src, dst, {
  recursive: true,
  force: true,
  dereference: false,
  errorOnBrokenSymbolicLinks: true,
  preserveTimestamps: true,
  // Skip Python bytecode (regenerated at runtime; different .pyc for .310/.311/.314 = wasteful
  // and confusing) and any editor / OS junk. This is the source of truth because `files:` in
  // package.json takes precedence over .npmignore — filter here instead.
  filter: (source) => shouldShip(source),
});

// R19 completeness check — file list parity. Filter to match the copy predicate above so a
// pyc-heavy source tree doesn't fail the check against a pyc-stripped destination.
const srcFiles = listFiles(src).sort();
const dstFiles = listFiles(dst).sort();
if (
  srcFiles.length !== dstFiles.length ||
  srcFiles.some((f, i) => f !== dstFiles[i])
) {
  console.error(
    `FAIL: file list mismatch after copy (source ${srcFiles.length} vs dst ${dstFiles.length})`
  );
  process.exit(1);
}

// Trust model: the co-shipped receipt (manifest-hashes.json) lets `flow doctor` detect
// POST-INSTALL drift across the entire bundled skill tree (all shipped assets: runner,
// harness, templates, references, law, eval). It does NOT establish package authenticity —
// an attacker rewriting tree files AND receipt together is invisible to doctor; that remains
// npm provenance/registry's job (hence the receipt ships in the tarball rather than being
// self-signed). L25's circular-trust objection applied to a self-emitted integrity file as
// an authenticity claim; this receipt makes no such claim.
// skills-manifest.json still ships as a completeness signal (file count + list).
// v0.23 M3 fix — `source` used to be `resolve()`d to an absolute local filesystem path (e.g.
// D:\project\flow\...) and that absolute path shipped inside the published npm tarball
// (skills-manifest.json is in package.json `files:`), leaking local machine layout and being
// non-reproducible across dev machines/CI. Store a repo-relative description instead — it's
// never used programmatically (only informational), so relative is strictly better here.
writeFileSync(
  join(pkgRoot, 'skills-manifest.json'),
  JSON.stringify(
    {
      source: process.env.FLOW_SKILL_SRC ? '$FLOW_SKILL_SRC (override)' : '../skills/flow',
      destRelative: 'skills/flow',
      fileCount: dstFiles.length,
      syncedAt: new Date().toISOString(),
      fileList: dstFiles,
    },
    null,
    2
  ) + '\n'
);

// C5 — pack-time runner integrity hash. sync.mjs is the only writer of the `hashes` object in
// portable-manifest.json (the rest of that manifest stays hand-maintained): the SHA256 of the
// source runner is recomputed here on every pack (prepack runs this file), so the recorded
// reference always matches the bytes that ship. Never hand-edit the hash; re-run this script.
const manifestPath = resolve(pkgRoot, '..', 'portable-manifest.json');
const runnerRel = 'skills/flow/runner/flow.sh';
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
manifest.hashes = manifest.hashes || {};
manifest.hashes[runnerRel] = createHash('sha256')
  .update(readFileSync(join(src, 'runner', 'flow.sh')))
  .digest('hex');
writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');

// Full bundled-tree integrity receipt — written inside the bundled skill so real npm/package installs
// can verify all shipped assets. Computed from the bundled copy. Deterministic: no timestamps,
// sorted keys, fixed shape.
const filesMap = {};
for (const rel of dstFiles) {
  if (rel === 'manifest-hashes.json') continue;
  const full = join(dst, rel);
  const hash = createHash('sha256').update(readFileSync(full)).digest('hex');
  filesMap[rel] = hash;
}
const receipt = {
  schema_version: 1,
  files: filesMap,
};
writeFileSync(
  join(dst, 'manifest-hashes.json'),
  JSON.stringify(receipt, null, 2) + '\n'
);

// --- WidelCode overlay: generated rules file (T1) ---------------------------
// `.widelai/rules/flowskill.md` is a projection of the repo's multi-home rule
// map — AGENTS.md + CONTRIBUTING.md + skills/flow/law/CLAUDE.md +
// skills/flow/references/attestations.md + skills/flow/references/cost-receipts.md
// + skills/flow/runner/flow.sh — NOT
// law/ alone (two of the rules live only in root AGENTS.md). It is generated
// HERE at pack time, the only point with all sources on disk, and shipped as
// a sibling payload in the npm tarball; the installer places it under
// ~/.widelai/rules/. It is NOT part of the skill tree, so
// manifest-hashes.json does not cover it — regeneration from the sources
// below is the integrity story: output is deterministic (no timestamps), and
// the test suite asserts byte-identical re-runs. Rules with no home in this
// repo (maker/verifier separation, denied-action verdict mapping, a deploy
// rule) are deliberately NOT stated here — see the "Not in this file" note in
// the emitted file and the T1 PR description.

// Locate a source line by content. A MISSING source file returns null — the
// caller skips generation (partial trees, e.g. the sync-release test
// fixtures, do not carry AGENTS.md/CONTRIBUTING.md). A file that EXISTS but
// no longer contains the pattern still fails loudly, so a stale rules file
// can never ship silently.
//
// Lines are matched after stripping a trailing carriage return, so
// `$`-anchored patterns also match on Windows (CRLF) checkouts; the returned
// text is the clean line, so generated output never carries CR bytes.
//
// @param {string} repoRoot - Repository root holding the source file.
// @param {string} relPath - Source path relative to repoRoot.
// @param {RegExp} pattern - Pattern the source line must match.
// @param {string} label - Human-readable source name for the loud failure.
// @returns {{ file: string, line: number, text: string } | null} The matched
//   line (1-based), or null when the source file is missing.
function findRulesSourceLine(repoRoot, relPath, pattern, label) {
  let text;
  try {
    text = readFileSync(resolve(repoRoot, relPath), 'utf8');
  } catch (e) {
    if (e && e.code === 'ENOENT') return null;
    throw e;
  }
  const lines = text.split('\n');
  for (let i = 0; i < lines.length; i++) {
    // Strip a trailing CR so `$`-anchored patterns match CRLF checkouts
    // (Windows `core.autocrlf`); the returned text is the clean line.
    const line = lines[i].replace(/\r$/, '');
    if (pattern.test(line)) return { file: relPath, line: i + 1, text: line.trim() };
  }
  console.error(`FAIL: widelai rules source not found: ${label} (pattern ${pattern} in ${relPath})`);
  process.exit(1);
}

/**
 * Strip a leading list marker (`-`, `*`, `1.`) and a trailing colon from a
 * quoted source line, so the generated rules file reads as prose.
 *
 * @param {string} text - Raw source line.
 * @returns {string} The line without its list marker or trailing colon.
 */
function stripListMarker(text) {
  return text.replace(/^\s*(?:[-*]|\d+\.)\s*/, '').replace(/:\s*$/, '').trim();
}

/**
 * Generate the WidelCode rules file (`.widelai/rules/flowskill.md`) from the
 * multi-home rule sources (root AGENTS.md, CONTRIBUTING.md, law/CLAUDE.md,
 * attestations.md, cost-receipts.md, flow.sh). Runs at pack time, the only point with all
 * sources on disk. Returns the generated path, or null (with a loud warning)
 * when a source file is missing — partial trees skip generation instead of
 * shipping rules whose homes cannot be verified. In the skip case any
 * previously generated file is removed first, so a stale rules file can
 * never ship from a tree that lacks its sources.
 *
 * @returns {string | null} Path of the generated rules file, or null when skipped.
 */
function generateWidelaiRules() {
  // Rule homes live in the repo that owns the skill source: honor the
  // FLOW_SKILL_SRC override (out-of-tree dev checkouts and CI matrix), so an
  // out-of-tree sync never pairs an overridden skill with this repo's rules.
  const repoRoot = process.env.FLOW_SKILL_SRC
    ? resolve(src, '..', '..')
    : resolve(pkgRoot, '..');
  const conventions = findRulesSourceLine(repoRoot, 'AGENTS.md', /bash 3\.2-safe/, 'AGENTS.md conventions (bash 3.2-safe / zero new runtime deps)');
  const bashCompat = findRulesSourceLine(repoRoot, 'CONTRIBUTING.md', /Bash 3\.2 compatibility/, 'CONTRIBUTING.md bash 3.2 compatibility');
  const forkBranch = findRulesSourceLine(repoRoot, 'CONTRIBUTING.md', /Fork and branch/, 'CONTRIBUTING.md fork and branch');
  const branchPerCard = findRulesSourceLine(repoRoot, 'skills/flow/law/CLAUDE.md', /Branch per card/, 'law branch per card');
  const oneWorktree = findRulesSourceLine(repoRoot, 'skills/flow/law/CLAUDE.md', /One card = one worktree/, 'law one card = one worktree');
  const verdict = findRulesSourceLine(repoRoot, 'skills/flow/references/attestations.md', /^verdict: pass\|fail\|override$/, 'attestations verdict vocabulary');
  const chain = findRulesSourceLine(repoRoot, 'skills/flow/references/attestations.md', /^### Receipt chain/, 'attestations receipt chain section');
  const cost = findRulesSourceLine(repoRoot, 'skills/flow/references/cost-receipts.md', /Cost receipts are warn-only/, 'cost-receipts warn-only cost evidence');
  const warnOnly = findRulesSourceLine(repoRoot, 'skills/flow/runner/flow.sh', /warning-only stage semantic receipt/, 'flow.sh warning-only next');
  const sources = [conventions, bashCompat, forkBranch, branchPerCard, oneWorktree, verdict, chain, cost, warnOnly];
  const dest = join(pkgRoot, '.widelai', 'rules', 'flowskill.md');
  if (sources.some((s) => s === null)) {
    // Partial tree (no AGENTS.md/CONTRIBUTING.md on disk): the release
    // fixtures and any subtree copy hit this. Skip, loudly — the full repo
    // always has all nine sources, so a skip here is never a silent loss.
    // Remove any previously generated file first: a stale rules file must
    // never ship from a tree that lacks its sources.
    rmSync(dest, { force: true });
    console.warn('WARN: widelai rules skipped: a rules source file is missing from this tree (partial tree?); re-run `npm run sync` in the full repo to generate .widelai/rules/flowskill.md');
    return null;
  }

  const out = [
    '<!-- GENERATED — do not edit by hand. Generated by npm-wrapper/scripts/sync.mjs from the sources listed below; re-run `npm run sync` to regenerate. -->',
    '# FlowSkill rules (WidelCode)',
    '',
    'WidelCode reads this file from `.widelai/rules/flowskill.md` (project) or `~/.widelai/rules/flowskill.md` (personal defaults). Each rule is one line pointing at its home in the flow-skill repo — the home is the source of truth, never this file.',
    '',
    `- Work only on a branch or worktree: "${stripListMarker(branchPerCard.text)}" (home: ${branchPerCard.file}:${branchPerCard.line}) / "${stripListMarker(oneWorktree.text)}" (home: ${oneWorktree.file}:${oneWorktree.line}). Contributors: "${stripListMarker(forkBranch.text)}" (home: ${forkBranch.file}:${forkBranch.line})`,
    `- Shell is bash 3.2-safe; zero new runtime dependencies: "${stripListMarker(conventions.text)}" (home: ${conventions.file}:${conventions.line}; also ${bashCompat.file}:${bashCompat.line})`,
    `- Receipts use schema \`flow-attestation/v1\` (flat \`key: value\`; verdict \`pass|fail|override\` only). (home: ${verdict.file}:${verdict.line})`,
    `- Receipt integrity: \`flow attest verify-chain\` over \`.flow/attestations/chain.log\` (tamper-evident ledger). (home: ${chain.file}:${chain.line})`,
    `- Cost receipts use schema \`flow-cost/v1\` (flat \`key: value\`; warn-only accounting evidence, never a gate). (home: ${cost.file}:${cost.line})`,
    `- \`flow next\` is warning-only on a missing/stale semantic receipt — it never hard-blocks advancement, so no second gate needs to agree first. (home: ${warnOnly.file}:${warnOnly.line})`,
    '',
    'Not in this file (deliberately): maker/verifier separation, denied-action verdict mapping, and a deploy rule have no home in this repo, so they are not stated here. See the T1 PR description.',
    '',
  ].join('\n');
  mkdirSync(dirname(dest), { recursive: true });
  writeFileSync(dest, out);
  return dest;
}

const widelaiRulesPath = generateWidelaiRules();

console.log(`sync OK: ${dstFiles.length} files, skills-manifest.json emitted, widelai rules ${widelaiRulesPath ?? 'skipped (partial tree)'}, runner hash ${manifest.hashes[runnerRel].slice(0, 8)}...`);

// Dev-only: copy skill content from ../flow/flow-skill/skills/flow into ./skills/flow.
// Ships in dev repo only — excluded from published tarball via `files` allowlist in package.json.
//
// `--compare <extracted> <repo>` is an argv short-circuit BEFORE any copy. It walks both
// trees with the same shouldShip predicate used by the copy filter (Phase 7 will extend
// that one function — do not fork the exclusion list in bash).
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

  const extractedFiles = listFiles(extracted).sort();
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

// L25 — NO .integrity emission (circular trust). Rely on npm provenance for tamper detection.
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

console.log(`sync OK: ${dstFiles.length} files, skills-manifest.json emitted`);

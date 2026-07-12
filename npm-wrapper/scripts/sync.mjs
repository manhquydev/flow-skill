// Dev-only: copy skill content from ../flow/flow-skill/skills/flow into ./skills/flow.
// Ships in dev repo only — excluded from published tarball via `files` allowlist in package.json.
import {
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const pkgRoot = resolve(__dirname, '..');
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
});

// R19 completeness check — file list parity.
function listFiles(root, acc = [], base = root) {
  for (const entry of readdirSync(root)) {
    const p = join(root, entry);
    if (statSync(p).isDirectory()) listFiles(p, acc, base);
    else acc.push(relative(base, p).replace(/\\/g, '/'));
  }
  return acc;
}

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
writeFileSync(
  join(pkgRoot, 'skills-manifest.json'),
  JSON.stringify(
    {
      source: src,
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

import {
  appendFileSync,
  chmodSync,
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { createHash, randomBytes } from 'node:crypto';
import { dirname, isAbsolute, join, parse, resolve, sep } from 'node:path';
import { homedir } from 'node:os';

import { RULES_POINTER_LINE } from './constants.mjs';

export const RECEIPT_NAME = 'manifest-hashes.json';

// L24 — Retry the codes Windows emits when an agent (Claude Code, Codex, Antigravity) holds an
// open handle inside the destination. EACCES is intentionally excluded: on POSIX it is almost
// always a hard permission denial (stale sudo install, wrong owner) that will not clear in
// under a second. Retrying it just delays the honest error message.
export function withRetry(fn, opts = {}) {
  const attempts = opts.attempts ?? 3;
  const initialMs = opts.initialMs ?? 100;
  const retryableCodes = opts.codes ?? ['EBUSY', 'EPERM', 'ENOTEMPTY'];
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      return fn();
    } catch (err) {
      lastErr = err;
      if (!retryableCodes.includes(err?.code) || i === attempts - 1) throw err;
      // Blocking sleep — installer runs sequentially, this is fine.
      const wait = initialMs * Math.pow(3, i);
      const sab = new SharedArrayBuffer(4);
      Atomics.wait(new Int32Array(sab), 0, 0, wait);
    }
  }
  throw lastErr;
}

export function rmRecursiveWithRetry(target) {
  return withRetry(() => rmSync(target, { recursive: true, force: true }));
}

// L23 — Reject any symlink recursively. Defense against upstream skill-content symlink smuggling
// (e.g. symlink → /etc/passwd smuggled into skills/flow via compromised upstream).
export function assertNoSymlinks(root) {
  for (const entry of readdirSync(root)) {
    const p = join(root, entry);
    const st = lstatSync(p);
    if (st.isSymbolicLink()) {
      const err = new Error(`symlink rejected: ${p}`);
      err.code = 'ESYMLINK';
      throw err;
    }
    if (st.isDirectory()) assertNoSymlinks(p);
  }
}

// L29 — Advisory lock: best-effort concurrent-run prevention.
// Uses `writeFileSync` with `flag: 'wx'` (exclusive-create — fails with EEXIST if the
// file already exists) so the check + acquire are atomic. The previous TOCTOU version could have
// two `npx` processes both observe "no lock" and both acquire.
// Stale-lock recovery: on EEXIST, read the recorded PID; if that PID is dead (ESRCH), remove
// the file and retry the exclusive-create once. `process.kill(pid, 0)` on a live PID always
// succeeds, including our own PID — so a re-entrant call sees "held" and refuses, which is
// the correct behavior (install() is not re-entrant-safe).
// Accepted same-uid limitation (documented in SECURITY.md): the lock path is predictable and an
// existing path is read to decide staleness; a local same-uid attacker could pre-place it. No
// malicious-same-uid filesystem safety is claimed anywhere in this installer.
export function acquireLock(lockPath) {
  mkdirSync(dirname(lockPath), { recursive: true });
  try {
    writeFileSync(lockPath, String(process.pid), { flag: 'wx' });
    return { held: false };
  } catch (err) {
    if (err?.code !== 'EEXIST') throw err;
  }
  // Lock exists — decide stale vs. held.
  let pid = null;
  try {
    pid = Number(readFileSync(lockPath, 'utf8').trim());
  } catch {
    // corrupted lock content — treat as stale
  }
  if (Number.isFinite(pid) && pid > 0) {
    try {
      process.kill(pid, 0);
      return { held: true, pid };
    } catch (killErr) {
      if (killErr?.code !== 'ESRCH') return { held: true, pid };
    }
  }
  // Stale — remove and retry the exclusive-create exactly once.
  try {
    rmSync(lockPath, { force: true });
  } catch {
    /* ignore */
  }
  try {
    writeFileSync(lockPath, String(process.pid), { flag: 'wx' });
    return { held: false };
  } catch (retryErr) {
    // Something else raced in between our rm and our retry — treat as held.
    if (retryErr?.code === 'EEXIST') return { held: true, pid: null };
    throw retryErr;
  }
}

export function releaseLock(lockPath) {
  try {
    rmSync(lockPath, { force: true });
  } catch {
    /* ignore */
  }
}

// ---------------------------------------------------------------------------
// Ownership receipt (manifest-hashes.json) — strict contract, mirrors what
// `flow doctor` enforces on an installed tree.
// ---------------------------------------------------------------------------

function sha256File(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

// Canonical relative path: POSIX separators, no absolute form, no drive colon, no empty or
// `.`/`..` segments (same rules as doctor_helper.py verify-receipt).
function assertCanonicalRel(p) {
  if (typeof p !== 'string' || p.length === 0) return 'empty path';
  if (p.includes('\\')) return 'backslash in path';
  if (p.includes(':')) return 'drive colon in path';
  if (isAbsolute(p) || p.startsWith('/') || p.startsWith('~')) return 'absolute path';
  const segs = p.split('/');
  for (const s of segs) {
    if (s.length === 0) return 'empty segment';
    if (s === '.' || s === '..') return 'traversal segment';
  }
  return null;
}

// Duplicate-key check (SEMANTIC pass, runs only after JSON.parse already proved the
// grammar): a small token-aware recursive-descent walker. Strings are lexed with escape
// handling and each key token is decoded via JSON.parse of the raw token, so `"files"` and
// `"\u0066iles"` collide exactly as they do after parsing. Objects track a decoded-key Set
// per level; arrays walk values (never keys); string values are lexed and skipped without
// recording; primitives are skipped - grammar is already proven, so the walker only needs
// structure. Throws EDUPKEY on any repeated object key.
function rejectDuplicateKeys(text) {
  let i = 0;

  function skipString() {
    const start = i; // text[i] is the opening quote
    i++;
    while (i < text.length) {
      const c = text[i];
      if (c === '\\') {
        i += 2;
        continue;
      }
      if (c === '"') {
        i++;
        return text.slice(start, i);
      }
      i++;
    }
    throw new Error('unterminated string');
  }

  function parseValue() {
    while (i < text.length && /\s/.test(text[i])) i++;
    const c = text[i];
    if (c === '{') return parseObject();
    if (c === '[') return parseArray();
    if (c === '"') {
      const tok = skipString();
      JSON.parse(tok); // validate the escape sequence itself
      return;
    }
    while (i < text.length && !/[,\]}]/.test(text[i])) i++;
  }

  function parseObject() {
    i++; // consume '{'
    const keys = new Set();
    for (;;) {
      while (i < text.length && /\s/.test(text[i])) i++;
      if (text[i] === '}') { i++; return; }
      if (text[i] === ',') { i++; continue; }
      if (text[i] !== '"') throw new Error('expected object key string');
      const rawKey = skipString();
      let decoded;
      try {
        decoded = JSON.parse(rawKey);
      } catch {
        throw new Error('malformed key escape');
      }
      if (typeof decoded !== 'string') throw new Error('non-string object key');
      if (keys.has(decoded)) {
        const err = new Error(`duplicate key in receipt JSON: ${decoded}`);
        err.code = 'EDUPKEY';
        throw err;
      }
      keys.add(decoded);
      while (i < text.length && /\s/.test(text[i])) i++;
      if (text[i] !== ':') throw new Error('expected colon after key');
      i++;
      parseValue();
    }
  }

  function parseArray() {
    i++; // consume '['
    for (;;) {
      while (i < text.length && /\s/.test(text[i])) i++;
      if (text[i] === ']') { i++; return; }
      if (text[i] === ',') { i++; continue; }
      parseValue();
    }
  }

  parseValue();
}

// Prototype-less data map: untrusted keys like `__proto__` stay plain data (no inherited
// reads, no setter collisions).
function nullProtoMap(obj) {
  const out = Object.create(null);
  for (const k of Object.keys(obj)) out[k] = obj[k];
  return out;
}

// Parse + validate a receipt document. Throws Error with a precise message on any violation.
export function readOwnershipReceipt(root, receiptPath = join(root, RECEIPT_NAME)) {
  let st;
  try {
    st = lstatSync(receiptPath);
  } catch {
    throw new Error(`ownership receipt missing: ${receiptPath}`);
  }
  if (st.isSymbolicLink()) throw new Error(`ownership receipt must not be a symlink: ${receiptPath}`);
  if (!st.isFile()) throw new Error(`ownership receipt is not a regular file: ${receiptPath}`);
  const text = readFileSync(receiptPath, 'utf8');
  // Grammar first (a malformed document must not reach the structure walker), then the
  // duplicate-key walk over the proven-valid token stream.
  let doc;
  try {
    doc = JSON.parse(text);
  } catch (err) {
    throw new Error(`ownership receipt is not valid JSON: ${err.message}`);
  }
  rejectDuplicateKeys(text);
  if (doc?.schema_version !== 1) throw new Error(`receipt schema_version must be 1`);
  const files = doc.files;
  if (!files || typeof files !== 'object' || Array.isArray(files)) {
    throw new Error(`receipt "files" map missing`);
  }
  const names = Object.keys(files);
  if (names.length === 0) throw new Error(`receipt lists no files`);
  const safe = Object.create(null);
  for (const rel of names) {
    const bad = assertCanonicalRel(rel);
    if (bad) throw new Error(`receipt path ${rel}: ${bad}`);
    const digest = files[rel];
    if (
      typeof digest !== 'string' ||
      digest.length !== 64 ||
      !/^[0-9a-f]{64}$/.test(digest)
    ) {
      throw new Error(`receipt digest for ${rel} is not 64-hex`);
    }
    if (rel === RECEIPT_NAME) throw new Error(`receipt must not list itself`);
    safe[rel] = digest;
  }
  return safe;
}

// Verify every receipted path exists under root as a regular file with the receipted digest.
// Read-only: never mutates anything. Throws on first mismatch with a precise message.
export function verifyTreeAgainstReceipt(root, files, { rootLabel = 'tree' } = {}) {
  for (const rel of Object.keys(files)) {
    const p = join(root, rel);
    let st;
    try {
      st = lstatSync(p);
    } catch {
      throw new Error(`${rootLabel}: receipted file missing: ${rel}`);
    }
    if (st.isSymbolicLink() || !st.isFile()) {
      throw new Error(`${rootLabel}: receipted path is not a regular file: ${rel}`);
    }
    const actual = sha256File(p);
    if (actual !== files[rel]) {
      throw new Error(`${rootLabel}: digest mismatch for ${rel}`);
    }
  }
}

// Generate ownership receipt content from every regular file in root (excluding the receipt
// itself). Source tree must already be symlink-free (assertNoSymlinks runs before this).
export function generateReceipt(root) {
  const files = manifestFromTree(root);
  return JSON.stringify({ schema_version: 1, files }, null, 2) + '\n';
}

// Hash every regular file under root (excluding the receipt itself) into an ownership map.
// Used for authored source checkouts that ship without a receipt.
export function manifestFromTree(root) {
  const files = Object.create(null);
  const walk = (dir, prefix) => {
    for (const entry of readdirSync(dir)) {
      const p = join(dir, entry);
      const rel = prefix ? `${prefix}/${entry}` : entry;
      if (rel === RECEIPT_NAME) continue;
      const st = lstatSync(p);
      if (st.isSymbolicLink()) throw new Error(`symlink rejected: ${p}`);
      if (st.isDirectory()) walk(p, rel);
      else if (st.isFile()) files[rel] = sha256File(p);
    }
  };
  walk(root, '');
  return files;
}

// Refuse when source and dest resolve to the same tree or one contains the other.
function assertDisjoint(sourceDir, destDir) {
  const s = resolve(sourceDir);
  const d = resolve(destDir);
  if (s === d) throw new Error(`source and destination are the same directory: ${s}`);
  if (d.startsWith(s + sep)) throw new Error(`destination ${d} is inside source ${s}`);
  if (s.startsWith(d + sep)) throw new Error(`source ${s} is inside destination ${d}`);
}

// Refuse when any ancestor of rawPath (or rawPath itself) is a symlink.
// Walks unnormalized path components as spelled BEFORE resolving '..' so that
// bypasses like '/tmp/symlink/../dest' are caught when the symlink component is visited.
function assertNoAncestorSymlinks(rawPath, label = 'destination') {
  if (typeof rawPath !== 'string' || !rawPath) return;

  const isAbs = isAbsolute(rawPath) || rawPath.startsWith('/') || rawPath.startsWith('\\');
  const cwd = process.cwd();
  const sep = (process.platform === 'win32' && cwd.includes('\\')) ? '\\' : '/';
  const rawCombined = isAbs ? rawPath : `${cwd.replace(/[/\\]+$/, '')}${sep}${rawPath}`;
  const parsedRoot = parse(rawCombined).root; // '/' on POSIX, 'C:\\' on Windows
  const rest = rawCombined.slice(parsedRoot.length);
  const segs = rest.split(/[/\\]+/).filter(Boolean);

  let cur = parsedRoot;
  for (const seg of segs) {
    if (seg === '.') continue;
    if (seg === '..') {
      try {
        const st = lstatSync(cur);
        if (st.isSymbolicLink()) {
          throw new Error(`${label} ancestor symlink refused: ${cur}`);
        }
      } catch (err) {
        if (err.code !== 'ENOENT') throw err;
      }
      cur = dirname(cur);
      continue;
    }

    cur = cur === parsedRoot ? join(cur, seg) : join(cur, seg);
    try {
      const st = lstatSync(cur);
      if (st.isSymbolicLink()) {
        throw new Error(`${label} ancestor symlink refused: ${cur}`);
      }
    } catch (err) {
      if (err.code !== 'ENOENT') throw err;
    }
  }
}
// Refuse when any entry inside the destination tree (any depth) is a symlink. lstat-based —
// a broken symlink is still a symlink and still refused. Runs BEFORE the old receipt is read
// or any dest byte is hashed.
function assertNoDestSymlinks(root) {
  const walk = (dir, prefix) => {
    for (const entry of readdirSync(dir)) {
      const p = join(dir, entry);
      const rel = prefix ? `${prefix}/${entry}` : entry;
      const st = lstatSync(p);
      if (st.isSymbolicLink()) {
        const err = new Error(`destination symlink refused: ${rel}`);
        err.code = 'EDESTSYMLINK';
        throw err;
      }
      if (st.isDirectory()) walk(p, rel);
    }
  };
  walk(root, '');
}

// Relative paths of destination entries that are neither regular files nor directories nor
// symlinks (FIFOs, sockets, devices). Symlinks are handled by assertNoDestSymlinks first.
function listSpecialFiles(root) {
  const out = [];
  const walk = (dir, prefix) => {
    for (const entry of readdirSync(dir)) {
      const p = join(dir, entry);
      const rel = prefix ? `${prefix}/${entry}` : entry;
      const st = lstatSync(p);
      if (st.isDirectory()) walk(p, rel);
      else if (!st.isFile()) out.push(rel);
    }
  };
  walk(root, '');
  return out;
}

function listRelativeFiles(root) {
  const out = [];
  const walk = (dir, prefix) => {
    for (const entry of readdirSync(dir)) {
      const p = join(dir, entry);
      const rel = prefix ? `${prefix}/${entry}` : entry;
      const st = lstatSync(p);
      if (st.isDirectory()) walk(p, rel);
      else if (st.isFile()) out.push(rel);
    }
  };
  if (existsSync(root)) walk(root, '');
  return out;
}

function ensureDir(dir) {
  mkdirSync(dir, { recursive: true });
}

// Core install — transactional, ownership-receipt based (replaces the old
// rm-cleanup-subdirs + merge-copy contract):
//   1. strict source receipt validation + digest re-verification (read-only)
//   2. read-only dest survey: conflicts / root mismatch / legacy collisions collected
//      up front; any hit aborts BEFORE the original destination is touched
//   3. staged candidate: receipted source files + preserved user customs + preserved
//      retired-modified files − pruned retired files; fresh receipt generated from the
//      staged bytes
//   4. rename-only backup of the existing dest, rename promote, promoted-receipt
//      verification; backup removed only after verification (never the sole old bytes
//      on a failure path — a failed restore keeps the backup and reports its path)
//
// `io.rename` is the only injection seam (used by failure-path tests); production callers
// never pass it.
export function install({
  sourceDir,
  destDir,
  dryRun = false,
  io = { rename: (a, b) => withRetry(() => renameSync(a, b)) },
}) {
  if (dryRun) return { success: true, dest: destDir, dryRun: true, warnings: [] };

  const rename = io.rename;
  const lockPath = join(dirname(destDir), '.flow-skill.installing.lock');
  const warnings = [];
  let lockHeld = false;

  try {
    // ---- strict input validation (nothing mutated, no dirs created yet) ------
    // All source/dest type + path validation happens BEFORE the lock is acquired,
    // because acquireLock() mkdirs the parent and we must not touch the filesystem
    // before we know the inputs are sane.
    // 1. Ancestor symlink checks on raw path spellings BEFORE any file reads or collapses
    assertNoAncestorSymlinks(sourceDir, 'source');
    assertNoAncestorSymlinks(destDir, 'destination');

    // 2. Disjoint check
    assertDisjoint(sourceDir, destDir);

    // 3. Source directory and symlink checks
    const sourceSt = lstatSync(sourceDir);
    if (sourceSt.isSymbolicLink()) throw new Error(`source is a symlink: ${sourceDir}`);
    if (!sourceSt.isDirectory()) throw new Error(`source is not a directory: ${sourceDir}`);
    if (resolve(sourceDir) === resolve(sep)) throw new Error(`source is the filesystem root`);
    assertNoSymlinks(sourceDir);

    // 4. Source SKILL.md presence check (safe now: source ancestry and tree are verified)
    if (!existsSync(join(sourceDir, 'SKILL.md'))) {
      throw new Error(
        `SKILL.md missing in sourceDir=${sourceDir} (did you run 'npm run sync'?)`
      );
    }

    // 5. Destination checks
    let destSt = null;
    try {
      destSt = lstatSync(destDir);
    } catch {
      /* fresh install */
    }
    if (destSt && destSt.isSymbolicLink()) {
      throw new Error(`destination is a symlink: ${destDir}`);
    }
    if (destSt && !destSt.isDirectory()) {
      throw new Error(`destination exists and is not a directory: ${destDir}`);
    }
    if (resolve(destDir) === resolve(sep)) throw new Error(`destination is the filesystem root`);

    // Source ownership manifest. Policy (director-authorized): an authored source checkout
    // WITHOUT a receipt is acceptable — build the manifest by hashing the read-only source
    // bytes. A receipt that EXISTS must be strictly valid and digest-verified; invalid →
    // reject. The installed dest gets no such allowance (legacy collision guard below).
    let sourceFiles = null;
    if (existsSync(join(sourceDir, RECEIPT_NAME))) {
      sourceFiles = readOwnershipReceipt(sourceDir);
      verifyTreeAgainstReceipt(sourceDir, sourceFiles, { rootLabel: 'source' });
    } else {
      sourceFiles = manifestFromTree(sourceDir);
    }

    // Receipt coverage completeness: the source manifest must describe EXACTLY the source
    // tree (minus the receipt itself). A subset would silently skip phantom files; extras
    // would be ownership lies. Either direction → reject.
    {
      const diskFiles = new Set(listRelativeFiles(sourceDir));
      diskFiles.delete(RECEIPT_NAME);
      const receiptKeys = new Set(Object.keys(sourceFiles));
      for (const rel of diskFiles) {
        if (!receiptKeys.has(rel)) {
          throw new Error(
            `source receipt does not cover the source tree (unreceiped file present): ${rel}`
          );
        }
      }
      for (const rel of receiptKeys) {
        if (!diskFiles.has(rel)) {
          throw new Error(
            `source receipt lists a file the source tree does not have (phantom entry): ${rel}`
          );
        }
      }
    }

    // Inputs are valid — acquire the per-destination advisory lock before the survey/build.
    const lock = acquireLock(lockPath);
    if (lock.held) {
      return {
        success: false,
        dest: destDir,
        error: `another install in progress (pid ${lock.pid}); wait or remove ${lockPath}`,
        warnings,
      };
    }
    lockHeld = true;

    // ---- read-only dest survey ----------------------------------------------
    const destExists = Boolean(destSt);
    let oldFiles = null; // null = no old receipt (fresh or legacy dest)
    let legacyDest = false;
    if (destExists) {
      // Refuse ANY symlink in the destination tree BEFORE reading the old receipt or hashing
      // anything — hashing through a link would validate the redirect target, not the tree,
      // and a skipped user symlink would be destroyed by the swap.
      assertNoDestSymlinks(destDir);
      // Receipt presence must use lstat (no-follow): a broken symlink at the receipt path is
      // still a receipt-shaped file and must be rejected, never downgraded to "legacy dest".
      const receiptSt = lstatSync(join(destDir, RECEIPT_NAME), { throwIfNoEntry: false });
      if (receiptSt !== undefined) {
        oldFiles = readOwnershipReceipt(destDir); // throws on invalid → dest untouched
        delete oldFiles[RECEIPT_NAME]; // old receipt is replaced, never a custom
      } else {
        legacyDest = true; // genuinely no receipt at all
      }
    }

    const conflicts = [];
    const retiredRemoved = [];
    const retiredPreserved = [];
    const preserved = [];
    const newSet = new Set(Object.keys(sourceFiles));
    newSet.delete(RECEIPT_NAME); // the candidate always gets a freshly generated receipt

    if (destExists) {
      // Non-regular, non-directory special files (FIFOs, sockets, devices) cannot be copied
      // into the candidate; ignoring them would destroy them in the swap. Refuse explicitly.
      for (const rel of listSpecialFiles(destDir)) {
        conflicts.push(`destination special file refused: ${rel}`);
      }
      for (const rel of Object.keys(oldFiles ?? {})) {
        const destPath = join(destDir, rel);
        const st = lstatSync(destPath, { throwIfNoEntry: false });
        if (st === undefined) {
          conflicts.push(`receipted file missing from destination (receipt/root mismatch): ${rel}`);
          continue;
        }
        if (!st.isFile()) {
          conflicts.push(`receipted path is not a regular file: ${rel}`);
          continue;
        }
        const disk = sha256File(destPath);
        if (disk !== oldFiles[rel]) {
          if (!newSet.has(rel)) {
            // retired and user-modified → preserved into candidate (reported, not deleted)
            retiredPreserved.push(rel);
          } else {
            // still shipped, user modified an owned file → hard conflict
            conflicts.push(`user-modified owned file: ${rel}`);
          }
        } else if (!newSet.has(rel)) {
          retiredRemoved.push(rel);
        }
      }
      // Unowned-dest-path collision guard, applied for receipted AND legacy dests alike:
      // a dest file at a path the OLD receipt does not own but the NEW source ships must
      // either match the new source bytes exactly (idempotent) or refuse as a conflict.
      for (const rel of newSet) {
        if (oldFiles && Object.hasOwn(oldFiles, rel)) continue; // owned path handled above
        const destPath = join(destDir, rel);
        if (existsSync(destPath) && sha256File(destPath) !== sourceFiles[rel]) {
          conflicts.push(
            `${legacyDest ? 'legacy destination' : 'unowned destination file'} collision with differing bytes: ${rel}`
          );
        }
      }
    }
    if (conflicts.length) {
      const err = new Error(
        `install refused before touching ${destDir}:\n  - ${conflicts.join('\n  - ')}\n` +
          `Resolve manually (no --force exists by design).`
      );
      err.code = 'ECONFLICT';
      throw err;
    }

    // ---- build staged candidate ---------------------------------------------
    const destParent = dirname(destDir);
    ensureDir(destParent);
    const stageDir = mkdtempSync(join(destParent, '.flow-skill-stage-')); // private 0700, random
    const backupSlot = join(destParent, `.flow-skill-backup-${randomBytes(8).toString('hex')}`);
    const failedSlot = join(destParent, `.flow-skill-failed-${randomBytes(8).toString('hex')}`);

    try {
      // Copy ONLY the new source-owned files; verify every staged copy byte-for-byte against
      // the source manifest (guards against disk/copy corruption before any swap happens).
      const stagedReceipt = Object.create(null);
      for (const rel of newSet) {
        const src = join(sourceDir, rel);
        const dst = join(stageDir, rel);
        ensureDir(dirname(dst));
        writeFileSync(dst, readFileSync(src));
        const stagedDigest = sha256File(dst);
        if (stagedDigest !== sourceFiles[rel]) {
          throw new Error(`staged copy of ${rel} does not match verified source bytes`);
        }
        stagedReceipt[rel] = stagedDigest;
      }
      if (destExists) {
        // preserve user-modified retired files + all unowned customs (anywhere in dest) —
        // for receipted AND legacy (no-old-receipt) destinations alike; the old receipt
        // file itself is replaced by the fresh one, never preserved
        for (const rel of retiredPreserved) {
          const dst = join(stageDir, rel);
          ensureDir(dirname(dst));
          writeFileSync(dst, readFileSync(join(destDir, rel)));
        }
        for (const rel of listRelativeFiles(destDir)) {
          if (
            rel === RECEIPT_NAME ||
            (oldFiles && Object.hasOwn(oldFiles, rel)) ||
            newSet.has(rel) ||
            retiredPreserved.includes(rel)
          ) {
            continue;
          }
          const dst = join(stageDir, rel);
          ensureDir(dirname(dst));
          writeFileSync(dst, readFileSync(join(destDir, rel)));
          preserved.push(rel);
        }
      }
      // The fresh receipt owns ONLY the new source-owned files (digests from the staged
      // copies). Preserved customs / modified-retired files are deliberately NOT in it —
      // otherwise a future upgrade would prune the user's own files as stale.
      writeFileSync(
        join(stageDir, RECEIPT_NAME),
        JSON.stringify({ schema_version: 1, files: stagedReceipt }, null, 2) + '\n'
      );
      const runnerScript = join(stageDir, 'runner', 'flow.sh');
      if (existsSync(runnerScript)) {
        try {
          chmodSync(runnerScript, 0o755);
        } catch (err) {
          warnings.push(`chmod +x runner/flow.sh failed: ${err.message}`);
        }
      }

      // ---- atomic swap with recovery ----------------------------------------
      // Promote AND verify inside one recovery scope: any failure (rename or post-promote
      // receipt verification) first quarantines the known bad candidate, then restores the
      // original via rename. The backup is NEVER cleaned up on a failure path.
      let backupPath = null;
      if (destExists) {
        rename(destDir, backupSlot);
        backupPath = backupSlot;
      }
      try {
        rename(stageDir, destDir);
        // Verify the promoted tree against the IMMUTABLE expected receipt (stagedReceipt):
        // self-consistency of whatever JSON sits in dest would accept a corrupted or
        // substituted candidate. Keyset equality + per-key digest equality + byte digests.
        const promoted = readOwnershipReceipt(destDir);
        const promotedKeys = Object.keys(promoted).sort();
        const expectedKeys = Object.keys(stagedReceipt).sort();
        if (
          promotedKeys.length !== expectedKeys.length ||
          promotedKeys.some((k, i) => k !== expectedKeys[i])
        ) {
          throw new Error(
            `promoted receipt keyset differs from staged expectation ` +
              `(promoted ${promotedKeys.length}, expected ${expectedKeys.length})`
          );
        }
        for (const rel of expectedKeys) {
          if (promoted[rel] !== stagedReceipt[rel]) {
            throw new Error(`promoted receipt digest differs from staged expectation: ${rel}`);
          }
        }
        verifyTreeAgainstReceipt(destDir, stagedReceipt, { rootLabel: 'installed' });
      } catch (swapErr) {
        // Quarantine the known bad candidate by RENAME ONLY. If the rename fails, the
        // candidate stays exactly where it is: we never restore onto an occupied
        // destination and never recursively delete at the destination path (a same-uid
        // concurrent actor must not be able to turn a recovery path into a deletion).
        let quarantined = false;
        let candidateGone = !existsSync(destDir);
        if (!candidateGone) {
          try {
            rename(destDir, failedSlot);
            quarantined = true;
            candidateGone = true;
          } catch {
            // leave the failed candidate at destDir; report it as failedCandidatePath
          }
        }
        let restored = false;
        let restoreErr = null;
        if (backupPath && candidateGone) {
          // Restore only onto a now-empty destination path.
          try {
            rename(backupPath, destDir);
            restored = true;
          } catch (err) {
            restoreErr = err;
          }
        }
        if (backupPath && !restored) {
          // Rollback impossible (restore rename failed, or destination still occupied by
          // the quarantined candidate): KEEP the backup (sole old bytes) and report both
          // paths as DATA — no executable inline command, no inferred state.
          try {
            rmSync(stageDir, { recursive: true, force: true });
          } catch {
            /* ignore */
          }
          return {
            success: false,
            dest: destDir,
            code: 'EROLLBACK',
            recoveryPath: backupPath,
            failedCandidatePath: quarantined ? failedSlot : destDir,
            partialState: quarantined
              ? 'destination path empty; failed candidate at failedCandidatePath; original tree intact inside recoveryPath'
              : 'failed candidate still at the destination path (quarantine rename failed); original tree intact inside recoveryPath',
            error:
              `transaction failed (${swapErr.message}); rollback not completed ` +
              `(${restored ? '' : restoreErr?.message ?? (quarantined ? 'destination still occupied by failed candidate' : 'unknown')}); ` +
              `ORIGINAL DESTINATION PRESERVED AT "${backupPath}"`,
            warnings,
          };
        }
        try {
          rmSync(stageDir, { recursive: true, force: true });
        } catch {
          /* ignore */
        }
        if (quarantined) {
          // failed candidate moved aside; on a successful restore it holds no user bytes we
          // must keep beyond diagnosis — remove it, never touching the restored original.
          try {
            rmSync(failedSlot, { recursive: true, force: true });
          } catch (err) {
            warnings.push(`failed-candidate cleanup failed (kept at ${failedSlot}): ${err.message}`);
          }
        }
        const e =
          swapErr?.code === 'ECONFLICT' || swapErr?.code === 'EDUPKEY'
            ? swapErr
            : new Error(
                `transaction failed (${swapErr.message}); ` +
                  (restored
                    ? 'original destination restored exactly; candidate removed'
                    : 'fresh install: candidate removed; no destination remains (no prior destination existed)')
              );
        if (e !== swapErr) e.code = swapErr?.code ?? 'ESWAP';
        throw e;
      }

      if (backupPath) {
        try {
          rmRecursiveWithRetry(backupPath);
        } catch (err) {
          warnings.push(`backup cleanup failed (kept at ${backupPath}): ${err.message}`);
        }
      }
      return {
        success: true,
        dest: destDir,
        warnings,
        files: newSet.size,
        receiptGenerated: true,
        preserved,
        retiredRemoved,
        retiredPreserved,
      };
    } catch (err) {
      // Best-effort stage cleanup; never remove a backup here (sole old bytes).
      try {
        rmSync(stageDir, { recursive: true, force: true });
      } catch {
        /* ignore */
      }
      throw err;
    }
  } catch (err) {
    return {
      success: false,
      dest: destDir,
      error: String(err?.message ?? err),
      code: err?.code ?? null,
      recoveryPath: err?.recoveryPath ?? null,
      warnings,
    };
  } finally {
    if (lockHeld) releaseLock(lockPath);
  }
}

// L28 (revised per phase-01 review F1) — Antigravity has 2 destinations under one target.
// Each destination is an independent transaction with its own receipt and backup. If the
// second fails after the first succeeded we do NOT roll back the first; the result says
// exactly which destinations are installed (per-destination truth, never a global
// atomic claim). Rolling back dest 1 would destroy freshly-installed valid content.
export function installAntigravity({ sourceDir, dests, dryRun = false }) {
  if (!Array.isArray(dests) || dests.length === 0) {
    return { success: false, error: 'no destinations provided' };
  }
  if (dryRun) return { success: true, dests, dryRun: true, warnings: [] };

  const attempts = [];
  for (let i = 0; i < dests.length; i++) {
    const r = install({ sourceDir, destDir: dests[i] });
    attempts.push({
      dest: dests[i],
      success: r.success,
      error: r.error ?? null,
      preserved: r.preserved ?? [],
      retiredRemoved: r.retiredRemoved ?? [],
      retiredPreserved: r.retiredPreserved ?? [],
    });
    if (!r.success) {
      const warnings = attempts.flatMap((a, idx) =>
        idx < i
          ? [`dest ${idx + 1} (${dests[idx]}) installed successfully with its own receipt; not rolled back`]
          : []
      );
      return {
        success: false,
        dests,
        attempts,
        error: `dest ${i + 1} failed: ${r.error}`,
        warnings,
      };
    }
  }
  return { success: true, dests, attempts, warnings: [] };
}

// WidelCode extras (T1) — places the generated rules file + AGENTS.md pointer
// line for the widelai target. Runs BEFORE the skill install (fail fast): a
// rules-file conflict aborts before the skill tree is touched, and a
// skill-install failure afterwards leaves only a harmless, idempotent rules
// file behind. Never overwrites user content: an existing rules file with
// differing bytes is a hard refusal (no --force exists by design); an
// existing AGENTS.md is only appended to, never rewritten. The pointer line
// is a discoverability aid — WidelCode already reads `.widelai/rules/*.md`
// natively (vendor docs), so the line's absence would not hide the rules.
//
// Concurrency: extras updates are serialized with an advisory lock under
// ~/.widelai (same acquireLock discipline as install()). The pointer is
// appended with a single appendFileSync, never read-modify-write, so a
// concurrent editor's changes cannot be lost between a read and a write.
// Destinations must be regular files: symlinks, directories and FIFOs are
// refused (a FIFO would hang the read below).
//
// @param {object} opts
// @param {string} opts.pkgRoot - npm-wrapper root holding `.widelai/rules/`.
// @param {string} [opts.home=homedir()] - User home owning `~/.widelai`.
// @returns {{ rulesDest: string, rulesWritten: boolean, agentsPath: string, pointerAppended: boolean }}
//   Paths written and whether this run wrote the rules file / appended the pointer.
export function installWidelaiExtras({ pkgRoot, home = homedir() }) {
  const rulesSrc = join(pkgRoot, '.widelai', 'rules', 'flowskill.md');
  // The generated file must be a regular file: a package-provided symlink
  // would copy arbitrary local bytes into WidelCode's rules file.
  let srcStat;
  try {
    srcStat = lstatSync(rulesSrc);
  } catch (err) {
    if (err.code === 'ENOENT') {
      throw new Error(
        `generated WidelCode rules file missing: ${rulesSrc} (run 'npm run sync' inside npm-wrapper/, or reinstall from a complete package)`
      );
    }
    throw err;
  }
  if (!srcStat.isFile()) {
    throw new Error(`generated WidelCode rules file is not a regular file: ${rulesSrc}`);
  }
  const rulesDest = join(home, '.widelai', 'rules', 'flowskill.md');
  const agentsPath = join(home, '.widelai', 'AGENTS.md');

  // Serialize concurrent extras updates: the check-then-append sequence is
  // not atomic on its own, so two processes could both observe "pointer
  // missing" and append a duplicate. Wait boundedly for a live holder, then
  // fail loudly instead of proceeding unserialized.
  //
  // Validate destination ancestors BEFORE acquireLock(): the lock file lives
  // under ~/.widelai and acquireLock() mkdirs that path, so a symlinked home
  // or .widelai would get the redirected directory created before the
  // promised symlink refusal. Rejected installs must stay side-effect-free.
  assertNoAncestorSymlinks(rulesDest, 'widelai rules destination');
  assertNoAncestorSymlinks(agentsPath, 'widelai AGENTS.md destination');
  const extrasLockPath = join(home, '.widelai', '.flow-skill.widelai-extras.lock');
  let lock = acquireLock(extrasLockPath);
  let waited = 0;
  while (lock.held && waited < 50) {
    // 100 ms sleep — same Atomics.wait technique as withRetry.
    const sab = new SharedArrayBuffer(4);
    Atomics.wait(new Int32Array(sab), 0, 0, 100);
    waited += 1;
    lock = acquireLock(extrasLockPath);
  }
  if (lock.held) {
    throw new Error(
      `another WidelCode extras update in progress (pid ${lock.pid ?? 'unknown'}); retry the install`
    );
  }
  try {
    return installWidelaiExtrasLocked({ rulesSrc, rulesDest, agentsPath });
  } finally {
    releaseLock(extrasLockPath);
  }
}

/**
 * Locked body of installWidelaiExtras: destination checks and writes, run
 * while the caller holds the extras lock. Kept separate so the lock
 * acquire/release stays visible in installWidelaiExtras.
 *
 * @param {object} opts
 * @param {string} opts.rulesSrc - Generated rules file inside the package.
 * @param {string} opts.rulesDest - Destination `~/.widelai/rules/flowskill.md`.
 * @param {string} opts.agentsPath - Destination `~/.widelai/AGENTS.md`.
 * @returns {{ rulesDest: string, rulesWritten: boolean, agentsPath: string, pointerAppended: boolean }}
 */
function installWidelaiExtrasLocked({ rulesSrc, rulesDest, agentsPath }) {
  // Refuse symlinks at the destination paths (same discipline as install()),
  // and require existing destinations to be regular files.
  for (const p of [rulesDest, agentsPath]) {
    let st;
    try {
      st = lstatSync(p);
    } catch (err) {
      if (err.code !== 'ENOENT') throw err;
      continue;
    }
    if (st.isSymbolicLink()) throw new Error(`destination is a symlink: ${p}`);
    if (!st.isFile()) throw new Error(`destination is not a regular file: ${p}`);
  }
  // Pre-lock checks are a snapshot: re-refuse ancestor symlinks under the
  // lock so a path swapped in between check and write is rejected too.
  assertNoAncestorSymlinks(rulesDest, 'widelai rules destination');
  assertNoAncestorSymlinks(agentsPath, 'widelai AGENTS.md destination');

  const generated = readFileSync(rulesSrc);
  let rulesWritten = false;
  if (existsSync(rulesDest)) {
    if (Buffer.compare(readFileSync(rulesDest), generated) !== 0) {
      throw new Error(
        `widelai rules file exists with different content (user-edited?): ${rulesDest} — refusing to overwrite; resolve manually`
      );
    }
  } else {
    mkdirSync(dirname(rulesDest), { recursive: true });
    try {
      // Exclusive create: a concurrent installer creating the file between
      // the check above and this write must not have its bytes overwritten.
      writeFileSync(rulesDest, generated, { flag: 'wx' });
      rulesWritten = true;
    } catch (err) {
      if (err.code !== 'EEXIST') throw err;
      // Created concurrently after our check: accept byte-identical content,
      // refuse anything else — same guard as the existsSync branch.
      if (Buffer.compare(readFileSync(rulesDest), generated) !== 0) {
        throw new Error(
          `widelai rules file exists with different content (user-edited?): ${rulesDest} — refusing to overwrite; resolve manually`
        );
      }
    }
  }

  let pointerAppended = false;
  if (existsSync(agentsPath)) {
    const current = readFileSync(agentsPath, 'utf8');
    // Split on /\r?\n/ so a CRLF pointer is recognized (no duplicate append).
    if (!current.split(/\r?\n/).includes(RULES_POINTER_LINE)) {
      const nl = current.length > 0 && !current.endsWith('\n') ? '\n' : '';
      appendFileSync(agentsPath, nl + RULES_POINTER_LINE + '\n');
      pointerAppended = true;
    }
  } else {
    mkdirSync(dirname(agentsPath), { recursive: true });
    try {
      // Exclusive create: never truncate a file created concurrently.
      writeFileSync(agentsPath, RULES_POINTER_LINE + '\n', { flag: 'wx' });
      pointerAppended = true;
    } catch (err) {
      if (err.code !== 'EEXIST') throw err;
      // Created concurrently after our check: append the pointer if it is
      // still missing (the lock makes this a rare fallback, not the norm).
      const current = readFileSync(agentsPath, 'utf8');
      if (!current.split(/\r?\n/).includes(RULES_POINTER_LINE)) {
        const nl = current.length > 0 && !current.endsWith('\n') ? '\n' : '';
        appendFileSync(agentsPath, nl + RULES_POINTER_LINE + '\n');
        pointerAppended = true;
      }
    }
  }

  return { rulesDest, rulesWritten, agentsPath, pointerAppended };
}

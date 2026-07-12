import {
  chmodSync,
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join } from 'node:path';

import { CLEANUP_SUBDIRS } from './constants.mjs';

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
// Uses `writeFileSync` with `flag: 'wx'` (exclusive-create — fails with EEXIST if the file
// already exists) so the check + acquire are atomic. The previous TOCTOU version could have
// two `npx` processes both observe "no lock" and both acquire.
// Stale-lock recovery: on EEXIST, read the recorded PID; if that PID is dead (ESRCH), remove
// the file and retry the exclusive-create once. `process.kill(pid, 0)` on a live PID always
// succeeds, including our own PID — so a re-entrant call sees "held" and refuses, which is
// the correct behavior (install() is not re-entrant-safe).
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

// Core install — parity with install.sh:24-27:
//   rm -rf <dest>/{runner,_templates,law,references,harness,playbooks}
//   cp -r <sourceDir>/. <dest>/
//   chmod +x <dest>/runner/flow.sh
// This intentionally preserves any user files in <dest> outside the 6 cleanup subdirs.
export function install({
  sourceDir,
  destDir,
  cleanupSubdirs = CLEANUP_SUBDIRS,
  dryRun = false,
}) {
  if (dryRun) return { success: true, dest: destDir, dryRun: true, warnings: [] };

  const lockPath = join(dirname(destDir), '.flow-skill.installing.lock');
  const warnings = [];
  let lockHeld = false;

  try {
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

    if (!existsSync(join(sourceDir, 'SKILL.md'))) {
      throw new Error(
        `SKILL.md missing in sourceDir=${sourceDir} (did you run 'npm run sync'?)`
      );
    }
    // Pre-scan source before touching dest.
    assertNoSymlinks(sourceDir);

    mkdirSync(destDir, { recursive: true });

    // Cleanup the 6 subdirs — matches install.sh:25.
    for (const sub of cleanupSubdirs) {
      const p = join(destDir, sub);
      if (existsSync(p)) rmRecursiveWithRetry(p);
    }

    // Merge copy — matches install.sh:26. External files outside CLEANUP_SUBDIRS are preserved.
    withRetry(() =>
      cpSync(sourceDir, destDir, {
        recursive: true,
        force: true,
        dereference: false,
        errorOnBrokenSymbolicLinks: true,
        preserveTimestamps: true,
      })
    );

    // (Post-copy symlink rescan removed) — the source scan above already vets every file we
    // wrote; scanning the destination additionally rejects legitimate NTFS junctions users
    // may have placed under `~/.claude/skills/flow/` for their own reasons. install.sh does
    // not have this restriction (`cp -r` merges over junctions fine) and the parity contract
    // says we don't either.

    // chmod +x runner/flow.sh — matches install.sh:27. No-op on Windows (NTFS ignores the bit).
    const runnerScript = join(destDir, 'runner', 'flow.sh');
    if (existsSync(runnerScript)) {
      try {
        chmodSync(runnerScript, 0o755);
      } catch (err) {
        warnings.push(`chmod +x runner/flow.sh failed: ${err.message}`);
      }
    }

    return { success: true, dest: destDir, warnings };
  } catch (err) {
    return {
      success: false,
      dest: destDir,
      error: String(err?.message ?? err),
      warnings: [
        ...warnings,
        'state may be inconsistent (partial write); re-run to fix',
      ],
    };
  } finally {
    if (lockHeld) releaseLock(lockPath);
  }
}

// L28 (revised per phase-01 review F1) — Antigravity has 2 destinations under one target.
// install.sh:52-53 makes 2 separate install_to calls with no rollback if the 2nd fails; we
// mirror that. Rolling back dest 1 destroys the freshly-installed content there and also
// risks harming anything the user had before install started, so we intentionally do NOT roll
// back. On dest-2 failure we report partial success and let the user re-run.
export function installAntigravity({ sourceDir, dests, dryRun = false }) {
  if (!Array.isArray(dests) || dests.length === 0) {
    return { success: false, error: 'no destinations provided' };
  }
  if (dryRun) return { success: true, dests, dryRun: true, warnings: [] };

  const attempts = [];
  for (let i = 0; i < dests.length; i++) {
    const r = install({ sourceDir, destDir: dests[i] });
    attempts.push({ dest: dests[i], success: r.success, error: r.error ?? null });
    if (!r.success) {
      const warnings = attempts.flatMap((a, idx) =>
        idx < i ? [`dest ${idx + 1} (${dests[idx]}) already installed; not rolled back`] : []
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

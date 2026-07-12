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

// L24 — Retry EBUSY/EPERM/ENOTEMPTY/EACCES with backoff.
// These are the codes Node emits when Windows agents hold open handles or SELinux delays fs ops.
export function withRetry(fn, opts = {}) {
  const attempts = opts.attempts ?? 3;
  const initialMs = opts.initialMs ?? 100;
  const retryableCodes = opts.codes ?? ['EBUSY', 'EPERM', 'ENOTEMPTY', 'EACCES'];
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

// L29 — Advisory lock: best-effort concurrent-run prevention. Not a hard guarantee.
// Detects stale lock via `process.kill(pid, 0)` returning ESRCH.
export function acquireLock(lockPath) {
  if (existsSync(lockPath)) {
    let pid = null;
    try {
      pid = Number(readFileSync(lockPath, 'utf8').trim());
    } catch {
      // corrupted lock — treat as stale
    }
    // Note: we do NOT bypass when pid === process.pid. install() releases its own lock in
    // finally, so seeing our own pid here means either (a) a prior invocation crashed and left
    // the lock behind — which the ESRCH branch would handle if the pid were also dead — or
    // (b) we're being called re-entrantly, which is unsupported. In case (a) a live process
    // check will still succeed (kill(self, 0) always works), so the caller sees "held" and
    // must remove the stale file manually. That's louder than a silent bypass and matches
    // the "advisory lock, best-effort" contract.
    if (Number.isFinite(pid) && pid > 0) {
      try {
        process.kill(pid, 0);
        return { held: true, pid };
      } catch (err) {
        // ESRCH => process gone; any other code => assume held to be safe
        if (err?.code !== 'ESRCH') return { held: true, pid };
      }
    }
    try {
      rmSync(lockPath, { force: true });
    } catch {
      /* ignore */
    }
  }
  mkdirSync(dirname(lockPath), { recursive: true });
  writeFileSync(lockPath, String(process.pid));
  return { held: false };
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

    // Post-copy defense — even if source somehow escaped assertNoSymlinks (race),
    // reject the write before the runner touches these paths.
    assertNoSymlinks(destDir);

    // chmod +x runner/flow.sh — matches install.sh:27. No-op on Windows (ntfs doesn't honor exec bit).
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

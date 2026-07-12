import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import {
  CLEANUP_SUBDIRS,
} from '../src/constants.mjs';
import {
  acquireLock,
  assertNoSymlinks,
  install,
  installAntigravity,
  releaseLock,
  withRetry,
} from '../src/installer.mjs';

// Build a mini source skill under a scratch dir. Mirrors the shape the runner expects:
// SKILL.md at root plus a runner/flow.sh so we can verify chmod behavior.
function makeSource(root) {
  mkdirSync(root, { recursive: true });
  writeFileSync(join(root, 'SKILL.md'), '---\nname: flow\n---\n');
  mkdirSync(join(root, 'runner'), { recursive: true });
  writeFileSync(join(root, 'runner', 'flow.sh'), '#!/bin/sh\necho flow\n');
  mkdirSync(join(root, 'references'), { recursive: true });
  writeFileSync(join(root, 'references', 'guide.md'), '# guide\n');
  return root;
}

function scratch(prefix) {
  return mkdtempSync(join(tmpdir(), `flow-skill-test-${prefix}-`));
}

test('happy path: install into empty dest creates SKILL.md and runner', () => {
  const tmp = scratch('happy');
  const src = makeSource(join(tmp, 'src'));
  const dest = join(tmp, 'dest', '.claude', 'skills', 'flow');

  const r = install({ sourceDir: src, destDir: dest });
  assert.equal(r.success, true, r.error);
  assert.equal(existsSync(join(dest, 'SKILL.md')), true);
  assert.equal(existsSync(join(dest, 'runner', 'flow.sh')), true);
  assert.equal(existsSync(join(dest, 'references', 'guide.md')), true);
});

test('idempotent: second run succeeds and produces the same tree', () => {
  const tmp = scratch('idem');
  const src = makeSource(join(tmp, 'src'));
  const dest = join(tmp, 'dest', '.claude', 'skills', 'flow');

  const r1 = install({ sourceDir: src, destDir: dest });
  assert.equal(r1.success, true);
  const filesFirst = readdirSync(dest).sort();

  const r2 = install({ sourceDir: src, destDir: dest });
  assert.equal(r2.success, true);
  const filesSecond = readdirSync(dest).sort();
  assert.deepEqual(filesFirst, filesSecond);
});

test('parity install.sh: preserves user files outside the 6 cleanup subdirs', () => {
  const tmp = scratch('preserve');
  const src = makeSource(join(tmp, 'src'));
  const dest = join(tmp, 'dest', '.claude', 'skills', 'flow');

  // First install to create the tree
  install({ sourceDir: src, destDir: dest });
  // User drops a personal note at the root — outside CLEANUP_SUBDIRS
  writeFileSync(join(dest, 'notes.md'), 'my custom notes\n');
  mkdirSync(join(dest, 'custom'), { recursive: true });
  writeFileSync(join(dest, 'custom', 'data.txt'), 'external\n');
  // File inside a cleanup subdir SHOULD be removed on re-install
  writeFileSync(join(dest, 'references', 'user-added.md'), 'goes away\n');

  const r = install({ sourceDir: src, destDir: dest });
  assert.equal(r.success, true);
  assert.equal(existsSync(join(dest, 'notes.md')), true, 'external file at root preserved');
  assert.equal(
    readFileSync(join(dest, 'notes.md'), 'utf8'),
    'my custom notes\n'
  );
  assert.equal(existsSync(join(dest, 'custom', 'data.txt')), true, 'external subdir preserved');
  assert.equal(
    existsSync(join(dest, 'references', 'user-added.md')),
    false,
    'file inside cleanup subdir removed'
  );
});

test('symlink in source is rejected', () => {
  const tmp = scratch('symlink-src');
  const src = makeSource(join(tmp, 'src'));
  // Add a symlink to an external file — this is exactly what an upstream attacker would smuggle.
  const externalTarget = join(tmp, 'external.txt');
  writeFileSync(externalTarget, 'secret\n');
  try {
    symlinkSync(externalTarget, join(src, 'evil-link'));
  } catch (err) {
    // Windows without dev-mode may block symlink creation; skip the test rather than false-pass.
    if (err.code === 'EPERM' || err.code === 'ENOSYS') {
      // eslint-disable-next-line no-console
      console.log('symlink creation not permitted on this platform; skipping test');
      return;
    }
    throw err;
  }
  assert.throws(() => assertNoSymlinks(src), /symlink rejected/);

  const dest = join(tmp, 'dest', '.claude', 'skills', 'flow');
  const r = install({ sourceDir: src, destDir: dest });
  assert.equal(r.success, false);
  assert.match(r.error, /symlink rejected/);
});

test('missing SKILL.md in source: install fails cleanly', () => {
  const tmp = scratch('nosource');
  const src = join(tmp, 'src');
  mkdirSync(src, { recursive: true });
  // no SKILL.md
  const dest = join(tmp, 'dest', '.claude', 'skills', 'flow');

  const r = install({ sourceDir: src, destDir: dest });
  assert.equal(r.success, false);
  assert.match(r.error, /SKILL\.md missing/);
});

test('advisory lock: second install refuses while first-alive pid holds lock', () => {
  const tmp = scratch('lock');
  const dest = join(tmp, 'dest', '.claude', 'skills', 'flow');
  const parent = join(tmp, 'dest', '.claude', 'skills');
  mkdirSync(parent, { recursive: true });
  const lockPath = join(parent, '.flow-skill.installing.lock');

  // simulate a live process holding the lock (our own PID)
  writeFileSync(lockPath, String(process.pid));

  const src = makeSource(join(tmp, 'src'));
  const r = install({ sourceDir: src, destDir: dest });
  assert.equal(r.success, false);
  assert.match(r.error, /another install in progress/);

  releaseLock(lockPath);
});

test('advisory lock: stale lock (dead pid) is reclaimed', () => {
  const tmp = scratch('stalelock');
  const parent = join(tmp, 'dest', '.claude', 'skills');
  mkdirSync(parent, { recursive: true });
  const lockPath = join(parent, '.flow-skill.installing.lock');
  // Astronomically unlikely to be a live pid on the test host.
  writeFileSync(lockPath, '999999999');

  const acquired = acquireLock(lockPath);
  assert.equal(acquired.held, false, 'stale lock should be reclaimed');
  releaseLock(lockPath);
});

test('withRetry: retries on EBUSY then succeeds', () => {
  let calls = 0;
  const result = withRetry(
    () => {
      calls++;
      if (calls < 3) {
        const err = new Error('busy');
        err.code = 'EBUSY';
        throw err;
      }
      return 'ok';
    },
    { attempts: 5, initialMs: 1 }
  );
  assert.equal(result, 'ok');
  assert.equal(calls, 3);
});

test('withRetry: propagates non-retryable errors immediately', () => {
  let calls = 0;
  assert.throws(
    () =>
      withRetry(() => {
        calls++;
        const err = new Error('nope');
        err.code = 'ENOENT';
        throw err;
      }),
    /nope/
  );
  assert.equal(calls, 1);
});

test('installAntigravity: both dests succeed', () => {
  const tmp = scratch('agr-happy');
  const src = makeSource(join(tmp, 'src'));
  const d1 = join(tmp, 'dest', '.gemini', 'antigravity-cli', 'skills', 'flow');
  const d2 = join(tmp, 'dest', '.gemini', 'config', 'skills', 'flow');

  const r = installAntigravity({ sourceDir: src, dests: [d1, d2] });
  assert.equal(r.success, true, r.error);
  assert.equal(existsSync(join(d1, 'SKILL.md')), true);
  assert.equal(existsSync(join(d2, 'SKILL.md')), true);
});

test('installAntigravity: dest2 fail leaves dest1 intact and reports partial (parity install.sh)', () => {
  const tmp = scratch('agr-fail');
  const src = makeSource(join(tmp, 'src'));
  const d1 = join(tmp, 'dest', '.gemini', 'antigravity-cli', 'skills', 'flow');
  // Force dest 2 to be a path we cannot write to (existing file where a dir must go).
  const parent2 = join(tmp, 'dest', '.gemini', 'config', 'skills');
  mkdirSync(parent2, { recursive: true });
  const blocker = join(parent2, 'flow');
  writeFileSync(blocker, 'not a directory');

  const r = installAntigravity({ sourceDir: src, dests: [d1, blocker] });
  assert.equal(r.success, false);
  assert.equal(r.attempts.length, 2);
  assert.equal(r.attempts[0].success, true);
  assert.equal(r.attempts[1].success, false);
  // Dest1 was installed BEFORE dest2 was attempted; it stays intact (install.sh:52-53 parity).
  assert.equal(existsSync(join(d1, 'SKILL.md')), true, 'dest1 SKILL.md should remain');
  assert.equal(existsSync(join(d1, 'runner', 'flow.sh')), true, 'dest1 runner/flow.sh should remain');
  // Warning must explicitly tell the caller that dest1 was NOT rolled back.
  assert.equal(
    r.warnings.some((w) => /not rolled back/.test(w)),
    true,
    'warning must document the partial state'
  );
});

test('dry-run: no files created', () => {
  const tmp = scratch('dry');
  const src = makeSource(join(tmp, 'src'));
  const dest = join(tmp, 'dest', '.claude', 'skills', 'flow');

  const r = install({ sourceDir: src, destDir: dest, dryRun: true });
  assert.equal(r.success, true);
  assert.equal(r.dryRun, true);
  assert.equal(existsSync(dest), false);
});

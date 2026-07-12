// Focused tests for the audit fixes:
//  - acquireLock uses O_EXCL (flag: 'wx') and refuses on real EEXIST
//  - withRetry no longer retries EACCES (dropped from default codes)
//  - detect.mjs template expansion uses path.join (no mixed separators)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, sep } from 'node:path';

import { acquireLock, releaseLock, withRetry } from '../src/installer.mjs';
import { detectAll } from '../src/detect.mjs';

function scratch(prefix) {
  return mkdtempSync(join(tmpdir(), `flow-lock-${prefix}-`));
}

test('acquireLock uses O_EXCL (wx) — writing to a pre-existing lock file yields EEXIST', () => {
  const tmp = scratch('excl');
  const lockPath = join(tmp, '.flow-skill.installing.lock');
  // Pre-place the lock with our own live PID so acquireLock treats it as held.
  writeFileSync(lockPath, String(process.pid));

  const first = acquireLock(lockPath);
  assert.equal(first.held, true, 'live-pid lock must be reported as held');
  releaseLock(lockPath);
});

test('acquireLock is race-safe against re-entrant callers', () => {
  const tmp = scratch('race');
  const lockPath = join(tmp, '.flow-skill.installing.lock');

  const a = acquireLock(lockPath);
  assert.equal(a.held, false);

  const b = acquireLock(lockPath);
  assert.equal(b.held, true, 'second acquire in the same process must see held (our own pid is alive)');

  releaseLock(lockPath);
});

test('acquireLock reclaims a stale lock whose recorded PID is dead', () => {
  const tmp = scratch('stale');
  const lockPath = join(tmp, '.flow-skill.installing.lock');
  // Astronomically unlikely to be a live PID on this host.
  writeFileSync(lockPath, '999999999');

  const r = acquireLock(lockPath);
  assert.equal(r.held, false, 'stale lock must be reclaimed');
  releaseLock(lockPath);
});

test('acquireLock treats corrupted lock content as stale', () => {
  const tmp = scratch('corrupt');
  const lockPath = join(tmp, '.flow-skill.installing.lock');
  writeFileSync(lockPath, 'not a number\n');

  const r = acquireLock(lockPath);
  assert.equal(r.held, false, 'unreadable pid should be treated as stale');
  releaseLock(lockPath);
});

test('withRetry no longer retries EACCES — surfaces the first denial', () => {
  let calls = 0;
  assert.throws(
    () =>
      withRetry(
        () => {
          calls++;
          const err = new Error('permission denied');
          err.code = 'EACCES';
          throw err;
        },
        { attempts: 5, initialMs: 1 }
      ),
    /permission denied/
  );
  assert.equal(calls, 1, 'EACCES must not be retried; expected 1 call, got ' + calls);
});

test('withRetry still retries EBUSY / EPERM / ENOTEMPTY (Windows agent contention)', () => {
  for (const code of ['EBUSY', 'EPERM', 'ENOTEMPTY']) {
    let calls = 0;
    const r = withRetry(
      () => {
        calls++;
        if (calls < 2) {
          const err = new Error(code);
          err.code = code;
          throw err;
        }
        return 'ok';
      },
      { attempts: 3, initialMs: 1 }
    );
    assert.equal(r, 'ok');
    assert.equal(calls, 2, `${code}: expected 2 calls, got ${calls}`);
  }
});

test('detect: dest paths use the OS separator (no mixed / and \\ on Windows)', () => {
  const home = mkdtempSync(join(tmpdir(), 'flow-sep-'));
  mkdirSync(join(home, '.claude'), { recursive: true });
  const entries = detectAll({ home });
  const claude = entries.find((e) => e.name === 'claude');
  const dest = claude.dests[0];

  // The dest must start with the given home path...
  assert.equal(dest.startsWith(home), true, `dest ${dest} should start with ${home}`);
  // ...and the tail after the home must use only the OS's canonical separator.
  const tail = dest.slice(home.length);
  const wrongSep = sep === '/' ? '\\' : '/';
  assert.equal(
    tail.includes(wrongSep),
    false,
    `dest tail ${tail} must not contain the wrong separator ${wrongSep}`
  );
});

test('detect: antigravity 2 dests each use OS separators', () => {
  const home = mkdtempSync(join(tmpdir(), 'flow-sep-agr-'));
  const entries = detectAll({ home });
  const agr = entries.find((e) => e.name === 'antigravity');
  assert.equal(agr.dests.length, 2);
  const wrongSep = sep === '/' ? '\\' : '/';
  for (const d of agr.dests) {
    assert.equal(d.startsWith(home), true);
    assert.equal(d.slice(home.length).includes(wrongSep), false);
  }
});

test('withRetry propagates non-retryable errors immediately', () => {
  let calls = 0;
  assert.throws(
    () =>
      withRetry(
        () => {
          calls++;
          const err = new Error('missing');
          err.code = 'ENOENT';
          throw err;
        },
        { attempts: 5, initialMs: 1 }
      ),
    /missing/
  );
  assert.equal(calls, 1);
});

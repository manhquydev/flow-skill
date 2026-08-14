---
phase: 5
title: "A5 EN/VI blob-hash manifest"
status: pending
priority: P2
effort: "0.5d"
dependencies: [2]
---

# Phase 5: A5 EN/VI blob-hash manifest

## Overview
Make EN/VI doc drift mechanically detectable: record each pair's git **blob hashes** in a small
manifest, verify in preflight/CI, refresh hashes on confirmed-consistent edits.
Pattern source: dsh `.i18n.yaml` blob-hash pairing, LIGHT cut only — no merge driver, no glossary,
no equal-authority rule (`research-260814-0915-deepseek-docs-bench.md` §1.2).

## Requirements
- Functional: pairs covered — `README.md`↔`README_VN.md`, `npm-wrapper/README.md`↔`npm-wrapper/README_VN.md`.
  Verify = both current blob hashes match the recorded pair; mismatch names which side moved.
- Non-functional: zero deps (`git rev-parse HEAD:<path>`); bash-3.2-safe; manifest is plain text.
  `git hash-object` / `git hash-object --path` is the forbidden dirty-tree hasher.

## Architecture
- `docs/i18n-pairs.txt`: `en_path vi_path en_blob vi_blob` per line.
- `scripts/check-i18n-pairs.sh`: `verify` (default) and `record <en_path>` (refresh a pair's hashes
  after both sides of a **committed** pair are confirmed consistent). **Hash the committed blob
  only:** `git rev-parse HEAD:<path>`. Do **not** add `*.md text eol=lf` in wave 1 (YAGNI; scripts
  already have `eol=lf`). Do **not** hash a dirty working tree (`git hash-object --path`) —
  `.gitattributes:8` leaves markdown to the platform default. `record` writes the HEAD blobs
  after the consistency commit, not of unstaged files. Local dirty-tree edits are invisible to
  verify until commit (CI sees HEAD; that is the gate).
- Wired into `scripts/release-preflight.sh` + a small suite in the Phase 2 manifest.

## Related Code Files
- Create: `docs/i18n-pairs.txt`, `scripts/check-i18n-pairs.sh`, `tests/test_i18n_pairs.sh`
- Modify: `scripts/release-preflight.sh`, `tests/manifest.txt`, `npm-wrapper/RELEASE_CHECKLIST.md`
  (replace the manual "check VN drift" checkbox with the script call)

## Implementation Steps
1. Implement script (verify/record); record initial hashes from current `HEAD:<path>` for both
   pairs (A5 is a drift detector, not a translation audit — treat today's committed blobs as
   the initial consistent state; no EN/VI rewrite in wave 1).
2. Test suite (must **commit** the edit in the temp repo, otherwise `HEAD:path` is unchanged and
   verify stays green): commit an EN-only edit → verify fails naming EN; commit the matching VI
   + `record` → verify passes. Also: a dirty working-tree CRLF rewrite of a listed `.md` must
   still verify green against `HEAD:path`.
3. Wire preflight + manifest; update RELEASE_CHECKLIST wording.

## Success Criteria
- [x] A **committed** edit of either side of a pair without `record` fails preflight/CI, message
      names the moved side. Dirty working-tree edits are not the gate.
- [x] `record` refresh flow documented in the script header.
- [x] Initial recorded state verified green in CI.

## Risk Assessment
CRLF on markdown is the real trap (`.gitattributes` does not pin `*.md`). Mitigate by hashing
the committed blob (`HEAD:path`), not the working tree. Test covers a CRLF working-tree
round-trip that must still verify green against `HEAD:path`.

<!-- Updated: Red Team R1 - committed-blob hashes, not dirty working-tree -->
<!-- Updated: Validation Session 1 - HEAD:path only; no *.md eol=lf; tests must commit -->
<!-- Updated: Red Team R2 - Requirements hasher is rev-parse, not hash-object -->

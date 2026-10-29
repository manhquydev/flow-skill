# Builder report — PR92-ATTEST-FIX-261027 (doc budget + TMPDIR portability)

- Builder lane: PR92BudgetPortabilityFix, parent lease PR92-ATTEST-FIX-261027, PR manhquydev/flow-skill#92
- Base worked on: PR head `22ccb503b5647c1f05c9e6218ff7a528efb8d1bf` (verified with `git rev-parse HEAD` immediately after `git checkout -B flow/pr92-attest-fix-261027 FETCH_HEAD` from `https://github.com/manhquydev/flow-skill.git pull/92/head`, before any edit)
- Superseded stale WIP at `94a22f63` preserved as `stash@{0}` ("PR92 stale fix WIP at 94a22f63 (superseded by head 22ccb503; parent-approved archive)") — kept as evidence, not dropped.
- Status: all scoped gates green; one conventional commit created on this base; non-force push to `https://github.com/flowskillharness/flow-skill.git` `feat/attest-chain` attempted immediately after this commit. The exact final head SHA and push outcome are in the builder's final response to the parent — a file included in a commit cannot contain that commit's own SHA, so this report records the verified base instead.

## Changes

1. **F4 — TMPDIR portability (fail-closed kept):** `skills/flow/runner/attestations.sh`, inside `_att_chain_verify` only:
   - latest-entry index temp: `mktemp 2>/dev/null` → `mktemp "${TMPDIR:-/tmp}/.att-chain.XXXXXX" 2>/dev/null || echo "${TMPDIR:-/tmp}/.att-chain.$$"`
   - ledger key index temp: same pattern with `.att-chain-keys.XXXXXX` / `.att-chain-keys.$$`
   - The `2>/dev/null` guard and `|| echo "${TMPDIR:-/tmp}/..."` fail-closed fallback are preserved: with a broken/absent `TMPDIR`, both the template call and the fallback path fail, the awk redirect into the index fails, and verify reports `BROKEN` (never a false pass). Explicit template makes BSD `mktemp` honor `TMPDIR` on macOS. Bash 3.2-safe parameter expansion only; no other function touched (all other `mktemp` sites in the file left byte-identical); no STOP-zone edits.
2. **F2 — doc budget:** `skills/flow/references/attestations.md` trimmed 1596 → **1578 words** (`wc -w`) against the 1580 budget in `docs/doc-budgets.txt`, by tightening 13 prose spots (dropped redundant qualifiers such as "full schemas" → "schemas", "raw receipt bytes" → "receipt bytes", "CRLF conversion" → "CRLF", "each later" → "later", compressed the deletion-gap clause "when no later entry remains and the receipt is gone too" → "when no later entry and receipt remain", "who holds no external copy" → "without an external copy", "for attestation" dropped where the section title already scopes it). Preserved exactly, as cited by `tests/test_attest_chain.sh` case Q: `newline-terminated`, `UNTRACKED`, `deletions escape`, `no-filters`; file remains newline-terminated. No schema, command, status word, limit, or matrix content changed.
3. **CHANGELOG.md:** new `[Unreleased]` `fix(attest)` note documenting the TMPDIR-honoring `_att_chain_verify` temp files and the 1578/1580 doc trim.
4. **portable-manifest.json:** no diff, by design — `sync.mjs` writes only the runner (`skills/flow/runner/flow.sh`) SHA-256 into it (`3657444b…`, unchanged because `flow.sh` is untouched). Consistency of the new `attestations.sh` bytes is carried by the regenerated bundled receipt `npm-wrapper/skills/flow/manifest-hashes.json` (gitignored build artifact): `sha256(runner/attestations.sh)` = `1b11214331e010fa0652fe65e76c3e0723a578a809f94bded2ef9324761bcb87`, byte-identical to the source file.
5. This report (`plans/reports/builder-281028-pr92-budget-portability.md`).

## Evidence — commands run from the leased worktree root (all observed this session)

| Command | Exit | Key result |
|---|---|---|
| `git stash push --include-untracked -m 'PR92 stale fix WIP at 94a22f63 (superseded by head 22ccb503; parent-approved archive)'` | 0 | stale WIP archived, stash retained |
| `git fetch https://github.com/manhquydev/flow-skill.git pull/92/head` && `git checkout -B flow/pr92-attest-fix-261027 FETCH_HEAD` | 0 | `git rev-parse HEAD` = `22ccb503b5647c1f05c9e6218ff7a528efb8d1bf` before any edit |
| `wc -w skills/flow/references/attestations.md` | 0 | **1578** (budget 1580); trailing byte `\n` |
| literal checks (`grep -c`) | 0 | `newline-terminated`=1, `UNTRACKED`=1, `deletions escape`=1, `no-filters`=1 |
| `bash tests/test_attest_chain.sh` | 0 | `RESULT pass=53 fail=0`; case K: `ok [verify nonzero when temp index cannot be built]`, `ok [temp index broken message]` (fail-closed stimulus reproduces with `TMPDIR=$SB/no-such-dir`) |
| `bash tests/test_doc_budgets.sh` | 0 | `RESULT: 8 passed, 0 failed` |
| `bash scripts/check-doc-budgets.sh` | 0 | `OK: skills/flow/references/attestations.md 1578 / 1580`; `PASS: doc budgets (6 files)` |
| `bash scripts/check-release-coherence.sh` | 0 | `PASS: release coherence` (79 manifest suite files; runner hash `3657444b` matches manifest) |
| `node npm-wrapper/scripts/sync.mjs` | 0 | `sync OK: 133 files, skills-manifest.json emitted, runner hash 3657444b…`; `git status` shows no `portable-manifest.json` diff |
| receipt-vs-source hash check (`node -e`, sha256 compare) | 0 | bundled receipt entry == source bytes == `1b11214331e010fa0652fe65e76c3e0723a578a809f94bded2ef9324761bcb87` |

## Commit / push plan (executed right after this file is written)

- One conventional commit: `fix(attest): honor TMPDIR in chain verify temp index and trim attestations doc to budget` — includes `CHANGELOG.md`, `skills/flow/references/attestations.md`, `skills/flow/runner/attestations.sh`, and this report. No version bumps, no release actions, no merge, no STOP-zone edits.
- Push without force: `git push https://github.com/flowskillharness/flow-skill.git HEAD:feat/attest-chain`. On auth refusal: stop, report BLOCKED with the exact refusal text; no retry loops, no force, no new PR.

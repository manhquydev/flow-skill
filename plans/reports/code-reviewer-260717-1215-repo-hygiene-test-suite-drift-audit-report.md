# Repo Hygiene + Test-Suite/Manifest Drift Audit

Advisory only. No files edited, deleted, or moved.

## 1. Untracked files (`git status --short`)

Command: `git status --short --untracked-files=all` (run from repo root).

```
?? old_flow.sh
?? plans/reports/docs-manager-260717-1215-npm-wrapper-final-consistency-audit-report.md
```

- `plans/reports/docs-manager-260717-1215-npm-wrapper-final-consistency-audit-report.md` — under `plans/reports/`, explicitly exempted by task scope (expected working artifact). Note: it did not appear in an earlier `Glob plans/reports/*` taken moments before this git status call, and did not appear in the *first* `git status --short` run of this session either — evidence another process (likely a concurrent teammate agent) wrote it mid-audit. Not a hygiene finding for this report.
- `old_flow.sh` — **in scope**, assessed below.

### `old_flow.sh` — assessment: leftover cruft, recommend delete

Evidence:
- Location: repo root (`D:\project\flow\flow-skill\old_flow.sh`). The canonical runner lives at `skills/flow/runner/flow.sh` — `old_flow.sh` is not even in the right directory to be a working copy of anything currently wired up.
- Size/age: 2219 lines, 112,943 bytes, mtime `Jul 10 09:13`.
- Current equivalent: `skills/flow/runner/flow.sh` is 3656 lines, 191,184 bytes, mtime `Jul 16 15:53` — newer, materially larger (1437 more lines).
- `diff old_flow.sh skills/flow/runner/flow.sh` produces 1536 diff lines. Sampled hunks show `old_flow.sh` is missing entire subsystems present in current `flow.sh`: the eval harness block (`EVAL_DIR`, `EVAL_MANIFEST`, `GATE_RULES_FILE`), the v0.22 routing-eval/concierge block (`EVAL_ROUTING_DIR`, `CONCIERGE_FILE`, `FLOW_CATALOG_FILE`), and a documented bugfix to `_register_td`/`_cleanup_tds` (space-path handling + bash-3.2/macOS empty-array-under-`set -u` guard). This confirms `old_flow.sh` is a stale pre-v0.22 snapshot, not a divergent branch of work.
- Cross-reference: `grep -rn old_flow` finds exactly one hit, in `plans/reports/status-audit-260712-1029-flow-skill-npm-publish-readiness-report.md:144`, where it was already flagged 5 days ago as an open question ("`old_flow.sh` ở repo root vẫn untracked từ trước; có nên xóa hay giữ?") that was never resolved. It has sat untracked and unaddressed since at least 260712.

**Recommendation**: delete `old_flow.sh`. It is a superseded snapshot of `skills/flow/runner/flow.sh`, was already flagged for removal 5 days prior and never actioned, is not referenced anywhere else in the repo, and its presence at repo root risks a future contributor mistaking it for a live entry point.

## 2/3. `tests/run_all.sh` suite list vs. files on disk

Extracted the `for suite in ...; do` loop contents from `tests/run_all.sh` (34 entries) and the output of `Glob tests/test_flow_*.sh` (34 files). Diffed both sorted lists (scratchpad-based diff, byte-for-byte after stripping `ls`'s executable-marker `*` noise):

**Result: identical sets. No orphaned test files, no dangling suite references.**

Every `test_flow_*.sh` file physically present in `tests/` is listed in `run_all.sh`'s loop, and every suite name in the loop corresponds to a real file. No action needed for #2/#3.

## 4. `portable-manifest.json` `"tests"` array vs. files on disk

Extracted the `tests` array from `portable-manifest.json` (34 entries, basenames) and diffed against the same disk listing.

**Result: identical sets. No mismatch.**

Every test file on disk is listed in the manifest and vice versa. No action needed for #4.

(Both #2/#3 and #4 checks were previously a known risk area per project history — verified clean as of this audit.)

## 5. `.gitignore` coverage

Root `.gitignore` (`D:\project\flow\flow-skill\.gitignore`):
```
10: # python
11: __pycache__/
12: *.pyc
```
Covers `__pycache__/` and `*.pyc` as required. No gap found.

`npm-wrapper/.gitignore`:
```
11: # Materialized at prepack from ../skills/flow — not tracked to avoid duplicate content
12: # in git. `npm run sync` regenerates before local test/CLI use.
13: skills/
14: skills-manifest.json
```
The entry is `skills/` (the whole synced directory), not the narrower `skills/flow/` the task description expected — but `skills/` is a superset that still ignores `skills/flow/`, so the intended protection (don't commit the materialized bundle) is intact and not accidentally reverted. No action needed.

## 6. Duplicate/near-duplicate reports in `plans/reports/`

Full listing (10 files, excluding the concurrently-written file noted in §1):
```
dogfood-self-build-260613.md
260618-xia-superpowers-compare.md
brainstorm-260710-2354-v021-eval-hardening-kill-express-lane-report.md
researcher-260712-1005-cross-os-test-matrix-node-lts-report.md
researcher-260712-1006-npm-trusted-publisher-first-publish-edge-cases-report.md
publish-setup-runbook-260712-0945-flow-skill-npm-wrapper-report.md
status-audit-260712-1029-flow-skill-npm-publish-readiness-report.md
docs-manager-260712-1151-post-publish-docs-audit-recommendation-report.md
research-260717-0915-npx-agent-installer-expansion-report.md
brainstorm-260717-0925-cross-agent-installer-expansion-report.md
```

**Suspicious pair (flag, not judged):**
- `research-260717-0915-npx-agent-installer-expansion-report.md` (157 lines) and `brainstorm-260717-0925-cross-agent-installer-expansion-report.md` (101 lines) — same date, 10 minutes apart, same topic slug (`*-agent-installer-expansion-report.md`), differing only in the `research-` vs `brainstorm-` prefix. Could be a legitimate two-step workflow (research feeding a brainstorm session), or an accidental re-run under a different report-type prefix. Recommend a human spot-check the content to confirm this isn't a naming collision/redundant artifact — no other pair in the directory shares this degree of name/timing overlap.

No other suspicious pairs found; the remaining 8 files have distinct topics/timestamps.

## Summary of Recommendations

| # | Finding | Action recommended | Severity |
|---|---|---|---|
| 1 | `old_flow.sh` at repo root — stale, superseded, untracked since ≥260712, already flagged and never actioned | Delete | Medium (cruft, previously flagged, zero references) |
| 2/3 | `run_all.sh` suite list vs. disk | None — verified in sync | N/A (clean) |
| 4 | `portable-manifest.json` tests array vs. disk | None — verified in sync | N/A (clean) |
| 5 | `.gitignore` python/npm-wrapper coverage | None — both covered | N/A (clean) |
| 6 | `research-260717-0915-...` / `brainstorm-260717-0925-...` installer-expansion reports | Human review to confirm not a duplicate/collision | Low (investigate only) |

## Unresolved Questions
- Should `old_flow.sh` be deleted outright, or does anyone still need a diff-able snapshot of the pre-v0.22 runner for reference? (Given it was already asked and left unanswered on 260712, recommend resolving now rather than deferring again.)
- Confirm whether `research-260717-0915-npx-agent-installer-expansion-report.md` and `brainstorm-260717-0925-cross-agent-installer-expansion-report.md` are sequential-workflow artifacts (keep both) or a duplicate run (consolidate/delete one) — content not judged in this audit.

Status: DONE
Summary: 1 Medium (stray old_flow.sh, previously flagged/never cleaned), 1 Low (possible duplicate report pair, needs human content check), 0 test/manifest drift found (suite list, disk files, and manifest all in sync), 0 .gitignore gaps.

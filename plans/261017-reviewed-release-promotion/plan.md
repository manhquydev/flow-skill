# Plan: Reviewed Release Promotion & Environment Reviewer Safety Gate

## Context & Safety Problem
Previously, `bash scripts/release.sh --yes` executed `scripts/sync-release.mjs --ship --yes`, where `shipRelease()` ran in-place surface synchronization (`syncRelease`), generated local release preparation commits (`chore(release): prepare v...`), recorded i18n pair hashes into `docs/i18n-pairs.txt`, committed them, executed a local verification battery, and pushed `master` along with release tags (`npm@<version>`, `v<version>`).

This created critical supply-chain and release-safety hazards:
1. **Un-CIed Tagged Commits:** Release tags could be minted on post-PR commits that had never been validated by GitHub Actions cross-OS CI.
2. **Unattended npm Publish Risk:** The GitHub repository environment `npm-publish` has `protection_rules=[]` via API, despite comments claiming a required reviewer gate was configured. Pushing an `npm@*` tag would trigger `publish-npm-wrapper.yml` and publish to npmjs.com unattended.
3. **Owner Configuration Prerequisite:** Configuring environment protection rules with required reviewers is an administrative action in GitHub repository Settings (Owner action); code cannot grant or enforce reviewer requirements on the environment.

## Goal & Architecture
Cut over `scripts/sync-release.mjs --ship --yes` (and `scripts/release.sh --yes`) to **promotion only** of a pre-prepared, PR-reviewed, and CI-verified master HEAD.
Zero new commits are created during `--ship --yes`.
Zero release surfaces are mutated during `--ship --yes`.

### Fail-Closed Gates Before Tag Creation, Push, or GitHub Release
Promotion aborts immediately (exit 1) unless all of the following gates pass:
1. **Strictly Clean Working Tree & Index:** `git status --porcelain` must be completely empty (no release-file exemptions).
2. **Master Branch Alignment:** Current branch (`git branch --show-current`) must be `master`.
3. **Live Remote HEAD Equality:** Local `HEAD` commit SHA must equal live `refs/heads/master` on remote `origin` (queried live via `git ls-remote origin refs/heads/master`, not a stale tracking ref).
4. **Coherence & Non-Drift Verification:** `runChecks()` must report `allPass: true` across all versions, manifests, README tables, and changelogs.
5. **Zero Synchronization Drift:** Prep synchronization would NOT modify any product or manifest files:
   - In-memory check confirms all 4 README release table sections already match disk.
   - Read-only tree comparison (`node npm-wrapper/scripts/sync.mjs --compare npm-wrapper/skills/flow skills/flow`) confirms bundled skills match repo source.
6. **i18n Pair Manifest HEAD Verification:** `bash scripts/check-i18n-pairs.sh verify` must exit 0, confirming committed `HEAD` blobs match `docs/i18n-pairs.txt` (never runs `record`).
7. **Exact-HEAD CI Verification:** Query GitHub Actions via `gh api` (`repos/{owner}/{repo}/commits/${headSha}/check-runs`) to verify the required aggregation check `all-checks-passed` exists for the exact HEAD SHA, has `status: "completed"`, and `conclusion: "success"`. Fails closed on absent, pending, failed, mismatched SHA, or denied network/auth (no `--skip-ci` escape hatch).
8. **Pre-Push Tag & Remote Recheck:** Re-queries live remote `origin` for `refs/heads/master` and tag existence immediately before tag creation to minimize race windows; refuses promotion if `npm@<version>` or `v<version>` already exists locally or on remote.
9. **Full Local Verification Battery:** Runs existing battery (`check-release-coherence`, `release-preflight`, `pack-rehearsal`, `check-doc-budgets`, `test_doc_budgets`, `test_flow_rules`, `npm test`) before tagging, pushing, or creating GitHub releases.

### Process & Documentation Corrections
- `docs/release-process.md` and `npm-wrapper/RELEASE_CHECKLIST.md`:
  - Update canonical release workflow: release preparation is authored in a PR, merged to `master`, and CI verified under `all-checks-passed`.
  - Remove inaccurate claims that required reviewer is already configured.
  - State explicitly that live release remains **OPERATOR BLOCKED** until the repository owner configures a required reviewer on the `npm-publish` environment in GitHub repository Settings and independently verifies `protection_rules`.

## Scope of Files Touched
- `scripts/sync-release.mjs`: Refactor `shipRelease()` into promotion-only workflow with fail-closed gates; update CLI help and dry-run reporting.
- `docs/release-process.md`: Update release chronology, promotion model, and operator-blocked environment gate.
- `npm-wrapper/RELEASE_CHECKLIST.md`: Correct environment checklist item and canonical release instructions.
- `tests/test_sync_release.sh`: Update integration cases (H, I, J, K) and add negative tests for dirty working tree, unconfirmed/mismatched remote HEAD, non-master branch, sync drift, unverified CI check, and existing tags.
- `plans/261017-reviewed-release-promotion/plan.md`: This plan.

## Non-Goals & Boundaries
- No version bumps to skill product or npm package.
- No changes to `.github/workflows/publish-npm-wrapper.yml` or CI workflows.
- No changes to `website/` or runner eval STOP zones (`_eval_engine_run`, `_run_with_timeout`).
- No new runtime dependencies (uses existing `git`, `node`, `bash`, and `gh`).

## Acceptance Criteria
1. `node scripts/sync-release.mjs --ship --yes`:
   - Exits 1 if working tree has any modified, staged, or untracked files.
   - Exits 1 if current branch is not `master`.
   - Exits 1 if local HEAD does not match remote `origin/master`.
   - Exits 1 if release surfaces show drift.
   - Exits 1 if `npm-wrapper/scripts/sync.mjs --compare` fails.
   - Exits 1 if `scripts/check-i18n-pairs.sh verify` fails.
   - Exits 1 if GitHub Actions `all-checks-passed` for HEAD is missing, incomplete, failed, or unreachable.
   - Exits 1 if tags `npm@<version>` or `v<version>` already exist.
   - Creates ZERO commits under any execution path.
   - Successfully tags, pushes, and creates GitHub Release when all promotion gates pass.
2. `--dry-run` remains strictly non-mutating and transparently reports local battery vs CI verification state.
3. `tests/test_sync_release.sh` passes 100% locally with mock `gh` and local bare remotes (no live network calls).
4. `scripts/check-doc-budgets.sh`, `tests/test_doc_budgets.sh`, `scripts/check-release-coherence.sh`, and `node scripts/sync-release.mjs --check` pass.

## Risk & Rollback
- Risk: Low to product runtime; high supply-chain improvement. Prevents accidental unattended package publishing.
- Rollback: Revert branch commit on `fix/release-reviewed-payload`.

# Plan: Make First-Run README Version Example Generic (No Stale Hardcoded Numbers)

## Who Is Hurt
First-run readers and developers onboarding to Flow see a confusing mismatch:
- `README.md:50-56` and `README_VN.md:49-54` currently show:
  `Do not pin @0.34.1 on npm...`
  `--help prints both: flow-skill v0.7.8 (ships skill v0.34.1)`.
- Meanwhile, the current published `@latest` (and local `npm-wrapper/bin/cli.mjs`) is `0.7.11` shipping skill `v0.34.4`, and the top compatibility table in the same READMEs already shows `v0.34.4` and `0.7.11`.
- Readers perceive that the installed package version diverges from what the documentation claims it prints.

## Baseline
- `README.md:50-56`:
  ```markdown
  Always use `@latest`. Do not `npm i` the package alone — that does not copy
  the skill. Do not pin `@0.34.1` on npm — that is the skill version, not the
  installer.

  Two version numbers (intentional): npm package = installer CLI; skill product
  = `SKILL.md` `metadata.version`. `--help` prints both:
  `flow-skill v0.7.8 (ships skill v0.34.1)`.
  ```
- `README_VN.md:49-54`:
  ```markdown
  Luôn dùng `@latest`. Đừng chỉ `npm i` package — lệnh đó không copy skill.
  Đừng pin `@0.34.1` trên npm — đó là version skill, không phải installer.

  Hai số version (cố ý): package npm = installer CLI; skill product =
  `SKILL.md` `metadata.version`. `--help` in cả hai:
  `flow-skill v0.7.8 (ships skill v0.34.1)`.
  ```
- Output of `node npm-wrapper/bin/cli.mjs --help | head -1`:
  `flow-skill v0.7.11 (ships skill v0.34.4)`

## Hypothesis
Replacing the hardcoded numeric strings (`@0.34.1`, `flow-skill v0.7.8 (ships skill v0.34.1)`) with clear placeholders (`flow-skill v<package-version> (ships skill v<skill-version>)`) and generic advice ("Do not use a skill product version as an npm package pin") allows the introductory text to remain perpetually accurate across future dual-axis releases without requiring manual text updates. The compatibility table and CLI remain the single home for live version numbers.

## Observable Acceptance Criteria
1. `README.md`:
   - Generic pinning guidance: "Do not use a skill product version as an npm package pin — that is the skill version, not the installer."
   - Dual-version explanation uses placeholder: ``flow-skill v<package-version> (ships skill v<skill-version>)``.
   - No stale hardcoded numeric example (`v0.7.8`, `@0.34.1`).
2. `README_VN.md`:
   - Parallel generic pinning guidance: "Đừng dùng version của skill product để pin package npm — đó là version skill, không phải installer."
   - Dual-version explanation uses identical placeholder: ``flow-skill v<package-version> (ships skill v<skill-version>)``.
   - No stale hardcoded numeric example (`v0.7.8`, `@0.34.1`).
3. Existing compatibility tables in both READMEs continue to reflect current versions (`v0.34.4`, `0.7.11`).
4. `npm-wrapper/README.md` and `npm-wrapper/README_VN.md` are inspected and remain accurate.
5. All verification commands pass cleanly:
   - `bash scripts/check-doc-budgets.sh`
   - `bash tests/test_doc_budgets.sh`
   - `bash scripts/check-release-coherence.sh`
   - `bash scripts/check-i18n-pairs.sh verify` (after updating `docs/i18n-pairs.txt`)
6. No version numbers bumped, no npm package changes, no installer behavior changes.

## Non-Goals
- No version bumps to skill or npm package.
- No changes to `scripts/sync-release.mjs` table sync logic.
- No website/ or runner eval STOP zone edits.

## Risk & Rollback
- Risk: Low (docs-only clarity improvement).
- Rollback: Revert branch commit.

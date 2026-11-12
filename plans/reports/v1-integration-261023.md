# Flow v1 parent integration lane

- Base: `1985c22e28b22156157851a62f42d3fa9f6b83b7` (verified origin/master); worktree `v1-integration-261023`; parent-owned allowlist only.
- Contract source: `plans/261023-1233-omp-v1-readiness/v1-outcome-contract.md`; execution plan: `plans/261023-1233-omp-v1-readiness/v1-execution-plan.md`.

## Integrated documents / CI contracts

- `docs/migration-v1.md`: says unreleased; Python >=3.7/stdlib required for the v1 target; graph owns ordering; disable flag refuses product operations; prior installer rollback uses an exact npm pin and installer CLI; no claim that `npm install` alone restores skill files or that additive schema proves rollback safety. Requires backup/restore evidence and settled writers.
- `skills/flow/harness/README.md`, `docs/system-architecture.md`, `skills/flow/SKILL.md`, both READMEs, `skills/flow/references/command-dispatch.md`, and `CHANGELOG.md`: describe the v1 target without claiming it has shipped; preserve separate npm/skill axes and gate/skip/card/ADR identity.
- `.github/workflows/ci.yml`: replaces the obsolete `no-python-degradation` success contract with `python-required-refusal` assertions for no-Python refusal before writes, help/doctor diagnostics, and disable refusal. Existing cross-OS matrix, shards, setup-python, and required-check structure remain unchanged.
- `scripts/release-preflight.sh`: selects the first working interpreter at the measured Python >=3.7 floor, checking `python3` then `python`, rather than stopping at a below-floor interpreter before checking `python`.
- No version bump, release, publication, or stable-1.0 claim.

## Verification observed

- `bash tests/test_flow_skill_harness_docs_contract.sh`: 19 passed, 0 failed.
- `bash scripts/check-doc-budgets.sh`: pass; all six governed files under budgets.
- `bash tests/test_doc_budgets.sh`: 8 passed, 0 failed.
- `bash scripts/check-i18n-pairs.sh`: English/Vietnamese README pairing passes.
- `bash scripts/check-release-coherence.sh`: pass; source still maps skill `0.34.9` and npm `0.7.16` on separate axes.
- PyYAML parses `.github/workflows/ci.yml`; required job list includes `python-required-refusal`, not `no-python-degradation`.
- GitHub release readback: `v0.34.9` exists, non-draft, non-prerelease; this is historical shipped status, not v1 acceptance.

## Not yet verified

- Runner behavior, no-Python/disable CI job against final integrated runner, DB backup/restore implementation, cross-OS tests, and full-suite results depend on the active lane A/B commits. Parent owns full `bash tests/run_all.sh`, release rehearsal, exact-head CI/review and integration after both builders settle.
- Stable 1.0 remains gated on all owner contract acceptance and rollback evidence.

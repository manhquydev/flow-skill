---
phase: 6
title: "Phase 6: Release — Python Mandatory, Major Bump"
status: todo
priority: P2
effort: "2d"
dependencies: [4, 5]
---

# Phase 6: Release — Python Mandatory, Major Bump

<!-- Updated: Red Team Session 1 (2026-07-26) — findings 10, 12, 15 applied -->

## Overview

Flip `FLOW_GRAPH_EXECUTOR` default on, make Python a hard dependency, define `FLOW_HARNESS_DISABLE` end-state, publish major version with migration guide. Deliberate breaking change (advise session 2026-07-26).

## Requirements

- Functional: preflight reusing `_python()` (`flow.sh:170-181` — accepts python3 OR python, avoids bricking Windows where only `python` exists); floor = what the code actually needs (audit says ~3.6; document the measured floor, do NOT invent 3.9); `doctor`, `--help`, `--version` EXEMPT from preflight (doctor is the no-python diagnostic survivor, `flow.sh:1778-1801`, and the preflight error message names it); `FLOW_HARNESS_DISABLE` becomes a startup hard error with actionable message (not silent no-op); flag default flips; legacy ladder removed in one revertable commit
- Non-functional: migration guide ≤1 page covering ALL breaking changes; CHANGELOG breaking section; docs updated within repo docs limit (800 LOC); no AI references in commits

## Architecture

- Preflight: extend existing `scripts/release-preflight.sh` lineage + `flow.sh` startup: `_python()` probe + `flow_harness.py` importable + Windows Store-stub guard (existing comment `flow.sh:265`). Failure → exit non-zero, 3-line message with per-OS install command + "run: flow doctor" (doctor exempt so it still prints diagnostics).
- `FLOW_HARNESS_DISABLE` (findings 10 + R5): hard error at dispatch ("harness is mandatory since v1.0.0; unset FLOW_HARNESS_DISABLE; see migration guide"). Inventory is GREP-DERIVED at implementation time, not hand-asserted (Round-2 fact-check corrected the hand list). Grep-verified set-sites today: `test_flow_card_lifecycle.sh:9,87`, `test_flow_coherence_kb.sh:46`, `test_flow_constitution.sh:108`, `test_flow_gate_capture.sh:22`, `test_flow_recall.sh:17,27,35,45,55,64,74` (×7), `test_flow_usage_log.sh:131,547,549,560` (×4 — the suite the original list missed entirely). Unset-only sites (no change needed): `test_flow_harness_strict.sh`, `test_flow_harness_trust_complete.sh:76`, `test_flow_card_lifecycle.sh:70`. Also update the user-facing message advertising the variable at `flow.sh:3667` and the 3 degradation docs (`skills/flow/harness/README.md:34,101`, `docs/codebase-summary.md:63`, `docs/system-architecture.md:22`).
- CI (findings 12 + R8): add `actions/setup-python` explicitly (currently absent — runner-image reliance); add no-python job asserting refusal message + doctor survival. **Windows budget is UNKNOWN**: the ~11.5m figure in `ci.yml:43-47` was a CANCELLED partial run at suite 28/33; run_all.sh now has 39 suites and this plan adds 7. Gate (moved earlier, plan-level SC): one FULL GREEN Windows run with per-suite `wall_s` recorded BEFORE Phase 4 lands; if over the 30m cap, split the matrix job, do not drop suites.
- Version: skill v0.24.0 → v1.0.0; npm 0.1.0 → 1.0.0 (`npm-wrapper/package.json`; add python requirement note — npm `engines` can't express it, so postinstall message + README).
- Topology upgrade path (finding 15): release notes document paused-execution behavior (`resume` refuses on `topology_hash` mismatch; `--force-retopology` forks); ship topology pin.
- Docs flip: topology JSON declared source of truth; `stage-state-machine.md` becomes narrative pointer; `system-architecture.md` updated (3 layers + executor).
- Dogfood before promote: one real project end-to-end — debt-gated skip path + ≥2 parallel cards + one forced crash-resume; `/flow retro` + `flow harness decision add` predicted-vs-actual (closes the Phase 1 supersession decision loop).

## Related Code Files

- Modify: `skills/flow/runner/flow.sh` (preflight + exemptions; `FLOW_HARNESS_DISABLE` hard error; default flip; ladder removal — one commit)
- Modify: `scripts/release-preflight.sh`
- Modify: the grep-derived `FLOW_HARNESS_DISABLE` set-site test files listed above (6 files, 16 set-sites); `tests/run_all.sh` (final named suite count)
- Modify: `.github/workflows/ci.yml` (setup-python, no-python job, timing)
- Modify: `skills/flow/SKILL.md` (version, Python requirement, graph surface); `npm-wrapper/package.json` + postinstall message
- Modify: `README.md`, `docs/system-architecture.md`, `docs/codebase-summary.md`, `CHANGELOG.md`, `skills/flow/harness/README.md`
- Create: `docs/migration-v1.md` (follow existing docs naming)

## Implementation Steps

1. Audit actual Python floor (grep f-strings/walrus/match across harness modules; test on the floor version in CI once); document measured floor.
2. Implement preflight + exemptions + `FLOW_HARNESS_DISABLE` hard error; re-derive the set-site inventory by grep at implementation time, update those test files + `flow.sh:3667` message + 3 docs.
3. CI: setup-python + no-python job + Windows timing measurement gate.
4. Migration guide: python requirement (per-OS install), `FLOW_HARNESS_DISABLE` removal, paused-execution topology guidance, DB-resolver note (stray worktree-local `.flow/harness.db` files from pre-v1 runs are ignored post-v1; document manual cleanup), pin-previous-major escape hatch.
5. Default flip + ladder removal (one revertable commit) → full matrix run.
6. Dogfood per Architecture; retro + decision record.
7. Version bumps + CHANGELOG; publish npm; tag.

## Success Criteria

- [ ] No-python env: verbs exit non-zero with actionable message; `doctor`/`--help`/`--version` still work (CI job green)
- [ ] `FLOW_HARNESS_DISABLE=1` → hard error naming migration guide; grep-derived set-site files (6 files, 16 sites) + `flow.sh:3667` message + 3 docs updated
- [ ] Full matrix green with named suite count; Windows wall-clock measured and within 30m cap BEFORE flip
- [ ] Measured Python floor documented in migration guide + README (no invented value)
- [ ] Dogfood evidence: debt-gated skip + 2 parallel cards + crash-resume demonstrated on a real project; retro + decision record written
- [ ] v1.0.0 skill + 1.0.0 npm published; CHANGELOG covers all three breaking changes; `docs/migration-v1.md` live and ≤800 LOC docs limit respected

## Risk Assessment

- User fallout (accepted trade-off): migration guide + pin-previous-major escape; monitor issues.
- Windows: Store-stub + Git Bash quirks gated by dedicated CI job, not local testing.
- Rollback: revert release commit restores flag-off + ladder; DB additive so downgrades safe.

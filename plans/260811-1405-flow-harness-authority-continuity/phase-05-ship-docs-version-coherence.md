---
phase: 5
title: "Ship docs version coherence"
status: pending
priority: P1
effort: "0.5d"
dependencies: [2, 3, 4]
---

# Phase 5: Ship docs version coherence

## Overview

Close the wave: full suite green, version/coherence, CHANGELOG, npm-wrapper sync if required, short north-star note so future upgrades map to usefulness / quality / continuity.

## Requirements

- Functional: `tests/run_all.sh` green  
- Functional: CHANGELOG entry for this wave  
- Functional: skill product version bump (SKILL.md + portable-manifest + plugin if present) when shipping  
- Non-functional: `flow.sh coherence` clean after version bump  
- Non-functional: **`npm-wrapper/scripts/sync.mjs` required** before any version bump that ships skill tree (not optional — red-team #8)

## Architecture

Versioning rule (existing harness README):

- Skill product version drives telemetry `flow_version`  
- npm package version is separate installer version  

Ship as **0.27.0** (or next free minor) themed: *harness authority continuity*.

**CHANGELOG honesty:** only claim waves actually merged (A / A+B / A+B+C).

## Related Code Files

- Modify: `CHANGELOG.md`
- Modify: `skills/flow/SKILL.md` metadata version
- Modify: `portable-manifest.json` (and `.claude-plugin/plugin.json` if present)
- Modify: `README.md` / `README_VN.md` status table if version advertised
- Optional: `docs/system-architecture.md` one-paragraph north-star
- Run: `npm-wrapper/scripts/sync.mjs` if publishing npm skill tree
- Run: `tests/run_all.sh`

## Implementation Steps

1. After implemented waves land, **sync npm-wrapper**:
   ```bash
   node npm-wrapper/scripts/sync.mjs
   ```
   Verify `npm-wrapper/skills/flow/harness/README.md` no longer has live trust pin table.
2. Run full suite:
   ```bash
   bash tests/run_all.sh
   ```
   Must include: docs_contract, lineage, native_rituals, assess, optional_smoke always-on.
3. Fix residual LIVE_AUTHORITY greps (not CHANGELOG history).  
4. Bump skill product version: `skills/flow/SKILL.md`, `portable-manifest.json`, `.claude-plugin/plugin.json`.  
5. Coherence check on declared version fields (project root with flow skill tree or documented procedure).  
6. CHANGELOG: list only shipped waves; note assess no-retrofit for old 00-inspect.  
7. README status table if advertised.  
8. Release npm per `docs/release-process.md` only if publishing.  
9. `ak plan check` phases when complete.

## Success Criteria

- [x] npm-wrapper skills synced (grep no live pin table in mirror)  
- [x] Full suite green (48 suites current baseline)  
- [x] Version fields coherent across SKILL + portable-manifest + plugin.json  
- [x] CHANGELOG honest to shipped waves  
- [x] Plan acceptance criteria checked for shipped scope  

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| npm-wrapper desync | sync.mjs before pack |
| Version skip coherence | run coherence before tag |
| Partial ship docs-only without tests | phase 2 already required focused tests; full suite here |

## Todo

- [x] npm-wrapper sync (required)  
- [x] run_all green  
- [x] version bump + coherence  
- [x] CHANGELOG + README  


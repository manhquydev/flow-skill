---
phase: 2
title: "Authority reframe atomic"
status: pending
priority: P1
effort: "1-1.5d"
dependencies: [1]
---

# Phase 2: Authority reframe atomic

## Overview

In **one** coherent change set: rewrite authority narrative + supersede GAP matrix + reframe harness-skill + **flip** contract tests that currently fail without pins 0.1.14/0.1.17. Axis: Usefulness + Continuity (no lying pins).

## Requirements

- Functional: live hot path never claims harness-cli 0.1.17 is current trust authority
- Functional: GAP states no upstream schema sync; flow owns bands 009–012, 014+
- Functional: tests enforce *new* contract (EOL honesty + story complete still required)
- Non-functional: refuse-forward rust path docs remain accurate
- Non-functional: existing DBs unchanged

## Architecture

### Target authority table (README)

| Layer | Authority |
|-------|-----------|
| Mechanical gates | `runner/flow.sh` exit codes |
| Semantic gates | `references/gate-rules.md` + law |
| Durable memory | `harness/flow_harness.py` + `.flow/harness.db` (flow-owned) |
| Historical ancestry | repository-harness pre-EOL; archive pin max `harness-cli-v0.1.22` |

### GAP file policy

Prefer **in-place supersede** of `GAP-MATRIX-0.1.17.md` (keep filename if tests path-stable) with banner:

```markdown
# SUPERSEDED (2026-08) — historical comparison only
# Live policy: no further schema sync from repository-harness / harness-cli
# Last published archive: harness-cli-v0.1.22 (EOL; no features)
```

Optional rename later: only if all refs updated + tests pass — **not required**.

### harness-skill reframe

- Early-exit if no flow project and no legacy binary  
- Primary path: `/flow harness` Python  
- Legacy `harness-cli` path: “archive binary if present; no live pin”  
- Remove **required** pin 0.1.17 as product claim  

### Test flip (mandatory same PR)

**Before (enforces dead live pins):**  
`tests/test_flow_skill_harness_docs_contract.sh` sections A/D require `0.1.17`/`0.1.14`  
`tests/test_flow_harness_lineage_contract.sh` same  

**After (enforce new contract):**

| Assertion | Intent | Removable? |
|-----------|--------|------------|
| README “flow-owned” / live authority durable language | Ownership honest | new |
| README/GAP EOL / no schema sync / historical archive | No upgrade illusion | new |
| `story complete` + `proof_source\|proof-source` | Trust boundary | **NEVER remove** |
| no bare `story update --status implemented` recipe | Trust boundary | **NEVER remove** |
| harness-skill: Forbidden implemented + Required complete + proof-source list | Trust boundary | **NEVER remove** |
| No **live** “Trust consumer pin 0.1.17” table | Honesty | replace |
| GAP may mention 0.1.14/0.1.17 only under Historical | History | allowed |
| optional smoke: pin file exists as **archive digest**; comments not “live trust CLI” | Split-brain fix | reframe |
| pins/*.sha256sums header comment: historical archive only | Split-brain fix | reframe |

**Acceptance for PR review:** diff of removed test asserts = **only** greps that enforced live pin authority — not story-complete greps.

## Related Code Files

- Modify: `skills/flow/harness/README.md`
- Modify: `skills/flow/harness/GAP-MATRIX-0.1.17.md`
- Modify: `skills/flow/SKILL.md` (harness bullet with pins)
- Modify: `skills/harness-skill/SKILL.md`
- Modify: `docs/system-architecture.md` (rust power-path wording)
- Modify: `tests/test_flow_skill_harness_docs_contract.sh`
- Modify: `tests/test_flow_harness_lineage_contract.sh`
- Modify: `tests/test_harness_cli_optional_smoke.sh` (comments + assertions: archive not live trust)
- Modify: `skills/flow/harness/pins/harness-cli-v0.1.17.sha256sums` header comments only
- Modify if needed: `docs/codebase-summary.md` stale “verbatim repository-harness”
- Do **not** edit: `CHANGELOG.md` historical 0.24 entries (immutable history)
- npm-wrapper mirror: either edit via phase 5 sync only, or sync immediately after this PR lands

## Implementation Steps

1. Apply README authority section replace pins table.
2. Banner + reword GAP matrix policy section.
3. SKILL.md: remove live pin sentence; point to flow-owned durable + GAP historical.
4. harness-skill: rewrite for `/flow harness` primary + archive binary optional; **keep** Forbidden implemented / Required complete / proof-source list **verbatim spirit**.
5. system-architecture: durable layer “flow-owned Python”; rust forward = frozen refuse-on-flow-lineage only.
6. Rewrite contract tests: replace live-pin greps; **keep** sections B/C style trust asserts; run both scripts.
7. Reframe optional smoke + pin file comments as historical archive.
8. `rg` verification against LIVE_AUTHORITY allowlist from phase 1.
9. Run focused suites: docs_contract, lineage_contract, optional_smoke always-on parts.

## Success Criteria

- [x] `bash tests/test_flow_skill_harness_docs_contract.sh` exit 0
- [x] `bash tests/test_flow_harness_lineage_contract.sh` exit 0
- [x] Live authority table/paragraph present in harness README
- [x] GAP first lines state superseded / no-sync
- [x] SKILL.md harness bullet has no live 0.1.17 trust pin
- [x] harness-skill: no required live pin claim; **still** has complete-only + forbidden implemented
- [x] optional smoke / pin file do not claim live trust consumer
- [x] PR review checklist: non-negotiable trust greps present

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| CI still greps pins elsewhere | Phase 1 inventory; full `run_all` in phase 5 |
| Users with external harness-cli binary | harness-skill still documents optional archive path |
| npm-wrapper skill copy drift | Phase 5 sync/coherence |

## Todo

- [x] Docs reframe
- [x] Test flip
- [x] Focused suite green

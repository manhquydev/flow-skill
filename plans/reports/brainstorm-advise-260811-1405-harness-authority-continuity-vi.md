# Brainstorm + Advise: nâng cấp harness flow tiếp theo

**Date:** 2026-08-11  
**Inputs:** vision (skill hữu ích coding agent → quality + continuity),  
`advise-260811-1354-repository-harness-latest-vs-flow-upgrade-vi.md`,  
hollow-done plan completed (0.26), phase-04 strategist still pending (deferred).

**Mode:** brainstorm contract + advise ranking → handoff plan  
`plans/260811-1405-flow-harness-authority-continuity/`

---

## Brainstorm contract (accepted)

### Outcome
Flow’s durable harness **tells the truth about ownership** after repository-harness EOL, and ships two **protocol ports** that raise:

1. **Usefulness** — agent/operator biết authority & next improve path  
2. **Quality under agents** — brownfield/assess không promote guess → policy; Scope/PRD stop khi material choice open  
3. **Continuity** — improve-harness ritual + recall path giữ lesson giữa session; state on disk remains SoR for ship

…while remaining **standalone** (no Rust `harness` binary, no AgentKit, no schema sync from dead CLI).

### Constraints
- Standalone: bash + optional python/sqlite only  
- Atomic flip of **docs + contract tests** that currently *require* pins 0.1.14/0.1.17  
- Existing `.flow/harness.db` projects open unchanged (no forced migration)  
- YAGNI/KISS: no full onboard-repository capsule v2 in this slice  
- Durable SQLite stays **flow-owned product**  

### Non-goals
- Re-integrate / maintain harness-cli  
- Port changesets 006–013  
- Graph default-on  
- Hollow-done wave 2 (0.26 shipped)  
- Native strategist ritual (hollow plan phase-04 backlog)  
- Skill install 3-way merge / engineering-wisdom pack  
- Dropping durable layer  

### Acceptance criteria
- [ ] Live “trust pin 0.1.17” narrative gone from skill hot path; historical EOL note only  
- [ ] GAP doc supersedes: **no further upstream schema sync**  
- [ ] `test_flow_*docs*contract*` + lineage tests green under **new** authority contract  
- [ ] Improve-flow-harness ritual documented (fresh-rerun before claim keep)  
- [ ] Assess template + gate-rules carry claim classes + material-authority stop  
- [ ] Full `tests/run_all.sh` green; version/coherence bumped when ship  
- [ ] Standalone install still works without external harness binary  

---

## Options compared

| Approach | What | Trade-off |
|----------|------|-----------|
| **A. Docs-only pin kill** | Rewrite README/GAP/tests | Fast; misses quality/continuity protocol ports |
| **B. Authority + improve + assess (Recommended)** | A + improve ritual + claim classes/stop | Medium effort; full north-star map |
| **C. Full onboard capsule + 3-way skill update** | Heavy port of repo-harness skills | High cost, low dogfood demand now |

**Recommend B.** Smallest approach that satisfies usefulness + quality + continuity after vision lock.

---

## Advise verdict

**Next implementation work is Wave Authority Continuity (B), not more hollow-done and not CLI resync.**

Ship order:
1. Atomic authority reframe (docs + tests that currently enforce dead pins)  
2. Improve-flow-harness ritual (port `$improve-harness` spirit)  
3. Assess claim classification + material-authority stop in gate-rules  
4. Version/coherence/CHANGELOG ship  

Weakest link: tests *encode* the old pin story — must change tests first-or-same PR or CI red forever.

---

## Handoff to plan

Plan dir: `plans/260811-1405-flow-harness-authority-continuity/`  
blockedBy: none (hollow-done completed; optional strategist remains separate backlog)  
blocks: none  

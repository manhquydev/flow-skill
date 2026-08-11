---
phase: 4
title: "Assess claims + material authority"
status: pending
priority: P1
effort: "0.5-1d"
dependencies: [2]
---

# Phase 4: Assess claims + material authority

## Overview

Raise **quality under agents** on brownfield + planning by minimal claim discipline and material-authority stop.  
**Not** “Stage 00-inspect” (that name is wrong — stage 00 is Idea). Assess is a **separate verb** producing `flow/00-inspect.md`.

## Requirements

- Functional: template `00-inspect.md` has claim ledger + gate checkbox
- Functional: **mechanical min** — filled assess must have ≥1 ledger row that is not placeholder-only (see tests)
- Functional: `gate-rules.md` new section **`## Brownfield assess (flow/00-inspect.md)`**
- Functional: Stages **02 / 03 / 05** get material-authority stop language
- Functional: `tests/test_flow_assess.sh` extended
- Non-functional: no evidence capsule v2 / no new python

## Architecture

### Claim classes

Authoritative | Observed | Derived | Decision required | Unknown  
(same meanings as plan.md / onboard spirit)

### Template (`00-inspect.md`)

- Section `## Evidence ledger (claims)` with table
- Gate checkbox: material claims tagged; no silent Unknown/Decision-required as product law
- Instruction: Verdict/Functionality/Risks material claims appear in ledger

### Mechanical floor (honest quality — not pure theater)

Runner today only checks boxes + `[FILL]`. This phase adds **template + tests**, and preferably a **light** runner check **only if cheap**:

**Preferred (YAGNI order):**

1. **Tests force scaffold shape** + clean fixture includes checked box + one real ledger row with a real path.  
2. Optional runner: if file has `## Evidence ledger` and status assess re-run, fail if zero non-FILL table rows — **only if** implementer can do it in <30 LOC without breaking old assess files without ledger.

Old projects without ledger: **no retrofit required**; assess already-created files remain valid (scan_gate only). New scaffolds get ledger.

### gate-rules.md

```markdown
## Brownfield assess (flow/00-inspect.md)
After `flow.sh assess` mechanical PASS:
- Are material claims tagged? Any Observed/Derived silently written as must-build product law?
- Decision required / Unknown listed for operator — not invented into Scope?

## Stage 02 / 03 / 05 — add bullet:
If materially different externally observable product choices remain open, stop;
list choice + consequences. Configurable defaults are not authority.
```

Wire assess duties in `command-dispatch.md` / SKILL assess path: after mechanical assess, apply Brownfield assess challenge.

## Related Code Files

- Modify: `skills/flow/_templates/00-inspect.md`
- Modify: `skills/flow/references/gate-rules.md`
- Modify: `skills/flow/references/command-dispatch.md` (assess duties)
- Modify: `tests/test_flow_assess.sh`
- Optional light: `skills/flow/runner/flow.sh` assess — only if cheap
- Do not: capsule scripts from repository-harness

## Implementation Steps

1. Template ledger + checkbox.  
2. gate-rules Brownfield section + material stop on 02/03/05.  
3. command-dispatch assess: semantic challenge pointer.  
4. Extend test_flow_assess.sh:
   - A: scaffold contains `Evidence ledger` + tag vocab
   - B: unfilled still exit 1
   - C: clean_inspect includes new checkbox checked + one ledger row with real path claim
5. Smoke: assess on empty sandbox creates new sections.  
6. Document in CHANGELOG (phase 5): no retrofit for old 00-inspect.

## Success Criteria

- [x] New assess scaffold has ledger + checkbox  
- [x] gate-rules has **Brownfield assess** header (not Stage 00-inspect)  
- [x] Material stop on 02/03/05  
- [x] test_flow_assess.sh green with new cases  
- [x] No capsule ported  
- [x] Old assess files without ledger still pass mechanical gate  

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Agents ignore tags | Semantic challenge + tests; optional light mechanical |
| Wrong seam (Idea) | Explicit header name |
| Breaking old assess | No mandatory ledger for pre-existing files |

## Todo

- [x] Template + gate-rules + dispatch  
- [x] test_flow_assess  
- [x] Smoke  

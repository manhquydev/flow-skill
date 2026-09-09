---
title: "Phase 4: Coding constitution"
status: todo
priority: P1
effort: "4h"
dependencies: []
---

# Phase 4: Coding constitution

## Overview

Flow `law/CLAUDE.md` is session/card process only. Mid-tier has nothing mechanical to obey while writing product code. Add a short coding constitution copied from DeepSeek AGENTS.md *disciplines* (not Cordis). Exclusive: `law/CODING.md` (create), `law/CLAUDE.md`, `_templates/card.md`, `_templates/05-contract.md`.

## Requirements

- Functional: `law/CODING.md` ≤400 words, numbered MUST/NEVER, one good/bad example each
- Functional: CLAUDE.md build-session points at CODING.md (read before implementing a card)
- Functional: card template Verify recipe requires `command + expected` (not only "concrete check")
- Functional: contract template includes one worked example row (Method/Path/Access/Input/Output including empty + failure) above `[FILL]`
- Non-functional: **no new `- [ ]` boxes** on card template (would fail `scan_gate` on every new card)

## Architecture

Do not put coding quality on `scan_gate` checkboxes. Law is always-on for build sessions; Verify recipe is what the agent copies. Matches dsh: constitution in AGENTS.md, not a fake companion invariant.

Topics (portable only):
1. Explicit resolve vs hidden `??` in handlers
2. Fail-loud named error vs silent default
3. Test title names observable behavior vs "works correctly"
4. No empty catch
5. Cite `flow/05-contract.md` / ADR / card id, never "as discussed"
6. Prefer maintained library named in ADR over hand-rolled parser when the swap deletes owned code

## File inventory

| Action | Path | Notes |
|---|---|---|
| Create | `skills/flow/law/CODING.md` | ≤400 words |
| Modify | `skills/flow/law/CLAUDE.md` | One bullet under build-session discipline |
| Modify | `skills/flow/_templates/card.md` | Verify FILL line only |
| Modify | `skills/flow/_templates/05-contract.md` | One example row |

Do not edit SKILL.md (phase 1 already points at CODING.md on card build). If phase 1 ships first without the file existing, the load is still valid (file added this phase). Parallel-safe.

## Implementation Steps

1. Write CODING.md
2. CLAUDE.md after rule 3 or 4: "Before coding a card, read `law/CODING.md`"
3. card.md Verify FILL: `command + expected output OR URL/path + observable user fact. Not "tests pass"`
4. 05-contract.md: one complete example interface row using fake `/healthz` GET public `{ok:true}` / `{ok:false,error}` so Flash copies a shape

## Test scenario matrix

| Path | Expect |
|---|---|
| Critical | CODING.md exists, `wc -w` ≤400 |
| Critical | CLAUDE.md links CODING.md |
| High | card.md Verify line contains `expected` |
| High | 05-contract.md contains a non-FILL example row |
| Medium | no new `- [ ]` in card.md vs master (diff) |

## Todo

- [ ] Write CODING.md
- [ ] Pointer in CLAUDE.md
- [ ] Tighten card Verify + contract example
- [ ] Confirm no new gate boxes

## Success Criteria

- [ ] All inventory files updated
- [ ] Zero new scan_gate boxes on templates
- [ ] CODING.md has MUST/NEVER and examples

## Risk Assessment

Agents ignore CODING.md like they ignore long SKILL.md. Signal: first dogfood card has empty catch + "tests pass". Response: phase 1 dispatcher already loads it only on card build (short). Do not duplicate CODING.md into SKILL.md.

## Dependency map

Parallel with 1, 2, 5.

---
title: "Glossary"
description: "The terms flow uses, defined once."
---

| Term | Meaning |
|---|---|
| **Gate** | A checklist that must be honestly satisfied before a stage or card advances. Passed only when the mechanical and semantic layers agree. |
| **Mechanical layer** | `runner/flow.sh`, a deterministic bash engine exiting 0 or 1. Ground truth. |
| **Semantic layer** | The model reading `SKILL.md`, judging what a script cannot: fabricated research, grade-laundered scope, hollow evidence. |
| **Durable layer** | The Python and SQLite store holding intake, story, trace, decision, and backlog records across sessions. |
| **Stage** | One of the gated planning steps, `00-idea` through `05-contract`, each producing a file under `flow/`. |
| **Card** | One scoped build session, `cards/C-NNN.md`, with allowed files, verify, independent test, and evidence. |
| **Contract** | Stage 05, the seam between producers and consumers. Written before code, never skippable. |
| **Done-evidence** | World-state proof that a card is finished: a live URL, a real invocation, an imported API, a real skill run. Never "tests pass". |
| **Debt** | A recorded, deliberate gate-skip in `DEBT.md`, with an exposure and a condition for closing it. |
| **Security-class** | Auth, authorization, admin exposure, tenancy, payments, data migration, removing validation. Halts an autonomous run; operator-only. |
| **Teach / work mode** | Who writes the planning artifacts — you, or the agent. The gates bind identically. |
| **Project type** | `web`, `cli`, `library`, or `skill`. Selects the contract seam and the done-evidence rule. |
| **Concierge** | The chat front door that routes natural language through mechanical state to exactly one proposed action. |
| **Drift check** | An advisory check that flags disagreement between artifacts: coherence, contract, tokens, consistency. |
| **Attestation** | A fingerprint-bound receipt proving a specific reviewed or verified subject, consumed by autonomous runs. |
| **Kill** | Abandoning at a gate. A valid, honoured outcome. |
| **Two-strikes** | A blocked card gets one repair by a fresh subagent before escalating. |
| **Playbook** | Paid-for stack knowledge, read before building on that stack and harvested after. `/flow promote` shares it across projects. |

Canonical definitions live with the skill:
[`skills/flow/SKILL.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/SKILL.md)

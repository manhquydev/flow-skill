---
title: "Stage artifacts"
description: "The files each flow stage produces, and where they live in your project."
---

The runner copies templates into your project as each stage unlocks. Planning artifacts live
under `flow/`, shipping units under `cards/`, and ledgers at the project root.

| Path | Stage | Contents |
|---|---|---|
| `flow/00-idea.md` | 00 | The three-sentence pitch: who has the problem, what they do today, what you would do instead |
| `flow/00-inspect.md` | brownfield | Current-state assessment: stack, functionality against product goals, risks, test baseline |
| `flow/01-research.md` | 01 | What already exists — competitors, live systems, real evidence |
| `flow/02-scope.md` | 02 | Graded features, cuts, and the scope sign-off |
| `flow/03-prd.md` | 03 | Numbered functional requirements (`FRn`) |
| `flow/04-adr.md` | 04 | Architecture decisions, including rejected options |
| `flow/05-contract.md` | 05 | The interfaces, written before code. The seam. Never skippable |
| `flow/constitution.md` | optional | Operator-authored per-project invariants, advisory |
| `cards/C-NNN.md` | build | One scoped build session: allowed files, implements, verify, independent test, evidence, risk |
| `MODE`, `PROJECT_TYPE` | — | Authoring mode and project type |
| `DEBT.md`, `RETRO.md`, `AUTO-LOG.md` | — | Deliberate skips, retro lines, autonomous run log |
| `.flow/harness.db` | — | Durable records |

Every planning artifact ships with `[FILL]` placeholders and gate boxes; both are scanned
mechanically, and either one left unresolved fails the stage. Unresolved decisions belong
under an `## Open decisions` heading, where the same scanner counts them.

Stage order, unlock conditions, and required contents:
[`skills/flow/references/stage-state-machine.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/stage-state-machine.md)

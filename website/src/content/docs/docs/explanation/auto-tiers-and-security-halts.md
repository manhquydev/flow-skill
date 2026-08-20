---
title: "When work must halt"
description: "Skip is a loan. Security-class work never skips silently. Auto is tiered, and Tier-C HALTs. This page is the public home for those rules."
---

Skip is a loan, and loans get written down. A security-class reason never skips silently and is never a planner's decision. `/flow auto` is tiered: green work can merge without asking, and security-class work **HALTs**.

This page is the operator home for those rules. Maintainer files stay canonical in the repo; they are linked only in the footer.

## Security-class halt rules {#security-class-halts}

These classes are never “such as” with a silent remainder. Every one of them **halts**.

- authentication / auth
- authorization
- admin-surface exposure
- tenancy
- payments
- data loss / data migration
- removing or weakening validation

On any of them:

- The **operator** accepts the exposure **in writing** in `DEBT.md`. You do not decide it for them.
- In `/flow auto` this is a **Tier-C HALT**. Stop and ask. Do not proceed.
- Closing a run with **open security debt** requires explicit operator acknowledgment. “Temporary” is not an acknowledgment.

## Skip a gate with debt {#skip-a-gate-with-debt}

Skipping is legitimate. Skipping silently is not.

Record the exposure first, then skip:

```
/flow debt add "skip 01-research" "<the exposure, concretely>" "<close before: named condition>"
/flow skip 01-research --reason "…"
```

Guards, in this order (they reference the class list above; they do not replace it with a shorter one):

1. Stage **05 (contract) can never be skipped**. Adapt the contract to the project type instead. See [Why the contract can never be skipped](/docs/explanation/stage-pipeline/#contract-never-skipped).
2. A security-class reason **halts**. The operator accepts the exposure **in writing** in `DEBT.md`. It is **never a planner’s decision**.
3. An **unrelated** open debt line will not unlock the stage.
4. `/flow skip` only advances when an **open** debt line **names that exact stage** **and** the reason is **not** security-class.
5. After a legitimate skip, `planning_complete` may tolerate that stage so cards are not blocked forever. The debt line remains open.

### DEBT.md

- The first skip creates `DEBT.md`.
- Line shape: skipped thing, concrete exposure, named close-before condition, date, cards.

```
- [ ] DEBT: <what was skipped> -- <exposure> -- close before: <named condition> -- opened <date> (cards: C-NNN...)
```

- Closing a run with **open security debt** requires explicit operator acknowledgment. “Temporary” is not an acknowledgment.
- A card blocked by a debt stays `todo` with PARTIAL evidence naming the debt. Never half-done, never rounded up to done.

## Run an auto build {#run-an-auto-build}

`/flow auto` preflights; on pass, it writes shared auto state. `/flow auto stop` returns to manual. There is no hidden bypass.

Preflight is **fail-closed**:

- every card has a classified risk (**no `unknown`**)
- security-class cards need a **distinct-author acknowledgement** in `DEBT.md`
- stage 05 carries a **current** `semantic_gate` receipt

Then, per card, the loop in operator language is: classify the tier, build in an isolated worktree with a scoped subagent, review, receipts, `check`, merge, deploy, live verify, paste world-state evidence, then done. Use `/flow workspace` verbs so the journal has no hole. A raw `git worktree add` records nothing.

### Tiers

| Tier | What | Action |
|---|---|---|
| **Tier-A** | Green, no security-class | Auto-merge without asking. |
| **Tier-B** | Fixable | **One** repair by a **fresh** subagent (two-strikes). First red of an ordinary card does not call a billable cross-vendor engine. |
| **Tier-C** | Security-class touch **or** a debt skip | **HALT**. Operator accepts in writing in `DEBT.md`. Never planner-decided. |

Hard caps (iterations / tokens / wall-clock) are mandatory. Exceed any → HALT + report. A loop with no cap is an antipattern.

Every gate decides on a **mechanical** signal (real exit code, real `## Verify`, live check). Never an agent’s self-assessment.

Parallel merge conflict → halt and re-plan. The overlap check was gamed.

## When the run stops itself {#halts-when-the-run-stops}

A run HALTs and reports. It never silently continues. It stops on any of:

- A hard-stop cap exceeded (iterations / tokens / wall-clock).
- A red ground-truth signal that cannot be repaired in two strikes.
- A Tier-C security-class touch.
- A merge conflict during parallel builds (the allowed-files overlap check was gamed: stop and re-plan).
- `BLOCKED` / `NEEDS_CONTEXT` from a subagent that more context cannot resolve.

On halt: state what stopped, what is done, the open debt or blocker, and **2–4 concrete options**. Do not patch around a regression. Let the operator decide.

---

Maintainer homes (not the public page): [`skills/flow/references/debt-and-halts.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/debt-and-halts.md), [`skills/flow/references/auto-run.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/auto-run.md), [`skills/flow/references/attestations.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/attestations.md).

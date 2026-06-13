# Stage state machine

How `/flow` advances. The runner computes "current stage" as the highest-numbered stage
file that exists in `flow/`. `/flow next` gate-checks that stage and, on pass, unlocks the
next one. Planning is complete only when **all six** stage gates are clean; only then does
`/flow card` unlock.

```
(no flow/)                      --/flow next-->  flow/00-idea.md        [stage 00 unlocked]
flow/00-idea.md   gate clean    --/flow next-->  flow/01-research.md    [stage 01 unlocked]
flow/01-research.md gate clean  --/flow next-->  flow/02-scope.md       [stage 02 unlocked]
flow/02-scope.md  gate clean    --/flow next-->  flow/03-prd.md         [stage 03 unlocked]
flow/03-prd.md    gate clean    --/flow next-->  flow/04-adr.md         [stage 04 unlocked]
flow/04-adr.md    gate clean    --/flow next-->  flow/05-contract.md    [stage 05 unlocked]
flow/05-contract.md gate clean  --/flow next-->  PLANNING COMPLETE      [/flow card unlocks]
all 6 gates clean               --/flow card-->  cards/C-001.md, C-002.md, ...
cards built + verified          --/flow check->  per-card exit gate (status done + evidence)
all cards done                  --/flow retro->  one line in RETRO.md
```

A gate FAIL never advances; it lists every unchecked box and `[FILL]` with line numbers.
**Kill is also a terminal state** — stopping at any gate (especially Scope) is a valid,
honored outcome, not a failure of the flow.

## What each artifact must contain (so the gate is meaningful)

| Stage | File | Must contain |
|---|---|---|
| 00 Idea | `flow/00-idea.md` | 3-sentence pitch (who/pain/what) + one named real person with the pain |
| 01 Research | `flow/01-research.md` | 3 opened competitors, 3 quoted complaints w/ links, real prices, ONE named first-10 channel, switch reason, free-vs-hard |
| 02 Scope | `flow/02-scope.md` | every feature Impact(H/M/L)+Grade(A/B/C), C-justification path, cut list, GO/KILL |
| 03 PRD | `flow/03-prd.md` | numeric success metric, pain&gain mapping table, user-action->observable-result features |
| 04 ADR | `flow/04-adr.md` | decisions with why+rejected covering storage/auth/deploy, NOT-doing list |
| 05 Contract | `flow/05-contract.md` | every feature->endpoint, request+response shapes, auth per endpoint |
| Card | `cards/C-NNN.md` | one-thing scope, deps, allowed files, verify steps, named done-evidence, pasted evidence when done |

## Shipping stages live inside cards
Build -> Review -> Deploy -> Verify-live are NOT `/flow next` stages. They happen inside
each card: the `## Verify` checklist (run for real) and `## Evidence` (world-state proof).
Card sequence (scaffold/CI -> vertical slice -> backend -> contract-tests -> UI mock ->
frontend -> e2e) is governed by `law/CLAUDE.md`.

## Runner contract
- `flow.sh` exit `0` = pass/advanced, `1` = gate fail or usage error.
- Reads/writes `flow/`, `cards/`, `MODE`, `RETRO.md`, and seeds `DESIGN.md` once, under `FLOW_PROJECT_ROOT` (default `$PWD`).
- `DEBT.md` is written by the **semantic layer** (Claude), not the runner — the runner only reminds.
- Templates are read-only from `<skill>/_templates`; never edited during a run.

# Artifact lifecycle — what moves after a change

Unlock order (`stage-state-machine.md`) says how a plan is *built the first time*.
This file says what happens to the artifacts *after* a requirement changes. It is
a naming convention, not a runner feature — there is no `flow.sh lifecycle`. Not a
`next` gate.

## Default: living plan + append-only cards

Flow runs **one product cycle** in `flow/` + `cards/`:

- **Living plan.** `flow/00…05` are amended in place. A changed requirement edits
  `03-prd.md` / `05-contract.md` where the requirement lives (plus a
  `## Clarifications` note if it came from `/flow clarify`). You do not fork a new
  planning tree.
- **Append-only cards.** Issued `cards/C-NNN.md` are **not** rewritten to chase a
  plan change. New or changed work becomes **new** cards (`C-NNN+1`), with
  `deps:` on the cards they build on. A "v2" is more cards + a plan amendment —
  **not** a parallel `specs/002-…/` universe.

This keeps one source of truth for *planning* (PRD + contract) and one for *done*
(world-state evidence in card `## Evidence`). It is why the mechanical scanner can
stay simple: there is exactly one `flow/` and one `cards/` to gate.

## The three models (name the one you are using)

| Model | What moves first | When |
|---|---|---|
| **living** (default) | the plan artifact is edited in place; new cards append | ordinary requirement change mid-cycle |
| **cycle-forward** | a fresh set of cards (and a PRD amendment) opens a new increment; old cards stay immutable as the shipped record | a v2 / next milestone on top of a shipped v1 |
| **flow-back** | code already drifted ahead of (or behind) the plan; you reconcile plan↔tree, then append remainder cards | after an out-of-band change, or to catch a hollow-complete plan |

All three keep the **append-only cards** rule. They differ only in what you touch
first. Pick one deliberately; do not silently rewrite issued cards to hide drift.

## Flow-back closer = converge

The flow-back model needs a step that reads the present code against the plan
(PRD `FRn`, contract interfaces, cards, constitution `INV-n`) and **appends**
remainder cards for whatever is `missing` / `partial` / `contradicts` /
`unrequested` — without rewriting history. That closer is `/flow converge`.

`/flow converge` is a **deferred cycle** (fixture-first): it ships only after a
hollow-complete eval fixture proves the semantic gap-detection works. Until then,
run the flow-back reconciliation **by hand**: read the tree vs PRD+contract, then
`/flow card` the remainder yourself. So the pointer here is "the flow-back closer
is converge, **when it exists**" — an honest forward-reference, with the hand-card
fallback in the meantime.

## What not to do

- **Do not add a `specs/NNN-slug/` tree** (spec-kit style) or a `feature.json`.
  Flow numbers work with card ids, not a second spec universe; a parallel tree is
  how you get two sources of truth that drift.
- Do not rewrite or renumber an issued card to match a plan edit — append instead.
- Do not treat the plan as immutable and pile all change into cards — the plan is
  living; keep PRD/contract honest so a stranger can still build v1 from them.

# Converge — append-only remainder cards (plan vs present code)

Flow can prove a *card* is not hollow (Verify + world-state Evidence). It cannot prove the
*plan* was fully expressed in the card tree. `converge` closes that gap: assess present code
against the plan, then **append** remainder cards for whatever is still missing. It never
rewrites history and never touches application code.

`converge` is the **flow-back closer** named in `references/artifact-lifecycle.md`.

## When
- After the originally planned cards are `done` but you want to confirm the codebase actually
  expresses every PRD `FRn`, contract interface, and constitution `INV-n`.
- Mid-cycle when code drifted ahead of (or behind) the plan and you need to reconcile.
- Not a `next` gate. Opt-in. The runner half only *appends* cards from a payload you produce.

## Operating constraints (non-negotiable)
- **Append-only.** Never edit, renumber, or delete an existing `cards/C-*.md`.
- **Never touch application code.** `converge` emits cards; a human/`auto` builds them later.
- **Byte-identical when converged.** If nothing remains, write nothing and print `CONVERGED`.
- **Assess present code, not a diff.** Read what the tree does now vs what the plan requires;
  this is not a git-diff or branch comparison.
- **Transactional.** Either every remainder card is written, or none is (no partial append).

## Intent inventory (what you load)
From the plan: PRD `## Features` (`FRn` + observable result), `05-contract.md` interfaces
(request/response/failure shapes, access), constitution `INV-n` MUST rows, the card set and
their claimed scope. This is the set of promises the code must keep.

## Code-scope map (what you check it against)
Read the source the cards claim to have built. For each promise, decide whether the present
code keeps it. Judge behaviour and interfaces, not line counts.

## Gap taxonomy (closed set)
- **missing** — a promised `FRn` / interface / MUST has no implementation in the tree.
- **partial** — implemented but incomplete against its observable result / failure shape.
- **contradicts** — the code does something the plan/contract forbids or specifies differently.
- **unrequested** — code surface exists that no `FRn`/interface/decision asked for.

## Severity (closed set)
- **CRITICAL** — a constitution MUST or a P1/baseline `FRn` is missing or contradicted.
- **HIGH** — a non-baseline `FRn` or a named contract interface missing/partial.
- **MED / LOW** — partials with a workaround; cosmetic contradictions.

## Disposition
- `missing` / `partial` / `contradicts` → a remainder card (`implements:` the `FRn`/interface,
  `## Scope` citing the source-ref + gap-type, `deps:` on the last related card).
- `unrequested` → a **review card** (or a `DEBT` line), never an instruction to delete code.

## Present the findings first
Emit a findings table (id, gap-type, severity, source-ref, one-line) to the operator BEFORE
any card is written. Then hand the payload to the runner, which appends the cards.

## Payload schema (`flow-converge/v1`)
Write findings to `.flow/converge-pending.md` (run-state, gitignored — so a `CONVERGED` run
never dirties `cards/`), then run `/flow converge` (or `flow.sh converge --file <path>`). The
runner is transactional: it appends every card or none. Format — a header, then one `---`-fenced
block per finding:

```
schema: flow-converge/v1
findings: 2

---
gap-type: missing
severity: HIGH
implements: FR2
source-ref: 03-prd.md:FR2
title: implement the mark-task-done endpoint
deps: C-002
allowed: src/app.py
---
gap-type: unrequested
severity: LOW
implements: none
source-ref: src/app.py:debug_dump
title: the debug_dump surface no feature asked for
deps:
allowed: src/app.py
```

Each block: `gap-type` (missing|partial|contradicts|unrequested — the runner rejects anything
else and writes nothing), `title` (required), and optional `severity`/`implements`/`deps`/
`source-ref`/`allowed`. `unrequested` becomes a **review** card (`implements: none`) — never a
delete instruction. Zero findings (or no payload) → the runner prints `CONVERGED` and writes
nothing. Appended cards ship with `[FILL]` Verify/Done-evidence (they are not built yet).

## Converge challenge

*(Sliced by the converge eval judge. This section is the criteria a reviewer applies when
asked whether a codebase still owes work against its plan.)*

A codebase is **converged** only when every promise in the plan is kept by the present code:

- Every PRD `FRn` has code that produces its stated observable result — not a stub, not a
  handler that returns the shape without the behaviour, not a sibling feature standing in.
- Every contract interface exists with its request/response **and failure** shape.
- Every constitution MUST is honoured.
- No code contradicts a stated decision, and no unrequested surface is silently load-bearing.

Report a **GAP** when at least one promise is not kept by the present code — most commonly a
declared `FRn` that the source never implements while its card is marked done. Report
**CONVERGED** only when the present code keeps every declared promise. When the evidence is
ambiguous, prefer **GAP** — an unflagged missing feature is the failure this check exists to
catch. A card marked done is not evidence the feature exists; read the source.

## Done when
- [ ] Findings table presented before any write
- [ ] Remainder cards appended (or `CONVERGED` printed and nothing written)
- [ ] No existing card edited; no application code touched

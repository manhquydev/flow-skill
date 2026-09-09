# Gate examples — hot-path PASS / FLAG

After `flow.sh` mechanical PASS, compare the artifact to these excerpts. Same challenges as `gate-rules.md`; **no new rules**. Full fixtures live in `eval/fixtures/` (f01a/f01b, f02a/f02b, fcda/fcdb).

## §01 Research

**PASS** (f01a) — named tool + working link; the note reads like someone opened it:

> 1. Splitwise (splitwise.com) — handles group expense splitting well, but its recurring-bill view buries anything not tagged "rent"; three of our pilot households gave up trying to track a shared internet bill inside it and moved back to a spreadsheet.

Same PASS shape: Tricount (tricount.com) + the export paywall they actually hit; a named Google Sheet as the incumbent, with a concrete concurrent-edit failure.

**FLAG** (f01b) — unsourced competitors; could be written without opening anything:

> 1. Splitwise — a well known bill-splitting app used by a lot of people, and honestly one of the first names that comes up whenever this category is discussed.

Same FLAG class: quotes with no URL ("users online"); "social media" as the first-10 channel. A later hostname floor is not "opened 3 competitors."

## §02 Scope

**PASS** (f02a) — C called C, path written next to the feature:

> Debt-simplification nudge (who-owes-whom, minimized transaction count) — impact H (the differentiator named in stage-01: "I want a nudge, not a number") — grade C (a real graph-minimization algorithm, not off-the-shelf) — path 1: this C IS the product's differentiator, so it goes FIRST in build order, and no sibling C features are scoped alongside it in v1.

**FLAG** (f02b-class C-launder) — **realtime graded B**. Impact is M, grade is B: the joined-bullet L-above-A scanner will not catch this. Judgment must.

> Real-time balance sync across all household members' devices — impact M (keeps everyone on the same page without needing to manually refresh, which matters for a shared-use app like this one) — grade B (can build this alongside the nudge feature using similar techniques, since the underlying data layer is shared between the two anyway)

`gate-rules.md` Stage 02: realtime, payments-from-scratch, custom auth, autonomous agentic pipeline, heavy concurrency = C. Call C a C. "Shared data layer / similar techniques" is the launder. Sibling tells: empty cut list; GO on vibe; "no C-grade items." Do **not** treat L-impact + B/C as this class (that fail is mechanical).

## §Card (`/flow check C-NNN`)

**PASS** (fcda) — every evidence item names a URL, curl/command, or path:

> Staging URL: https://staging.householdsplit.app/g/demo-4person/balance (live; group seeded via `scripts/seed-demo-group.ts`)
> Test run: `PASS src/balance/simplify.test.ts` — 14 cases
> Screenshot: `docs/evidence/C-001-staging-balance-screen.png` — nudge text "Alice owes Bob $12.50" replacing the raw pairwise table

**FLAG** (fcdb) — process-only / artifact-less. CI green, two approvals, release notes. No URL, curl, or path:

> The pull request went through the normal review process, picked up the two required approvals, and the CI pipeline stayed green the whole way through. The branch was merged into main and is now included in this cycle's release notes under "new features," so the nudge is part of the current build going forward.

Merge ≠ shipped. Plausible prose that names neither artifact nor the command that produced it is still hollow (`ground-truth-gates.md` rule 8).

# Gate examples — hot-path PASS / FLAG

After `flow.sh` mechanical PASS, compare the artifact to these excerpts. Same challenges as `gate-rules.md`; **no new rules**. Full fixtures live in `eval/fixtures/` (f01a/f01b, f02a/f02b, f05a/f05b, fcda). `fcdb` is a mechanical FAIL (`flow.sh check` exits 1) — not a semantic FLAG after PASS.

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

## §03 PRD

**PASS** — numeric success metric; pain table maps evidence → v1 feature; FR1 is action→result with empty/fail:

> Success metric: 10 named Facebook-group households settle a recurring bill through the nudge in week 1; median time-to-nudge < 2h.
>
> | P1 | Roommate who owns the internet bill | Recurring bills not tagged rent vanish; households bounce to a spreadsheet | stage-01: "I want a nudge, not a number." — reddit.com/r/personalfinance/comments/17k2xq1 | Shared Google Sheet that breaks under concurrent edits | Debt-simplification nudge (FR1) | Group balance shows "Alice owes Bob $12.50" instead of a pairwise table |
>
> FR1: As a roommate who paid the internet bill, I open the group balance, and I see the minimized who-owes-whom nudge; empty: none; fail: pairwise table plus "couldn't simplify".

**FLAG** — unquantified adjective in Features, or a feature that kills no pain:

> FR2: As a roommate, I get a fast, intuitive balance view.
>
> Pain table has P1 (spreadsheet concurrent-edit) but Features also lists "in-app chat", which kills no named pain.

Same FLAG class: "save time" / "better UX" as the success metric; an `FRn` with no empty/fail/`none`.

## §05 Contract

**PASS** (f05a) — shaped table: method / path / request / response / errors / owner:

> | Method | Path | Request | Response | Errors | Owner |
> |---|---|---|---|---|---|
> | GET | /healthz | none | `{ "ok": true }` | 503 if deps down | platform |

Auth is explicit (public `/healthz` only; other routes bearer session; 401 if missing). Error model is machine-readable.

**FLAG** (f05b) — vibe / auth-optional; prose APIs, no shapes:

> We will expose some APIs as needed. Endpoints are flexible and will evolve.
> Auth might be optional depending on context. Errors should be helpful.

Same FLAG class: Access/effects is a vibe word (secure / authenticated / restricted); missing failure shape on a write.

## §Card (`/flow check C-NNN`)

**PASS** (fcda) — every evidence item names a URL, curl/command, or path:

> Staging URL: https://staging.householdsplit.app/g/demo-4person/balance (live; group seeded via `scripts/seed-demo-group.ts`)
> Test run: `PASS src/balance/simplify.test.ts` — 14 cases
> Screenshot: `docs/evidence/C-001-staging-balance-screen.png` — nudge text "Alice owes Bob $12.50" replacing the raw pairwise table

**Mechanical FAIL** (fcdb) — `flow.sh check` exits 1. Process-only / artifact-less. CI green, two approvals, release notes. No URL, curl, or path:

> The pull request went through the normal review process, picked up the two required approvals, and the CI pipeline stayed green the whole way through. The branch was merged into main and is now included in this cycle's release notes under "new features," so the nudge is part of the current build going forward.

Merge ≠ shipped. Plausible prose that names neither artifact nor the command that produced it is still hollow (`ground-truth-gates.md` rule 8). Do not treat this as a semantic FLAG after mechanical PASS — the script already fails it.

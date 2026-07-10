# Stage 02 — Scope (go/no-go)

Scope = features chosen by IMPACT × COST, inside your time budget.
KILL here is cheap and smart. Killing a weak idea at this gate is a SUCCESS outcome.

## Gate — check ALL before `/flow next`
- [x] Every feature below has an IMPACT (H/M/L with the business reason) AND a grade (A/B/C)
- [x] No L-impact feature above grade A survives in v1
- [x] The suggested-features section was actually considered (each suggestion has an in/out decision)
- [x] fit(grades, budget) holds — every C in scope is justified as path 1, 2, or 3 above (written next to the feature)
- [x] If the product IS a C feature: it is FIRST in build order, and its sibling C features are on the cut list
- [x] The cut list is written (what I am NOT building in v1)
- [x] GO / KILL decision is written below
- [x] No FILL placeholders remain in this file

## Time budget

3 weekends (roughly 24 hours of build time)

## Features in v1 (each with impact AND grade)

- Expense entry + equal/unequal split — impact H (core job: this is the one thing users
  came for) — grade A (CRUD form over a shared-group data model)
- Magic-link email auth — impact H (acquisition: no password friction for the first-10
  household to onboard) — grade B (third-party auth library, not custom) — path 2:
  re-architected from a custom session system to a managed magic-link provider
- Debt-simplification nudge (who-owes-whom, minimized transaction count) — impact H (this
  is the actual differentiator named in stage-01 research: "I want a nudge, not a number")
  — grade C (a real graph-minimization algorithm, not off-the-shelf) — path 1: this C IS
  the product's differentiator, so it goes FIRST in build order (before auth polish or
  CSV export), and no sibling C features are scoped alongside it in v1
- Push reminder when a balance sits unpaid for 7+ days — impact M (retention: keeps the
  household using it instead of drifting back to the spreadsheet) — grade A (managed push
  notification service, OneSignal free tier)

## Suggested features (impact-first — proposed, not decided)

- CSV export for bank reconciliation — impact M (retention/trust: matches the exact
  friction named in stage-01, "we gave up because we couldn't reconcile at month-end") —
  grade A (structured data → CSV is a solved problem) — IN: cheap and directly answers a
  named pain, added to v1 cut list re-evaluation next cycle, deferred to v1.1 because the
  3-weekend budget is already fully allocated to the four features above
- Multi-currency support — impact L (nobody in the named first-10 household group travels
  or splits in a second currency) — grade B (real but not trivial: exchange-rate handling)
  — OUT: L-impact above grade A is cut per the gate rule

## Cut list (NOT in v1 — deferred, not deleted)

- CSV export — deferred to v1.1, see suggested-features reasoning above
- Multi-currency support — deferred indefinitely unless a pilot household actually needs it
- In-app chat between household members — nice-to-have, no named user asked for it

## Decision

GO — the core differentiator (debt-simplification nudge) is a real but bounded C feature,
sequenced first per path 1, and the rest of v1 stays at grade A/B within the 24-hour budget.

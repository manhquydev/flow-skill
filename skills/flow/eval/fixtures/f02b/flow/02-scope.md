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

3 weekends (roughly 24 hours of build time), which should be enough given the team's
familiarity with the stack and the fact that most of these features build on well
established patterns rather than anything unusual.

## Features in v1 (each with impact AND grade)

- Expense entry + equal/unequal split — impact H (core job: this is the central thing the
  app needs to do well for it to be useful at all) — grade A (basic CRUD form over a
  reasonably simple data model, nothing unusual about the approach here)
- Magic-link email auth — impact H (acquisition: reduces friction for new users signing up
  and getting into the app quickly) — grade B (standard auth flow, using patterns that are
  common enough across similar apps that this shouldn't require much custom work)
- Debt-simplification nudge (who-owes-whom, minimized transaction count) — impact H (this
  is the differentiator that sets the product apart from just another expense tracker) —
  grade B (should be manageable with some careful engineering, reusing patterns from the
  auth flow above and general good coding practices, so it doesn't need to be treated as
  a separate high-risk item on its own)
- Real-time balance sync across all household members' devices — impact M (keeps everyone
  on the same page without needing to manually refresh, which matters for a shared-use
  app like this one) — grade B (can build this alongside the nudge feature using similar
  techniques, since the underlying data layer is shared between the two anyway)
- Live in-app chat between household members — impact L (nice extra for engagement, gives
  people a reason to open the app more often even outside of settling up expenses) —
  grade A (should be a quick addition once the core app is working, since chat is a well
  understood feature with plenty of existing patterns to draw from)

## Suggested features (impact-first — proposed, not decided)

- CSV export for bank reconciliation — impact M (helps with trust, gives users a way to
  double check the numbers against their own bank statements if they want to) — grade A
  (straightforward data export, shouldn't add much complexity) — IN, will add if time
  allows, since it seems like a reasonably cheap addition on top of the core feature set
- Multi-currency support — impact L (some users might want this if they travel or split
  costs with people abroad, though it's not clear how common that actually is for the
  target audience) — grade A (shouldn't be too hard to add basic currency conversion,
  there are plenty of libraries that handle exchange rates already) — IN, seems useful
  enough to include without much added risk

## Cut list (NOT in v1 — deferred, not deleted)

- Nothing major, most things can probably fit in the budget with good planning and by
  staying disciplined about scope creep as the build progresses, so there isn't really a
  strong candidate for the cut list at this point in the process.

## Decision

GO — the feature set looks solid and buildable within the time budget, and the team feels
confident about the overall approach based on past experience with similar projects.

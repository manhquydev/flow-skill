# Stage 02 — Scope (go/no-go)

Scope = features chosen by IMPACT × COST, inside your time budget.
KILL here is cheap and smart. Killing a weak idea at this gate is a SUCCESS outcome.

## Impact rubric (business value — score BEFORE looking at cost)

| Impact | Meaning |
|---|---|
| H | moves money or the core promise: gets users in (acquisition), gets them paying (revenue), or delivers the one job they came for |
| M | keeps users / saves real time weekly (retention, operations) |
| L | nice-to-have; nobody would pay for or switch over it |

Decision matrix: **H-impact features justify B/C cost** (via the C-paths below).
**L-impact features must be grade A or they're cut** — and even grade-A L-features are
cut when the budget is tight. The classic failure is a v1 full of A-grade L-impact
features: cheap to build, worthless to sell.

## AI coding grade rubric

| Grade | Meaning | Examples |
|---|---|---|
| A | cheap for AI | CRUD, forms, dashboards, content sites, API wrappers |
| B | moderate | file processing, 3rd-party integrations, auth via library, single LLM call, HITL AI drafts |
| C | expensive | realtime, payments from scratch, custom auth, autonomous agentic AI pipelines, heavy concurrency |

**Grade is a COST estimate, not a permission.** The gate is fit(grades, budget), not "no C allowed."
When a C feature is the real need, three honest paths:
1. **The C feature IS the product** → invert the cut: C goes FIRST (riskiest assumption first),
   everything else is minimized to serve it, and the budget is renegotiated against reality.
   But: one C proves the value prop — its siblings are v2 cards, not v1 scope.
2. **Re-architect C down to B** (highest-leverage move): multi-step agent → single LLM call;
   auto-send → human-approves-draft; custom pipeline → managed service / library.
   Same user value, one grade cheaper.
3. **Irreducible C that doesn't fit the budget** → KILL or re-budget. Both are honest.

## Gate — check ALL before `/flow next`
- [ ] Every feature below has an IMPACT (H/M/L with the business reason) AND a grade (A/B/C)
- [ ] No L-impact feature above grade A survives in v1
- [ ] The suggested-features section was actually considered (each suggestion has an in/out decision)
- [ ] fit(grades, budget) holds — every C in scope is justified as path 1, 2, or 3 above (written next to the feature)
- [ ] If the product IS a C feature: it is FIRST in build order, and its sibling C features are on the cut list
- [ ] The cut list is written (what I am NOT building in v1)
- [ ] GO / KILL decision is written below
- [ ] No FILL placeholders remain in this file

## Time budget

[FILL: e.g. "2 weekends" / "20 hours"]

## Features in v1 (each with impact AND grade)

- [FILL: feature — impact H/M/L (business reason: acquisition/revenue/retention/core job) — grade A/B/C — why]

## Suggested features (impact-first — proposed, not decided)

Up to 3 features NOT in the original idea, each chosen for business impact (how does this
get users in / get money in / keep users?). Grounded in the stage-01 GTM findings — e.g.
the first-10-users channel often implies a share/invite/referral surface; the pricing
research often implies an upsell or a paid tier. Default is OUT; each needs an explicit
decision.

- [FILL: suggestion — impact + why (tie to GTM research) — grade — IN or OUT + reason]

## Cut list (NOT in v1 — deferred, not deleted)

- [FILL: feature — why deferred]

## Decision

[FILL: GO or KILL — one sentence why]

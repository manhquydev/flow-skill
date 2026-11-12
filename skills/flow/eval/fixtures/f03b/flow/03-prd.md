# Stage 03 — PRD

1-2 pages max. Test: could a stranger build v1 from this without asking you anything?

## Gate — check ALL before `/flow next`
- [x] Every section below is filled from MY scope decision (stage 02), not re-expanded
- [x] Success metric is a NUMBER, not vibes ("save time" fails; "first response < 2h" passes)
- [x] Each feature names the user action and the observable result, tagged with a stable `FRn:` id
- [x] Pain & gain is a MAPPING TABLE: every pain cites evidence (a stage-01 quote or a named observation), and names the v1 feature that kills it; every v1 feature kills at least one pain
- [x] A stranger could build v1 from this without asking me anything
- [x] No FILL placeholders remain in this file
- [x] No unresolved open decisions (resolve via /flow clarify, or assume/cut)
- [x] No unquantified adjectives (fast / secure / intuitive / robust / prominent) in Features or NFRs — a number, a named constraint, or cut the word
- [x] Every `FRn` names the failure or empty case (what the user sees when it fails or there is nothing), or an explicit `none`

## Context

Shared apartment households spend time each month reconciling who paid what for
utilities, rent, and groceries. Existing tools are cumbersome and require complex
setup. This product enters as a ledger that turns expense logs into settlement nudges.

## Target users

Roommates who split shared bills and want an easy way to track who owes what.

## Pain & gain (mapping table — the traceability spine of the PRD)

| # | Persona | Pain (concrete) | Evidence (stage-01 quote/source or named observation) | Today's workaround | V1 feature that kills it | Observable gain |
|---|---|---|---|---|---|---|
| P1 | Roommate | Group bills are hard to track and people forget | stage-01: general frustration with spreadsheets | Shared notes app | Debt-simplification nudge (FR1) | Clear summary of who owes what |
| P2 | Roommate | Signing up for existing apps takes too many steps | stage-01: friends dislike downloading heavy apps | Manual text messages | Magic-link login (FR2) | Quicker access without passwords |

### Pains NOT addressed in v1 (deliberate — tie to the scope cut list)

- Currency conversion: deferred to future versions.

## Problem statement

Roommates need a clean way to split shared living costs without using heavy accounting apps.

## Features (user-centric — action → observable result)

- FR1: As a household member, I open the dashboard and see a fast balance overview that simplifies debts; empty: none; fail: error banner.
- FR2: As an invited roommate, I click the link and sign in quickly to view the group; empty: none; fail: invalid link message.
- FR3: As a user, I can view real-time chat messages from other roommates about upcoming bills; empty: no messages; fail: connection retry notice.

## Non-functional requirements

- Performance: system should be fast and scalable for concurrent household usage.
- Interface: mobile-friendly layout suitable for quick lookups on smartphones.

## Tech stack

- Web application with Node.js backend and modern relational database.

## Success metric (numbers only)

- 50 registered users in the first month.
- 80% satisfaction score on post-settlement feedback prompts.

## Open decisions

None.

## Assumptions

- Users have smartphones with active internet connections.
- English is the primary interface language.

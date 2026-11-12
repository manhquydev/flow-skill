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

Shared apartment households spend 30-45 minutes every month reconciling who paid
what for utilities, rent, and groceries. Existing tools either force every expense
through a peer-to-peer payment rail or require a multi-tab spreadsheet that breaks
on concurrent mobile edits. This product enters as a lightweight ledger that turns
expense logs into minimized who-owes-whom settlement nudges.

## Target users

Primary: The roommate who pays the group internet or power bill upfront and collects
from 2-4 flatmates. Tech-literate, mobile-first, currently tracks splits in Apple Notes
or Google Sheets.

## Pain & gain (mapping table — the traceability spine of the PRD)

| # | Persona | Pain (concrete) | Evidence (stage-01 quote/source or named observation) | Today's workaround | V1 feature that kills it | Observable gain |
|---|---|---|---|---|---|---|
| P1 | Bill-payer roommate | Recurring utility bills vanish in group chats; flatmates forget to pay within 7 days | stage-01: "I want a nudge, not a number." — u/frugal_flatmate | Shared Google Sheet with manual highlight colors | Debt-simplification nudge (FR1) | Dashboard shows exact net transfer "Alice pays Bob $14.20" instead of 6 pairwise splits |
| P2 | New household member | Onboarding to group expense tools requires full account creation with SMS OTP | stage-01: "We gave up on app X because roommate 3 refused to install it." | Cash transfer via Venmo with memo notes | Magic-link email entry (FR2) | User joins household ledger via 1-click tokenized URL in email |
| P3 | Busy flatmate | Manual calculations lead to rounding disputes and overpayments | stage-01: "Someone always ends up short by three dollars on the power bill." | Splitting pennies by mental math | Equal and unequal split calculator (FR3) | Exact cents balance calculated with remainder assigned deterministically to the payer |

### Pains NOT addressed in v1 (deliberate — tie to the scope cut list)

- Multi-currency conversion: deferred to v1.1 per stage-02 cut list; all first-10 households operate in USD.
- In-app payment processing: out of scope for v1; settlement remains external (Zelle, Venmo, cash).

## Problem statement

Households of 2-5 roommates lack a zero-account-creation ledger that condenses
overlapping monthly shared expenses into a single net payment instruction per person.

## Features (user-centric — action → observable result)

- FR1: As a household member viewing the group ledger, I tap "Simplify Balances", and I see the minimum number of pairwise settlements required to resolve all debts; empty: "All settled up — no balances owed"; fail: un-minimized pairwise ledger with notice "Could not minimize transactions; showing raw balances".
- FR2: As an invited roommate, I click the email magic link, and I see the group dashboard with my name selected as an active member; empty: "No group found for this link"; fail: "Magic link expired or invalid — request a new invitation".
- FR3: As a payer entering an expense, I input the total amount in cents and select participating members, and I see each member's share calculated with remainder cents allocated to the payer; empty: "Enter an amount greater than $0.00"; fail: "Split total does not match amount entered".

## Non-functional requirements

- Page load: initial ledger view renders within 800ms on 4G mobile connections.
- Ledger data storage: local SQLite with WAL mode; transaction writes commit within 50ms.
- Session tokens: cryptographically signed HMAC-SHA256 tokens valid for 30 days.

## Tech stack

- Backend: Node.js 20 LTS with native HTTP / SQLite
- Frontend: HTML5, CSS3, vanilla JavaScript (no framework bundles)
- Deployment: single container on Fly.io with persistent volume for SQLite DB

## Success metric (numbers only)

- 10 active households log at least 4 shared expenses during week 1 of pilot.
- Median time to log an expense from opening link is under 20 seconds.
- Zero arithmetic discrepancies reported across first 200 expense split calculations.

## Open decisions

None. All scope and technical boundaries locked in stage 02.

## Assumptions

- Households contain between 2 and 6 active members.
- All expenses are denominated in a single shared fiat currency (USD).
- Internet connectivity is available when logging expenses; offline sync is deferred to v2.

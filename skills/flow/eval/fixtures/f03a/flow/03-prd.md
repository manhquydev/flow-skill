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

Shared apartment households spend ~25 minutes every month reconciling who paid
what for utilities, rent, and groceries. Existing tools either force every expense
through a peer-to-peer payment rail or require a shared Google Sheet that has no
reminders, no per-person balance view, and silently breaks on concurrent edits.
This product enters as a lightweight ledger that turns expense logs into
minimized who-owes-whom settlement nudges and 7-day unpaid reminders.

## Target users

Primary: The roommate who pays the group internet or power bill upfront in a
2-5 roommate household (1-4 flatmates). Tech-literate, mobile-first, currently
tracks splits in a shared Google Sheet.

## Pain & gain (mapping table — the traceability spine of the PRD)

| # | Persona | Pain (concrete) | Evidence (stage-01 quote/source or named observation) | Today's workaround | V1 feature that kills it | Observable gain |
|---|---|---|---|---|---|---|
| P1 | Bill-payer roommate | Unpaid balances sit untouched for weeks when roommates do not open the app, forcing monthly "who forgot" arguments | stage-01: "Splitwise is great until someone doesn't open the app for two weeks and the balance just sits there. I want a nudge, not a number." — u/frugal_flatmate (reddit.com/r/personalfinance/comments/17k2xq1) | Manual chat messages reminding roommates to check the sheet | 7-day unpaid-balance push reminder (FR4) | After a net balance sits unpaid for 7 days, the debtor receives a push notification naming the exact amount owed and payee |
| P2 | Bill-payer roommate | Pairwise bills bury recurring utilities and cause monthly "who forgot" arguments | stage-01: "Every month it's the same fight about who forgot to pay for internet. I don't need another budgeting app, I need someone to just tell me the number." — u/threeway_hcol_split (r/Roommates) | Shared Google Sheet with manual highlight colors | Debt-simplification nudge (FR1) | Dashboard shows the minimized net transfer (e.g. "Alice pays Bob $14.20") instead of pairwise tables |
| P3 | New household member | Households refuse apps that force every flatmate to install or register full accounts just to view splits | stage-01 pilot observation (Facebook group interviews): households require a switch taking under 5 minutes that "doesn't require the whole household to create new accounts" | Cash/Venmo transfers with memo notes | Magic-link email entry (FR2) | Invited roommate opens the household ledger in one click from an email link without password registration |
| P4 | Busy flatmate | Existing apps refuse unequal multi-way splits unless roommates compute each person's dollar share manually first | stage-01: "We tried three apps and gave up and went back to a spreadsheet because none of them let us split a bill three unequal ways without doing the math ourselves first." — Tricount App Store review (apps.apple.com/us/app/tricount/id594204643) | Mental math and manual spreadsheet formulas | Equal and unequal split calculator (FR3) | Payer chooses equal or unequal mode, enters per-member exact cents or percentage weights, and sees validated shares |

### Pains NOT addressed in v1 (deliberate — tie to the scope cut list)

- Multi-currency support: deferred indefinitely per stage-02 cut list unless a pilot household actually needs it; all first-10 households operate in USD.
- CSV export for bank reconciliation: deferred to v1.1 per stage-02 cut list because the 3-weekend v1 budget is allocated to FR1-FR4.
- In-app chat and in-app payment settlement: cut in stage 02 (no named user asked for chat; settlement remains external via Zelle, Venmo, or cash).

## Problem statement

Households of 2-5 roommates lack a zero-account-creation ledger that condenses
overlapping monthly shared expenses into a single net payment instruction per person
with 7-day unpaid reminders.

## Features (user-centric — action → observable result)

- FR1: As a household member viewing the group ledger, I tap "Simplify Balances", and I see the minimum number of pairwise settlements required to resolve all debts; empty: "All settled up — no balances owed"; fail: un-minimized pairwise ledger with notice "Could not minimize transactions; showing raw balances".
- FR2: As an invited roommate, I click the email magic link from the managed auth provider, and I see the group dashboard with my name selected as an active member; empty: "No group found for this link"; fail: "Magic link expired or invalid — request a new invitation".
- FR3: As a payer entering an expense, I input the total amount in cents, select participating members, choose "Equal" or "Unequal" mode, and for "Unequal" enter either exact cent amounts per member or integer percentage weights (remainder cents allocated deterministically to the payer), and I see each member's computed share; empty: "Enter an amount greater than $0.00"; fail: if unequal cent amounts do not equal the total or percentages do not sum to 100%, block save and show "Split total does not match expense total".
- FR4: As a debtor whose net balance remains unpaid for 7+ days, I receive a push notification via the managed push service (OneSignal) stating the net amount and payee; empty: none (no notification when net balance is $0.00); fail: log delivery failure in the ledger audit list and retry on the next daily check without duplicating sent reminders for the same 7-day window.

## Non-functional requirements

- Page load: initial ledger view renders within 800ms on 4G mobile connections.
- Ledger data storage: local SQLite with WAL mode; transaction writes commit within 50ms.
- Auth integration: delegates email magic-link token issuance and validation to the managed third-party auth provider scoped in stage 02 (no custom password store).

## Tech stack

- Backend: Node.js 20 LTS with native HTTP / SQLite
- Frontend: HTML5, CSS3, vanilla JavaScript (no framework bundles)
- Managed services: third-party magic-link auth provider; OneSignal free tier for 7-day push reminders
- Deployment: single container with persistent volume for SQLite DB

## Success metric (numbers only)

- 10 active households log at least 4 shared expenses during week 1 of pilot.
- Median time to switch and log a first expense from opening the invite link is under 5 minutes (per stage-01 switch threshold).
- Zero arithmetic discrepancies reported across first 200 expense split calculations.

## Open decisions

None. All scope and technical boundaries locked in stage 02.

## Assumptions

- Households contain between 2 and 5 active members.
- All expenses are denominated in a single shared fiat currency (USD).
- Internet connectivity is available when logging expenses; offline sync is deferred to v2.

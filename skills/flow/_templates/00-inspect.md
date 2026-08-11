# Stage 00-inspect — Brownfield assessment (existing codebase)

Run this BEFORE planning when the project ALREADY EXISTS. Goal: an honest current-state map so
planning starts from reality, not a blank page. Fill every section from EVIDENCE (read the code),
then check the gate. `/flow assess` seeds the auto-scan and validates this gate.

## Gate — check ALL before planning
- [ ] I detected the stack / build / test / run commands (from real files; listed below)
- [ ] I mapped the main components/modules and entry points
- [ ] I assessed current functionality state (works / partial / broken) with file evidence
- [ ] I assessed UI/UX state vs the product's stated goals (or noted "no UI")
- [ ] I listed the top risks / tech-debt / known issues
- [ ] I noted the test + quality baseline (what is covered vs not)
- [ ] A human reviewed this assessment (brownfield assessment is operator-gated)
- [ ] Every material claim in this assessment is tagged in the Evidence ledger (no Unknown/Decision-required silently treated as product law)
- [ ] No FILL placeholders remain in this file

## Detected (auto-scan)
[FILL: replace with the `/flow assess` auto-scan output — stack, CI, context files]

## Ranked surfaces (auto-scan — read these first)
The auto-scan ranks source files by how widely their symbols are referenced (highest-leverage
code first). Start your functionality + risk assessment from the top of that list — the surfaces
most of the codebase depends on are where a hidden cross-cutting risk (e.g. unscoped data access)
is most likely to hide. [FILL: note which ranked surfaces you inspected + what you found.]

## What this product is (from docs/specs/code, not guesses)
[FILL: 2-3 sentences — the real product + who it's for + the core job]

## Current functionality state (evidence)
[FILL: per major feature — works / partial / stub / missing, each with file:line]

## UI / UX state vs product goals
[FILL: screens/flows present + gaps vs the stated goals; or "no UI"]

## Risks / tech-debt / known issues
[FILL: top items, ranked; cite where]

## Test + quality baseline
[FILL: what is tested vs not; how to run the suite; coverage if known]

## Evidence ledger (claims)

Tag every material claim from Functionality / Risks / Verdict. Do **not** write product
policy as fact unless **Authoritative**. Tags:

| Tag | Meaning |
|-----|---------|
| **Authoritative** | Instruction, accepted decision, product contract, documented procedure |
| **Observed** | Code/config/tests show current behavior |
| **Derived** | Direct operational consequence of observed implementation |
| **Decision required** | Normative/product choice with no authority yet |
| **Unknown** | Repo does not establish the answer |

| Claim | Tag | Source (path or "none") |
|-------|-----|-------------------------|
| [FILL: one material claim] | Observed \| Authoritative \| Derived \| Decision required \| Unknown | path:line or none |

## Verdict
[FILL: is the codebase healthy enough to build on? what must be fixed first?]

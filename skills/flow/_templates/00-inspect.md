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
- [ ] No FILL placeholders remain in this file

## Detected (auto-scan)
[FILL: replace with the `/flow assess` auto-scan output — stack, CI, context files]

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

## Verdict
[FILL: is the codebase healthy enough to build on? what must be fixed first?]

# Stage 01 — Research (inspect first)

Rule: INSPECT what already exists. Evidence required — links, quotes, screenshots.
"I think there's nothing like this" without searching = gate fail.

## Gate — check ALL before `/flow next`
- [x] I actually OPENED 3 existing tools/competitors (links below, with one honest note each)
- [ ] I found 3 REAL user complaints online and quoted them (with source links)
- [x] I wrote what competitors CHARGE (real prices) and who is paying them
- [ ] I named the ONE channel my first 10 users come from (a place, not "social media")
- [x] I wrote why those users would pick this over the status quo (one honest paragraph)
- [x] I wrote what is technically free vs hard for this idea
- [x] No FILL placeholders remain in this file

> DOGFOOD NOTE: two boxes are deliberately left UNCHECKED because they cannot be honestly
> satisfied for an INTERNAL TOOL improvement (no public market). They are evidence, not laziness.
> See FLOW-FEEDBACK below + the backlog growth item.

## What exists already (3 — open them, don't guess)

1. GitHub Spec Kit — https://github.com/github/spec-kit (Sep 2025, ~90k stars). Honest note: template-based init, but NO explicit project-type routing; assumes one spec structure.
2. BMAD-METHOD — https://github.com/bmad-code-org/BMAD-METHOD (~46.7k stars, MIT). Honest note: full SDLC with 12+ agents but treats all specs uniformly; no type-aware done gates.
3. Tessl — https://tessl.io / https://docs.tessl.io (spec registry, 10k+ prebuilt specs). Honest note: project type is implicit in chosen spec deps, not an explicit contract switch.

(Also reviewed: AWS Kiro — https://kiro.dev — Spec/Vibe modes, no project-type adapters, assumes full-stack web.)
Finding: competitors treat project type as a *flavor*, not a *gate*. None switch the done-definition (REST+Swagger vs CLI exit codes vs library test coverage).

## What users say (3 real complaints, quoted, with source)

Only ONE real, linked complaint found that touches project-type mismatch:
1. > "ng build for a library fails: does not support the 'build' target" — https://github.com/nrwl/nx/issues/1241 (tool config assumed application-type; library broke). Pre-spec-driven era.

I could NOT find 3 real, linked complaints about spec-driven frameworks being web-centric. Spec Kit's issue tracker has 0 "my CLI/library doesn't fit" complaints — the tools are <1 year old. This gate item assumes a market-facing product with a public user-feedback loop; an internal tooling improvement does not generate public complaints. (BOX LEFT UNCHECKED — honest.)

## GTM & business reality

Building is the cheap part now. Distribution and willingness-to-pay are where ideas die.

### Who pays today, and how much (pricing reference points)

- AWS Kiro → $0 (50 credits/mo) to $200/mo (Power tier), credit-based SaaS — https://kiro.dev/pricing/. Paid by AWS-native teams/enterprises.
- GitHub Spec Kit → free (MIT, GitHub-funded). Used by Copilot/enterprise teams.
- BMAD-METHOD → free (MIT, community). Startups/SMBs/self-hosted.
- Tessl → freemium (pricing not public). Enterprise spec-first teams.
No tool charges for "project-type awareness" — it is not monetized anywhere yet.

### The first-10-users channel (one, named)

DOES-NOT-FIT for an internal tool improvement. /flow's "first 10 users" are its EXISTING users building non-web things (skills, CLIs, libraries — e.g. us, building /flow itself). Adoption path is a release note ("New in /flow: project types"), not a market channel like Product Hunt / HN. This gate item assumes a product launch with customer acquisition. (BOX LEFT UNCHECKED — honest; for an internal tool this is NOT a kill signal, which is itself the finding.)

### Why switch (vs the status quo)

Today every spec-driven framework locks teams into one contract shape: spec -> monolithic web output. Building a CLI or library with them means manually suppressing the REST-endpoint contract, ignoring the "deployed URL = done" gate, and repurposing coverage logic for exit codes. A project-type-aware /flow lets a team declare once — "this is web | cli | library | skill" — and have the Contract stage, card sequence, and done-evidence adapt automatically. Monorepo teams with mixed types gain most: no template pollution, no per-project contract remapping.

## Technically free vs hard

- Free (solved by libraries/platforms): define a project-type enum + auto-detect from repo signals (package.json `bin`, `pyproject` scripts, a SKILL.md, etc.); ~50 LOC.
- Hard (custom work, real risk): per-type done-evidence validators (web: live URL + Swagger; cli: install + invoke + exit codes; library: public API + coverage; skill: install + a real /flow run) and per-type agent steering. ~1000-1500 LOC, purely additive, no breaking change to existing schema.

## FLOW-FEEDBACK (dogfood evidence)
Research gate items 2 (online complaints) and 4 (first-10-users channel) assume a MARKET-FACING product and do not fit an INTERNAL tool improvement. Proposed fix: an internal-tool variant of the gate — item 2 -> "is there a real internal pain / first-party observed friction?"; item 4 -> "who on the team benefits, and how do they hear about it?". Recorded as a backlog growth item.

# Stage 03 — PRD

1-2 pages max. Test: could a stranger build v1 from this without asking you anything?

## Gate — check ALL before `/flow next`
- [ ] Every section below is filled from MY scope decision (stage 02), not re-expanded
- [ ] Success metric is a NUMBER, not vibes ("save time" fails; "first response < 2h" passes)
- [ ] Each feature names the user action and the observable result
- [ ] Pain & gain is a MAPPING TABLE: every pain cites evidence (a stage-01 quote or a named observation), and names the v1 feature that kills it; every v1 feature kills at least one pain
- [ ] A stranger could build v1 from this without asking me anything
- [ ] No FILL placeholders remain in this file

## Context

[FILL: 3-5 sentences — the situation this product enters]

## Target users

[FILL: persona(s) — who, demographic, behavior. Reuse stage 00/01 evidence.]

## Pain & gain (mapping table — the traceability spine of the PRD)

Every row: a concrete pain, the evidence it's real, what people do about it today, the
ONE v1 feature that kills it, and the observable gain. If a feature kills no pain, cut
it; if a pain has no feature, it goes to the "not addressed" list — honestly.

| # | Persona | Pain (concrete) | Evidence (stage-01 quote/source or named observation) | Today's workaround | V1 feature that kills it | Observable gain |
|---|---|---|---|---|---|---|
| P1 | [FILL] | [FILL] | [FILL] | [FILL] | [FILL] | [FILL] |

### Pains NOT addressed in v1 (deliberate — tie to the scope cut list)

- [FILL: pain → why deferred / which v2 item covers it]

## Problem statement

[FILL: 1-2 sentences]

## Features (user-centric — action → observable result)

- [FILL: "As a <user>, I <action>, and I see <result>" — one per v1 feature from stage 02]

## Non-functional requirements

[FILL: only the ones that matter for v1 — e.g. mobile-first, page load, no-login]

## Tech stack

[FILL: backend / db / frontend / deploy target — name specific choices]

## Success metric (numbers only)

[FILL: e.g. "10 tickets filed by real residents in week 1; median first-response < 2h"]

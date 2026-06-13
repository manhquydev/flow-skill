# Stage 03 — PRD

1-2 pages max. Test: could a stranger build v1 from this without asking you anything?

## Gate — check ALL before `/flow next`
- [x] Every section below is filled from MY scope decision (stage 02), not re-expanded
- [x] Success metric is a NUMBER, not vibes ("save time" fails; "first response < 2h" passes)
- [x] Each feature names the user action and the observable result
- [x] Pain & gain is a MAPPING TABLE: every pain cites evidence (a stage-01 quote or a named observation), and names the v1 feature that kills it; every v1 feature kills at least one pain
- [x] A stranger could build v1 from this without asking me anything
- [x] No FILL placeholders remain in this file

## Context

/flow is a gated build harness that today assumes every project is a web app: the Contract stage demands an HTTP endpoint table, the standard card sequence demands a deployed URL + Swagger, and done-evidence is defined as a live URL. When the thing being built has no API or URL (a CLI, a library, a Claude Code skill), several gates either cannot be honestly satisfied or point the builder at the wrong proof. This PRD adds an explicit project-type so the gates adapt.

## Target users

Developers using /flow to build non-web products — CLI tools, libraries/packages, and Claude Code skills. Concretely: us, building /flow itself (a skill), which this dogfood proved /flow cannot cleanly describe.

## Pain & gain (mapping table — the traceability spine of the PRD)

| # | Persona | Pain (concrete) | Evidence (named observation) | Today's workaround | V1 feature that kills it | Observable gain |
|---|---|---|---|---|---|---|
| P1 | Skill/CLI builder | done-evidence is defined as "live URL"; a CLI's real proof is "installs + runs + exit codes" | dogfood: /flow's done = deployed URL, explicitly rejects "tests pass" — wrong for a CLI | check a box loosely / ignore the rule | F2 per-type done-evidence definition | "done" means the right thing per type |
| P2 | Non-web builder | Contract stage demands an HTTP endpoint table; a CLI/library has none | dogfood finding (stage 05 mismatch) | leave endpoints blank / fake them | F3 per-type Contract guidance (+ F1 setting) | Contract describes subcommands/public API, not fake endpoints |
| P3 | Any builder | /flow has no idea what kind of thing it's building | dogfood: every web-assumption stems from this | nothing | F1 project-type setting + command | one declaration adapts the gates |
| P4 | Non-web builder | the standard card sequence (scaffold /healthz, Swagger, deploy URL, e2e browser) is web-only | buildflow CLAUDE.md card sequence | improvise | F4 per-type card-sequence guidance | a sequence that fits the type |
| P5 | Any operator | a legitimately-skipped gate (recorded in DEBT) still hard-blocks `next` with no skip path | dogfood: Research gate blocked, DEBT recorded, still stuck | manual file hack / dishonest checkbox | F5 `flow.sh skip --reason` | honest gate-skips without hacks |

Every v1 feature (F1-F5) kills at least one pain; every pain has a feature.

## Pains NOT addressed in v1 (deliberate — tie to the scope cut list)

- Auto-detecting the project type (S1) — explicit setting first.
- A project-type-aware Research-gate variant (S2, backlog #1) — bigger; deferred.
- Automated done-evidence validators (S3) — v1 ships guidance enforced by the Claude layer.

## Problem statement

/flow assumes web; give it a project type so Contract, the card sequence, and done-evidence adapt to web | cli | library | skill.

## Features (user-centric — action -> observable result)

- As a builder, I run `/flow project-type cli`, and /flow records the type and adapts its guidance (F1).
- As a CLI builder, when I reach done-evidence, /flow tells me "done = installs + runs + exit codes", not "deploy a URL" (F2).
- As a non-web builder, at Contract I'm guided to describe subcommands / public API / a real /flow run, not HTTP endpoints (F3).
- As a non-web builder, I see a card sequence that fits my type (F4).
- As an operator who recorded a DEBT skip, I run `/flow skip 01-research --reason ...` and advance honestly (F5).

## Non-functional requirements

- Purely additive: the 46 existing tests must stay green; default project type = `web` (back-compat).
- Runs on Git Bash (Windows) + Unix; no new dependencies.

## Tech stack

bash (flow.sh engine) + markdown references; no new runtime. PROJECT_TYPE file mirrors the MODE mechanism.

## Success metric (numbers only)

1. Re-running this dogfood for a `skill`-type project reaches its done-definition with 0 dishonest checkboxes and 0 manual file hacks (today: 2 hacks were required — the manual stage-file copy and the loose-skip).
2. 46 existing tests stay green + >= 8 new tests for project-type behavior pass.
3. 5 of 5 dogfood friction findings have a shipped feature or a tracked backlog item.

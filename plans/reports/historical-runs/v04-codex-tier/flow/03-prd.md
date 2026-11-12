# Stage 03 — PRD

## Gate — check ALL before `/flow next`
- [x] Every section below is filled from MY scope decision (stage 02), not re-expanded
- [x] Success metric is a NUMBER, not vibes
- [x] Each feature names the user action and the observable result
- [x] Pain & gain is a MAPPING TABLE: every pain cites evidence + names the v1 feature; every feature kills ≥1 pain
- [x] A stranger could build v1 from this without asking me anything
- [x] No FILL placeholders remain in this file

## Context

`/flow` is a gated build harness whose entire value is *honest gates*. Today it orchestrates
every stage and its adversarial Review gate on a single vendor (Claude, via ck:→bmad→built-in).
The `openai-codex` plugin (v1.0.4) is installed in the host but `/flow` can't reach it. This
feature adds Codex (GPT-5.x) as a 4th, cross-vendor tier — rescue/escalation, cross-model
review, and (per operator decision) an opt-in primary drafter — while keeping the skill portable
(unbroken when Codex is absent) and every gate identical on every path.

## Target users

The flow-skill operator (dogfood loop; tracks quality metrics and hit the same-model review
ceiling at review-pass-#4) and any Claude Code user who has the `openai-codex` plugin and wants
a genuine second engine for stuck builds, independent reviews, or to run stages on GPT-5.x.

## Pain & gain (mapping table — the traceability spine)

| # | Persona | Pain (concrete) | Evidence | Today's workaround | V1 feature that kills it | Observable gain |
|---|---|---|---|---|---|---|
| P1 | operator | Builder & reviewer share one model → correlated misses pass green gates | `quality-metrics.md:38,41` (review-pass-#4 caught an auth-skip a same-model pass missed); cross-model 43→91% merge-ready (gemini-cli #26397) | apply a different *human* review lens manually | **F-B** cross-model Codex reviewer (optional 4th lens) | review surfaces ≥1 finding class same-model missed; logged as durable metric |
| P2 | operator | Two-strikes deadlock dead-ends at "fresh subagent or operator" — same model re-fails | `agent-detection.md:31-32` | manual debugging (operator hours) | **F-A** + **F-C** Codex rescue tier / auto Tier-B escalation | a blocked card gets a genuinely different engine before escalation |
| P3 | GPT-preferring user | `/flow` is Claude-only; can't run stages on their preferred engine | `agent-detection.md:15-21` (every tier is Claude) | don't use `/flow`, or fork it | **F-E** Codex opt-in primary at research/build | operator selects Codex for a stage; same gate judges the output |
| P4 | any user w/o plugin | A vendor-coupled skill would BREAK where Codex is absent | `/flow` portability promise (SKILL.md §Agent orchestration) | n/a | **F-D** detect-and-degrade + cost discipline | identical behavior to today when Codex absent; zero new failure surface |

### Pains NOT addressed in v1 (deliberate — tie to cut list)

- Per-stage cheapest-engine routing (cost router) → deferred (S1 cut, YAGNI).
- Native `flow.sh doctor` Codex probe → deferred to next release (forbidden to edit runner mid-run);
  v1 documents availability at the semantic layer (S3).

## Problem statement

A single-vendor gate has a structural blind spot; the cheapest way to close it is a second
engine at high-value moments — but only if it stays opt-in, gated identically, and degrades to
today's behavior when the engine is absent.

## Features (user-centric — action → observable result)

- **F-A:** As an operator, when a same-model agent is BLOCKED twice, I (or `/flow`) hand the
  scoped task to `codex:codex-rescue`, and I see a fresh-engine attempt before any operator escalation.
- **F-B:** As an operator, at the Review gate I run Codex as a 4th adversarial lens on the card
  diff, and I see its findings (JSON `review-output.schema.json`) merged into triage — informing,
  never auto-failing; the same Review gate still decides.
- **F-C:** As an operator running `/flow auto`, a Tier-B card that fails its same-model repair
  escalates once to a Codex fresh-engine repair (two-strikes), and I see it in `AUTO-LOG.md`.
- **F-D:** As any user, if the `openai-codex` plugin is absent/unauthenticated, `/flow` behaves
  exactly as today (ck:→bmad→built-in) and announces "codex tier unavailable — degraded", and
  Codex calls only fire at gated high-value moments (two-strikes, security-class review), never every stage.
- **F-E:** As an operator, I select Codex as the primary drafter for a research or build stage,
  and I see the artifact drafted by Codex then judged by the identical stage gate; default stays ck:.

## Non-functional requirements

- **Portability (load-bearing):** zero hard dependency on Codex; detect-and-degrade.
- **Gate parity:** no path (Codex incl.) ever lowers a gate; Codex drafts/critiques, the gate judges.
- **Context isolation:** Codex handoffs get task + files + acceptance only (no session history), per orchestration-protocol.
- **Cost discipline:** second-engine calls gated to high-value moments; default engine stays ck:.
- **No runner edits:** all v1 changes land in `references/*.md`, `SKILL.md`, `README*` (forbidden to edit `runner/flow.sh` mid-run).

## Tech stack

No new runtime code. Integration surface: `Task(subagent_type="codex:codex-rescue")` and the
`codex-companion.mjs task|review|adversarial-review` runtime (provided by `openai-codex` v1.0.4).
Changes are markdown: `references/agent-detection.md`, `references/agent-stage-mapping.md`,
`references/adversarial-review.md`, `references/auto-run.md`, `SKILL.md`, `README.md`/`README_VN.md`.
Durable metric via existing harness (`intake`/`intervention`/`decision`). Verify via live Codex calls.

## Success metric (numbers only)

1. **Detection correctness:** in this host (plugin present) `/flow` selects/announces the Codex
   tier in ≥1 stage; in a simulated absent-plugin run it degrades with 0 new failures (assert in a test).
2. **Live cross-model review:** ≥1 live `codex` review/rescue call completes and returns ≥1
   finding or a structured verdict on a real card diff (the "full live verify" the operator chose).
3. **Gate parity:** all 14 existing dev suites stay green (baseline this session: ALL PASSED) +
   any new test green → 0 regressions.
4. **Dogfood signal:** ≥3 distinct quality findings (gate friction/quality) captured to
   `docs/quality-metrics.md` for the skill-upgrade loop.

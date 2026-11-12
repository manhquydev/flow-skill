# Stage 02 — Scope (go/no-go)

Scope = features chosen by IMPACT × COST, inside the time budget. KILL here is cheap and smart.

## Gate — check ALL before `/flow next`
- [x] Every feature below has an IMPACT (H/M/L with the business reason) AND a grade (A/B/C)
- [x] No L-impact feature above grade A survives in v1
- [x] The suggested-features section was actually considered (each suggestion has an in/out decision)
- [x] fit(grades, budget) holds — every C in scope is justified as path 1, 2, or 3 (written next to it)
- [x] If the product IS a C feature: it is FIRST in build order, and its sibling C features are on the cut list
- [x] The cut list is written (what I am NOT building in v1)
- [x] GO / KILL decision is written below
- [x] No FILL placeholders remain in this file

## Time budget

~1 session (this dogfood run). It is doc/wiring work on an existing skill — no new mechanical
runner code; the build cards edit markdown references + SKILL.md + README, plus live Codex verify.

## Features in v1 (each with impact AND grade)

- **F-A · Codex detection + a 4th "rescue/second-engine" tier in the agent ladder** —
  impact **H** (core promise: closes the measured single-vendor blind spot; without it the rest
  has nowhere to plug in) — grade **B** (3rd-party integration via an existing plugin + detection
  logic in a reference doc; no runtime code). Justify: B fits budget directly.
- **F-B · Cross-model adversarial reviewer in the Review gate** — impact **H** (the dogfood pain
  that motivated this — review-pass-#4 class defects) — grade **B** (wire `codex review` /
  `codex:codex-rescue` into `adversarial-review.md` as an *optional 4th lens*; the gate still
  judges, Codex only informs). Justify: B; the JSON `review-output.schema.json` already exists.
- **F-C · `/flow auto` Tier-B repair can escalate to a Codex fresh-engine on two-strikes** —
  impact **M** (saves operator hours on deadlocks; retention/ops, not core promise) — grade **B**
  (one branch in `auto-run.md` two-strikes logic). Justify: B.
- **F-D · Graceful absence + cost discipline guardrails** (detect-and-degrade; gate the call to
  high-value moments only) — impact **H** (non-negotiable: the skill must stay portable/unbroken
  where Codex is absent — this is `/flow`'s whole portability promise) — grade **A** (a detection
  check + written rules). Justify: A, and it's load-bearing for every other feature.
- **F-E · Codex as an OPTIONAL primary drafter at selected stages** (operator decision, scope
  expansion 2026-06-14) — impact **H** (lets a team that prefers GPT-5.x run research/build on it
  directly, not only as rescue/critic; widens `/flow`'s portability claim from "Claude-only ladder"
  to "genuinely multi-vendor") — grade **B** (a *selectable* primary slot in the ladder +
  per-stage guidance; `codex:codex-rescue --write` already does write-capable card work). Justify:
  B. **Guardrail:** the gate + contract are still identical on the Codex path (Codex drafts, the
  same gate judges); Codex-as-primary is *opt-in per stage*, default stays ck: so nothing regresses
  for existing users. Stage applicability: research + build cards (where a write/produce engine
  fits); NOT the scope/PRD/ADR judgment stages by default (those stay Claude unless operator picks).

fit(grades, budget): all B/A, no C → fits the budget. F-E adds live-call cost (more Codex
invocations) — accepted by operator (full live verify already chosen).

## Suggested features (impact-first — proposed, not decided)

- **S1 · Auto-pick the cheapest engine per stage (cost router à la OpenRouter)** — impact L for
  this skill (no market; adds config surface) — grade C (routing logic) — **OUT**: YAGNI; `/flow`
  needs *one* second engine at high-value moments, not a router. Revisit only if multi-vendor demand appears.
- **S2 · Record cross-model review agreement/disagreement as a durable metric** (harness
  `intervention`/`intake`) — impact M (feeds the quality-metrics loop the user explicitly wants) —
  grade A (one harness call in the review hook) — **IN** (folded into F-B's durable hook; it's the
  "thông số để nâng cấp skill" the operator asked for).
- **S3 · `/flow doctor` reports Codex availability** — impact M (legibility: operator sees the
  tier is live) — grade A — **IN** (tiny, high-signal; folded into F-D as a doc note + the
  detection announce-the-path rule). No runner edit (forbidden during run); documented for next bump.

## Cut list (NOT in v1 — deferred, not deleted)

- Cost router / per-stage engine selection (S1) — YAGNI for a single-second-engine design.
- Editing `runner/flow.sh` to add a native `flow codex`/`flow doctor` Codex probe — **forbidden
  during a run** (SKILL.md law). Deferred to a follow-up release; v1 wires it at the semantic
  (Claude/reference) layer where it belongs.
- ~~Codex as a primary stage drafter~~ — **moved INTO scope as F-E** (operator decision
  2026-06-14). Now an opt-in selectable primary at research/build stages; default stays ck:.

## Decision

**GO (scope expanded by operator 2026-06-14)** — H-impact core (F-A/F-B/F-D/F-E) at grade A/B
fits the budget, closes a *measured* quality gap, and the engine is already installed and unused.
Scope stays at the semantic/reference layer (no runner edits). F-E makes `/flow` genuinely
multi-vendor (Codex selectable as primary at research/build), gated identically and opt-in so
existing Claude-default users see no regression.

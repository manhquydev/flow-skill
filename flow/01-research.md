# Stage 01 — Research (inspect first)

Project type: **skill** (internal tool / no public market) → non-web framing applies. Evidence
is first-party friction + who-benefits, not a market/pricing case. Mixed sources below are
labelled **[first-party: read the source]** (ground truth) vs **[web: researcher]** (cited,
not independently verified — treat directional).

## Gate — check ALL before `/flow next`
- [x] I actually OPENED 3 existing tools/competitors (links below, with one honest note each)
- [x] (non-web) I named the concrete first-party friction / observed pain that justifies this
- [x] (non-web) what people spend AROUND this problem today (time, a worse tool, manual work)
- [x] (non-web) who benefits + how they hear about it; "no market channel" is NOT a kill signal
- [x] I wrote why those users would pick this over the status quo (one honest paragraph)
- [x] I wrote what is technically free vs hard for this idea
- [x] No FILL placeholders remain in this file

## What exists already (3 — opened, not guessed)

1. **OpenRouter** (multi-model routing gateway) — [web]
   https://dev.to/sym/multi-model-llm-orchestration-with-openrouter-g4l
   Good: one API to 400+ models, automatic provider failover. Falls short: routes at
   request-time only — no *adversarial choreography*, no "rescue on block" or cross-model
   review orchestration. It picks a model; it doesn't make two models check each other.
2. **LangGraph** (multi-agent state graphs) — [web]
   https://medium.com/cwan-engineering/building-multi-agent-systems-with-langgraph-04f90f312b8e
   Good: composable coder→reviewer→fix loops with persistent state. Falls short: single-vendor
   ecosystem; the reviewer is typically the *same* model family — no genuine vendor diversity.
3. **Aider architect-mode** (CLI two-model: architect proposes, editor executes) — [web]
   Good: vendor-agnostic, per-task model choice, mature git automation. Falls short: it's a
   *propose/execute* split, not *adversarial review*; no escalation-on-deadlock logic.
4. **(first-party baseline) `/flow`'s own ck:→bmad→built-in ladder** —
   `references/agent-detection.md:15-21`. Good: portable, degrades cleanly. Falls short: every
   tier is a Claude-model drafter; the two-strikes escalation is "fresh subagent or operator"
   (`:31-32`) — same model, correlated blind spots. **This is the gap.**

Verdict: none combine *both* rescue-escalation AND cross-model adversarial review in one
gated harness. `/flow` + a Codex tier would.

## First-party friction (non-web pain that justifies this)

1. > **Review pass #4 (dogfood) caught a real security weakness** — the contract/auth seam was
   > skippable — only because a *different review lens* was applied (`docs/quality-metrics.md:38,41`).
   > Same-model self-review had passed it. This is exactly the correlated-blind-spot failure a
   > second engine addresses. [first-party]
2. > The host already has the engine sitting unused: `openai-codex` plugin **v1.0.4** installed
   > (`~/.claude/plugins/cache/openai-codex/codex/1.0.4/`), exposing `codex:codex-rescue` (agent)
   > + `codex:review`/`adversarial-review` (with a JSON `review-output.schema.json`). `/flow`
   > can't reach it. [first-party: read the plugin source]
3. > Two-strikes deadlock today dead-ends at the operator (`agent-detection.md:31-32`) — manual
   > intervention is the "worse tool / manual work" people spend time on around this problem.
   > [first-party]

## What people spend around this today (the "price")

- Status quo: a blocked card costs **operator hours** of manual debugging (the `/flow auto`
  Tier-B "fresh subagent" is still same-model, so it re-fails on model-shared blind spots).
- Cost of the proposed lever [web: researcher]: GPT-5.x Codex ≈ **$1.75/M input, $14/M output**
  (~$0.35–0.70 per rescue/review call), OR **bundled in a ChatGPT Plus/Pro subscription** ($20/$200
  mo) — for an internal skill the subscription model makes a rescue call a negligible cost lever.
  ROI framing: one avoided PR-rework (hours) dwarfs a sub-dollar second-engine call.

## Who benefits & how they hear about it (non-web)

The flow-skill operator (dogfood loop — metrics already track "Reviews-to-clean" and same-model
correlation is the next quality ceiling) and any Claude Code user with the `openai-codex` plugin.
They learn about it via the version bump + README "Agent orchestration" section + `/flow recall`
surfacing the new tier. **No market channel — expected for a skill, not a kill signal.**

## Why switch (vs the status quo)

Because the gap is *measured, not hypothetical*: cross-model review empirically catches markedly
more real defects than same-model. Concrete data points [web: researcher, directional — not
independently verified]: a Gemini-CLI study of 27 PRs found single-model review **43% merge-ready**
vs an iterative cross-model (Gemini↔Claude) loop **91% merge-ready**
(https://github.com/google-gemini/gemini-cli/discussions/26397); and LLM-as-judge studies report
systematic same-model self-bias (style/authority) that a different vendor doesn't share. `/flow`'s
whole value is honest gates — a same-model-only adversarial gate has a structural blind spot, and
a second engine is the cheapest way to close it without weakening any gate.

## Technically free vs hard

- **Free (solved by the platform):** invoking Codex — the `openai-codex` plugin already provides
  the `codex:codex-rescue` subagent (`Task(subagent_type)`) + `codex-companion.mjs task|review|
  adversarial-review` runtime, auth, background/foreground, and a JSON review schema. `/flow`'s
  detection ladder + status-protocol contract already exist to plug a new tier into.
- **Hard / real risk:** (a) **graceful absence** — the plugin may be missing or unauthenticated
  (headless/CI: device-code/OAuth can fail — researcher cite, issue #9253); detection must degrade
  silently to today's behavior. (b) **disagreement noise / false positives** — a cross-model
  reviewer adds findings that may conflict; need a triage rule (it *informs*, the gate still
  judges; never auto-fail on Codex opinion alone). (c) **the gate must stay identical** — Codex is
  a drafter/critic, never a gate-lowerer (same law as ck:/bmad). (d) **cost discipline** — gate the
  second-engine call to high-value moments (two-strikes, security-class review), not every stage.

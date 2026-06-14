# Agent detection & priority

`/flow` orchestrates whatever specialist agents exist in the host, and degrades to
built-in behavior when none are present. It stays portable: rich where agents exist,
unbroken where they don't.

## Detection (at runtime, by the skill = Claude)

You already know which agents and skills the host exposes (the Task tool's
`subagent_type` registry + the available Skills list). Detect by checking that registry —
do NOT assume. Also glob for project-local definitions when unsure:
- ck: agents: `.claude/agents/*.md` (project) and the host agent registry.
- bmad skills: the Skills list (`bmad-*`) and `.claude/skills/bmad-*`.

## Priority order (operator chose: ck: first, bmad alternative)

For each stage, pick the FIRST available:
1. **ck: agent** (primary) — planner, researcher, architect, fullstack-developer, code-reviewer, tester, ui-ux-designer, docs-manager, git-manager, debugger, scout.
2. **bmad-* skill** (alternative) — bmad-prd, bmad-create-architecture, bmad-spec, bmad-create-story, bmad-dev-story, bmad-code-review, bmad-check-implementation-readiness, bmad-market-research, bmad-technical-research, bmad-qa-generate-e2e-tests.
3. **built-in fallback** — you (Claude) do it inline, or spawn a generic `Explore`/`general-purpose` agent. Output shape must match the agent path so the gate is identical.

## Codex — the cross-vendor second engine (a tier that crosses the ladder, not just sits under it)

When the `openai-codex` plugin is present, a **fourth path** unlocks: **Codex (OpenAI GPT-5.x)**.
Codex is not "tier 4 below built-in" in the linear sense — it is a *cross-vendor engine* used at
three specific moments where a genuinely different model is worth more than another Claude pass.
Full seam (invocation surfaces, shapes, cost gate): **`references/codex-integration.md`**.

- **Rescue / escalation (default use).** When a same-model agent returns BLOCKED a second time
  (two-strikes), hand the scoped brief to `codex:codex-rescue` BEFORE escalating to the operator.
  A different engine breaks deadlocks correlated blind spots can't. This *replaces* "fresh subagent
  or escalate" as the preferred second strike when Codex is available.
- **Cross-model review.** At the Review gate, run Codex as an extra adversarial lens
  (`codex-companion.mjs review|adversarial-review`) — see `adversarial-review.md`. It INFORMS
  triage; the gate still judges. Never let Codex's verdict auto-pass or auto-fail a card.
- **Opt-in primary drafter.** The operator MAY select Codex as the primary drafter for a
  research or build stage (`codex:codex-rescue --write` / `codex-companion.mjs task --write`).
  Default stays ck:; the identical stage gate judges the Codex-drafted artifact.

**Detection (I1) — installed ≠ usable.** The codex tier has two states (`codex-integration.md` §I1):
**INSTALLED** (`codex:codex-rescue` in the registry OR the `openai-codex` plugin dir exists) and
**USABLE** (INSTALLED + a non-billable `codex-companion.mjs setup --json` check reports
`ready` + `auth.loggedIn`; NOT `status`, which has no auth field — see `codex-integration.md`).
**Only select Codex when USABLE.** INSTALLED-but-not-usable (no auth / unreachable — common in
headless/CI) or absent → **degrade** to ck:→bmad→built-in, announce "codex tier unavailable —
degraded to <path>", record the reason. Never route to Codex on mere presence: that would spend a
billable attempt then fail at invocation. Codex absence/unusability never lowers a gate and never
breaks a run — this is the portability promise. "Eligible" in this file means USABLE.

**Cost gate (F-D).** Codex calls are billable (external GPT-5.x). Fire them ONLY at high-value
moments: a two-strikes deadlock, a security-class card review, or an explicit operator opt-in.
Never call Codex on every stage by default.

## Rules

- **Same gate regardless of path.** The buildflow gate (`flow.sh` + `gate-rules.md`) is the
  contract. An agent fills an artifact; the gate still judges it. A missing agent never
  lowers a gate — it only changes who drafts.
- **Context isolation (orchestration-protocol).** Give each subagent ONLY: the task, the
  specific files to read/modify, acceptance criteria, and relevant law/contract excerpts.
  Never the full session history. One card = one scoped brief.
- **Status protocol.** Every subagent returns DONE / DONE_WITH_CONCERNS / BLOCKED /
  NEEDS_CONTEXT. Handle BLOCKED/NEEDS_CONTEXT before retry (more context → simpler task →
  escalate). Two-strikes: a second red result → **Codex rescue if the tier is eligible**
  (`codex:codex-rescue`, a different engine), else fresh subagent, else escalate to operator.
- **Durable record hook.** After a stage/card agent finishes, write the durable record via
  `flow.sh harness ...` (story add/update, trace, decision add) so progress survives the
  session. See `agent-stage-mapping.md` for the per-stage hook.
- **Announce the path.** Tell the operator which path ran ("research via `researcher`
  agent" / "via bmad-market-research" / "inline fallback") so the run is legible.

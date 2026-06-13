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

## Rules

- **Same gate regardless of path.** The buildflow gate (`flow.sh` + `gate-rules.md`) is the
  contract. An agent fills an artifact; the gate still judges it. A missing agent never
  lowers a gate — it only changes who drafts.
- **Context isolation (orchestration-protocol).** Give each subagent ONLY: the task, the
  specific files to read/modify, acceptance criteria, and relevant law/contract excerpts.
  Never the full session history. One card = one scoped brief.
- **Status protocol.** Every subagent returns DONE / DONE_WITH_CONCERNS / BLOCKED /
  NEEDS_CONTEXT. Handle BLOCKED/NEEDS_CONTEXT before retry (more context → simpler task →
  escalate). Two-strikes: a second red result → fresh subagent or escalate to operator.
- **Durable record hook.** After a stage/card agent finishes, write the durable record via
  `flow.sh harness ...` (story add/update, trace, decision add) so progress survives the
  session. See `agent-stage-mapping.md` for the per-stage hook.
- **Announce the path.** Tell the operator which path ran ("research via `researcher`
  agent" / "via bmad-market-research" / "inline fallback") so the run is legible.

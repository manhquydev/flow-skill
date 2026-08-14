---
title: "Agent orchestration"
description: "Stages delegate to specialist agents when they exist and degrade to built-in behaviour when they do not — the gate never moves."
---

Each stage can delegate its drafting to a specialist agent, and falls back to built-in
behaviour when none is installed, which is what keeps `flow` portable rather than dependent on
somebody else's agent registry. The priority ladder is specialist agents first, then
equivalent skills, then the built-in fallback. The stage map is roughly what you would expect:
research to a researcher, scope and PRD to a planner, ADR to an architect, contract to a
spec-oriented kernel, build to a full-stack developer, review to a code reviewer or a
three-layer adversarial review, live verification to a tester.

The rule that makes this safe is one sentence: **agents are pluggable, gates are fixed.** The
gate is identical on every path, so a missing agent can never lower a bar and a fancy agent
can never raise a pass it did not earn. Delegation is also context-isolated by design — a
subagent gets only its task, its files, its acceptance criteria, and the relevant law or
contract excerpts, never the session history — and it returns one of a small set of verdicts.
After any delegation the gate runs, the semantic challenge is applied, the durable hook is
written, and which path actually ran is announced.

Stage-to-agent map, prompt template, and durable hooks:
[`skills/flow/references/agent-stage-mapping.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/agent-stage-mapping.md)

---
title: "The two-layer harness"
description: "Why flow splits gating into a deterministic script and a model gatekeeper, and why a gate passes only when both agree."
---

This is the core idea of `flow`. Everything else is a consequence of it.

A gate has to catch two very different kinds of failure, and no single component is good at
both. So `flow` runs two layers, and a gate is passed only when **both** agree.

## Layer one — the mechanical gate

`runner/flow.sh` is a bash engine that is deterministic and exits 0 or 1. It owns the stage
and card lifecycle, and it checks the things that are trivially cheatable and trivially
detectable:

- unchecked gate boxes, including leftover `- [ ]` bullets under `## Open decisions` — the
  same scanner handles both
- leftover `[FILL]` placeholders
- card status validity
- an empty `## Evidence` section on a card claiming to be done

Its exit code is ground truth. The rule for the model is blunt: always run the script first,
read its exit code, and relay it faithfully. Never substitute your own judgment for it.

What this layer cannot do is read for meaning. It cannot tell a real competitor quote from an
invented one, or an honest B-grade feature from a C that was written up as a B.

## Layer two — the semantic gate

That is the model's job. After the script passes, the skill applies a per-stage set of
challenges before the operator is allowed to advance. This is where fabricated research gets
questioned, where grade-laundered scope gets named, where an endpoint with no auth column
gets flagged, and where "tests pass" pasted into an evidence section gets rejected as
mid-pipeline.

The instruction is symmetrical and matters in both directions: do not silently advance past a
hollow artifact, and do not silently block a sound one. When the script passes but the
content is weak, the operator is told exactly that — it mechanically passed and it is
qualitatively weak — and the operator decides.

## Why the split, rather than one smarter checker

A script cannot judge meaning; a model cannot be trusted to be deterministic about mechanics.
Splitting them puts each failure class where it can actually be caught, and it makes the
cheatable half enforceable rather than persuadable. You cannot talk `exit 1` out of its
opinion. You also cannot write a regular expression that detects a fabricated market quote.

There is a second, subtler benefit. Because the mechanical layer is a separate process with a
real exit code, the model's own claims about a gate are auditable. An agent that says "the
gate passed" can be checked against a signal it did not produce.

## The third layer: durable memory

Underneath both sits a durable layer — a Python and SQLite store holding intake and risk
lane, story and proof, trace and tier, decisions, and a backlog. It degrades gracefully: if
`python3` is absent, gates still run and only this layer switches off.

```
+---------------------------------------------------------------+
|  Semantic layer  -  SKILL.md + references/  (the model)       |
|  judgment: hollow content, grade-laundering, adversarial      |
|  review, agent orchestration, work mode, auto tiers           |
+---------------------------------------------------------------+
              | calls (exit code = ground truth)
              v
+---------------------------------------------------------------+
|  Mechanical layer  -  runner/flow.sh  (bash, exit 0/1)        |
|  stage/card lifecycle, gate checks, debt ledger,              |
|  design check, harness passthrough                            |
+---------------------------------------------------------------+
              | reads/writes (best-effort, graceful degrade)
              v
+---------------------------------------------------------------+
|  Durable layer  -  Python + sqlite3 (flow-owned)              |
|  intake/risk-lane, story+proof, trace+tier, decision, backlog |
+---------------------------------------------------------------+
```

It is external memory. Progress and friction survive across sessions and context windows,
which is the antidote to the slow degradation that happens when a long project lives only in
a conversation.

## The consequence for agents

Agents are pluggable; gates are fixed. A stage can delegate drafting to a specialist agent
when one is present, and falls back to built-in behaviour when none is. The gate is identical
on every path, so a missing agent can never lower a bar. An agent drafts; the gate still
judges.

The same rule governs the optional cross-vendor engines. A second or third model can review a
card, but its verdict informs triage — it never auto-passes and never auto-fails.

## See also

- [Gates and semantic challenges](/docs/explanation/gates-and-semantic-challenges)
- [System architecture](/docs/explanation/system-architecture)
- [Done means world-state evidence](/docs/explanation/done-evidence)

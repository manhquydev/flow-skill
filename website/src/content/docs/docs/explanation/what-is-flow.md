---
title: "What is flow"
description: "flow is a gated build harness for coding agents: honest gates between an idea and real done-evidence, not a project-management layer."
---

`flow` is a **gated build harness**. It walks a product from an idea to real
done-evidence — a deployed URL, an installed CLI that runs, an importable library API, or a
skill that reaches its own done-definition — through gates that must be honestly satisfied
before you advance.

It is a skill you install into a coding agent, not a service you sign up for and not a
framework your code depends on. It is standalone: no AgentKit and no claudekit are required,
though optional multi-model review unlocks when those engines are present.

## The problem it exists for

A coding agent will happily produce a plausible plan, a plausible research document, and a
plausible claim that the work is finished. Each artefact reads well in isolation. The failure
is systemic rather than local: nothing in the loop is positioned to say *no*.

Two specific failure modes account for most of the damage.

**Paperwork that looks like progress.** A research document with fabricated competitor
quotes passes any structural check. A scope document where a C-grade feature has been written
up as a B passes too. Both read fine; neither survives contact with reality.

**"Done" that is not done.** An agent reports a card complete because the tests are green and
the branch merged. Nobody loaded the page. Nobody ran the command. "Tests pass" is a
mid-pipeline state that has been quietly promoted to a terminal one.

## What flow does about it

Three commitments, and everything else follows from them.

**Done means proof in the world.** Every card names its evidence up front, and the gate
demands that evidence pasted in before the card can be marked done. For a web project that is
a live URL and real `curl` output; for a CLI, a real invocation with its exit code. Merged
code and green CI are explicitly not accepted. See
[Done means world-state evidence](/docs/explanation/done-evidence).

**Two layers must agree.** A deterministic script catches the cheatable mechanics — unchecked
boxes, leftover `[FILL]` placeholders, empty evidence — and exits 0 or 1. The model reading
the skill catches what a script cannot: fabricated research, grade-laundered scope, an
endpoint with no auth. A gate is passed only when both agree. See
[The two-layer harness](/docs/explanation/two-layer-harness).

**Killing at a gate is a valid outcome.** A harness that can only say "proceed" is a
conveyor belt. Killing a weak idea at Scope is cheap and smart, and flow treats it as a
first-class result rather than a failure to be worked around.

## What it is not

It is not a project-management tool: there is no board, no burndown, no estimate. It is not a
code generator — it gates whatever agent or human writes the code. It is not a CI system,
though its evidence rules are stricter than most CI gates. And it is not a wrapper that makes
an agent smarter; it makes an agent *accountable*, which is a different and more useful thing.

## The shape of a run

```
Idea -> Research -> Scope -> PRD -> ADR -> Contract -> Cards -> Build -> Review -> Deploy -> Verify-live -> Retro
|------------------ planning (files in flow/) ------------------|  |------- shipping (inside cards/) -------|
```

Planning is six gated stages that live as files under `flow/`. Shipping is a series of cards
under `cards/`, each one a single scoped build session against the contract written at stage
05. Between sessions a durable store keeps debt, retros, traces, and playbooks, so the next
session starts with prior pain in view.

Chat is the default entry — describe what you want and the concierge proposes one next
action. Typed verbs such as `/flow next` always win over chat routing.

## Where to go next

- [The stage pipeline](/docs/explanation/stage-pipeline) — what each gate defends against.
- [The two-layer harness](/docs/explanation/two-layer-harness) — the mechanism in detail.
- [Install and first run](/docs/tutorials/install-and-first-run) — see a gate refuse in ten
  minutes.

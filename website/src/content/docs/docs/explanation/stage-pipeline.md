---
title: "The stage pipeline"
description: "What each gated stage from Idea to Retro is defending against, and why the contract is the one stage that can never be skipped."
---

```
Idea -> Research -> Scope -> PRD -> ADR -> Contract -> Cards -> Build -> Review -> Deploy -> Verify-live -> Retro
|------------------ planning (files in flow/) ------------------|  |------- shipping (inside cards/) -------|
```

The pipeline is not a checklist of documents to produce. Each stage exists because a specific
kind of self-deception tends to happen at that point in a build, and the gate is aimed at
that deception.

## Planning: six gated files

Planning artifacts live under `flow/` and are numbered so the order is not negotiable.

**00 — Idea.** A three-sentence pitch: who has the problem, what they do today, what you
would do instead. The gate is looking for a problem rather than a solution wearing a
problem's clothes. This is the cheapest place in the entire project to kill something.

**01 — Research.** What already exists: competitors, live systems, real prices. The rule is
*inspect first, evidence not vibes*. This stage is where fabrication is most tempting and
most expensive, because a plan built on invented competitors is confidently wrong for weeks.
A script cannot detect an invented quote; the semantic gate is the only defence.

**02 — Scope.** Grade features and cut. The characteristic failure here is
grade-laundering — a C-grade feature written up as a B because you want to build it. Scope is
where most projects are saved or lost, which is why `work` mode pauses for an explicit
operator sign-off at exactly this point and nowhere else.

**03 — PRD.** The surviving scope becomes numbered functional requirements. Every `FRn`
written here must later be claimed by a card and served by a contract interface. That trace
is mechanically auditable, so a requirement cannot quietly evaporate between planning and
building.

**04 — ADR.** Architecture decisions, including what you rejected and why. The rejected
options are the valuable part: six months later they are the reason nobody re-litigates a
settled question.

**05 — Contract.** The interfaces, written before any code exists. Method, path, auth,
request and response shapes for a web project; commands, flags, output shapes and exit codes
for a CLI; the exported API surface for a library; the command surface for a skill.

## Why the contract can never be skipped

Every other planning stage can be skipped with honest recorded debt. Stage 05 cannot, ever.

The contract is the **seam**. Producers build to it, consumers build from it, and the two
sides can proceed independently precisely because the shape between them is fixed. Skipping
it does not save time; it relocates the cost to integration, where two half-built sides
discover they disagree and someone rewrites one of them.

The discipline that follows is strict: never improvise a shape. If a shape turns out wrong,
amend the contract first and then change the code. Honour a shape now with a null or a stub
even when its real value ships in a later card.

If the contract does not fit your project type, adapt it — read "endpoint" as
"interface" or "command" — rather than skipping it.

## Shipping: cards

After stage 05 passes, `/flow card` cuts build cards. Each card is one scoped build session
with an allowed-files list, the requirements it implements, a verify block, an independent
test, and an evidence section that starts empty.

Build, review adversarially, deploy, then verify **live** as a user would. The card is done
when world-state evidence is pasted in and the check gate passes — not when the tests are
green.

## Brownfield: stage 00-inspect

An existing codebase does not start at Idea. `/flow assess` scaffolds and gates
`flow/00-inspect.md`, a current-state map covering the stack, what the product does today
against what it is supposed to do, risks, and the test baseline. It is operator-reviewed, and
it exists so that planning for an existing system is grounded in what is actually there
rather than in what the repository's README claims.

## Retro

One honest line per run, written by the operator and never by the agent. It feeds the durable
layer, so the next project's `recall` surfaces this project's pain.

## Kill is a valid exit

Every gate has three outcomes, not two: pass, block, and kill. A harness that can only say
"proceed" is a conveyor belt with a compliance ritual attached. Killing a weak idea at Scope
is the cheapest good decision available in a build.

## See also

- [Stage artifacts](/docs/reference/stage-artifacts)
- [Gates and semantic challenges](/docs/explanation/gates-and-semantic-challenges)
- [Your first greenfield project](/docs/tutorials/first-greenfield-project)

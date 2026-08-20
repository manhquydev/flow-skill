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

## Why the contract can never be skipped {#contract-never-skipped}

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

## Advance with `/flow next` {#advance-with-next}

`/flow next` gate-checks the stage you are on and, only if it passes, unlocks the next one.
The runner treats the highest-numbered file already in `flow/` as current. Planning is
complete only when all six stage gates are clean; only then does `/flow card` unlock.

When the mechanical layer fails it prints exactly what is wrong with line numbers — unchecked
gate boxes, leftover `[FILL]` placeholders — and stops. A FAIL never advances. The listing is
the whole diagnosis: open the named file, fix those lines, run `/flow next` again. Do not
guess which box was empty.

When the script passes, the semantic challenge for the stage just completed is applied before
you are allowed to move on, so a mechanically clean but hollow artifact still gets named as
weak. In `teach` mode the agent will never check a box or write an artifact for you; it only
tells you what is failing.

Kill is a valid terminal state. Stopping at any gate, especially Scope, is an honored
outcome, not a failure of the flow. Pass, block, and kill are the three answers; a harness
that can only say "proceed" is a conveyor belt.

## Project types {#project-types}

`flow` was born web-shaped. The honest way to support other kinds of software was not to
generalise the gates into vagueness but to name exactly which three things change. Set the
type with `/flow project-type web|cli|library|skill` before stage 05. The value is stored in
a `PROJECT_TYPE` file and defaults to `web`. Running the command with no argument prints the
current value and the done-evidence rule it implies.

The type adapts the stage 05 contract seam, the standard card sequence, and what
done-evidence means. Everything else — every gate's spirit, "contract before code", "done is
proof in the world" — is untouched. Changing the type later means revisiting the contract, so
it is cheap now and expensive after.

- **web.** Contract: HTTP endpoints (method, path, auth, request, response); OpenAPI served.
  Done: a live deployed URL plus real `curl` output.
- **cli.** Contract: commands, flags, output shapes, exit codes. Done: the tool installs and
  a real invocation returns the expected output and exit code. First move on a CLI build:
  `/flow project-type cli`.
- **library.** Contract: the public API surface — exported functions and types with their
  shapes. Done: the public API imports, a usage example runs, coverage threshold met.
- **skill.** Contract: the commands and files the agent reads. Done: installed into the skill
  home and a real run reaches its own done-definition. First move on a skill build:
  `/flow project-type skill`.

A CLI build is not a diluted web build: the proof it must produce is just as concrete, it
simply takes the shape of an installed tool and a real exit code rather than a deployed URL.
The gates themselves are unchanged — only the shape of the proof moves.

Some stage-05 gate wording still says "endpoint" and asks for an auth column, which is web
flavouring. For other types you read "endpoint" as "interface" or "command" and substitute
writes and side-effects for auth — the stage preamble explicitly licenses that adaptation,
and the equivalent no-drift check is the per-type done-evidence actually passing.

## Project types matrix {#project-types-matrix}

Set with `/flow project-type <web|cli|library|skill>`, stored in `PROJECT_TYPE`, default
`web`.

| Type | Contract seam (stage 05) | Done-evidence | Card sequence |
|---|---|---|---|
| `web` | HTTP endpoints — method, path, auth, request, response; OpenAPI served | A live deployed URL plus real `curl` output | scaffold and `/healthz`, vertical slice, backend, contract test, UI mock, frontend, e2e |
| `cli` | Commands, flags, output shapes, exit codes | The tool installs and a real invocation returns the expected output and exit code | scaffold plus one real command, subcommand groups, tests, install smoke on a clean directory |
| `library` | The public API surface — exported functions and types with their shapes | The public API imports, a usage example runs, coverage threshold met | scaffold plus core API, rounds of API, tests, a runnable usage example, publish dry-run |
| `skill` | The commands and files the agent reads | Installed into the skill home and a real run reaches its own done-definition | scaffold plus one runnable command, references and law, install, a dogfood run |

Constant across all four types: every requirement maps to an interface, every interface has
its shapes written before code, the contract is the seam, and "tests pass" or "merged" is
never done.

## Modes and run strategies {#modes}

`flow` has four mode axes and they are genuinely independent, so you set each one per project
and combine them however the work demands.

**Authoring mode** decides who writes the gate artifacts: `teach`, the default, means you
write and the agent only gate-keeps; `work` means the agent interviews you once, drafts
stages 00 to 05, and pauses only for the scope sign-off.

**Project type** decides what done means — a live URL for web, a real invocation and exit
code for a CLI, an importable API for a library, an installed run for a skill.

**Run mode** decides how cards get built: manual, where you drive card, build, check; or
auto, an autonomous run with tiered handling that halts on security-class work.

**Greenfield versus brownfield** decides where you start: stage 00-idea for something new, or
a gated current-state assessment for an existing codebase.

What no axis changes is the bar. Gates and done-rules are identical across every combination;
the modes move authorship, proof shape, and drive, never the height of the gate.

## Clarify open decisions {#clarify-open-decisions}

Unresolved product decisions live as `- [ ]` bullets under an `## Open decisions` heading on
the Scope, PRD, and Contract artifacts. They are counted by the *same* box scanner the gates
already use, which means an unsettled decision genuinely blocks the stage rather than sitting
in a comment nobody reads.

`/flow clarify` prints those leftover bullets, scoped to that section, and always exits 0 —
it is an advisory printer, not a second gate. Settling them is a bounded, opt-in write-back
ritual: work through the bullets one at a time, record the decision in the artifact, and
check the box. Nothing about `clarify` is a prerequisite for `/flow next`; the gate scanner
enforcing the boxes already is.

## Stage artifacts {#stage-artifacts}

The runner copies templates into your project as each stage unlocks. Planning artifacts live
under `flow/`, shipping units under `cards/`, and ledgers at the project root. Paths below
are files, not headings.

| Path | Stage | Contents |
|---|---|---|
| `flow/00-idea.md` | 00 | The three-sentence pitch: who has the problem, what they do today, what you would do instead |
| `flow/00-inspect.md` | brownfield | Current-state assessment: stack, functionality against product goals, risks, test baseline |
| `flow/01-research.md` | 01 | What already exists — competitors, live systems, real evidence |
| `flow/02-scope.md` | 02 | Graded features, cuts, and the scope sign-off |
| `flow/03-prd.md` | 03 | Numbered functional requirements (`FRn`) |
| `flow/04-adr.md` | 04 | Architecture decisions, including rejected options |
| `flow/05-contract.md` | 05 | The interfaces, written before code. The seam. Never skippable |
| `flow/constitution.md` | optional | Operator-authored per-project invariants, advisory |
| `cards/C-NNN.md` | build | One scoped build session: allowed files, implements, verify, independent test, evidence, risk |
| `MODE`, `PROJECT_TYPE` | — | Authoring mode and project type |
| `DEBT.md`, `RETRO.md`, `AUTO-LOG.md` | — | Deliberate skips, retro lines, autonomous run log |
| `.flow/harness.db` | — | Durable records |

Every planning artifact ships with `[FILL]` placeholders and gate boxes; both are scanned
mechanically, and either one left unresolved fails the stage. Unresolved decisions belong
under an `## Open decisions` heading, where the same scanner counts them.

## See also

- [Gates and semantic challenges](/docs/explanation/what-is-flow#semantic-challenges)
- [What done means](/docs/explanation/what-is-flow#done-means-world-state)
- [Your first greenfield project](/docs/tutorials/first-greenfield-project)
- [When work must halt](/docs/explanation/auto-tiers-and-security-halts)

---

Maintainer homes (not the public page): [`skills/flow/references/stage-state-machine.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/stage-state-machine.md), [`skills/flow/references/project-types.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/project-types.md), [`skills/flow/references/mode-work.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/mode-work.md), [`skills/flow/references/clarify.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/clarify.md).

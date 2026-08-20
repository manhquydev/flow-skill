---
title: "What is flow"
description: "flow is a gated build harness for coding agents: honest gates between an idea and real done-evidence, not a project-management layer."
---

`flow` is a **gated build harness**. It walks a product from an idea to real
done-evidence — a deployed URL, an installed CLI that runs, an importable library API, or a
skill that reaches its own done-definition — through gates that must be honestly satisfied
before you advance.

It is a skill you install into a coding agent, not a service you sign up for and not a
framework your code depends on. **Flow owns the gates and the receipts, never the runtime.**
It is standalone: no AgentKit and no claudekit are required, though optional multi-model
review unlocks when those engines are present.

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
[Done means world-state evidence](#done-means-world-state).

**Two layers must agree.** A deterministic script catches the cheatable mechanics — unchecked
boxes, leftover `[FILL]` placeholders, empty evidence — and exits 0 or 1. The model reading
the skill catches what a script cannot: fabricated research, grade-laundered scope, an
endpoint with no auth. A gate is passed only when both agree. See
[The two-layer harness](#two-layer-harness).

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

## The two-layer harness {#two-layer-harness}

This is the core idea of `flow`. Everything else is a consequence of it.

A gate has to catch two very different kinds of failure, and no single component is good at
both. So `flow` runs two layers, and a gate is passed only when **both** agree. Both layers,
or it did not pass.

### Layer one — the mechanical gate

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

### Layer two — the semantic gate

That is the model's job. After the script passes, the skill applies a per-stage set of
challenges before the operator is allowed to advance. This is where fabricated research gets
questioned, where grade-laundered scope gets named, where an endpoint with no auth column
gets flagged, and where "tests pass" pasted into an evidence section gets rejected as
mid-pipeline.

The instruction is symmetrical and matters in both directions: do not silently advance past a
hollow artifact, and do not silently block a sound one. When the script passes but the
content is weak, the operator is told exactly that — it mechanically passed and it is
qualitatively weak — and the operator decides.

### Why the split, rather than one smarter checker

A script cannot judge meaning; a model cannot be trusted to be deterministic about mechanics.
Splitting them puts each failure class where it can actually be caught, and it makes the
cheatable half enforceable rather than persuadable. You cannot talk `exit 1` out of its
opinion. You also cannot write a regular expression that detects a fabricated market quote.

There is a second, subtler benefit. Because the mechanical layer is a separate process with a
real exit code, the model's own claims about a gate are auditable. An agent that says "the
gate passed" can be checked against a signal it did not produce.

### The third layer: durable memory

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

### The consequence for agents

Agents are pluggable; gates are fixed. A stage can delegate drafting to a specialist agent
when one is present, and falls back to built-in behaviour when none is. The gate is identical
on every path, so a missing agent can never lower a bar. An agent drafts; the gate still
judges.

The same rule governs the optional cross-vendor engines. A second or third model can review a
card, but its verdict informs triage — it never auto-passes and never auto-fails.

## Done means world-state evidence {#done-means-world-state}

Every card names its done-evidence up front, and the gate demands that evidence pasted in
before the card can be marked done. "Tests pass" and "code merged" are mid-pipeline states.
They are never done.

### The failure this prevents

The most common way an agent-assisted build goes wrong is not a bug. It is a status. A card
is reported complete because the tests are green, the review is approved, and the branch
merged. Every one of those statements is true. Nobody has loaded the page.

Each of those signals measures a **proxy** for the thing you care about. Tests measure your
model of the system against itself. A merge measures agreement about a diff. Neither touches
the actual running world. Proxies drift from reality quietly, and the drift is invisible
exactly when it matters most, because all the dashboards are green.

The fix is not more proxies. It is to require one observation of the real thing.

### What counts, per project type

The project type decides the shape of the proof, and the spirit is identical in every case:
somebody interacted with the deployed reality and pasted what came back.

| Project type | Done-evidence |
|---|---|
| `web` | The live deployed URL plus real `curl` output |
| `cli` | The tool installs, and a real invocation returns the expected output and exit code |
| `library` | The public API imports, a usage example runs, coverage threshold met |
| `skill` | Installed into the skill home, and a real run reaches its own done-definition |

Set the type with `/flow project-type <type>`; the default is `web`. The contract seam and
the rest of the type matrix live on
[Project types](/docs/explanation/stage-pipeline/#project-types).

### What does not count

Process artefacts, however impressive:

- an approved pull request
- a green CI badge or workflow run
- release notes describing what shipped
- a code review that found nothing
- an agent's own summary saying the work is complete

The mechanical layer enforces a floor here: a card whose evidence section contains only
process prose is rejected, so the discipline cannot be argued away in the moment. Beyond that
floor, the semantic gate asks the harder question — is this evidence the *world*, or a
description of the world?

An agent's self-assessment is specifically excluded. The ground-truth signal for every gate
is something the agent did not generate: a script's exit code, a real verify command's
output, a live check.

### Why the gate refuses an empty evidence section so aggressively

```
  [x] status is 'done' but ## Evidence is empty (paste world-state proof: URL/curl/DB row)
FAIL: C-001 has gate violations (above).
```

This fires even when the code is finished and correct. The reason is that the cheapest moment
to capture evidence is the moment you were looking at the running thing anyway. If it is
deferred, it is reconstructed later from memory, and reconstructed evidence is indistinguishable
from invented evidence.

The same reasoning drives the CLI-owned flip, `/flow card done C-NNN`: it applies the same
rules as `check` and reverts if the gate fails, so there is no code path that produces a
hollow done.

### The honest way out

If a card genuinely cannot be proven right now — the deploy target does not exist yet, the
external service is unavailable — the answer is not to weaken the evidence. It is to record
the exposure as debt, in writing, with a condition for closing it. Debt is visible and
surfaces in `recall`; a hollow done is invisible and surfaces in production.

How to open that line, and when a skip is refused, lives on
[Skip a gate with debt](/docs/explanation/auto-tiers-and-security-halts/#skip-a-gate-with-debt).
How to paste the proof onto a card lives on
[Create and check cards](/docs/how-to/create-and-check-cards).

## Semantic challenges {#semantic-challenges}

A mechanical pass means the file is structurally complete. It says nothing about whether the
content is true. The semantic challenge is the per-stage set of questions the model applies
after the script passes, and it is deliberately specific to each stage because each stage
invites a different lie.

Research invites fabricated competitors and sourceless numbers. Scope invites grade-laundering,
where a feature you want to build is written up a grade above what it earned. The PRD invites
requirements with no owner and pain with no feature. The contract invites an endpoint with no
auth column. Cards invite evidence that describes process rather than the world. A generic
"is this good?" prompt catches none of these reliably; a named challenge per stage does.

The instruction runs in both directions: never silently advance past a hollow artifact, and
never silently block a sound one. When something passes mechanically but reads weak, the
operator is told exactly that and decides. There is also a behavioral proof that this layer
works at all — `/flow eval` feeds hollow-but-mechanically-clean fixtures to a fresh judge and
scores whether they get flagged, which is a lower bound rather than a guarantee.

### Per-stage, not generic

**Idea (00).** Is the pitch really three sentences (who / pain / what)? Is the named person a
real, specific person or group, not "users"? Is the pain concrete, not a category? The
forge-idea ritual is opt-in; it never becomes a condition this gate checks for.

**Research (01).** Highest fabrication risk. Were three competitors *actually opened*? For a
web / market product: are the complaints real quotes with working source links, and is the
first-ten-users channel a specific place? For cli / library / skill / internal tool: is the
first-party friction concrete and observed, with named beneficiaries — "no market channel" is
expected here, not a kill. Costs must be real, not guessed.

**Scope (02).** Watch for grade laundering. Call a C a C (realtime, payments from scratch,
custom auth, autonomous agentic pipeline, heavy concurrency). If material product choices
remain open (quota, identity key, tenancy, response contract, enforcement owner), stop and
list them — configurable defaults are not authority. A bullet under `## Assumptions` that
encodes product law without operator or ADR authority is an open decision or a stop, not a
silent default.

**PRD (03).** Is the success metric a real number, not "better UX"? Does every pain cite
evidence and name the v1 feature that kills it, and does every v1 feature kill at least one
pain? Orphans on either side are scope drift. Could a stranger build v1 from this without
asking the operator anything?

**ADR (04).** Does each decision name a real rejected alternative, not a strawman? Are
storage, auth, and deploy actually decided, not "TBD"? Is the NOT-doing list honest about
what is deferred?

**Contract (05).** The interface is the project type's seam: web = endpoint, cli =
command + flags + output/exit, library = public function + args + return, skill =
command/file. Every PRD feature maps to at least one interface and vice versa. Every
interface has both input and output shapes, with names that will not drift. The
access/effects column is real for every interface — do not let a web product blank it. Read
the contract against any doc it names as its own source of truth before you pass; a
contradiction here ships as "passed" and every card inherits it.

**Card (`/flow check C-NNN`).** Is the scope one thing? Is `## Independent test` a
user-visible proof, not "unit tests pass"? Does the diff stay inside `## Allowed files`? Do
shapes match `flow/05-contract.md` exactly? Is `## Evidence` world-state — a clickable URL,
real curl output, a DB row — and does every item name the artifact or the command that
produced it?

**Consistency (`/flow consistency`).** Advisory; it never blocks the build path. After the
runner's ID-based passes, the model still has to catch hollow coverage (an `FRn` pasted onto
a card that does not deliver it), requirements that contradict across artifacts, a cut-list
feature reappearing as v1, and terminology drift (`ticket` / `issue` / `request`).

The full challenge text for the model lives in the maintainer file linked in the footer.
Security-class skips and auto HALTs are not this page; they live on
[When work must halt](/docs/explanation/auto-tiers-and-security-halts).

## System architecture {#system-architecture}

`flow` is three cooperating layers plus on-disk artifacts: a fast deterministic engine for
the cheatable mechanics, a skill for judgment, and a durable store so records survive
sessions. The public operator picture is four pieces — skill, runner, artifacts, and two
version channels.

### Skill

The semantic layer is `SKILL.md` plus the playbooks under `skills/flow/references/`. It is
what the hosting agent reads: dispatch, gatekeeper, orchestration. After `runner/flow.sh`
returns 0, this layer runs the per-stage challenges above. It never replaces the script's
exit code with a vibes pass.

### Runner

The mechanical layer is `runner/flow.sh`. It is bash, deterministic, exit 0 or 1. It owns
the stage and card lifecycle, gate checks (`[FILL]`, boxes, empty evidence), the debt ledger,
the design check, and harness passthrough. Its exit code is ground truth. Always run it
first; always relay it faithfully.

Underneath, a flow-owned Python and SQLite CLI holds intake and risk lane, story and proof,
trace and tier, decisions, and backlog. If `python3` is missing, gates still run; only this
durable layer switches off.

### Artifacts

The artifacts live in the project being built, not inside the skill home:

```
flow/00-idea.md .. 05-contract.md   planning, gated
cards/C-NNN.md                      shipping units
MODE, RETRO.md, DEBT.md, AUTO-LOG.md, DESIGN.md
.flow/harness.db                    durable records
```

Planning files under `flow/` are the gated stages. Each card under `cards/` is one scoped
build session against the stage-05 contract. The ledger files and `.flow/harness.db` are how
debt, retros, and traces survive the next context window.

### Two version channels

Distribution is two parallel channels feeding the same canonical tree. The npm installer
(`npx @manhquy/flow-skill@latest`) is the primary path: pure Node, no shell required. The
repository install script is the reference implementation used in development and CI. Both
write the same skill home, so a project can switch channels without reissuing a gate.

```
  monorepo skills/flow/  --npm run sync-->  npm-wrapper/skills/flow  --npm pack-->  registry
         |                                         |
         | install.sh / agent skill homes          | npx @manhquy/flow-skill@latest
         v                                         v
  ~/.claude/skills/flow                     same tree via installer CLI
```

Those channels version different artefacts. The **skill product** versions the gates,
`SKILL.md`, the runner, references, and templates — the thing that judges your build. The
**npm package** versions only the installer CLI: agent detection, copy paths, flags. They
are not supposed to match. `--help` prints both numbers. Check them on your machine rather
than from any document. The pairing story, including which number to pin, lives on
[Two version numbers](/docs/how-to/troubleshoot-install/#two-version-numbers).

## Where to go next

- [The stage pipeline](/docs/explanation/stage-pipeline) — what each gate defends against.
- [Install and first run](/docs/tutorials/install-and-first-run) — see a gate refuse.
- [Create and check cards](/docs/how-to/create-and-check-cards) — paste the proof, mark done.

---

Maintainer homes (not the public page): [`docs/adr/0001-discipline-layer-identity.md`](https://github.com/manhquydev/flow-skill/blob/master/docs/adr/0001-discipline-layer-identity.md), [`skills/flow/references/gate-rules.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/gate-rules.md), [`docs/system-architecture.md`](https://github.com/manhquydev/flow-skill/blob/master/docs/system-architecture.md).

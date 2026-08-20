---
title: "Your first greenfield project"
description: "Walk a new project from idea through the six planning gates to a build card, and see what each gate refuses."
---

This tutorial takes an empty directory to a real build card. You will write six planning
artifacts, and each one is judged twice — once by a script that cannot be argued with, once
by the model reading it as a critic.

You need the skill installed first: [Install and first run](/docs/tutorials/install-and-first-run).

Time: an hour or two, depending on how honest you are with yourself at the Scope gate.

## The pipeline you are about to walk

```
Idea -> Research -> Scope -> PRD -> ADR -> Contract -> Cards -> Build -> Review -> Deploy -> Verify-live -> Retro
|------------------ planning (files in flow/) ------------------|  |------- shipping (inside cards/) -------|
```

Planning is stages `00` through `05`, and they live as files under `flow/`. Shipping happens
inside `cards/`. You cannot cut a card until all six planning gates have passed or carry
honest recorded debt.

## Step 1 — pick what "done" means

```
/flow project-type web
```

The project type decides what evidence the harness will demand at the end: a live deployed
URL for `web`, a real invocation with the expected output and exit code for `cli`, an
importable public API plus a running usage example for `library`, an installed skill that
reaches its own done-definition for `skill`. The default is `web`. Setting it now saves you
from writing a contract in the wrong shape.

## Step 2 — decide who writes the artifacts

```
/flow mode teach
```

In `teach` mode — the default — **you** write every planning artifact and the agent only
gate-keeps. In `work` mode the agent interviews you once, drafts stages `00` to `05`
itself, and pauses only for the scope sign-off. The gates bind identically either way; the
only difference is whose fingers are on the keyboard.

If you are learning the harness, stay in `teach` for this first project. You will see what
each gate is actually checking.

## Step 3 — stage 00, the idea

```
/flow next
```

The runner creates `flow/00-idea.md` and fails the gate, because the template is full of
`[FILL]` markers and unchecked boxes. Open the file and write a three-sentence pitch: who
has the problem, what they do today, and what you would do instead. Check the boxes you have
genuinely satisfied. Run `/flow next` again.

When the script passes, the agent applies the semantic challenge for the stage you just
finished. This is the half a script cannot do: it will push back if your "problem" is a
solution in disguise, or if the pitch describes a feature rather than a person in pain.

**Killing the project here is a valid outcome.** A weak idea killed at stage 00 costs an
hour. The same idea killed after the contract costs a week.

## Step 4 — stage 01, research

Fill `flow/01-research.md` with what already exists: competitors, live systems you looked
at, prices you actually checked. The rule under this stage is *inspect first — evidence, not
vibes*.

The semantic gate here is unusually sharp, because fabricated research is the single easiest
thing to write and the single hardest thing for a script to catch. A quote with no source, a
competitor you did not open, a market number with no link — expect to be asked where it came
from.

If the stage genuinely does not fit — an internal tool with no public market, say — do not
fake it. Record the debt and skip honestly:

```
/flow debt add "skip 01-research" "internal tool, no public market" "before public release"
/flow skip 01-research --reason "internal tool, no public market"
```

`skip` only advances when an open debt line names that exact stage and the reason is not
security-class.

## Step 5 — stages 02 to 04, scope, PRD, ADR

- **Scope** (`flow/02-scope.md`) is where projects are usually saved or lost. Grade features
  honestly; the semantic gate is watching for grade-laundering, where a C-grade feature gets
  written up as a B because you want to build it.
- **PRD** (`flow/03-prd.md`) turns the surviving scope into numbered functional
  requirements. Every `FRn` you write here must later be claimed by a card and served by a
  contract interface — that trace is mechanically auditable.
- **ADR** (`flow/04-adr.md`) records the architecture decisions and, importantly, what you
  rejected and why.

Run `/flow next` after each. Anything unresolved goes under an `## Open decisions` heading
as a `- [ ]` bullet; those bullets are counted by the same gate scanner, so an unresolved
decision blocks the stage until you either settle it or consciously move it.

## Step 6 — stage 05, the contract

`flow/05-contract.md` is the seam, and it is the one stage that can never be skipped. Write
the interfaces before any code exists: method, path, auth, request shape, response shape for
a web project — commands, flags, output shapes, exit codes for a CLI.

From here on the rule is absolute: backend builds **to** the contract, UI consumes **from**
it. If a shape turns out wrong, you amend the contract first and then change code. Honour a
shape now with a null or a stub even when its real value ships in a later card.

When this gate passes you will see:

```
PASS: stage 05-contract gate clean. Planning is COMPLETE.
All planning stages passed (or were debt-skipped). Run '/flow card' to create build cards.
```

## Step 7 — cut the first card

```
/flow card
```

This writes `cards/C-001.md`. A card is one scoped build session: an allowed-files list, the
requirements it implements, a `## Verify` block you will actually run, an
`## Independent test` describing the user-visible proof, and a `## Evidence` section that
starts empty.

Before you build, run `/flow recall` — it reads back open debt, the last retro, the previous
card's scope, and any promoted playbooks, so you start with prior pain in view.

## Step 8 — build, then prove it

Build only what the card's allowed-files list names. Then:

```
/flow check C-001
```

The card fails while `## Evidence` is empty, even if the code is perfect and every test
passes:

```
  [x] status is 'done' but ## Evidence is empty (paste world-state proof: URL/curl/DB row)
FAIL: C-001 has gate violations (above).
```

Paste the real proof — a live URL with actual curl output for a web project, the real
invocation and exit code for a CLI — and check it again:

```
PASS: C-001 is valid (status: done).
```

## What you learned

- Six planning gates, each judged mechanically and then semantically.
- Kill and honest debt-backed skip are both first-class outcomes.
- The contract is written before code and is the only unskippable stage.
- "Tests pass" is mid-pipeline; done is proof in the world.

## Next

- [Create and check cards](/docs/how-to/create-and-check-cards) for the day-to-day loop.
- [The stage pipeline](/docs/explanation/stage-pipeline) for what each stage is defending
  against.
- [Done means world-state evidence](/docs/explanation/what-is-flow/#done-means-world-state) for why step 8 is
  strict.

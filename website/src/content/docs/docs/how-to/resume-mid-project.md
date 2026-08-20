---
title: "Resume mid-project"
description: "Pick up a flow project cold without re-deriving state: run resume first, read the NEXT line, handle a stale lock, or assess a brownfield."
---

You left a project two weeks ago, or you are a fresh agent session with no memory of it.
Do **not** start by reading files and guessing where you were.

## Run resume first {#resume}

```
/flow resume
```

This is the first verb to type when entering a project mid-cycle. It is read-only, takes no
lock, and composes a session-story brief from state that already exists on disk:

- the last session, by command names only — never raw arguments
- the in-flight card and how long it has been sitting (dwell)
- the current gate state
- exactly one `NEXT ->` line

Read the `NEXT ->` line and do that. It is produced by the same decision helper that
`/flow status` uses, so the two never disagree.

## When to skip it

Skip `resume` when you already have live context in this conversation — if you are the one
who just ran `next` or `card` a minute ago, running it again adds nothing. It is for cold
entry, not for every command.

## Then get the working view

```
/flow
```

Plain `/flow` is `status`: where you are, what is blocking, current-stage dwell, the card
list (compacted to a summary past ten cards), and a one-line memory summary. Use `resume`
to re-enter, `status` to keep working.

## Recall and promote {#recall-and-promote}

```
/flow recall
```

Run `recall` at the start of a stage or a card, before you author anything. It reads back
the durable layer: open debt, the most recent retro, the previous card's scope, harness
friction and backlog, audit health, and any promoted playbooks. Treat the output as context
to apply, not noise, so the work starts with prior pain in view instead of rediscovering it.

Capture is engine-fired rather than voluntary: advancing past stage 01 seeds an intake, a
passing card check records a tier-scored trace, and a deliberate skip logs its debt.
`status` shows a one-line memory summary; `card` injects the previous card's scope
automatically. Improvement is mechanical too: `harness audit` scores entropy and drift,
`harness propose` mines repeated friction into an improvement backlog once a pattern fires
at least twice, and `harness decision outcome` closes the predicted-versus-actual loop.

A conversation window forgets. A durable record does not.

### Promote a playbook

When a lesson is bigger than one project, lift it:

```
/flow promote <playbook.md>
```

That copies the playbook into the cross-project knowledge base at
`~/.claude/flow/playbooks`. From then on `recall` surfaces it everywhere, not only where it
was learned.

The loop is capture, reuse, improve: `next` and `check` write records automatically,
`recall` reads them back, and `promote` shares the ones that earned their keep.

For extra engines (Codex and Antigravity) and the rest of the durable loop, see
[Agent orchestration](/docs/explanation/agent-orchestration/#second-engine).

## Unlock a stale session {#unlock-stale-session}

`flow` allows one session per project. Two sessions sharing one plan overwrite each other's
state. The runner keeps a `flow/.lock`: mutating commands such as `next`, `card`, `skip`,
and `auto` refuse a fresh foreign lock, `status` warns, and the lock auto-reclaims after
its TTL — `FLOW_LOCK_TTL`, 900 seconds by default.

```
/flow unlock
```

Use this only when the other session is genuinely dead — a crashed terminal, an abandoned
window. If another session is live, stop and coordinate with whoever is running it. Never
force past a live lock; concurrent runs corrupt the plan.

`FLOW_FORCE=1` takes over a lock you are sure is dead. `/flow unlock` clears it. If the
runner reports **BLOCKED by another session's lock**, stop and coordinate — never
`FLOW_FORCE` past a live session.

For hard protection rather than a warning, export a stable session id once per session and
pass it on every call:

```bash
export FLOW_SESSION_ID=$(uuidgen)
FLOW_SESSION_ID=$FLOW_SESSION_ID bash ~/.claude/skills/flow/runner/flow.sh next
```

Without it the runner can only warn — it cannot prove a different session, so it never
self-blocks.

## Assess a brownfield {#assess-a-brownfield}

A project with code but no `flow/` directory is brownfield. There is no session story to
recover yet, so do not start with `resume`. An existing codebase does not start at the Idea
stage. `/flow assess` scaffolds and gates `flow/00-inspect.md` — a current-state map —
before any planning stage opens. Planning for an existing system should be grounded in
what is there, not in what the repository's README claims is there.

Greenfield projects skip this and start at `/flow next` (Idea).

### Operator steps

1. From the project root, run:

   ```
   /flow assess
   ```

   The first run copies the inspect template to `flow/00-inspect.md`, seeds an auto-scan
   (stack, CI, context files, ranked surfaces), and seeds law files. It does not pass the
   gate yet.

2. Fill every section from **evidence** (read the code):
   - stack / build / test / run commands from real files
   - main components, modules, and entry points
   - current functionality (works / partial / stub / missing) with file evidence
   - UI/UX state versus the product's stated goals, or note "no UI"
   - top risks, tech-debt, known issues
   - test and quality baseline (what is covered, how to run the suite)
   - a **Verdict**: is the codebase healthy enough to build on, and what must be fixed first?

3. Start the functionality and risk pass from the **Ranked surfaces** auto-scan. Those
   files are the highest-leverage code — the surfaces most of the codebase depends on,
   where a hidden cross-cutting risk is most likely to hide.

4. Tag every material claim from Functionality / Risks / Verdict in the **Evidence
   ledger**. Do not write product policy as fact unless the tag is **Authoritative**.

   | Tag | Meaning |
   |-----|---------|
   | **Authoritative** | Instruction, accepted decision, product contract, documented procedure |
   | **Observed** | Code/config/tests show current behavior |
   | **Derived** | Direct operational consequence of observed implementation |
   | **Decision required** | Normative/product choice with no authority yet |
   | **Unknown** | Repo does not establish the answer |

5. A human reviews the assessment. Brownfield is operator-gated. In `teach` mode the
   agent reports; it does not tick boxes or author the artifact for you.

6. Re-run `/flow assess`. Mechanical PASS means no `[FILL]` leftovers and every gate box
   is checked. FAIL lists the remaining holes; fill them from evidence and run again.

7. After mechanical PASS, apply the semantic challenge before planning:
   - Are material claims tagged Authoritative / Observed / Derived / Decision required / Unknown?
   - Is any **Observed** or **Derived** claim silently promoted to must-build product law without operator authority?
   - Are **Decision required** / **Unknown** items listed for the operator — not invented into Scope/PRD?
   - An empty ledger, or only `[FILL]` rows while the boxes are checked, is hollow: report mechanically-passed-but-qualitatively-weak.

8. When both layers agree, proceed to planning with `/flow next`.

You can reuse `scout` / `researcher` (or `bmad-document-project`) to gather evidence. The
gate still judges. The operator still reviews.

## Running from a subdirectory

If you run `flow` from a subdirectory such as `frontend/` that has no `flow/` of its own, it
adopts the nearest ancestor flow project and prints a one-line note to stderr, rather than
minting a fragmented second root. A subdirectory with its own `flow/` or `cards/` is always
respected, as is an explicit `FLOW_PROJECT_ROOT`.

## See also

- [Create and check cards](/docs/how-to/create-and-check-cards)
- [Agent orchestration](/docs/explanation/agent-orchestration)
- [Command reference](/docs/reference/commands)

---

Maintainer homes (not the public page): [`skills/flow/SKILL.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/SKILL.md), [`skills/flow/references/command-dispatch.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/command-dispatch.md), [`skills/flow/_templates/00-inspect.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/_templates/00-inspect.md), [`skills/flow/references/gate-rules.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/gate-rules.md).

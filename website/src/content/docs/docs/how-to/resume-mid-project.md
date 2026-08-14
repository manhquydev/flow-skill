---
title: "Resume mid-project"
description: "Pick up a flow project cold without re-deriving state: run resume first, read the NEXT line, and handle a stale lock."
---

You left a project two weeks ago, or you are a fresh agent session with no memory of it.
Do **not** start by reading files and guessing where you were.

## Run resume first

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

## Load the memory before you touch anything

```
/flow recall
```

`recall` reads back the durable layer: open debt, the most recent retro, the previous card's
scope, harness friction and backlog, audit health, and any promoted playbooks. Run it before
authoring a stage or a card so you start with prior pain in view instead of rediscovering it.

## If a lock blocks you

`flow` allows one session per project. A `flow/.lock` file refuses a second concurrent
session, because two sessions sharing one plan will stomp each other.

```
/flow unlock
```

Use this only when the other session is genuinely dead — a crashed terminal, an abandoned
window. If another session is live, stop and coordinate with whoever is running it. Never
force past a live lock; concurrent runs corrupt the plan. The lock also auto-reclaims after
its TTL, 900 seconds by default.

For hard protection rather than a warning, export a stable session id once per session and
pass it on every call:

```bash
export FLOW_SESSION_ID=$(uuidgen)
FLOW_SESSION_ID=$FLOW_SESSION_ID bash ~/.claude/skills/flow/runner/flow.sh next
```

Without it the runner can only warn — it cannot prove a different session, so it never
self-blocks.

## If you are picking up someone else's code, not your own plan

A project with code but no `flow/` directory is brownfield. Run
[the assessment](/docs/tutorials/brownfield-assess) instead of `resume`; there is no session
story to recover yet.

## Running from a subdirectory

If you run `flow` from a subdirectory such as `frontend/` that has no `flow/` of its own, it
adopts the nearest ancestor flow project and prints a one-line note to stderr, rather than
minting a fragmented second root. A subdirectory with its own `flow/` or `cards/` is always
respected, as is an explicit `FLOW_PROJECT_ROOT`.

## See also

- [Create and check cards](/docs/how-to/create-and-check-cards)
- [Unlock a stale session](/docs/how-to/unlock-stale-session)
- [Command reference](/docs/reference/commands)

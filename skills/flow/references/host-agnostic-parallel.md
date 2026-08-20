# Host-agnostic parallel occupancy

Flow requires **no named multiplexer**. Parallel cards are a ready-gate +
worktrees + host-owned placement + world-state fan-in. Absence of Herdr, tmux,
in-process `Task`, or any other host **never fails a gate** and never changes
`flow.sh` exit.

Herdr and tmux appear below only as **examples, never as a dependency** or a
first-class adapter.

## Degrade ladder

| Rung | Primitive already in the process | Who binds occupants | Who waits |
|---|---|---|---|
| **0** | In-process subagents / `Task` | Hosting agent; cwd = the card's worktree | Host `Task` join |
| **1** | Operator extra terminals / tabs | Human pastes the print-enter block | Human |
| **2** | Process is **already inside** a mux (`HERDR_ENV=1` / `TMUX` set) | That mux's **own** skill/CLI; flow does not wrap or detect it | That mux's own wait |
| **3** | None of the above, or `/flow ready` overlap | Serial: one card | Hosting agent, one at a time |

Rung 2 is opt-in by the mux's own environment injection, never by `PATH`.
Inside-mux probe is the mux's own env (`HERDR_ENV=1`, `TMUX`), never
`command -v herdr` from outside (a CLI can talk to a same-uid socket without
`HERDR_ENV`). Absence of rungs 0–2 is the default path, not a degrade footnote.

## Gate parity

Host `idle` / `done` / `blocked` is **not a card pass**. `flow.sh check` still
judges, and it must run **in the card's worktree** (parent-tree check of main
is a false fail/pass). Screen output is not evidence.

Keep the four "blocked" senses distinct:

| Sense | Meaning | Home |
|---|---|---|
| **host-blocked** | mux/pane approval chrome or occupant stuck | the host |
| **subagent-BLOCKED** | scoped subagent status protocol | `agent-detection.md` |
| **ready-blocked** | deps unmet or allowed-files overlap | `flow.sh ready` |
| **Tier-C security halt** | security-class exposure; operator DEBT | `auto-run.md` |

Mixing them auto-answers a payments card or auto-halts a yes/no prompt.

## File-is-the-wait

The **HOST waits** (Task join / human / the mux's own wait). `flow.sh` **never waits on or polls** another agent. Fan-in is world-state: re-invoke `check` in
the card worktree after the host's wait returns.

## Forbidden (ADR-0001; not a nit)

`flow.sh` must not exec host control CLIs (`herdr agent start`, `herdr agent wait`, `herdr agent prompt`, `herdr server stop`, `tmux send-keys`, and equivalents).
Forbidden by name: `mux-up`, `mux-run-wave`, `mux-proxy`. No screen output as
evidence. No hook install into `~/.claude` or `~/.omp`. No long-lived socket subscribe (`events.subscribe`). `flow.sh` never spawns agents; placement is print-enter or the host's own Task/mux.

Own-runtime / own-PTY / own-wait is a successor ADR plus a separate product,
not a card in this skill.

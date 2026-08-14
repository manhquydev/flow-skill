---
title: "Harness subcommands"
description: "The durable layer CLI reached through /flow harness: intake, story, trace, decision, backlog, query, audit, propose."
---

`/flow harness <args>` is a passthrough to the durable layer, a flow-owned Python and SQLite
CLI that stores what survives between sessions.

| Subcommand | Purpose |
|---|---|
| `intake` | Record an incoming request with a type, summary, and flags; risk flags such as auth auto-escalate the lane |
| `story` | Track a unit of work and its proof. Complete it with `story complete --proof-source …` |
| `trace` | Tier-scored record written when a card check passes |
| `decision` | Record a decision and later close the loop with its actual outcome |
| `backlog` | The improvement backlog that `propose` writes into |
| `query` | Read records back |
| `audit` | Score entropy and drift in the accumulated records |
| `propose` | Mine repeated friction and interventions into backlog items; deterministic, fires at two or more occurrences |

Most of these are written for you by the engine — advancing a stage seeds an intake, a passing
check records a trace — so the manual surface is mostly reading. The layer is optional: without
`python3` the gates still run and only this store disables.

Schema, flags, and the live authority table:
[`skills/flow/harness/README.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/harness/README.md)

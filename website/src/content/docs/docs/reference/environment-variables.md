---
title: "Environment variables"
description: "The environment overrides you are most likely to need: project root, session identity, locking, and telemetry."
---

The runner reads a number of `FLOW_*` variables. These are the ones documented for everyday
use; the complete set is defined in the runner source.

| Variable | Effect |
|---|---|
| `FLOW_PROJECT_ROOT` | Override the project root instead of relying on the directory walk. |
| `FLOW_SESSION_ID` | A stable session identifier. Export it once per session and pass it on every call to get hard concurrency protection rather than a warning. |
| `FLOW_LOCK_TTL` | Seconds before a `flow/.lock` is auto-reclaimed. Default 900. |
| `FLOW_FORCE` | Set to `1` to take over a lock you are certain is dead. |
| `FLOW_LOG_DISABLE` / `DO_NOT_TRACK` | Disable the local JSONL usage log that `/flow usage` rolls up. The log is local-only either way. |
| `FLOW_EVAL_RETRY_BACKOFF` | Retry backoff in seconds for the billable eval batch. Default 5; set 0 in tests. |

Without `FLOW_SESSION_ID` the runner cannot prove that a competing session is different, so
it warns rather than blocking — that is why exporting it matters on a shared machine.

Authoritative definitions:
[`skills/flow/runner/flow.sh`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/runner/flow.sh)

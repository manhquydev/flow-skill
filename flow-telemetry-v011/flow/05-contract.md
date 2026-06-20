# Stage 05 — Interface Contract (the seam)

Project type **skill/CLI**: interfaces = runner commands + harness functions + the event JSON
schema. The schema is the true seam (producer = `flow.sh _log_event`, consumer =
`flow_harness.py` rollup) — the place producer/consumer drift would hide.

## Gate — check ALL before `/flow next`
- [x] Every PRD feature maps to at least one INTERFACE below
- [x] Every interface has its INPUT and OUTPUT shapes written
- [x] Access/effects column filled for every interface
- [x] No FILL placeholders remain in this file

## Interfaces (cli commands + harness functions)

| Interface | Name | Access/Effects | Input shape | Output shape |
|---|---|---|---|---|
| runner cmd | `flow.sh usage [--global] [--include-ephemeral] [--json] [--summary]` | reads logs; writes SQLite mirror | flags | analytics text (or json); exit 0 |
| runner→harness | `cmd_usage` (flow.sh) | **must forward `--global` to the rollup step** before `usage` | `$@` incl. `--global` | calls `harness rollup [--global]` then `harness usage [--global] [--include-ephemeral]` |
| harness cmd | `flow_harness.py rollup [--global]` | ingests JSONL→`usage_event`; advances cursor | src path(s) | rows ingested; exit 0 |
| harness cmd | `flow_harness.py usage [--global] [--include-ephemeral] [--json] [--summary]` | reads `usage_event` | filter flags | analytics; **default excludes ephemeral**; exit 0 |
| shell fn | `_session_id()` (flow.sh, NEW) | pure; no side-effect | env (`FLOW_SESSION_ID`/`CLAUDE_CODE_SESSION_ID`/`CODEX_*`/`AGY_*`/`$PPID`+host) | non-empty stable string |
| shell fn | `_cycle_id()` / `_ensure_cycle()` (flow.sh) | reads/writes `CYCLE_FILE` | project state | non-empty `epoch-host` string; stamps file if absent |
| shell fn | `cmd_assess` (flow.sh) | **must call `_ensure_cycle`** so assess-first events get a cycle_id | — | (existing assess output) |
| shell fn | `_log_event` (flow.sh) | appends FULL line to per-project + COMPACT line to global | event vars | two JSONL lines per schema below |
| shell fn | lock acquire (flow.sh) | reclaims foreign lock if PID dead (`kill -0`) or TTL expired; else blocks | lock file `ts\|owner\|pid\|host\|cmd` | acquire / BLOCKED |
| harness fn | dwell computation in `cmd_usage` | reads `usage_event` stage transitions | rows w/ `stage_from/to`,`epoch_s`,`cycle_id` | per-stage wall-clock dwell, labeled vs exec-time |

## Shared shapes

```
# CLI conventions
exit 0 = ok ; 1 = gate/usage fail ; 2 = error
flags:  --global (device-wide)  --include-ephemeral (include tmp/test)  --json  --summary

# EVENT SCHEMA — the seam. Producer: flow.sh _log_event. Consumer: flow_harness.py rollup.
# FULL line (per-project ~/.flow/events.jsonl) — existing fields UNCHANGED, add `ephemeral`:
FullEvent {
  ts, epoch_s, session_id, cycle_id, project, command, args, exit_code,
  gate_pass: true|false|null, duration_s, stage_from, stage_to, card,
  project_type, mode, flow_version, tier, host, read_only,
  gate_fail_reason,            # existing
  ephemeral: true|false        # NEW (FR5) — true if project root under tempdir or name ~ ^tmp\.
}
# COMPACT line (device-global ~/.claude/flow/usage.jsonl) — add 2 fields, keep small:
CompactEvent {
  ts, epoch_s, session_id, cycle_id, project, command, exit_code,
  gate_pass, duration_s, stage_to, flow_version, read_only,
  ephemeral: true|false,                 # NEW (FR5)
  gate_fail_reason: <string, truncated ≤120 chars>   # NEW (FR6)
}
# Backward-compat: consumer treats MISSING ephemeral as false; MISSING gate_fail_reason as "".
# usage_event table: add `ephemeral` column (default 0); rollup tolerates old lines w/o it.
# Read-time ephemeral fallback: a row is ephemeral if field==true OR project matches ^tmp\.
```

## Feature → interface map

- **FR1** → `cmd_usage` forwards `--global` to `rollup`; `flow.sh usage --global`.
- **FR2** → `_cycle_id`/`_ensure_cycle` + `cmd_assess` calls it; `_log_event` stamps `cycle_id`.
- **FR3** → dwell computation in harness `cmd_usage` (uses `stage_from/to`,`epoch_s`,`cycle_id`).
- **FR4** → `_session_id()` populates event + lock owner; lock acquire uses `kill -0` liveness.
- **FR5** → `_log_event` writes `ephemeral`; harness `usage`/`rollup` default-exclude (with `^tmp\.` read fallback); `--include-ephemeral` opt-in.
- **FR6** → `_log_event` COMPACT line adds truncated `gate_fail_reason`; harness `usage --global` can surface it.

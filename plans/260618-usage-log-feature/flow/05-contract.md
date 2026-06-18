# Stage 05 — Interface Contract (the seam)

Project type **skill**. The seam is the **function + CLI + file-schema interface** between the
runner (`flow.sh`), the durable layer (`harness/`), and the on-disk logs. Build cards wire TO
this table; nothing improvises an event shape, sink path, or column outside it. Shapes are
ground-truth against the existing runner idioms (`_now()`, best-effort `2>/dev/null || true`).

## Gate — check ALL before `/flow next`
- [x] Every PRD feature maps to at least one INTERFACE below
- [x] Every interface has its INPUT and OUTPUT shapes written
- [x] Access/effects column filled for every interface
- [x] No FILL placeholders remain in this file

## OpenAPI / Swagger rule (web only — N/A here)
N/A for `skill`. The no-drift equivalent is done-evidence: the installed skill runs and a real
`flow.sh` invocation writes a schema-valid event line to both sinks; `flow usage` reads it back.

## Interfaces (cli/shell functions + harness CLI + file schemas)

| Interface | Name / invocation | Access/Effects | Input shape | Output shape |
|---|---|---|---|---|
| **I1 Capture fn** (FR1) | `_log_event` (sourced in `flow.sh`) | writes both sinks; **best-effort, never fails, returns 0** | env: `FLOW_LOG_CMD`, `FLOW_LOG_ARGS`, `FLOW_STAGE_FROM/TO`, `FLOW_CARD`, `FLOW_EXIT`, `FLOW_GATE_PASS`, `FLOW_START_S` | side-effect: 1 JSON line appended per sink; stdout none |
| **I2 EXIT trap** (FR1,FR4) | `trap '_log_on_exit' EXIT` (set once near top) | captures `$?` on FIRST line, computes `duration_s = _now()-FLOW_START_S`, calls I1, **re-exits original `$?`** | none (reads `$?` + globals) | exit code identical to pre-trap; never alters it |
| **I3 Mask fn** (FR3) | `_mask_secrets <string>` | pure (stdout); no side-effect | a raw arg string | same string with denylist matches → `***`; exit 0 |
| **I4 Cycle stamp** (FR5) | in `cmd_next` when **stage 00 unlocks** → write `.flow/cycle_id` | writes `.flow/cycle_id` (best-effort) | none | a stable id `<epoch_s>-<short-host>`; read by I1 |
| **I5 Event shape** (FR1,FR2) | the JSON object (below) | — | — | full (per-project) / compact (global) — see shapes |
| **I6 Sinks** (FR2) | `.flow/events.jsonl` (full) · `~/.claude/flow/usage.jsonl` (compact) | append O_APPEND; dirs `mkdir -p` best-effort | one event line | file grows by 1 line; compact line <PIPE_BUF (4096B) |
| **I7 Migration 006** (FR6) | `harness/schema/006-usage-event.sql` | DDL (`usage_event` + `rollup_cursor`) | — | tables created on next migrate |
| **I8 Rollup** (FR6) | `flow_harness.py rollup [--project-root R]` | reads JSONL, upserts `usage_event`; **idempotent** via `rollup_cursor.last_offset` | sink path(s) | `{"rolled": N, "skipped": M}` JSON; exit 0 |
| **I9 Stats reader** (FR7) | `flow_harness.py usage [--project-root R] [--global]` | read-only | usage_event rows | text: cycle-time, gate fail-rate, kill rate, per-stage dwell, count |
| **I10 `flow usage`** (FR7) | `flow.sh usage` → dispatch → I8 then I9 | read-only (rolls up first) | none | I9 text; exit 0 |
| **I11 Disable** (NFR) | env `FLOW_LOG_DISABLE=1` **OR** `DO_NOT_TRACK=1` (standard env, honored as hygiene) | none | env | I1/I2 no-op; engine unchanged. Log is local-only, never transmitted. |

## Shared shapes

```
Event (I5) — FULL line, per-project .flow/events.jsonl:
  { "ts":"2026-06-18T10:22:01Z", "epoch_s":1781000521, "session_id":"sess-...",
    "cycle_id":"1781000000-host", "project":"flow-skill", "command":"next",
    "args":["<masked>"], "exit_code":0, "gate_pass":true, "duration_s":3,
    "stage_from":"03-prd", "stage_to":"04-adr", "card":null,
    "project_type":"skill", "mode":"work", "flow_version":"0.8.0",
    "tier":"builtin", "host":"PC", "read_only":false }

Event — COMPACT line, global ~/.claude/flow/usage.jsonl (drops args/host/stage_from to stay <PIPE_BUF):
  { "ts":..., "epoch_s":..., "session_id":..., "cycle_id":..., "project":"flow-skill",
    "command":"next", "exit_code":0, "gate_pass":true, "duration_s":3,
    "stage_to":"04-adr", "flow_version":"0.8.0", "read_only":false }

usage_event (I7) columns: id PK · src TEXT · line_no INT · epoch_s INT · session_id · cycle_id ·
  project · command · args · exit_code · gate_pass · duration_s · stage_from · stage_to · card ·
  project_type · mode · flow_version · tier · host · read_only ;  UNIQUE(src,line_no) [idempotent]
rollup_cursor (I7): src TEXT PK · last_offset INT · updated_at

read_only set true for: status, recall, ready, usage, query, tokens, coherence, consistency, contract, constitution, doctor, design.
gate_pass: true|false for next/check (derived from exit), null for non-gate commands.
Mask denylist (I3): case-insensitive match on token|secret|password|passwd|credential|api[_-]?key|bearer|authorization|-----BEGIN → value → "***".
exit codes: 0 ok. Logging never introduces a non-zero exit (I2).
```

## Feature → interface map

- **FR1** (mechanical event) → I1 + I2 + I5 + I6.
- **FR2** (dual sink) → I5 (full/compact) + I6.
- **FR3** (masking) → I3 (used by I1 before write).
- **FR4** (no-fail) → I2 (re-exit `$?`) + I1 (best-effort wrap) + I11.
- **FR5** (cycle_id) → I4 (stamp) + I5 (carried).
- **FR6** (rollup) → I7 (schema) + I8 (idempotent rollup).
- **FR7** (`flow usage` stats) → I9 (compute) + I10 (command).

# flow-harness — durable layer

The durable memory of `/flow`: intake classification, story packets with proof status,
auto-scored execution traces, decision records, and the growth-rule backlog. Ported from
`repository-harness` (same SQLite schema, `schema/00N-*.sql` verbatim). State lives at
`<project>/.flow/harness.db` and survives across sessions — this is the "external memory"
that fights context rot.

## Backends

| Backend | When | How |
|---|---|---|
| **python** (default) | always works; no install | `python flow_harness.py <cmd>` — stdlib `sqlite3` only |
| **rust** (power-path) | scale/perf, or you already use repository-harness | `FLOW_HARNESS_BACKEND=rust` forwards argv to the compiled CLI |

Build the Rust power-path:
```bash
cd D:/project/flow/repository-harness
cargo build --release -p harness-cli
export FLOW_HARNESS_BACKEND=rust
export FLOW_HARNESS_CLI="$PWD/target/release/harness-cli"   # .exe on Windows
```
If `FLOW_HARNESS_BACKEND=rust` but no binary is found, the tool tells you how to build it.
Disable the durable layer entirely with `FLOW_HARNESS_DISABLE=1` (engine still runs).

## Commands ↔ Runtime-Substrate responsibility

| Command | Responsibility (of 11) |
|---|---|
| `intake --type <t> --summary <s> [--flags ...] [--lane ...] [--narrow-scope]` | Task specification + risk classification |
| `story add\|update\|verify\|verify-all` | Task state + Verification (mechanical proof) |
| `trace --summary ... [--story\|--card C-NNN] [--agent ...] [--actions ...] [--files-changed ...] --outcome ...` | Observability + Failure attribution (auto-scored tier). Flags accept `-` or `_` (`--actions_taken`, `--files_changed`, `--files_read`) and `--card` is an alias of `--story`. A bad/missing flag prints a guiding "common forms" hint (not a silent exit-2). |
| `decision add\|verify\|outcome` | Project memory (durable ADR row + companion markdown); `outcome` closes the predicted-vs-actual loop |
| `backlog add\|close` | Entropy auditing + harness self-improvement (growth rule) |
| `audit` | Entropy/drift score (0-100) + findings (orphaned/unverified/stale records) |
| `propose [--commit]` | Deterministic improvement proposals from repeated friction/interventions + audit drift (>=2 to fire) |
| `tool register` | Tool access registry |
| `intervention add` | Intervention recording (human/reviewer/ci/agent overrides) |
| `query matrix\|backlog\|friction\|tools\|decisions` | Read durable state (incl. predicted-vs-actual decisions) |

## Risk lanes (intake)
`tiny` (docs/copy/narrow edits, smoke proof) · `normal` (story-sized, bounded blast radius)
· `high_risk` (auth, authorization, data model, audit/security, external providers,
contracts, cross-platform, weak proof, multi-domain).
Classification: 0-1 flags -> normal (or `--lane tiny`); 2-3 -> normal+stronger validation;
4+ -> high_risk; **any hard gate -> high_risk** and cannot be downgraded without
`--narrow-scope` (operator accepts the exposure in writing).

## Trace tiers (auto-scored on write)
- **tier 1 (minimal, tiny lane):** `task_summary` (>=10 chars) + `outcome`.
- **tier 2 (standard, normal lane):** + `intake_id`, `story_id`, `agent`, `actions_taken`,
  `files_read`, `files_changed`, and at least one of `errors`/`harness_friction`.
- **tier 3 (detailed, high_risk lane):** + `decisions_made`, `errors`, `harness_friction`,
  and one of `duration_seconds`/`token_estimate`/`notes`.
A trace below its lane's required tier is flagged (advisory — never hard-fails the agent).
Linking a trace to an unverified story prints a **pre-close gate** warning.

## How `/flow` uses it (auto-wired in flow.sh, best-effort)
- `/flow next` past **stage 01 (research)** → seeds an `intake` row (lane=normal default; reclassify with risk flags if it touches auth/data/external/contracts).
- `/flow next` past **stage 04 (ADR)** → reminds you to record each decision durably (`decision add`) — the ADR markdown is not a durable record.
- `/flow card` creates a card → seeds a `story` row (tracking handle).
- `/flow check C-NNN` (todo) → `story update --status in_progress`.
- `/flow check C-NNN` (done) → `story update --status implemented` + a `trace` (its **tier verdict is shown**, so thin traces are visible).
- `/flow recall` → reads the durable layer back (friction + backlog + audit health) into your working context — the capture→reuse loop.
- `/flow retro` → surfaces `propose` (deterministic improvement proposals from repeated friction/interventions + audit drift) for you to commit.
- `/flow harness <args>` exposes the full CLI directly.
All wiring degrades gracefully: if python is absent or `FLOW_HARNESS_DISABLE=1`, the
mechanical engine runs unchanged.

## Usage signal: accessed_count (read-only, schema 005)
`query decisions|friction|backlog` increment an `accessed_count` on every surfaced row and order
output **most-reused-first**, so `recall` floats the knowledge you actually reuse to the top. It is
a **read-only ordering signal** — never used to prune, delete, or archive a row. Low count is not
low value: a rare one-time lesson (often a security decision) is recalled rarely *because it is
rare*. Security-class rows (`auth|authoriz|admin|tenan|payment|migrat|valid|secret|credential`)
always sort first and are never deprioritized. The story `matrix` view is intentionally left
ordered by id (it is a status table, not recalled knowledge).

## Usage log: mechanical flight-recorder (schema 006)
Distinct from the curated, agent-authored records above: `flow.sh` itself self-records **every
invocation** (no agent action needed) to append-only JSONL — `.flow/events.jsonl` (full, per-project)
plus `~/.claude/flow/usage.jsonl` (compact, device-global). Fields: ts/epoch_s, session_id, cycle_id
(stamped when stage 00 unlocks), command, masked args, exit_code, gate_pass, duration_s (seconds),
stage_from→to, card, project_type, mode, flow_version, tier, host, read_only.
- **Local-only, never transmitted.** Disable with `FLOW_LOG_DISABLE=1` or the standard `DO_NOT_TRACK=1`.
- Secret-shaped args (token/secret/password/credential/api_key/bearer/authorization/PEM) are masked
  before disk (conservative whole-field redaction).
- **Best-effort, never fails:** a logging error (unwritable sink, etc.) never alters a command's exit
  code or breaks it (EXIT trap captures `$?` first, re-exits unchanged).
- `flow.sh usage` → `flow_harness.py rollup` (idempotent ingest into the `usage_event` table via
  `UNIQUE(src,line_no)` + `rollup_cursor`) then `flow_harness.py usage` (cycle-time, gate fail-rate,
  per-stage dwell, cycle completion, command breakdown). `--global` reads the device-wide log.
- JSONL is the source of truth; `usage_event` is a derived, queryable mirror. Semantic events keep
  using `trace`/`intervention`/`decision` — the usage log does not duplicate them.

**Closed feedback loop (schema 007).** The recorded data feeds the surfaces where you already act:
- `recall` appends a one-line digest (`flow_harness.py usage --summary`): cycles, cycle-time, gate
  fail-rate, top gate-fail stage — so build history reaches you at stage/card start (silent if no data).
- `propose` (`_build_proposals`) emits a backlog proposal when a stage's gate fail-rate ≥ 50% across
  ≥ 2 cycles (honest heuristic; you commit it — never auto-applied).
- `flow usage --prune [--keep N]` / `flow_harness.py prune` caps each sink to its last N lines
  (crash-safe temp + `os.replace`; resets that sink's mirror + cursor so the next rollup rebuilds cleanly).
- A failing `next`/`check` records `gate_fail_reason` (e.g. `fill:2,unchecked:1`) and attributes the
  failing stage, so "stage X fails often" is diagnosable. All best-effort / exit-code preserving.

## Files
- `flow_harness.py` — CLI entrypoint + backend toggle.
- `_domain.py` — pure rules (input types, lanes, hard gates, trace tiers). Testable in isolation.
- `_db.py` — sqlite connection + migration runner.
- `schema/00N-*.sql` — DDL, verbatim from repository-harness.

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
| `trace --summary ... [--story ...] --outcome ...` | Observability + Failure attribution (auto-scored tier) |
| `decision add\|verify` | Project memory (durable ADR row; markdown ADR is the companion) |
| `backlog add\|close` | Entropy auditing + harness self-improvement (growth rule) |
| `tool register` | Tool access registry |
| `intervention add` | Intervention recording (human/reviewer/ci/agent overrides) |
| `query matrix\|backlog\|friction\|tools` | Read durable state |

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
- `/flow recall` → reads the durable layer back (friction + backlog) into your working context — the capture→reuse loop.
- `/flow harness <args>` exposes the full CLI directly.
All wiring degrades gracefully: if python is absent or `FLOW_HARNESS_DISABLE=1`, the
mechanical engine runs unchanged.

## Files
- `flow_harness.py` — CLI entrypoint + backend toggle.
- `_domain.py` — pure rules (input types, lanes, hard gates, trace tiers). Testable in isolation.
- `_db.py` — sqlite connection + migration runner.
- `schema/00N-*.sql` — DDL, verbatim from repository-harness.

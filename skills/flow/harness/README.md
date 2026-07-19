# flow-harness — durable layer

The durable memory of `/flow`: intake classification, story packets with proof status,
auto-scored execution traces, decision records, and the growth-rule backlog. Ported from
`repository-harness` (shared base schema + flow-only usage extensions). State lives at
`<project>/.flow/harness.db` and survives across sessions — this is the "external memory"
that fights context rot.

## Authority pins (repository-harness)

| Pin | Tag | Use |
|-----|-----|-----|
| Protocol floor | **`harness-cli-v0.1.14`** | protocol v1 discovery floor |
| Trust / consumer | **`harness-cli-v0.1.17`** | US-101 spirit + release proof |
| **Do not use** | `harness-cli-v0.1.16` | tag without published assets |

Gap inventory: [`GAP-MATRIX-0.1.17.md`](./GAP-MATRIX-0.1.17.md). Flow does **not** claim bit-identical US-101.

## Backends

| Backend | When | How |
|---|---|---|
| **python** (default) | always works; no install | `python flow_harness.py <cmd>` — stdlib `sqlite3` only |
| **rust** (frozen seam) | only on a non-flow-lineage DB | `FLOW_HARNESS_BACKEND=rust` forwards argv to the compiled CLI |

**The rust seam is frozen for flow-lineage DBs.** flow's Python port re-homed its
accessed-count + usage-log migrations to versions 009-012 (leaving 006-008 free), so the schema
diverges from upstream repository-harness beyond the shared 001-005 base. Forwarding a flow DB
(usage mirror present, or `schema_version >= 9`) to an external `harness-cli` would silently
diverge, so the python entrypoint **refuses** to forward in that case (exit 2, with a guiding
message). Use the Python backend for flow projects. The seam stays in code as a compat-guarded
power-path for non-flow DBs; flow does not build or ship the binary.

Disable the durable layer entirely with `FLOW_HARNESS_DISABLE=1` (engine still runs).

### STRICT durable writes (`flow.sh`)

| Env | Behavior |
|-----|----------|
| unset | soft: engine exit 0; one-line `flow-harness: warn` on fail |
| `FLOW_HARNESS_STRICT=1` | soft exit; louder stderr |
| `FLOW_HARNESS_STRICT=fail` | propagate nonzero from durable ops on card/check |

## Story completion (trust boundary)

- **Rejected:** `story update --status implemented`
- **Use:** `story complete --id <id> --proof-source card_markdown_gate|manual|verify_command [--evidence …]`
- `card_markdown_gate` / `manual` set status implemented with **honest** `proof_source=…` in notes — **never** forge `last_verified_result=pass`
- `verify_command` requires prior `story verify` pass

## Versioning (harness vs npm)

- Telemetry / usage events carry **`flow_version` from the installed skill product**
  (`SKILL.md` metadata), not from the npm installer package version.
- When you change harness schema or CLI behavior, bump the **skill product** version
  (SKILL.md + plugin.json + portable-manifest) and run `flow.sh coherence`.
- Publishing a new npm tarball is a separate step (`npm-wrapper` sync + tag `npm@…`) —
  see [`docs/release-process.md`](../../../docs/release-process.md).

## Commands ↔ Runtime-Substrate responsibility

| Command | Responsibility (of 11) |
|---|---|
| `intake --type <t> --summary <s> [--flags ...] [--lane ...] [--narrow-scope]` | Task specification + risk classification |
| `story add\|update\|complete\|verify\|verify-all` | Task state + Verification (mechanical proof) |
| `trace --summary ... [--story\|--card C-NNN] [--agent ...] [--actions ...] [--files-changed ...] --outcome ...` | Observability + Failure attribution (auto-scored tier). Flags accept `-` or `_` (`--actions_taken`, `--files_changed`, `--files_read`) and `--card` is an alias of `--story`. A bad/missing flag prints a guiding "common forms" hint (not a silent exit-2). |
| `decision add\|verify\|outcome` | Project memory (durable ADR row + companion markdown); `outcome` closes the predicted-vs-actual loop |
| `backlog add\|close` | Entropy auditing + harness self-improvement (growth rule) |
| `audit` | Entropy/drift score (0-100) + findings (orphaned/unverified/stale records) |
| `propose [--commit]` | Deterministic improvement proposals from repeated friction/interventions + audit drift (>=2 to fire) |
| `tool register --kind <cli\|binary\|mcp\|skill\|http> [--capability <kebab>] [--scan-target <path\|url>]` · `tool check [--name]` · `tool remove --name` | Tool access registry (kind-aware inbound, ported from repository-harness 005). Registration always succeeds and records a probed presence `status` (present/missing/unknown); `tool check` re-probes. cli/binary resolve on PATH (PATHEXT-aware), mcp/skill by scan-target path, http by 2s TCP. An absent tool is a clean skip, never a failure. |
| `intervention add` | Intervention recording (human/reviewer/ci/agent overrides) |
| `query matrix\|backlog\|friction\|tools\|decisions` | Read durable state (incl. predicted-vs-actual decisions). `query tools [--capability <kebab>] [--status present\|missing\|unknown] [--responsibility <r>]` is the mechanical "what is equipped for purpose X" lookup — a step asks for a capability and clean-skips when nothing is present. |

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
- `/flow check C-NNN` (done) → `story complete --proof-source card_markdown_gate` + a `trace` (tier verdict shown; honest provenance, no shell-verify stamp).
- `/flow recall` → reads the durable layer back (friction + backlog + audit health) into your working context — the capture→reuse loop.
- `/flow retro` → surfaces `propose` (deterministic improvement proposals from repeated friction/interventions + audit drift) for you to commit.
- `/flow harness <args>` exposes the full CLI directly.
All wiring degrades gracefully: if python is absent or `FLOW_HARNESS_DISABLE=1`, the
mechanical engine runs unchanged.

## Usage signal: accessed_count (read-only, schema 009 — see Backends re-homing note above)
`query decisions|friction|backlog` increment an `accessed_count` on every surfaced row and order
output **most-reused-first**, so `recall` floats the knowledge you actually reuse to the top. It is
a **read-only ordering signal** — never used to prune, delete, or archive a row. Low count is not
low value: a rare one-time lesson (often a security decision) is recalled rarely *because it is
rare*. Security-class rows (`auth|authoriz|admin|tenan|payment|migrat|valid|secret|credential`)
always sort first and are never deprioritized. The story `matrix` view is intentionally left
ordered by id (it is a status table, not recalled knowledge).

## Usage log: mechanical flight-recorder (schema 010 — see Backends re-homing note above)
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

**Closed feedback loop (schema 011 — see Backends re-homing note above).** The recorded data feeds the surfaces where you already act:
- `recall` appends a one-line digest (`flow_harness.py usage --summary`): cycles, cycle-time, gate
  fail-rate, top gate-fail stage — so build history reaches you at stage/card start (silent if no data).
- `propose` (`_build_proposals`) emits a backlog proposal when a stage's gate fail-rate ≥ 50% across
  ≥ 2 cycles (honest heuristic; you commit it — never auto-applied).
- `flow usage --prune [--keep N]` / `flow_harness.py prune` caps each sink to its last N lines
  (crash-safe temp + `os.replace`; resets that sink's mirror + cursor so the next rollup rebuilds cleanly).
- A failing `next`/`check` records `gate_fail_reason` (e.g. `fill:2,unchecked:1`) and attributes the
  failing stage, so "stage X fails often" is diagnosable. All best-effort / exit-code preserving.

## Files
- `flow_harness.py` — CLI entrypoint + backend toggle + compat guard.
- `_domain.py` — pure rules (input types, lanes, hard gates, trace tiers, tool kinds/responsibilities,
  capability normalization). Testable in isolation.
- `_presence.py` — kind-aware tool presence probes (cli/binary on PATH+PATHEXT, mcp/skill by path,
  http by 2s TCP). Pure stdlib; never raises. Ported from repository-harness `infrastructure.rs`.
- `_db.py` — sqlite connection + idempotent migration runner + legacy reconciliation.
- `schema/00N-*.sql` — DDL. **001-005 are a faithful port of repository-harness** (005 =
  tool-extensions, kind-aware tool registry). **009-012 are flow-specific** (accessed-count +
  usage-log mirror), re-homed off 005-008 so the upstream 005 number is free and the lineages no
  longer collide. Migrations are column-idempotent and safe to re-run; an old DB built under the
  pre-005 numbering is reconciled automatically on the next `init`.

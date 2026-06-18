# Stage 04 — ADR (architecture decisions)

Short. The most valuable section is what you are NOT doing and why.

## Gate — check ALL before `/flow next`
- [x] Each decision has a one-line "why" and a one-line "what I rejected"
- [x] The NOT-doing list is written
- [x] Decisions cover: data storage, auth approach, deploy target
- [x] No FILL placeholders remain in this file

## Decisions

| # | Decision | Why | Rejected alternative |
|---|---|---|---|
| 1 | **Storage: reuse `usage_event` + rollup (no new table)** | the v0.9.0 mirror already holds everything recall/propose need | a separate aggregate/summary table — duplicate state, drift risk |
| 2 | **recall summary = call `flow_harness.py usage --summary` (compact one-block), appended best-effort in `cmd_recall`** | one source of truth for the query logic (python), shell just prints | re-implementing the SQL/aggregation in shell — divergence + portability cost |
| 3 | **propose usage branch: a stage with gate fail-rate ≥ threshold over ≥N recorded cycles → one backlog proposal (heuristic, operator commits)** | matches the existing `propose` contract (deterministic, ≥2-to-fire, human commits) | auto-creating/auto-applying changes, or an ML/anomaly model — over-engineered, violates the no-auto-change rule |
| 4 | **prune = read → keep last N → write temp → `os.replace` (atomic)** | crash-safe; the live tail is never lost mid-rewrite | in-place truncate / seek-rewrite — a crash mid-write corrupts or loses the log |
| 5 | **gate-fail reason: the gate body sets `FLOW_LAST_GATE_FAIL` (e.g. `fill:2,unchecked:1`) before a failing return; the EXIT trap/`_log_event` reads it into `gate_fail_reason`** | the body already computes the counts; the trap only reads a var | parsing the command's stdout inside the trap — fragile, couples to wording |
| 6 | **No-fail stays load-bearing: recall/propose/gate degrade silently without usage data or python** | this increment must not make the everyday commands fail | letting a usage-query error surface in `recall`/`next` |
| 7 | **"Deploy target" = installed skill + a real run** (skill done-evidence): `recall` shows the summary, `propose` emits a row, `--prune` caps a file, a failed gate records a reason — on the installed runner | skill ships by install; done = real behavior, not tests | a web deploy — N/A |
| 8 | **Version 0.9.0 → 0.10.0** (new backward-compatible capability: recall summary, propose branch, `--prune`, new event field) | semver minor for additive features | patch 0.9.1 — undersells the new surfaces; major — nothing breaks |

## NOT doing in v1 (and why it's safe to skip)

- **Millisecond duration (open issue #3b)** — WONTFIX: `date +%N` is GNU-only; seconds is the portability-correct ruling from v1 (R1). Not a defect; closed by decision.
- **trace-tier auto-population (open issue #3c / DF-4)** — out of scope: it's card→`trace` field auto-fill in the durable layer, a separate harness-DX concern; belongs to its own increment.
- **Usage trend arrows (S-x) / dashboard (S-y)** — deferred: a single summary + `flow usage` suffices; trends need more cycles to mean anything (YAGNI).
- **Auto-applying usage-derived improvements** — never: `propose` only surfaces; the operator commits (preserves the human gate).
- **New schema/table** — none needed; `usage_event` is sufficient.

# Xia Analysis: LangGraph → flow harness graph executor (mode --port)

Approved decision record. Input for /ak:plan. Analysis date: 2026-07-26.

## Source manifest

- Repo: `langchain-ai/langgraph`, branch `main`, commit `30c4d58db86455128e42ddec96b1ba53c553ba22` (2026-07-25)
- Clone: shallow, scratchpad (ephemeral) — cite repo-relative paths + SHA, not clone paths
- Scope: `libs/langgraph/langgraph/{pregel,graph,channels,types.py}`, `libs/checkpoint`, `libs/checkpoint-sqlite`, `libs/checkpoint-conformance`
- License: MIT. Port CONCEPTS + schema shapes, not code verbatim.

## Local target

- flow v0.24.0 (npm 0.1.0 GA). Harness: `skills/flow/harness/flow_harness.py` + `_db.py` + `schema/*.sql` (SQLite, 10 tables: intake, story, trace, decision, backlog, intervention, tool, usage_event, rollup_cursor, schema_version; migrations 001–005, 009–012, idempotent engine, set-membership version gate)
- Direction (confirmed by user, advise session 2026-07-26): harness → graph executor; Python becomes mandatory (major bump); topology covers planning + shipping (all-in M1); topology-as-data; gate parity preserved (flow.sh stays quality ground-truth); no LangGraph/external framework dependency.

## Source anatomy (evidence-graded, from dissection agents)

### Core engine (libs/langgraph)
- BSP super-step loop (`pregel/_loop.py` ~2k LOC, `_algo.py` ~1.5k): plan tasks (PUSH=Send, PULL=channel-version triggers) → execute parallel → `apply_writes` atomically → bump `channel_versions`.
- **Trigger-by-version**: node fires iff subscribed channel version > `versions_seen[node][channel]`. Replay-safe dedup. (`_algo.py:262-269`)
- Deterministic task ordering before write application (`_algo.py:256`) — replay determinism contract.
- `Send(node, arg)` = dynamic fan-out task w/ own namespace; `Command(goto/update/resume)` = control redirect.
- `interrupt()` semantics: raise → pause; `Command(resume=v)` → **re-execute node from start**, resume value returned by 2nd `interrupt()` call via scratchpad counter. Requires checkpointer.
- Durability modes: sync/async/exit. Retry/timeout policies per node. Subgraph isolation via `checkpoint_ns` ("parent|child:task_id").
- Reducer contract: associative+commutative; LastValue errors on concurrent writes.

### Checkpoint stack (libs/checkpoint*)
- `Checkpoint{v, id(UUID6 monotonic), ts, channel_values, channel_versions, versions_seen, updated_channels}`; `CheckpointMetadata{source: input|loop|update|fork, step, parents, run_id}`; `CheckpointTuple{config, checkpoint, metadata, parent_config, pending_writes}`.
- SQLite DDL (checkpoint-sqlite, WAL): `checkpoints(thread_id, checkpoint_ns DEFAULT '', checkpoint_id, parent_checkpoint_id, type, checkpoint BLOB, metadata BLOB, PK(thread_id,checkpoint_ns,checkpoint_id))`; `writes(thread_id, checkpoint_ns, checkpoint_id, task_id, idx, channel, type, value BLOB, PK(...,task_id,idx))`. No blob dedup table.
- **pending_writes**: `put_writes` persists node outputs immediately post-node, before next checkpoint commit — closes crash window. Resume = restore snapshot + re-apply pending writes.
- `parent_checkpoint_id` chain → time-travel + forking.
- Conformance suite: 5 mandatory capabilities (PUT, PUT_WRITES, GET_TUPLE, LIST, DELETE_THREAD) + 4 optional; invariants: monotonic sortable ids, newest-first list w/ cursor pagination, round-trip fidelity, full ancestor chain on copy.
- Serde: msgpack + pickle fallback + typed envelopes — NOT ported (see decision 7).

## Dependency matrix

| Source component | Local equivalent | Status |
|---|---|---|
| BSP super-step loop | auto-run serial loop (prose) | NEW (concept, card/step level) |
| Checkpoint + versions_seen | trace (event log only) | NEW |
| pending_writes | — | NEW (highest value) |
| SQLite checkpoints/writes schema | harness.db + migration engine | NEW adapted (extend lineage) |
| Send fan-out | /flow ready + worktrees | EXISTS partial → adapt |
| interrupt/resume | Must-ask gates | EXISTS conceptually → make durable |
| Channels/reducers | files + git (merge = reducer) | CONFLICT → not ported |
| JsonPlus serde | simple rows | CONFLICT → stdlib JSON |
| DeltaChannel | — | SKIP (YAGNI) |
| Conformance pattern | 39 bash suites | PORT pattern |

## Key insights

1. Trigger-by-version = the resume-without-redo mechanism. Port as step journal + per-node seen-version.
2. pending_writes closes node-done→checkpoint-commit crash window. Port at step granularity.
3. Interrupt = re-execute-from-start + injected resume value. Maps 1:1 to Must-ask gate; add durable interrupt row + operator decision as resume value.
4. Determinism: deterministic card ordering + git merge as reducer ≈ LangGraph's sorted tasks + associative reducers.
5. PK (thread, ns, id) + parent id → map (project, stage|card ns, checkpoint) + fork chain for two-strikes repair.

## Challenge outcomes (approved 2026-07-26)

1. **Paradigm gap (critical)**: LangGraph nodes = cheap deterministic functions; flow nodes = expensive non-deterministic LLM sessions w/ side effects. RESOLUTION: checkpoints ONLY at deterministic gate/step boundaries (bash checks, git SHA, file hash as "channel value"); never mid-LLM-work; resume never replays LLM effort, it replays from last verified evidence.
2. 80/20: port checkpoint schema + versions_seen + pending_writes; skip channels/BSP engine internals.
3. No second source of truth: new tables FK → story/trace; trace remains observability journal, checkpoint tables own execution state.
4. Maintenance: port conformance-suite PATTERN as harness executor invariant tests.
5. Dependencies: zero new deps. stdlib json + type tag; UUID6-equivalent monotonic id (~50 LOC stdlib).
6. Cycles: planning stays acyclic + conditional skips; ONLY bounded cycle = two-strikes repair subgraph (loop bound = 2).

## Decision matrix (approved)

| # | Decision | Choice |
|---|---|---|
| 1 | Execution model | Hybrid: event-sourced step journal, super-step semantics at card level |
| 2 | State store | Local-lean: checkpoint stores manifest (git SHA, file hashes, refs), no blobs |
| 3 | Checkpoint schema | Port adapted: new `execution`/`checkpoint`/`step_write` tables in migration lineage, FK story/trace |
| 4 | Crash recovery | Port pending_writes at step granularity |
| 5 | Fan-out | Port adapted: card DAG from topology; worktree = task; git merge = reducer |
| 6 | HITL | Port: gate-as-interrupt, durable interrupt row + resume = operator decision |
| 7 | Serde | Local: stdlib JSON + type tag column |
| 8 | Delta encoding | Skip (YAGNI) |
| 9 | Contract tests | Port conformance pattern (executor invariant suite) |
| 10 | Durability mode | Sync only |

## Risk score

1 critical (paradigm gap — resolved by checkpoint-at-gate rule), 3 medium (schema integration, fan-out merge, execution model refactor). Overall **Medium-Low → proceed**.

## Rollback posture (for plan)

New tables additive-only in migration lineage (existing idempotent engine); flow.sh gate behavior unchanged until executor consumers wired; feature can ship dark behind harness subcommands before flow.sh delegates transitions.

## Unresolved questions

- Exact naming/columns of new tables vs existing `story`/`trace` FKs — plan phase decides.
- Whether `/flow ready` DAG source-of-truth lives in topology file or card frontmatter — plan phase decides.
- Prune/retention policy for checkpoint rows (delete per project on promote?) — plan phase decides.

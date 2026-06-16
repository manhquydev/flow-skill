# Stage 04 — ADR (architecture decisions)

## Gate — check ALL before `/flow next`
- [x] Each decision has a one-line "why" and a one-line "what I rejected"
- [x] The NOT-doing list is written
- [x] Decisions cover: data storage, auth approach, deploy target
- [x] No FILL placeholders remain in this file

## Decisions

| # | Decision | Why | Rejected alternative |
|---|---|---|---|
| 1 | `/flow constitution` is a **standalone advisory command** (pattern of `consistency`/`contract`/`tokens`), never called from `cmd_next` | keeps flow's mechanical-first / cheap hot path; semantic challenge is operator-invoked | wiring it into every gate — rejected: red-team proved a per-gate LLM token-tax |
| 2 | **Data storage:** extend the existing SQLite harness via a versioned migration (`005-accessed-count.sql`); `accessed_count` is a **read-only ordering signal**, no prune, security-class rows hard-excluded | reuse the proven idempotent migration framework (`_db.py:91-102`); deletion would lose rare-but-critical security lessons | a vector DB / external memory store (rejected: portability); prune-by-access (rejected: data-loss bug) |
| 3 | `assess` repo-map uses an **optional `tree-sitter` import with graceful glob fallback** | portability law — no new REQUIRED dep; must run on Windows Git Bash + Codex where tree-sitter may be absent | requiring tree-sitter — rejected: breaks the offline CI + Codex tier |
| 4 | **Auth approach:** none — local skill, no network, no secrets; trust boundary is the operator's own shell/process | a local CLI skill has no remote surface to authenticate | JWT capability-delegation tokens for subagents — rejected by research as over-engineering (same trust domain) |
| 5 | **Deploy target:** installed into `~/.claude/skills/flow` (+ `~/.codex/skills/flow`); done = a real `/flow` run reaches the skill done-definition | matches the `skill` project-type done rule | npm/registry packaging — rejected: out of scope for this increment |

## NOT doing in v1 (and why it's safe to skip)

- **Gate self-eval harness** — no offline LLM-judge exists; it can't live in the bash CI. Safe to
  skip: the gates already work in practice; measuring them is a separate infra investment.
- **Session-identity / fencing tokens** for the advisory concurrency lock — separate research scout;
  current advisory-warn behavior is unchanged and adequate for single-operator use.
- **Auto-promote a constitution playbook to the cross-project KB** — YAGNI until multiple projects
  author constitutions.
- **Semantic doc-coherence beyond version drift** — pre-existing backlog item, not this increment.

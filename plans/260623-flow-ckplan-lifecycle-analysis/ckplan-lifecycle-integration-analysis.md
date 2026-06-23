# Is flow underusing ck:plan? — Lifecycle/status model analysis

**Status:** ANALYSIS (research/discussion — no flow code changed)
**Date:** 2026-06-23 · flow at v0.15.0
**Trigger:** Operator: "flow seems to not use ck:plan and its variants flexibly; I find ck:plan's model
— how a plan is created and where its status goes when done — compelling; it feels like a core command."
**Method:** 3-agent flow-skill team (flow-reality grounding · ck:plan deep-dive · anti-FOMO adjudication).

## The answer: PARTLY TRUE — and the v0.15.0 decision under-reasoned one half

ck:plan is **two fused things**, and v0.15.0 only judged one:

1. **ck:plan-as-DRAFTER** (research→design→write the plan). **Twin of flow's `planner` agent + 6 gated
   stages. Correctly dropped in v0.15.0 — VALIDATED, no reversal.** Surfacing it would double-gate flow's
   own planning authority (same reason cook/vibe/ship were cut).
2. **ck:plan-as-LIFECYCLE-SYSTEM** (status frontmatter mutated by `ck plan check`, hydration, sync-back,
   kanban board, cross-plan deps, archive). **This half was NEVER separately evaluated** — it got hidden
   under the flat "twin" label. That framing was too coarse.

**On rigor, flow does NOT underuse ck:plan — it SURPASSES it.** flow's done-gate requires world-state
evidence (`flow.sh:702`) and its status store is CLI-mutated in a SQLite harness (`flow.sh:710`); ck:plan's
status is markdown the model hand-edits (can drift/go stale). So the premise is **FALSE on rigor**.

**Where the premise is TRUE: lifecycle *legibility*.** flow already HAS a rich 5-state lifecycle
(`planned|in_progress|implemented|changed|retired`) — but it's **hidden in the harness story**, auto-mutated
as a side effect of `flow.sh check`. The operator is only ever shown a **2-state card** (`todo|done`,
`flow.sh:217`). So "what's actually mid-flight right now" is invisible without re-deriving it. ck:plan's
lifecycle is *legible*; flow's is *enforced-but-hidden*. **That is the one real thing the operator's instinct
correctly caught.**

## Per-gap adjudication (grounded in flow's REAL use: single-product gated builds, CLI-first operator)

| Gap vs ck:plan | Verdict | Why |
|---|---|---|
| Operator can't see `in_progress` (hidden in harness) | **REAL — worth fixing** | Cheap (surface existing data); bites on every context-switch |
| Card-status writes go through the model's hand-edit, not a verb | **REAL — 90% present** | Harness already CLI-mutated; only the card frontmatter write is hand-done |
| No archive/terminal state (done cards pile up; `retired` is dead) | **REAL-but-marginal** | Only bites CMC-scale multi-cycle builds |
| Visual kanban board | **LOW-ROI / borderline FOMO** | Operator is CLI-first; `flow status` text is the right default |
| Cross-plan / cross-cycle dependency graph | **FOMO** | flow runs single-cycle builds; intra-card `deps:` already covers it |
| `ck config ui` server · `--html`/`--wiki` export · `ck plan` scaffolding | **FOMO — hard cut** | Breaks flow's zero-dep portability (Node server exits 1 without the CLI) |

## Recommendation — PORTABLE-ONLY, ROI-ranked (must work with zero `ck` CLI / no server)

| Rank | Borrow | Verdict | What it looks like in flow |
|---|---|---|---|
| 1 | Surface `in_progress` in status | **BORROW-NATIVE** | `cmd_status` adds an "in flight" line from existing harness story data (~8 lines) |
| 2 | CLI-owned card-status writes | **BORROW-NATIVE** | `flow.sh card start\|done C-NNN` verb owns the frontmatter write (validates evidence on `done`), killing hand-edit drift |
| 3 | red-team / validate rigor passes | **RESEARCH-MORE** | Likely already covered by flow `consistency` + adversarial-review — check overlap, don't duplicate |
| 4 | Archive/terminal state | **DEFER** | Activate the dormant `retired` via `card archive` only when a real long project's list is noisy (>20 done cards) |
| 5 | Static-HTML board | **REJECT for now** | Only if operator says text status is insufficient |
| 6 | Cross-plan deps | **REJECT** | YAGNI for single-cycle builds |

**FOMO traps cut:** the `ck config ui` Node server, `--html`/`--wiki` export, `ck plan` scaffolding/status
(hard-coupled to the `ck` CLI), and wholesale ck:plan surfacing (double-gates the planner).

## Proposed phasing

- **Phase 1 — "Legible lifecycle" — SHIPPED v0.16.0 (2026-06-23):** `flow.sh card start|done` verbs +
  an "in flight" section in `flow.sh status`. `card start` records a portable `cards/.inflight` registry
  (`<id> <epoch>`, no python needed) + best-effort harness `in_progress`; `card done` is a CLI-owned,
  gate-parity flip (reverts on a failed done-gate, never a hollow done). Both opt-in, coexist with
  hand-edit + `/flow check`. New suite `test_flow_card_lifecycle.sh` (19 assertions); full suite green;
  coherence PASS; adversarial review APPROVE_WITH_NITS (one LOW status-less-card message fixed + guarded
  by a test). The `.inflight` start stamp is the foundation for the deferred per-card dwell metric.
- **Phase 2 — Archive (research-only):** design `card archive` (activate `retired`); build only when flat-list
  growth demonstrably bites.
- **Everything else — rejected / research-only.** No board, no cross-plan deps, no ck:plan surfacing.

## Provenance
3-agent team, read-only, claims confirmed against `flow.sh` source (status 2-state at :217, harness
auto-mutation at :710-711, world-state done-gate at :702). Note: the "214 invocations" figure is from MEMORY,
not a freshly-queried real `usage.jsonl` (only test fixtures on disk); reality-check grounded on qualitative
real usage (CMC, C2-App-001, flowstat, flow self-hosting). No flow files modified.

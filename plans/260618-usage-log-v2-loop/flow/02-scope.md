# Stage 02 — Scope (go/no-go)

Scope = features chosen by IMPACT × COST, inside your time budget.
KILL here is cheap and smart. Killing a weak idea at this gate is a SUCCESS outcome.

## Impact rubric (business value — score BEFORE looking at cost)

| Impact | Meaning |
|---|---|
| H | moves money or the core promise: gets users in (acquisition), gets them paying (revenue), or delivers the one job they came for |
| M | keeps users / saves real time weekly (retention, operations) |
| L | nice-to-have; nobody would pay for or switch over it |

Decision matrix: **H-impact features justify B/C cost** (via the C-paths below).
**L-impact features must be grade A or they're cut** — and even grade-A L-features are
cut when the budget is tight. The classic failure is a v1 full of A-grade L-impact
features: cheap to build, worthless to sell.

## AI coding grade rubric

| Grade | Meaning | Examples |
|---|---|---|
| A | cheap for AI | CRUD, forms, dashboards, content sites, API wrappers |
| B | moderate | file processing, 3rd-party integrations, auth via library, single LLM call, HITL AI drafts |
| C | expensive | realtime, payments from scratch, custom auth, autonomous agentic AI pipelines, heavy concurrency |

**Grade is a COST estimate, not a permission.** The gate is fit(grades, budget), not "no C allowed."
When a C feature is the real need, three honest paths:
1. **The C feature IS the product** → invert the cut: C goes FIRST (riskiest assumption first),
   everything else is minimized to serve it, and the budget is renegotiated against reality.
   But: one C proves the value prop — its siblings are v2 cards, not v1 scope.
2. **Re-architect C down to B** (highest-leverage move): multi-step agent → single LLM call;
   auto-send → human-approves-draft; custom pipeline → managed service / library.
   Same user value, one grade cheaper.
3. **Irreducible C that doesn't fit the budget** → KILL or re-budget. Both are honest.

## Gate — check ALL before `/flow next`
- [x] Every feature below has an IMPACT (H/M/L with the business reason) AND a grade (A/B/C)
- [x] No L-impact feature above grade A survives in v1
- [x] The suggested-features section was actually considered (each suggestion has an in/out decision)
- [x] fit(grades, budget) holds — every C in scope is justified as path 1, 2, or 3 above (written next to the feature)
- [x] If the product IS a C feature: it is FIRST in build order, and its sibling C features are on the cut list
- [x] The cut list is written (what I am NOT building in v1)
- [x] GO / KILL decision is written below
- [x] No FILL placeholders remain in this file

## Time budget

~1 session. Additive Python (harness) + shell (recall/gate hook + usage --prune) + tests/docs. Same risk profile as v0.9.0 (shared runner+harness).

## Features in v1 (built as 3 cards, ordered high→low per the open-issue list)

- **F1 (HIGH) — usage-aware `recall`.** `cmd_recall` appends a compact usage summary read from `usage_event` (rolls up first): median cycle-time, the top gate-fail stage(s), cycles started vs reached-cards. Impact **H** — closes half the capture→reuse payoff (the recorded data finally reaches the operator's start-of-stage context). Grade **B** (query + format + no-fail degrade).
- **F2 (HIGH) — usage→`propose`.** `_build_proposals` gains a branch: a stage whose gate fail-rate is high over ≥N cycles emits a backlog proposal (honest heuristic, surfaced for the operator to commit — never auto-applied, matching the existing ≥2-to-fire design). Impact **H** — closes the other half (the most objective build-pain signal becomes a committable improvement). Grade **B**.
- **F3 (LOW) — `flow usage --prune [--keep N]`.** Crash-safe cap of the JSONL sinks (atomic rewrite to a temp then replace; default keep last N lines). Impact **M/L** — bounds unbounded growth (issue #2). Grade **B**.
- **F4 (LOW) — gate-fail reason capture (R5).** The gate body sets `FLOW_LAST_GATE_FAIL` (e.g. `fill:2,unchecked:1`) before a failing `next`/`check` exit; `_log_event` records it in a new `gate_fail_reason` field. Impact **L** — makes "stage X fails" diagnosable (issue #3a). Grade **B**.

## Suggested features (considered, default OUT)
- **S-x — auto-`recall` usage *trend* arrows (improving/worsening over time).** Impact L, grade B. **OUT** — needs ≥several cycles of data to be meaningful; a single summary suffices now (YAGNI).
- **S-y — usage dashboard / chart.** Impact L, grade B. **OUT** — text summary in recall + `flow usage` is enough (anti-FOMO; same call as v1 S-c).

## Cut list (NOT in v1 — deferred / consciously closed)
- **duration in milliseconds (open issue #3b)** — **WONTFIX (closed by decision):** seconds is a deliberate portability choice; `date +%N` is GNU-only and would break the runner's BSD/macOS support (the v1 R1 ruling stands). Not a defect.
- **trace-tier auto-population (open issue #3c / DF-4)** — **OUT OF SCOPE:** this is about card→`trace` field auto-fill in the durable layer, a long-standing concern unrelated to the usage log; it belongs to a separate harness-DX increment, not this loop-closing one.
- Usage trend arrows (S-x), dashboard (S-y) — deferred per above.

## Decision

**GO** — F1–F4 in 3 cards (C-001 = F1+F4 on `flow.sh`; C-002 = F2+F3 on harness py + `flow.sh usage --prune`; C-003 = tests/docs/version). This clears the section-3 open list: #1→F1+F2, #2→F3, #3a→F4; #3b WONTFIX and #3c out-of-scope, both closed in writing rather than left dangling.

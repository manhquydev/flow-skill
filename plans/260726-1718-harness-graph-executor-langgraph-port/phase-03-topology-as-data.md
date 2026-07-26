---
phase: 3
title: "Phase 3: Topology as Data (trusted, linted, pinned)"
status: todo
priority: P1
effort: "2d"
dependencies: [2]
---

# Phase 3: Topology as Data (trusted, linted, pinned)

<!-- Updated: Red Team Session 1 (2026-07-26) — findings 6, 7, 8, 15 applied -->

## Overview

Encode flow's topology (planning 00→05 with the EXISTING debt-gated skip mechanism + shipping card lifecycle with bounded repair cycle) as declarative JSON, trusted and pin-verified, plus `graph lint`. JSON not YAML (stdlib; zero-dependency). Linear 00→05 stays the default path; skips are represented, never invented.

## Requirements

- Functional: `flow-topology.json` (install-dir only), predicate registry, `graph lint` (incl. cmd allowlist + pin check), topology pin file
- Non-functional: human-diffable; `topology_version` int + canonical-JSON `topology_hash`; loadable only from `$SCRIPT_DIR/../references/` (project-local override rejected)

## Architecture

### Trust model (finding 6 — topology is executable-adjacent, treat as code)

- Load path: skill install dir ONLY (`flow.sh` resolves references via `$SCRIPT_DIR/../references/`, assignments at `flow.sh:68,76,77`). A project-local `flow-topology.json` is ignored with a warning. No override env flag in M1.
- `cmd` is an **argv array**, never a shell string, and IS EXECUTED by the executor (user decision R6). Because no `check <stage>` verb exists (planning gates run inside `cmd_next` via `scan_gate`, `flow.sh:865-875`; `cmd_check` takes card ids only, `flow.sh:1096-1103`), this phase ADDS a thin read-only dispatcher verb **`gate`** wrapping `scan_gate` (`flow.sh:149-172` — file-scoped, side-effect-free): `gate <stage>` (closed `$STAGES` set) AND `gate --card C-NNN` (Round-3 F6: scan-only card variant — `cmd_check` is Must-ask (`concierge.md:56`) AND MUTATES on pass: story update/complete + trace writes, `flow.sh:1163-1181`, so `check` is EXCLUDED from autonomous topology execution). `gate` classified May-run in `concierge.md` + `command-dispatch.md`, added to `_log_is_readonly` (`flow.sh:3577-3582`), `test_flow_concierge.sh` expectations updated (27 existing verbs + `gate`).
- Execution isolation (Round-3 F6): node cmds run with NO open write transaction and NO held DB lock (child harness processes write to the same DB — an open `BEGIN IMMEDIATE` would block them into busy_timeout failures recorded as false gate-RED).
- Placeholders: cmds may contain `{card}` only; substituted from the execution ns at run time; lint rejects any other `{...}` token.
- Lint enforces allowlist + ARG SHAPE (R6, corrected Round-4): argv[0] ∈ {flow.sh, git}; flow.sh verb ∈ dispatcher set AND arg shape matches that verb's real signature — `gate` → one `$STAGES` member OR `--card` followed by `{card}`/`C-[0-9]{1,4}`; **`check` has NO shape entry** (a verb banned from autonomous cmd position gets no allowlisted shape — a shape row would read as conditional permission); git verbs ∈ {worktree, merge-base, rev-parse, status, log}. Plus a SMOKE FIXTURE: tests execute every topology cmd (sample substitutions) and assert exit is a gate verdict, never usage/not-found.
- Pin: `skills/flow/harness/pins/flow-topology.sha256` shipped with the skill (extends existing pins/ convention — `pins/` exists with the harness-cli sums file). Executor compares canonical-JSON hash at every load; mismatch = refuse to run (exit 2), not just record. Pin regenerated via a documented `sha256sum` command (no `--write-pin` flag — an in-tool writer whose "refused in CI" mechanism can't be specified is worse than no flag).

### Schema shape (example is lint-clean — finding 15: previous draft referenced `stage-04` without declaring it)

```json
{
  "topology_version": 1,
  "entry": ["stage-00", "card-dispatch"],
  "nodes": {
    "stage-00": {"type": "gate_check", "stage": "00-idea", "cmd": ["flow.sh", "gate", "00-idea"]},
    "stage-01": {"type": "gate_check", "stage": "01-research", "cmd": ["flow.sh", "gate", "01-research"]},
    "stage-02": {"type": "gate_check", "stage": "02-scope", "cmd": ["flow.sh", "gate", "02-scope"]},
    "stage-03": {"type": "gate_check", "stage": "03-prd", "cmd": ["flow.sh", "gate", "03-prd"]},
    "stage-04": {"type": "gate_check", "stage": "04-adr", "cmd": ["flow.sh", "gate", "04-adr"]},
    "stage-05": {"type": "gate_check", "stage": "05-contract", "cmd": ["flow.sh", "gate", "05-contract"]},
    "card-dispatch": {"type": "record_evidence"},
    "card-build": {"type": "record_evidence"},
    "card-review": {"type": "gate_check", "cmd": ["flow.sh", "gate", "--card", "{card}"]},
    "card-repair": {"type": "record_evidence", "max_visits": 2},
    "card-merge": {"type": "git_op"},
    "card-verify-live": {"type": "record_evidence"}
  },
  "edges": [
    {"from": "stage-00", "to": "stage-01"},
    {"from": "stage-01", "to": "stage-02"},
    {"from": "stage-02", "to": "stage-03"},
    {"from": "stage-03", "to": "stage-04"},
    {"from": "stage-04", "to": "stage-05"},
    {"from": "card-dispatch", "to": "card-build"},
    {"from": "card-build", "to": "card-review"},
    {"from": "card-review", "to": "card-merge", "when": "review_green"},
    {"from": "card-review", "to": "card-repair", "when": "review_red"},
    {"from": "card-repair", "to": "card-review"},
    {"from": "card-merge", "to": "card-verify-live"}
  ]
}
```

(Round-5 H2: the example previously declared `card-dispatch`/`card-build`/`must-ask-gate` with no edges — disconnected, failing its own unreachable-nodes rule. Fixed: explicit `entry` roots field, dispatch→build→review edges added, and the static `must-ask-gate` node removed from the example — the `interrupt` node type stays in the enum for topologies with structural operator points, but the generic card lifecycle opens interrupts DYNAMICALLY via `graph record --interrupt` (Phase 2), not via a static node. "Unreachable" is defined as: not reachable from any declared `entry` root.)

### Predicates (finding 7 — represent existing mechanisms, never invent policy)

- Registry `graph_predicates.py`; names only in JSON, implementations in Python; predicates read ONLY durable artifacts (files, DB rows) — never LLM/network.
- Debt-skips are a TRAVERSAL SEMANTIC, not edge predicates (Round-7 H1 — guarded bypass edges were additive-only: skipped nodes stayed reachable via unguarded default edges, and chained skips — reachable, since `cmd_skip` imposes no once-only/ordering constraint, `flow.sh:1223-1263` — dead-ended). `plan_next()` (Phase 2) transitively substitutes the successors of any `gate_check` node whose mapped stage is in `$ROOT/flow/.skipped` (bare stage names written by `cmd_skip` at `flow.sh:1253`, matched `grep -qxF` at `:307-309`); the loader builds the node↔stage mapping from each gate_check node's explicit `stage` field. Registry is exactly `{review_green, review_red, always}`. Topology NEVER writes `.skipped`; it only observes it — every skip retains its governance chain (DEBT + security-class + 05-guard in `cmd_skip`), `planning_complete()` stays satisfied, no new skip policy invented. (The earlier `project_type_skips_prd` predicate is DELETED: no per-type planning skips documented; project type lives in `$ROOT/PROJECT_TYPE`.)
- `review_green`/`review_red`: read recorded gate exit in latest checkpoint manifest.
- Card lifecycle subgraph is generic; card instances + deps come from card files (Phase 4) — individual cards are NOT topology nodes.

### Lint rules

Unknown node refs in edges; unregistered predicate names; planning-subgraph cycles; any cycle lacking a `max_visits` node; nodes unreachable from declared `entry` roots (missing/empty `entry` = lint error); node type outside enum {gate_check, git_op, record_evidence, interrupt}; **cmd not argv-array / not allowlisted / arg shape mismatching the verb's real signature / unknown placeholder / MUTATING verb (`check` etc.) in autonomous cmd position**; **planning-subgraph `gate_check` node missing its `stage` field or stage unmapped to `$STAGES`; card-subgraph `gate_check` nodes MUST NOT declare `stage`** (Round-9 F1 — the loader's skip mapping covers ONLY stage-carrying nodes; a `stage` on `card-review` would make the review gate skippable via `.skipped` with no DEBT row naming it); **skip-reachability, scoped per subgraph (Round-8 F1): from the planning entry root (`stage-00`) the planning terminal `stage-05` (unskippable per `flow.sh:1236-1240`) must be reachable under EVERY one of the 2^5 = 32 subsets of the 5 skippable stages (`$STAGES` minus `05-contract`, `flow.sh:122`), evaluated with `plan_next`'s skip-substitution semantic; from the card entry root (`card-dispatch`) the card terminal `card-verify-live` must be reachable** (replaces the per-node bypass-edge rule, which asserted edge existence but never path existence); **pin mismatch**. Ten+ seeded error fixtures, one per rule, incl. the shipped example itself passing lint AND the smoke fixture — run in an ISOLATED project root with `FLOW_HARNESS_DB` set, every cmd executed with sample substitutions, exit must be a gate verdict (never usage/not-found), and ZERO harness rows written by smoke execution.

## Related Code Files

- Create: `skills/flow/references/flow-topology.json`
- Create: `skills/flow/harness/graph_predicates.py`
- Create: `skills/flow/harness/pins/flow-topology.sha256`
- Modify: `skills/flow/runner/flow.sh` (new read-only `gate` verb wrapping `scan_gate`: `gate <stage>` closed-set validated + `gate --card C-NNN` scan-only variant; `_log_is_readonly` entry)
- Modify: `skills/flow/references/command-dispatch.md` (+`gate` row), `skills/flow/references/concierge.md` (May-run += `gate`), `tests/test_flow_concierge.sh` (verb count + classification expectations)
- Modify: `skills/flow/harness/graph_executor.py` (loader: install-dir-only + pin verify + canonical hash; replace Phase 2 fixture path)
- Modify: `skills/flow/harness/flow_harness.py` (register `graph lint`)
- Create: `tests/test_flow_graph_lint.sh`
- Modify: `tests/run_all.sh` (register); `.github/workflows/ci.yml` (lint step)

## Implementation Steps

1. Read `stage-state-machine.md`, `project-types.md:30-42` (skip governance), `auto-run.md`, `cmd_skip` (`flow.sh:1223-1262`); transcribe CURRENT behavior only — default path must equal the legacy ladder.
2. Land the `gate` verb in flow.sh (stage + `--card` scan-only variants wrapping `scan_gate`), add it to `_log_is_readonly` (`flow.sh:3577-3582`), add the `command-dispatch.md` row + `concierge.md` May-run entry + `test_flow_concierge.sh` expectation update.
3. Implement predicate registry (`review_green`, `review_red`, `always`) + the node↔stage mapping consumed by `plan_next`'s skip-substitution (Phase 2).
4. Implement loader (install-dir only, pin verify, canonical JSON hash → `topology_hash`) + lint; wire `graph lint` into CI + run_all.sh.
5. Resume-on-mismatch policy (finding 15): recorded `topology_hash` ≠ current → `resume` refuses with actionable message; `--force-retopology` forks the chain (`meta.source='fork'`). `topology_version` int lets cosmetic hash changes ship with a bump policy documented in Phase 6 release notes.

## Success Criteria

- [x] `graph lint` exit 0 on shipped topology; exit 1 with node/edge-precise message per seeded fixture (≥10 fixtures incl. arg-shape, placeholder, mapping, pin-mismatch); smoke fixture executes every shipped cmd without usage/not-found errors
- [x] New `gate <stage>` verb: read-only, closed-set validated, classified May-run; `test_flow_concierge.sh` green with updated count
- [x] Default walk (no `.skipped` present) == legacy 00→05 ladder exactly
- [x] Project-local topology file is ignored with warning; pin mismatch refuses execution
- [x] Skip-substitution fires ONLY when `flow/.skipped` names the mapped stage; chained-skip fixture (02-scope + 03-prd both skipped) reaches stage-04 from stage-01; topology never writes `.skipped`
- [x] Resume with changed topology refuses; `--force-retopology` forks with `meta.source='fork'`
- [x] Suite registered in `tests/run_all.sh`; CI lint step green

## Risk Assessment

- Topology/doc drift: lint asserts default path == documented sequence; `stage-state-machine.md` gains pointer in Phase 6.
- Pin update ergonomics: every intentional topology edit needs pin regen via the documented `sha256sum` command (no in-tool writer).
- New `gate` verb widens the dispatcher surface — kept read-only (scan only, no unlock side effects) and closed-set validated; concierge classification test is the guard.

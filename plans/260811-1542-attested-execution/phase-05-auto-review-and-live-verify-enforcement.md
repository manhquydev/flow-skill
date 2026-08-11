---
phase: 5
title: "Auto review and live-verify enforcement"
status: completed
priority: P1
effort: "1.5-2d"
dependencies: [3, 4]
---

# Phase 5: Auto review and live-verify enforcement

## Context links

- [Plan overview](./plan.md)
- [Card risk contract](./phase-03-card-risk-contract-and-auto-preflight.md)
- [Receipt substrate](./phase-04-attestation-receipt-substrate.md)
- `skills/flow/runner/flow.sh:737-947,950-1030,1166-1197`
- `skills/flow/runner/flow.sh:1365-1465,1610-1669,2403-2455`
- `skills/flow/references/auto-run.md:3-76`
- `skills/flow/references/ground-truth-gates.md:1-39`
- `tests/test_flow_auto_done_path.sh`
- `tests/test_flow_workspace.sh`

## Overview

Turn Phase 3 risk policy and Phase 4 receipts into one explicit autonomous
execution mode. `/flow auto` performs the complete activation preflight, writes
shared `.flow/auto-state`, and makes later card transitions fail closed. Outside
active auto, the same receipt checks are visible warnings so existing
manual/teach/work projects remain usable.

The state file is a policy latch, not a daemon or authenticated session. It
survives shell/agent restarts and linked worktrees until `flow auto stop`.

## Requirements

### Functional

- `/flow auto` requires:
  - a Git repository with resolvable integration history;
  - a reliable Phase 2 live process-supervisor capability;
  - planning complete and at least one card;
  - the complete Phase 3 risk/ack preflight;
  - a current accepted `semantic_gate` receipt for committed
    `flow/05-contract.md`.
- Only after all checks pass, write shared `.flow/auto-state` atomically.
- Activation/refresh is accepted only from the resolved main worktree on an
  attached integration branch. Linked-worktree or detached callers refuse with
  the exact main-worktree command.
- Re-running `/flow auto` revalidates and refreshes state; it never preserves a
  stale activation silently.
- `/flow auto stop` removes active, stale, or malformed auto state and returns
  the project to warning-only behavior.
- While auto state exists:
  - malformed/stale state blocks every enforced transition;
  - `check` requires a current accepted card semantic receipt;
  - a done card additionally requires a current passing `live_verify` receipt;
  - `card done` inherits the same checks and restores `todo` on failure;
  - `ready` does not count a done dependency whose semantic/live receipts are
    missing, stale, invalid, or red;
  - removing an ancestry-merged worktree requires both receipts;
  - removing an unmerged/abandoned worktree remains allowed.
- `status` and `resume` show `INACTIVE|ACTIVE|STALE|INVALID`, activation time,
  integration branch, receipt/risk blockers, and the exact repair command.
- `/flow next` remains warning-only in v0.28; it reports stage semantic receipt
  state before advancing but never changes the mechanical result.

### Non-functional

- Bash + Git only; no Python/SQLite gate dependency.
- One state owner and one validation path in `runner/attestations.sh`.
- Active state is shared across linked worktrees using Phase 4’s main-state
  resolver.
- A shared main-state auto-policy mutex serializes preflight, activation,
  refresh, and stop.
- Receipt failures are checked before graph/harness completion side effects.
- No hidden bypass flag. Deliberate manual continuation uses `flow auto stop`.

## Architecture

### Auto-state contract

Path:

```text
<main-state-root>/.flow/auto-state
```

Closed canonical schema:

```text
schema: flow-auto/v1
status: active
activated_at: <UTC RFC3339>
activated_by: <sanitized session label, <=128 bytes>
integration_branch: <validated branch name>
risk_fingerprint: git-<sha1|sha256>:<object-id>
contract_fingerprint: git-<sha1|sha256>:<object-id>
```

`risk_fingerprint` hashes every sorted `cards/C-*.md` ID and normalized risk fields;
it excludes mutable card status/Evidence. `contract_fingerprint` must equal the
current accepted Stage 05 semantic receipt fingerprint.

State currentness reruns the full risk acknowledgement validation, not only the
hash comparison. This catches a referenced commit that ceased to be an
ancestor after history rewrite. It also revalidates the Stage 05 receipt. A
branch rename, card-set/risk mutation, contract mutation, invalid ack, or
invalid state schema makes the latch `STALE`/`INVALID`.

The activation label aids audit only. It never binds enforcement to one process
or authenticates an actor.

### Enforcement matrix

| Command/boundary | Auto inactive | Auto active/current | Auto stale/invalid |
|---|---|---|---|
| `next` | Warn on stage receipt | Warn only | Warn only |
| `check` todo | Warn on card semantic | Require semantic | Block |
| `check` done | Warn on semantic/live | Require semantic + live pass | Block |
| `card done` | Existing check + warnings | Same hard checks; revert on failure | Block + revert |
| `ready` | Existing readiness + advisory receipt state | Done deps require both receipts | No buildable output; non-zero |
| merged `workspace remove` | Warn only | Require both receipts before removal | Block |
| unmerged `workspace remove` | Existing abandon behavior | Allow abandon without receipts | Allow abandon |

Receipt enforcement occurs before `_graph_record`, durable story completion,
trace writes, worktree telemetry ingest, or removal. A failed attestation gate
must not journal a false completed boundary.

When auto is inactive, missing/malformed risk or receipt metadata produces only
a warning and never changes the command’s pre-v0.28 exit code. When auto state
exists but is stale/invalid, the hard matrix applies.

### Completion ownership and ordering

Active `card done C-NNN` is integration-checkout owned:

1. Refuse when invoked from a linked/detached worktree; print the resolved
   main-worktree command.
2. Acquire locks in the Phase 4 order.
3. Validate current auto state and semantic/live receipts while the card is
   still committed `todo`.
4. Call a new read-only prospective-done helper that reuses
   `_card_done_evidence_ok` without first changing `status`; do not call
   `cmd_check` through its current status-dependent path.
5. Mutate `status`/`Evidence` only after all gates pass. These CLI-owned fields
   are excluded from semantic projection/cleanliness.
6. Leave the integration card change explicit for the normal commit workflow;
   `workspace remove` is not permitted to discard the only done-state update.

Failure before step 5 leaves the card unchanged. Signal-safe restoration remains
defense in depth, not the primary ordering mechanism.

### Merged worktree rule

Before removing a worktree, resolve its branch tip and test ancestry against the
main integration HEAD:

- ancestor: merged path; validate the semantic receipt against the still-live
  review worktree and validate live receipt against integration/deployed state;
- not ancestor: abandon path; receipt absence does not block removal;
- ambiguous/missing branch identity while auto is active: refuse rather than
  guess merged versus abandoned.

The merged path must resolve one validated card identity from the workspace
registry or exact `workspace remove <branch> --card C-NNN`. Missing, stale, or
conflicting mappings refuse before telemetry ingest/removal and print the
reconciliation command.

`--force` only bypasses Git dirty-tree refusal. It does not bypass a merged
auto receipt gate; the operator must stop auto explicitly.

## File inventory

| Action | File | Intended change | Rough size | Test impact |
|---|---|---|---:|---|
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/runner/attestations.sh` | Auto-state parser/writer/currentness + reusable enforcement helpers | 140-220 LOC | Attestation + auto suites |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/runner/flow.sh` | `auto [stop]`, next/check/done/ready/workspace hooks, status/resume | 180-280 LOC | Broad runner lifecycle |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/SKILL.md` | Auto activation and explicit stop contract | 20-35 LOC | Docs contract |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/references/auto-run.md` | Receipt-producing sequence and no-bypass rule | 40-70 LOC | Graph/auto docs |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/references/ground-truth-gates.md` | Active-auto enforcement matrix | 20-35 LOC | Docs contract |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/references/command-dispatch.md` | `auto`/`auto stop`/attestation consent classes | 5-15 LOC | Concierge |
| Create | `/home/manhquy/Downloads/flow-skill/tests/test_flow_auto_attestation_enforcement.sh` | Activation, state lifecycle, transition matrix | 320-460 LOC | Register in run_all |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/test_flow_auto_done_path.sh` | Active versus inactive done behavior | 40-80 LOC | Focused |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/test_flow_workspace.sh` | Merged block/unmerged abandon/force semantics | 60-100 LOC | Focused |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/test_flow_resume.sh` | State visible with and without telemetry | 25-50 LOC | Focused |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/test_flow_status_legibility.sh` | Active/stale/invalid summaries | 25-50 LOC | Focused |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/test_flow_concierge.sh` | New subcommand classification | 10-20 LOC | Focused |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/run_all.sh` | Register suite atomically | <5 LOC | Full |

## Interface checklist

- [ ] `cmd_auto "$@"` distinguishes activation from exact `stop`; extra args fail.
- [ ] No state file is written when any blocker exists.
- [ ] State is shared from main and linked worktrees.
- [ ] Activation/refresh/stop are serialized by the shared auto-policy mutex.
- [ ] Activation from linked or detached worktrees refuses.
- [ ] Full risk/ack and Stage 05 receipt are revalidated at each hard boundary.
- [ ] `check` performs receipt checks before durable/graph writes.
- [ ] `card done` validates before mutation and is owned by the integration
  checkout; failure leaves todo unchanged.
- [ ] `ready` cannot upgrade status/evidence-only done into an auto-satisfied dep.
- [ ] Merged versus unmerged removal is determined before deleting the tree.
- [ ] `--force` cannot bypass merged active-auto enforcement.
- [ ] `auto stop` can clear malformed state safely.
- [ ] `resume` does not hide state in its no-telemetry early-return path.
- [ ] Inactive projects retain existing exit behavior.

## Dependency map

```text
Phase 3 risk + ack -------+
                          +--> auto activation --> .flow/auto-state
Phase 4 stage receipt ----+                         |
                                                    v
Phase 4 card/live validators --> check/done/ready/workspace enforcement
                                                    |
                                                    v
                                           Phase 6 acceptance corpus
```

## Test scenario matrix

| Priority | Scenario | Expected |
|---|---|---|
| Critical | Risk valid but Stage 05 receipt missing/stale/red | Auto refuses; no state file |
| Critical | Live supervisor capability unavailable | Auto refuses; manual path remains usable |
| Critical | One unknown/security-invalid card among valid cards | All blockers printed; no activation |
| Critical | Valid activation, then card risk/Stage 05 changes | State stale; hard boundaries block |
| Critical | Concurrent linked activation and `auto stop` | Shared lock yields one deterministic final state |
| Critical | Activation attempted from card worktree/detached HEAD | Refuse; no shared state written |
| Critical | Active `check` without card semantic receipt | Fail before graph/harness side effects |
| Critical | Active `card done` without live pass | Fail and card restored to todo |
| Critical | Active done dep has stale semantic/live receipt | `ready` reports blocked, never BUILDABLE because of it |
| Critical | Active merged worktree lacks either receipt | Removal refused; tree remains |
| Critical | Active unmerged worktree lacks receipts | Removal/abandon allowed |
| Critical | `workspace remove --force` on merged branch lacks receipt | Still refused |
| Critical | Merged workspace has no/stale/conflicting card mapping | Refuse before ingest/remove; show `--card` repair |
| High | `auto stop` after invalid state | State removed; manual path warning-only |
| High | Linked worktree observes main auto state | Same ACTIVE/STALE result |
| High | Inactive legacy `check`/`card done` | Existing result plus actionable warning |
| High | `next` lacks semantic receipt | Warning only; mechanical pass/fail unchanged |
| Medium | `resume` has no event log | Auto state still shown |

## Implementation steps

1. Add failing activation/state-lifecycle and transition-side-effect tests.
2. Implement strict auto-state read/write/remove helpers plus the shared
   auto-policy mutex in `attestations.sh`.
3. Compute risk-set fingerprint and re-run Phase 3 acknowledgement validation
   when checking state currentness.
4. Extend `cmd_auto` to require main attached integration checkout, all-card
   risk + Stage 05 semantic receipt, then atomically activate; add exact
   serialized `auto stop`.
5. Add a single enforcement helper called before `cmd_check` success side
   effects; make done require both receipt kinds.
6. Reorder `cmd_card_done`: require integration checkout, validate receipts and
   mechanical evidence before status mutation, preserve restore trap as backup.
7. Make `cmd_ready` receipt-aware only when auto exists; retain advisory
   behavior otherwise.
8. Resolve/validate card identity and merged/abandoned status before `_ws_remove`
   deletes or ingests; add exact `--card C-NNN` repair path and enforce receipts
   only on the merged path.
9. Render state in `status` and in every `resume` branch, including no
   telemetry.
10. Add warning-only stage/card/live guidance for inactive/manual commands.
11. Update auto/ground-truth/dispatch docs and help.
12. Run focused suites, graph/worktree regressions, no-Python smoke, then the
    full suite.

## Todo

- [ ] Auto-state contract implemented
- [ ] Activation + stop lifecycle complete
- [ ] Check/done/ready enforcement complete
- [ ] Merged removal guarded; abandon preserved
- [ ] Status/resume/manual warnings complete
- [ ] Focused/full/no-Python suites green

## Success criteria

- [ ] Auto cannot activate without valid risk state and current Stage 05
  semantic review.
- [ ] Once active, no card can pass review/done/dependency/merged-removal
  boundaries without the exact required current receipts.
- [ ] Receipt failure produces no false graph/harness completion event.
- [ ] Explicit `auto stop` is the only supported policy downgrade.
- [ ] Manual and legacy projects remain non-breaking.

## Risk assessment

| Risk | Mitigation |
|---|---|
| Stale latch bricks ordinary work | `status` explains why; `auto stop` is explicit and always available |
| Worktree removal destroys evidence before check | Validate before ingest/remove; shared receipts survive removal |
| Readiness drifts from check | Reuse the same receipt validators; test active done deps end-to-end |
| Session restart loses policy | Shared persistent state; actor label never used as ownership lock |
| Agent deletes state file | Explicitly outside hostile-host boundary; docs state filesystem writers can disable/replace run-state |

## Security considerations

- Auto state and actor labels are not cryptographic identity.
- Never infer merged state from registry prose; use Git ancestry.
- Do not let `--force`, malformed state, or unavailable Python weaken the gate.
- Avoid printing receipt contents, command argv, or environment in status.

## Rollback

Run `flow auto stop`, then revert Phase 5 enforcement. Receipt and risk files
remain inert and readable. No database migration or card rewrite is required.

## Next steps

Phase 6 proves the complete attack/migration corpus, dogfoods the active path,
and cuts the coherent v0.28 release.

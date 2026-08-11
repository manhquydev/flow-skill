---
title: "flow v0.28 — Attested Execution / Trust Control Plane"
description: "Persist card risk and require fingerprint-bound semantic/live verification receipts on autonomous transitions while preserving the standalone Bash floor."
status: completed
priority: P1
effort: "8-12d"
branch: master
tags: [feature, critical, security, trust, auto, harness]
blockedBy: []
blocks: [260726-1718-harness-graph-executor-langgraph-port]
created: 2026-08-11
sources:
  - plans/reports/brainstorm-260811-1526-flow-next-product-direction.md
  - plans/260811-1120-flow-hollow-done-trust-eval/plan.md
  - plans/260811-1405-flow-harness-authority-continuity/plan.md
---

# flow v0.28 — Attested Execution / Trust Control Plane

## Overview

Make a current, explicit semantic verdict mechanically required for `/flow auto`.
Risk classification becomes card state. Semantic review and live verification
produce bounded receipts tied to the exact artifact/revision they evaluated.
Changing the subject makes the receipt stale; missing, structurally tampered,
stale, or failed receipts cannot unblock an active autonomous run.

The receipt layer is a workflow-integrity boundary, not an independent reviewer
or hostile-host trust anchor. A semantic receipt proves that the declared,
machine-readable review contract was executed and recorded against the current
subject; actor/engine labels and unsigned files do not prove who performed it.

This is a **HOLD SCOPE** deep plan. It implements the trust control plane first,
then leaves context/model economics and ecosystem adapters for later releases.

## Roadmap order

| Release | Direction | Why this order |
|---|---|---|
| **v0.28** | **Attested Execution / Trust Control Plane** | Closes verified transition-trust gaps before increasing autonomy or distribution |
| v0.29 | Context Pack & Model Economics | Can reuse receipt fingerprints as stable context/cache identities |
| v0.30 | Ecosystem Bridges | GitHub/CI/MCP adapters can project a trustworthy verdict instead of more prose |

## Scope challenge

- **Existing code to reuse:** `scan_gate`, `cmd_gate`, `card_status`,
  `_card_done_evidence_ok`, `_card_allowed_files`, worktree/graph state,
  harness risk lanes, durable trace/decision/usage surfaces.
- **Minimum change:** one closed risk contract, one receipt format, one
  shared-state resolver, two receipt kinds, enforcement only while auto mode is
  active.
- **Complexity:** six phases because contract, attestation execution hygiene, risk migration,
  receipt substrate, enforcement, and release proof have different rollback
  boundaries. No new service or generalized policy engine.
- **Selected mode:** **HOLD SCOPE**.

## Verified problem statement

| Gap | Current evidence | Required v0.28 correction |
|---|---|---|
| Semantic verdict is not transition state | `skills/flow/SKILL.md:29-41,88,136-142`; `skills/flow/runner/flow.sh:950-1030` | Persist semantic verdict against the current subject fingerprint; enforce in auto |
| Tier-C halt is prose only | `skills/flow/references/auto-run.md:7-21`; `skills/flow/_templates/card.md:3-5`; `skills/flow/runner/flow.sh:1652-1669` | Persist card risk; fail auto preflight on `unknown` or invalid security acknowledgement |
| Done evidence can be a decoy | `skills/flow/runner/flow.sh:1240-1363,1409-1431`; `skills/flow/references/ground-truth-gates.md:31-36` | Require runner-minted `live_verify` receipt in auto; keep prose Evidence as human-readable context |
| Existing timeout/output helpers are unsafe to reuse for live attestation | `skills/flow/runner/flow.sh:251-255,2576-2605`; `DEBT.md:3` | Add an attestation-only argv supervisor with streaming caps, process-group cleanup, and fail-closed capability detection |
| Usage logging persists full command args | `skills/flow/runner/flow.sh:3922-3930,3971-4012` | Attestation events expose only subcommand/subject/result; global harness sanitization remains a separate follow-up |
| Worktree durable state needs one shared owner | `skills/flow/harness/_db.py:35-122`; `tests/test_flow_graph_parallel_cards.sh:39-56,131-142` | Add a conservative Bash state-root resolver with parity tests; receipts remain readable without Python |
| Release metadata already drifts | `npm-wrapper/package.json:3`; `docs/quality-metrics.md:4-18`; `.github/workflows/publish-npm-wrapper.yml:50-60`; `npm-wrapper/CHANGELOG.md:41-46` | Add executable release-doc coherence and select `next` as the canonical future prerelease tag |

## Goals

| # | Goal | Priority |
|---|---|---|
| 1 | Every card has persisted `risk`, `risk-reason`, and `risk-ack` state; absent legacy metadata reads as `unknown` | P1 |
| 2 | `/flow auto` fails closed on unknown risk, invalid security acknowledgement, or a missing/stale/red Stage 05 semantic receipt | P1 |
| 3 | Two receipt kinds ship: `semantic_gate` and `live_verify`; both are fingerprint-bound, atomic, bounded, and secret-safe | P1 |
| 4 | While auto mode is active, `check`, `card done`, dependency readiness, and merged-worktree teardown cannot bypass required current receipts | P1 |
| 5 | While auto is inactive, manual/teach/work paths remain backward compatible and show guided warnings; planning `next` is never hard-enforced in v0.28 | P1 |
| 6 | Bash remains the core read/enforcement floor; Python/SQLite are optional and never required to parse or validate receipts | P1 |
| 7 | Full deterministic corpus proves missing, structurally tampered, stale, dirty-tree, timeout, non-zero, and security-ack failures across supported platforms | P1 |

## Constraints

- Standalone skill. No AgentKit, MCP, vendor, cloud, or model hard dependency.
- Bash + Git own auto enforcement. Python/SQLite may mirror metadata only.
- `auto` and receipt mint/validation require a Git repository; non-Git manual
  flow remains warning-only and usable.
- Closed risk vocabulary: `standard|security-class|unknown`.
- Auto only accepts a clean committed review subject. Dirty or untracked files
  block receipt mint/consumption, except CLI-owned `status`/`Evidence` projection
  fields and the skill-owned `.flow/` run-state.
- Fingerprints detect staleness; they do **not** authenticate a human or model.
- No raw prompts, raw tool output, secrets, tokens, or unbounded excerpts in
  receipts.
- Preserve project types, teach/work modes, hand-edited cards, worktrees,
  graph executor, and current evidence floor.
- Existing graph code remains shipped. Do not activate Python as a mandatory
  dependency or make graph default-on.

## Non-goals

- MCP gateway, MCP marketplace, OAuth broker, or hosted control plane.
- IDE/CLI coding agent, model router, pricing engine, token billing system.
- Dashboard, remote receipt service, signing PKI, cryptographic actor identity.
- General policy language, arbitrary receipt types, vector memory, trajectory warehouse.
- Spec Kit/OpenSpec clone or artifact-model rewrite.
- Hard enforcement of manual `/flow next` in v0.28.
- Installer transaction rewrite or tarball redesign; only release-coherence
  checks required by this trust release.

## Locked design decisions

| ID | Decision |
|---|---|
| D1 | Auto-first enforcement. When auto state is absent, manual `next`/`check`/`card done` warn and guide but remain usable. While auto is active, `check`/`card done` enforce; `next` remains warning-only. |
| D2 | Risk fields: `risk`, `risk-reason`, `risk-ack`. New cards default `risk: unknown`; legacy missing field reads `unknown`. |
| D3 | `security-class` acknowledgement is `risk-ack: git:<full-commit-oid>` pointing to an ancestor commit whose `DEBT.md` contains the exact open grammar `DEBT: security-class C-NNN`. The author of that line at the referenced commit must differ from the executing Git identity. v0.28 deliberately makes missing/same/ambiguous identity fail-closed for auto; the shipped graph interrupt only records `author_distinct` as audit evidence. |
| D4 | Receipt source of truth is an atomic line-oriented file under the main state root `.flow/attestations/`. Optional SQLite mirror never gates. |
| D5 | Receipt kinds are exactly `semantic_gate` and `live_verify` for v0.28. Unknown kinds/fields, duplicate keys, multiline values, or missing required keys are rejected. |
| D6 | Receipt verdict vocabulary: `pass|fail|override`. `override` is semantic-only in auto and requires an ancestor DEBT commit containing exact open grammar `DEBT: semantic-override <stage-name-or-C-NNN>` whose line author differs from the executing Git identity. Auto never accepts `live_verify: override`; security-class risk acknowledgement remains a separate check. |
| D7 | Stage semantic fingerprint = exact committed artifact blob. Card semantic fingerprint = canonical card-contract projection + clean base/reviewed-revision/tree identities. Live fingerprint = deployed revision + canonical Verify/Done-evidence projection + committed verification-owner manifest + explicit target identity + executed argv digest. Semantic receipts record the reviewed revision metadata needed to revalidate them after an ancestry-preserving merge. |
| D8 | Git object IDs use the repository’s storage object format (`sha1` or `sha256`). Untracked/dirty review subjects fail closed rather than being silently omitted. |
| D9 | Auto preflight requires the full risk set plus a current accepted Stage 05 semantic receipt, then atomically activates persisted auto policy state in the shared main `.flow` directory. Card/live receipts are later transition gates, not prerequisites to activation. `auto stop` clears state; `status`/`resume` expose active/stale/invalid state. |
| D10 | Existing Evidence text remains for operators, but it cannot replace a current `live_verify` receipt during active auto. |
| D11 | Attestation owner/oracle commands are committed repo-relative executables invoked with runner-constructed argv, root-pinned cwd, streaming time/output bounds, process-group cleanup, and no shell escape. Existing optional harness stored-command migration is out of v0.28 scope. |
| D12 | Canonical future npm prerelease dist-tag is the selected new `next` policy, replacing stale operational `rc` paths; historical `rc` records remain history only. |
| D13 | Receipt files are latest-assessment state. A valid semantic `fail` and a started live attempt’s `fail` replace any older `pass`; another successful assessment/run is required to return to green. Same-subject commands serialize writers and consumers under one lock. A live attempt marker is written before spawn; any unresolved marker makes auto consumers fail closed until the dead owner is recovered. Invalid CLI/schema input does not overwrite a receipt. |

## Receipt contract

Required single-line keys, in canonical order:

```text
schema: flow-attestation/v1
kind: semantic_gate|live_verify
subject_type: stage|card
subject_id: <closed stage name or C-NNN>
subject_fingerprint: git-<sha1|sha256>:<object-id>
verdict: pass|fail|override
actor: <sanitized identifier, <=128 bytes>
engine: <sanitized identifier, <=128 bytes>
evidence_ref: <none or repo-relative bounded reference>
timestamp: <UTC RFC3339>
override_ref: <none or git:<full-object-id>>
owner_ref: repo:<repo-relative owner manifest>
owner_fingerprint: git-<sha1|sha256>:<object-id>
```

`live_verify` additionally records bounded scalar metadata:
`subject_revision`, `command_fingerprint`, `result_code`, `result_fingerprint`,
`duration_ms`, `target_id`, `revision_oracle_ref`, and
`revision_oracle_fingerprint`.
`result_code` is closed:
`exit:<0..255>|timeout|output-cap|signal:<1..64>|spawn-error`.
`result_fingerprint` hashes canonical outcome metadata (status, byte counts,
argv digest, and duration bucket), never stdout/stderr bytes. `duration_ms`
may have 1000ms resolution on the Bash-only portability floor. A cap breach,
timeout, or non-zero result writes a latest-attempt `fail` receipt, never a
`pass`.

`semantic_gate` records review identity needed for deterministic revalidation:

- stage: `subject_revision`;
- card: `subject_base`, `subject_revision`, and `subject_tree`.

Those values are validated object IDs, not free-form refs. A card receipt stays
current after an ancestry-preserving merge only when the reviewed revision is
an ancestor of integration HEAD, the current canonical card-contract projection
still matches the reviewed revision, and every path changed by
`subject_base..subject_revision` except the card markdown path has the same
object/mode at integration HEAD. The card path is compared through its canonical
projection so CLI-owned `status`/`Evidence` updates remain allowed.
Conflict resolution or later edits to a reviewed path make the receipt stale.
Squash/rebase invalidates the receipt and requires review of the final integrated
revision.

## Target state flow

```text
card scaffold
  -> risk=unknown
  -> operator/agent classifies
  -> /flow auto preflight
       unknown ------------------------------> BLOCK
       security-class + bad/missing ack -----> HALT
       Stage 05 receipt missing/stale/red ----> BLOCK
       valid risk ----------------------------> auto-active
  -> build on committed worktree branch
  -> committed machine-readable semantic review owner executes
  -> semantic_gate receipt(current branch subject)
  -> /flow check
       missing/stale/tampered receipt --------> BLOCK in auto
  -> merge + deploy
  -> runner executes bounded live probe
  -> live_verify receipt(current deployed revision)
  -> /flow card done
       missing/stale/failed receipt ----------> BLOCK in auto
  -> workspace remove
       merged path rechecks both receipts
       unmerged path may abandon without them
```

## Cross-plan dependencies

| Relationship | Plan | Decision |
|---|---|---|
| Blocks/supersedes remaining direction | `260726-1718-harness-graph-executor-langgraph-port` | Keep shipped graph foundation; do not execute its remaining Python-mandatory/default-on Phase 6 |
| Builds on completed | `260811-1120-flow-hollow-done-trust-eval` | Preserve evidence floor; receipts add stronger auto proof |
| Builds on completed | `260811-1405-flow-harness-authority-continuity` | Preserve flow-owned authority and optional durable layer |

## Phases

| # | Phase | Status | Depends | Effort |
|---|---|---|---|---|
| 1 | [Contract freeze and executable baseline](./phase-01-contract-freeze.md) | Pending | — | 1d |
| 2 | [Harness verification authority and redaction](./phase-02-harness-verification-authority-and-redaction.md) | Pending | 1 | 1.5-2d |
| 3 | [Card risk contract and auto preflight](./phase-03-card-risk-contract-and-auto-preflight.md) | Pending | 1 | 1-1.5d |
| 4 | [Attestation receipt substrate](./phase-04-attestation-receipt-substrate.md) | Pending | 1,2 | 2-3d |
| 5 | [Auto review and live-verify enforcement](./phase-05-auto-review-and-live-verify-enforcement.md) | Pending | 3,4 | 1.5-2d |
| 6 | [Eval, migration, dogfood, and release](./phase-06-eval-migration-dogfood-and-release.md) | Pending | 2,3,4,5 | 1-2d |

Dependency chain: `1 -> {2,3}; 2 -> 4; {3,4} -> 5; {2,3,4,5} -> 6`.

## Implementation slicing

| Slice | Content | May ship alone? |
|---|---|---|
| A | Phase 1 contract/tests baseline | No behavior change; may merge alone |
| B | Phase 2 attestation execution hygiene | Yes, after focused + full tests |
| C | Phases 3-5 risk + receipts + auto enforcement | **Atomic release slice**; do not ship auto-active without all enforcement backstops |
| Release | Phase 6 migration/eval/docs/version/distribution | Required before v0.28 tag |

## Plan-level success criteria

- [ ] New cards scaffold `risk: unknown`; legacy cards without fields remain
  usable manually but `/flow auto` reports each as blocked.
- [ ] Security-class auto work requires a committed, ancestor, card-naming
  DEBT acknowledgement and cannot be self-released by a reviewer verdict.
- [ ] `/flow auto` cannot activate without a current accepted semantic receipt
  for the exact committed `flow/05-contract.md` artifact.
- [ ] Receipt parser rejects duplicate/unknown keys, multiline injection,
  invalid IDs, invalid object format, path traversal, and oversized values.
- [ ] Semantic `pass` requires a committed review-owner manifest whose exact
  command and subject fingerprint match; prose Verify text alone cannot mint a
  pass.
- [ ] Editing a stage, card contract projection, branch tree, verify spec, or
  deployed revision, verification owner, target identity, or reviewed changed
  path makes the relevant prior receipt stale.
- [ ] Dirty tracked changes and untracked files block card semantic receipt
  mint/acceptance in auto.
- [ ] Timeout, output-cap breach, signal termination, or non-zero live command
  never mints a passing `live_verify` receipt and replaces an older pass with
  latest-attempt red state once execution has begun; abrupt death leaves a
  fail-closed attempt marker.
- [ ] Active auto enforcement is visible in `status`/`resume`; `auto stop`
  clears it; abandoned unmerged worktrees remain removable.
- [ ] Manual `next` remains non-breaking and clearly warns when a semantic
  receipt is absent/stale.
- [ ] Receipt read/enforcement paths pass with Python absent.
- [ ] Attestation owner/oracle execution uses fixed cwd, streaming output caps,
  process-group timeout cleanup, redacted structured logging, and deterministic
  fail-closed refusal when a reliable supervisor is unavailable.
- [ ] Stage 05 Contract sound/hollow eval fixtures are shipped and
  deterministic fixture-structure tests pass.
- [ ] `bash tests/run_all.sh`, npm wrapper tests, release coherence, and
  `git diff --check` pass; CI is green on Ubuntu, macOS, and Windows.
- [ ] Skill version becomes `0.28.0`; plugin/portable/npm bundle mirrors and
  public docs are coherent.
- [ ] No unresolved Critical/High red-team finding, failed material claim, or
  whole-plan contradiction remains.

## Rollback strategy

- Phase 2 is independently revertible; no receipt dependency.
- Phase 3 metadata is additive. On rollback, extra card lines are ignored by
  older runners.
- Phases 4-5 are guarded by persisted auto-active state. Emergency rollback:
  `flow auto stop`, then revert enforcement while leaving receipt files inert.
- Receipt files are run-state; removing `.flow/attestations/` loses audit
  history but does not corrupt cards or the harness DB.
- No destructive DB migration is required. Any optional receipt mirror is
  additive and ignored by older versions.

## Red Team Review

**LOOP CLOSED 2026-08-11 — Full tier, 3 independent reviewers; 0 unresolved
Critical/High findings after adjudication.** 27 raw observations were deduped to
15 material findings; 15 accepted and applied, 7 lower-severity notes folded into
the same edits, and no finding was rejected for lack of source/plan evidence.

| # | Severity | Finding | Evidence | Disposition |
|---:|---|---|---|---|
| 1 | Critical | `card done` mutates tracked status before receipt consumption | `flow.sh:1172-1184`; prior `plan.md:229-230` | Accepted: validate before mutation; status/Evidence projection and `.flow` are owned exclusions; completion is integration-checkout owned |
| 2 | Critical | Receipt writer/consumer TOCTOU | `flow.sh:1365-1459`; Phase 4 prior reader-only contract | Accepted: one subject lock spans validation and irreversible side effects |
| 3 | Critical | Interrupted live attempt leaves old pass authoritative | `flow.sh:1174-1177`; `tests/test_flow_usage_log.sh:628-637` | Accepted: pre-spawn attempt marker; unresolved marker blocks until dead-owner recovery |
| 4 | Critical | Deployed revision caller-asserted | Phase 4 prior live algorithm; `flow.sh:1300-1314` | Accepted: committed verification-owner manifest plus machine-readable revision oracle |
| 5 | Critical | Semantic pass self-mintable from arbitrary CLI verdict | `SKILL.md:29-41,136-142`; Phase 4 prior CLI | Accepted: exact committed review-owner manifest is required; remaining unsigned-host limitation stated |
| 6 | Critical | Edited unsigned verdict cannot be detected by subject fingerprint | `.flow` ordinary writable state `flow.sh:85-90,109-117` | Accepted: remove false detection claim; only malformed/schema/subject inconsistency is detectable |
| 7 | Critical | Shared auto activation/stop races | `flow.sh:58-60,496-523,1652-1653` | Accepted: shared main-state auto-policy mutex |
| 8 | High | Activation from linked worktree binds card branch | `flow.sh:29-49,2335-2337` | Accepted: activate/refresh only from resolved main worktree; linked/detached attempts refuse |
| 9 | High | Done dependency escapes risk set | `flow.sh:1628-1640`; `tests/test_flow_auto_done_path.sh:20-24` | Accepted: one all-card risk-set function includes done dependencies |
| 10 | High | Timeout/output cap can leave descendants or buffer unbounded output | `flow.sh:2576-2605`; `flow_harness.py:257-279` | Accepted: streaming cap, owned process group, TERM/KILL/wait; unsupported supervisor blocks auto |
| 11 | High | Attestation argv leaks to usage log | `flow.sh:3922-3930,3971-4002` | Accepted: log subcommand/subject/result only; never argv after `--`; inspect all event sinks |
| 12 | High | `.flow` run-state makes clean gate permanently dirty | `flow.sh:109-117,3971-4002`; linked `.git` file shape | Accepted: explicit owned-state exclusion; no `.gitignore` mutation dependency |
| 13 | High | Merged removal lacks guaranteed card identity | `flow.sh:2290-2303,2415-2452` | Accepted: validated branch→card mapping or explicit `--card`; refuse before ingest/remove with repair command |
| 14 | High | Global harness sanitizer/legacy shell migration bloats v0.28 | `flow.sh:191-206,302-308`; Phase 2 inventory | Accepted: narrow Phase 2 to attestation-local execution/redaction; defer optional durable-wide migration |
| 15 | Medium | `rc` and stage-vocabulary consumers omitted | `npm-wrapper/scripts/smoke.mjs`, `SECURITY.md`, public docs | Accepted: inventory exact operational consumers and all seven stage-vocabulary docs |

Whole-plan sweep after edits: checked D1-D13, risk-set wording, live owner/oracle
grammar, lock ordering, manual matrix, `next` policy, and every phase dependency;
no stale `todo-only`, reader-only, self-authenticating, or current-guidance
claim remains.

### Round 2 — targeted correction audit

Rechecked the corrected producer authority, deployed-revision oracle,
changed-path survival, attempt recovery, auto/subject lock ordering,
integration-owned completion, and optional-harness scope boundary. Result:
**0 Critical, 0 High, 0 whole-plan contradictions**. One adjacent contradiction
found during the sweep—status/Evidence updates changing the card blob while
changed-path identity was exact—was corrected by excluding the card markdown
path from object/mode comparison and validating it through canonical projection.

## Validation Log

**Full tier complete 2026-08-11.**

| Check | Result | Evidence |
|---|---|---|
| Material claim audit | 90 checked: 15 per phase; 58 source-backed, 32 design/contract consistency claims | Source reads across `flow.sh`, harness, templates, tests, DEBT, workflows, release docs |
| Failed material claims | 0 | D12 current-guidance claim corrected; optional-harness migration claim removed |
| Unverified material claims | 0 | Future behavior is stated as requirements/tests, not current behavior |
| Whole-plan contradictions | 0 | Cross-phase sweep over D1-D13, schemas, locks, risk set, owner/oracle, completion/removal |
| Internal plan links | PASS | Local relative-link existence sweep |
| `ak plan reindex --apply` | PASS | `260811-1542-attested-execution` recognized |
| `ak plan use .../260811-1542-attested-execution` | PASS | Active path printed by CLI |
| `ak plan validate .../260811-1542-attested-execution` | PASS | `[OK] ... is a valid plan directory` |
| `git diff --check` | PASS | No output |
| Explicit untracked whitespace scan | PASS | Plan directory + brainstorm report; no trailing whitespace |
| Workspace scope | PASS | Only old-plan supersession, new v0.28 plan, and accepted brainstorm report are changed |

Validation is for planning artifacts only. Product implementation/tests/CI are
intentionally not run; those gates are assigned to the phase files.

## Open questions

None. Scope and roadmap order are locked by the accepted brainstorm; validation
may reopen only a source-proven contradiction.

<!-- slug: attested-execution -->

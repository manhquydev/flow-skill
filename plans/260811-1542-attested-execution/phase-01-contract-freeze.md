---
phase: 1
title: "Contract freeze and executable baseline"
status: completed
priority: P1
effort: "1d"
dependencies: []
---

# Phase 1: Contract freeze and executable baseline

## Context links

- [Plan overview](./plan.md)
- [Accepted brainstorm](../reports/brainstorm-260811-1526-flow-next-product-direction.md)
- `skills/flow/SKILL.md:27-41,88,136-142`
- `skills/flow/runner/flow.sh:950-1030,1240-1363,1652-1669`
- `skills/flow/harness/_db.py:35-122`
- `skills/flow/harness/graph_executor.py:591-626,698-720`
- `tests/run_all.sh:1-23`

## Overview

Freeze the public contract before behavior changes: risk fields, receipt schema,
subject fingerprints, shared state-root ownership, auto-active lifecycle,
backward compatibility, and failure codes. Add executable contract tests so
later phases cannot silently reinterpret the design.

## Requirements

### Functional

- Document exact card-risk, receipt, fingerprint, and auto-state schemas.
- Define which commands mint, read, require, and invalidate receipts.
- Define worktree/main-state ownership without requiring Python.
- Define legacy behavior for cards without risk metadata and projects without
  receipt state.
- Make cross-plan supersession bidirectional and explicit.

### Non-functional

- Closed vocabularies; no generalized policy DSL.
- All persisted values single-line, bounded, CRLF-normalized, and
  duplicate-key-rejected.
- Fingerprints are stale-detection only, never actor authentication.
- No behavior flip or version bump in this phase.

## Architecture

### Contract files

Create one focused reference:

`skills/flow/references/attestations.md`

It owns:

1. Risk field grammar.
2. Receipt grammar and canonical key order.
3. Subject projection/fingerprint algorithms.
4. Auto-active state lifecycle.
5. Error/exit behavior and manual degradation.
6. Security limits and rollback.

`SKILL.md`, `auto-run.md`, `gate-rules.md`, and
`ground-truth-gates.md` link to this reference rather than duplicating the full
schema.

### Card risk grammar

```text
risk: standard|security-class|unknown
risk-reason: <single line, 1..256 bytes once classified>
risk-ack: none|git:<full repository object id>
```

Rules:

- Missing legacy fields normalize to `unknown`, empty reason, `none`.
- `standard` requires a non-placeholder reason and `risk-ack: none`.
- `security-class` requires a non-placeholder reason; auto additionally
  validates `risk-ack`.
- `unknown` requires `risk-ack: none`.
- Duplicate fields are invalid, not “last value wins”.

### Committed producer manifests

Semantic and live passes cannot be minted from arbitrary caller-supplied
verdict/argv alone. Cards and Stage 05 reference a committed, repo-relative
owner manifest:

```text
schema: flow-attestation-owner/v1
kind: semantic_gate|live_verify
subject_id: <closed stage name or C-NNN>
target_id: none|<lowercase [a-z0-9._-], 1..64 bytes>
command: repo:<repo-relative executable>
revision_oracle: none|repo:<repo-relative executable>
```

Rules:

- `semantic_gate` requires `target_id: none` and `revision_oracle: none`.
- `live_verify` requires a non-`none` target and revision oracle.
- Both executable paths must be tracked regular files at `subject_revision`,
  stay inside the project, have stable object/mode identity, and be invoked
  directly without shell re-parsing.
- `owner_fingerprint` hashes a canonical manifest of the owner file plus its
  command object/mode; for live owners it also includes the oracle object/mode.
- The semantic producer emits one strict bounded result document containing the
  exact subject fingerprint, verdict, finding counts, and evidence reference.
  The runner verifies that document before minting the receipt.
- The live revision oracle emits exactly one full repository-format OID that
  must equal the requested deployed revision before the probe may pass.
- Target-defining values must be manifest/argv data. Inherited environment may
  supply credentials but must not choose the deployment target.
- These manifests make producer inputs reproducible; unsigned files and Git
  labels remain non-cryptographic and forgeable by a hostile filesystem owner.

Runner-constructed argv is fixed:

```text
<command> --subject-id <id> --subject-revision <oid> --subject-fingerprint <fp>
<revision_oracle> --subject-id <id> --subject-revision <oid> --target-id <target>
```

No manifest arguments or caller suffix are permitted. Semantic stdout is exactly:

```text
schema: flow-semantic-result/v1
subject_fingerprint: <exact requested fingerprint>
verdict: pass|fail
critical_count: <0..999>
high_count: <0..999>
evidence_ref: none|repo:<relative-path>
```

`pass` requires both counts zero. `override` is never producer output; the
runner constructs it only after validating the separate DEBT override contract.

Scalar grammar shared by receipts/auto state:

- `actor`, `engine`, `activated_by`:
  `[A-Za-z0-9][A-Za-z0-9._@/-]{0,127}`;
- `evidence_ref`: `none` or `repo:<normalized relative path>`, maximum 256
  UTF-8 bytes, no `.`/`..`/empty segment or symlink escape;
- `target_id`: `[a-z0-9][a-z0-9._-]{0,63}`;
- all absent optional references use literal `none`;
- timestamps are UTC `YYYY-MM-DDTHH:MM:SSZ`; integers reject signs, spaces,
  leading plus, and overflow.

### DEBT acknowledgement grammar

Auto recognizes only exact open-line prefixes:

```text
- [ ] DEBT: security-class C-NNN -- <bounded reason> -- close before: <condition>
- [ ] DEBT: semantic-override <00-idea|01-research|02-scope|03-prd|04-adr|05-contract|C-NNN> -- <bounded reason> -- close before: <condition>
```

The referenced commit must be an integration ancestor. The matching line must
exist in that commit’s monorepo-aware `DEBT.md` blob, and `git blame` at that
commit must yield a non-empty author identity distinct from the executing Git
identity. Missing, ambiguous, or same identity is not accepted by auto.

Exactly one matching DEBT line is allowed. Compare the matching line’s
`author-mail` from `git blame --line-porcelain <commit> -L n,n` with the email
from `git var GIT_AUTHOR_IDENT`; trim angle brackets/whitespace and compare
lowercase. Missing/multiple/same values fail closed. Git identity remains
forgeable by a repository/config owner and is not presented as authentication.

### Receipt paths

```text
<main-state-root>/.flow/attestations/
  semantic_gate/stage-05-contract.receipt
  semantic_gate/card-C-001.receipt
  live_verify/card-C-001.receipt
```

Atomic write: temp file created in the destination directory, permissions
restricted, fsync/best-effort where portable, then same-filesystem rename.

### Subject projections

| Subject | Canonical projection |
|---|---|
| Stage semantic | Exact committed Git blob bytes; no excluded sections |
| Card semantic | `deps`, `implements`, risk fields, Scope, Allowed files, Verify, Done-evidence + base/head/tree object IDs |
| Card live verify | Verify + Done-evidence + committed owner manifest + target ID + deployed revision + exact executed argv fingerprint |

Mutable `status` and `Evidence` are excluded from card projections so recording
world-state proof after review does not invalidate a still-current review.

Kind-specific receipt metadata is part of the closed schema:

- all kinds: `owner_ref`, `owner_fingerprint`;
- stage semantic: `subject_revision`;
- card semantic: `subject_base`, `subject_revision`, `subject_tree`;
- card live verify: `subject_revision`, `command_fingerprint`,
  `result_code`, `result_fingerprint`, `duration_ms`, `target_id`,
  `revision_oracle_ref`, `revision_oracle_fingerprint`.

`result_code` is exactly
`exit:<0..255>|timeout|output-cap|signal:<1..64>|spawn-error`.
`result_fingerprint` excludes command output and hashes only canonical outcome
metadata. `duration_ms` is an integer and may be second-resolution multiplied
by 1000 when no portable high-resolution clock exists.

Card semantic revalidation accepts either the original clean review worktree or
an ancestry-preserving integrated revision whose current contract projection
still matches the reviewed commit and whose reviewed changed-path manifest
(`subject_base..subject_revision`, excluding the card markdown path) has
identical object/mode entries at the integrated revision. The card path is
validated by canonical projection instead. Squash/rebase, conflict resolution,
or later edits to a reviewed code/config path require a new receipt.

Cleanliness excludes only the skill-owned `.flow/` state and the mutable
`status`/`Evidence` projection fields written by the CLI. All other tracked,
index, and untracked changes fail closed. Implementations must not mutate a
tracked `.gitignore` to achieve this exclusion.

### Main state-root resolution

The Bash resolver must match the durable Python resolver’s intent:

1. Explicit `FLOW_PROJECT_ROOT` remains the project root.
2. Determine Git worktree top and first/main worktree.
3. Translate a linked worktree subpath to the equivalent main-worktree subpath.
4. Refuse unsafe translation for submodules or `--separate-git-dir`; use the
   current root and report that receipts are local to that checkout.
5. Never place `.flow` state inside Git internals.

## File inventory

| Action | File | Intended change | Rough size | Test impact |
|---|---|---|---:|---|
| Create | `/home/manhquy/Downloads/flow-skill/skills/flow/references/attestations.md` | Canonical v0.28 risk/receipt/auto contract | 180-260 LOC | New contract test |
| Create | `/home/manhquy/Downloads/flow-skill/tests/test_flow_attestation_contract.sh` | Static grammar/link/schema invariants | 120-180 LOC | Register in `run_all.sh` |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/run_all.sh` | Register contract suite in the same change | <5 LOC | Full suite count changes |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/SKILL.md` | Link contract; no enforcement claim yet | 10-20 LOC | Docs contract |
| Modify | `/home/manhquy/Downloads/flow-skill/plans/260726-1718-harness-graph-executor-langgraph-port/plan.md` | Keep supersession notice/dependency coherent | <20 LOC | Plan validation only |

## Interface checklist

- [ ] `risk`, `risk-reason`, `risk-ack` grammar has one owner.
- [ ] Receipt required and optional keys are enumerated.
- [ ] `actor`, `engine`, `activated_by`, `evidence_ref`, `target_id`, and
  placeholder grammars are byte-bounded and closed.
- [ ] Duplicate/unknown key policy is explicit.
- [ ] Subject IDs are closed: six stage names or normalized `C-NNN`.
- [ ] Fingerprint object-format behavior covers SHA-1 and SHA-256 repositories.
- [ ] Dirty/untracked behavior is explicit and fail-closed in auto.
- [ ] Owned `.flow` state and CLI-owned card fields cannot self-invalidate an
  otherwise current receipt.
- [ ] Semantic/live pass producers are committed manifests, not arbitrary
  caller verdicts or commands.
- [ ] Owner/oracle refs and object fingerprints are revalidated for currentness.
- [ ] Manual warning behavior is distinct from auto hard failure.
- [ ] Auto state activation/stop/cross-session lifecycle is defined.
- [ ] Security acknowledgement proof and residual identity limit are explicit.
- [ ] Contract distinguishes v0.28’s fail-closed auto identity rule from the
  graph executor’s existing audit-only `author_distinct` field.

## Dependency map

```text
existing runner + graph/harness evidence
                 |
                 v
attestations.md contract
       |         |          |
       v         v          v
  phase 2     phase 3    phase 4
  harness      risk      receipts
```

## Test scenario matrix

| Priority | Scenario | Expected |
|---|---|---|
| Critical | Receipt schema omits required key | Contract test fails |
| Critical | Receipt schema permits duplicate keys | Contract test fails |
| Critical | Card semantic projection includes mutable Evidence/status | Contract test fails |
| Critical | Semantic pass accepts caller verdict without owner manifest | Contract test fails |
| Critical | Live pass lacks target ID or revision oracle | Contract test fails |
| High | Docs call fingerprints actor authentication | Contract test fails |
| High | Docs require Python to read/validate receipt | Contract test fails |
| High | Old graph plan still directs Python mandatory/default-on | Plan consistency fails |
| Medium | Public docs copy full schema instead of linking owner | Duplication grep fails |

## Implementation steps

1. Write `attestations.md` from plan decisions D1-D13.
2. Specify exact CLI shapes without implementing them:
   - `flow attest semantic --stage <stage> --revision <rev> --owner <manifest>`
   - `flow attest semantic --card <id> --base <rev> --revision <rev> --owner <manifest>`
   - `flow attest live-verify <id> --revision <rev> --owner <manifest>`
   - `flow attest status [<stage|card>]`
   - `flow attest recover <C-NNN> --mark-failed`
   - `flow auto stop`
3. Specify exact exit behavior:
   - `0` valid/pass,
   - `1` missing/stale/red policy result,
   - `2` invalid usage/schema,
   - timeout remains non-zero and never pass.
4. Specify latest-assessment behavior: create a fail-closed attempt marker
   before live spawn; valid semantic red and terminal live red atomically
   replace older pass; writers and hard-boundary consumers share the same
   subject lock; invalid invocation does not mutate receipt state.
5. Write static contract tests before later implementation.
6. Register the suite in `tests/run_all.sh`.
7. Confirm the old graph plan is blocked/superseded without changing shipped
   source or completed releases.
8. Run focused contract test and `ak plan validate`.

## Todo

- [ ] Canonical contract reference written
- [ ] Static contract suite registered
- [ ] Cross-plan notice verified two-way
- [ ] No behavior/version changes included

## Success criteria

- [ ] One canonical, unambiguous schema owner exists.
- [ ] Later phases can implement without choosing new field names or lifecycle
  semantics.
- [ ] Contract tests fail on every forbidden ambiguity above.
- [ ] Cross-plan conflict is resolved without reverting graph functionality.

## Risk assessment

| Risk | Mitigation |
|---|---|
| Contract too broad becomes policy engine | Only three risk values, two receipt kinds, one auto state |
| Worktree translation repeats prior drift | Contract requires parity fixtures against `_db.py`; unsafe shapes refuse translation |
| Receipt claims stronger security than delivered | Explicit stale-detection/non-authentication statement |

## Security considerations

- Treat every persisted scalar as attacker-adjacent text.
- Do not include command output or prompts in the schema.
- Path references must be repo-relative, traversal-free, and bounded.

## Rollback

Revert reference/test/link changes. No runtime or persisted state exists yet.

## Next steps

Phases 2 and 3 may start after this contract is green.

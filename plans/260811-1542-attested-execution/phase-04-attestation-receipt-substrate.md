---
phase: 4
title: "Attestation receipt substrate"
status: completed
priority: P1
effort: "2-3d"
dependencies: [1, 2]
---

# Phase 4: Attestation receipt substrate

## Context links

- [Plan overview](./plan.md)
- [Phase 1 contract](./phase-01-contract-freeze.md)
- [Phase 2 attestation execution hygiene](./phase-02-harness-verification-authority-and-redaction.md)
- `skills/flow/runner/flow.sh:19-122,178-299,302-359,395-423,1240-1363,4048-4092`
- `skills/flow/harness/_db.py:35-122`
- `skills/flow/harness/graph_executor.py:72-103,137-165,304-328`
- `tests/test_flow_graph_parallel_cards.sh:39-56,131-142,173-197`
- `skills/flow/references/ground-truth-gates.md:1-39`

## Overview

Implement the standalone receipt library and `flow attest` command surface.
Receipts are atomic files under the shared main state root. Bash can mint,
parse, fingerprint, and validate them without Python; optional durable logging
is best-effort and never participates in gate decisions.

## Requirements

### Functional

- Add `runner/attestations.sh` as the single owner of:
  - main state-root resolution;
  - card/stage projection;
  - Git object-format fingerprints;
  - strict receipt parsing/validation;
  - atomic writes/private modes;
  - live command execution metadata;
  - auto-state read/write primitives used in Phase 5.
- Add `flow attest semantic`, `flow attest live-verify`, and
  `flow attest status`.
- `semantic` supports stage and card subjects.
- Stage/card semantic mint executes the exact committed review-owner manifest;
  caller-supplied labels/verdicts cannot mint pass.
- Stage semantic mint requires a clean tracked artifact at a committed revision.
- Card semantic mint requires a clean committed subject and explicit base/head.
- `live-verify` executes the committed owner manifest, first requires its
  revision oracle to return the exact deployed OID, then mints pass only for a
  successful bounded probe against the manifest target.
- Reading a receipt recomputes the current subject fingerprint and reports
  `current|missing|stale|invalid|red`.
- Currentness also revalidates the committed owner/oracle refs and their exact
  object/mode fingerprints recorded in the receipt.

### Non-functional

- Bash 3.2 compatible; Git Bash compatible; no jq/Python requirement.
- Receipt mint/currentness requires Git; non-Git callers receive an actionable
  unsupported result without breaking ordinary manual gates.
- No raw command output, prompts, environment, secrets, full argv, or absolute machine
  paths in receipts.
- All file paths quoted; no eval.
- No receipt DB migration in v0.28 ship bar.

## Architecture

### Library boundary

`flow.sh` sources `runner/attestations.sh` before dispatch. The library expects
the runner’s resolved `ROOT` and exposes only `_att_*` helpers plus
`cmd_attest`.

This split avoids adding several hundred security-sensitive lines to the
already large runner while keeping the installed bundle standalone.

### Shared main state root

```text
current project root
   -> non-git / main worktree -----------------> ROOT/.flow
   -> linked worktree + safe main mapping -----> MAIN_EQUIV/.flow
   -> submodule/separate-git-dir ambiguity ----> ROOT/.flow + explicit warning
```

Parity test compares Bash and `_db.default_db_path()` owners where Python is
available; no-Python tests prove Bash independently.

`.flow/` is skill-owned state and is excluded explicitly from Git cleanliness
checks. The implementation must not edit `.gitignore`; linked worktrees whose
`.git` is a file receive the same behavior.

### Fingerprint algorithms

#### Stage

1. Validate stage against the closed set.
2. Resolve the requested revision to a full commit and require Git cleanliness
   for the tracked artifact; do not compare host-normalized checkout bytes.
3. Resolve the exact committed blob object ID for the stage path; do not
   normalize CRLF or hash a host-specific checkout representation.
4. Prefix with repository object format and record `subject_revision`.

#### Card semantic

1. Require Git repo, explicit base revision, explicit/default head revision.
2. Require worktree/index clean, including untracked files. No “ignore
   untracked” escape in auto.
3. Extract canonical card-contract projection.
4. Resolve full base commit, head commit, head tree.
5. Record a sorted changed-path manifest for `base..head` containing path,
   object ID, and mode, excluding the subject card markdown path (covered by
   canonical projection).
6. Hash canonical manifest through `git hash-object --stdin`.
7. Record `subject_base`, `subject_revision`, and `subject_tree`.

Currentness is context-aware:

- before merge, current clean worktree HEAD/tree must equal the reviewed
  revision/tree;
- after an ancestry-preserving merge, the reviewed revision must be an
  ancestor of integration HEAD and the current card-contract projection must
  equal the reviewed revision’s projection; every reviewed changed path must
  retain the same object/mode at integration HEAD;
- conflict resolution or later integration edits to a reviewed code/config path
  are stale; status/Evidence-only card commits remain current;
- squash/rebase or contract drift is stale and requires a new receipt.

#### Live verify

1. Resolve deployed revision to full commit; require the reviewed card revision
   is its ancestor and reviewed changed-path objects/modes survive there.
2. Load the exact committed live-owner manifest; validate tracked executable
   objects, target ID, probe, and revision-oracle paths.
3. Run the oracle under the Phase 2 supervisor. Its only accepted stdout is one
   full OID equal to deployed revision; otherwise write terminal fail.
4. Extract Verify + Done-evidence + owner manifest projection.
5. Fingerprint exact runner-constructed argv boundaries without shell
   re-parsing. Target identity is explicit; inherited environment cannot choose
   a target.
6. Before spawn, atomically write an attempt marker under the subject lock.
7. Stream output with byte caps; own the process group; on timeout/cap/signal,
   TERM then KILL and wait for descendants before terminal publication.
8. Hash canonical outcome metadata and byte counts, never output bytes.
9. Atomically replace marker/older receipt with terminal result; mint `pass`
   only on oracle match, probe exit 0, no timeout, and no cap breach.

### Strict receipt parser

- Read at most a bounded file size.
- Exact `key: value` lines only.
- Reject blank keys, unknown keys, duplicates, missing keys, multiline values,
  invalid order if canonical order is required, NUL/control characters, and
  oversized values.
- Validate evidence path with repo containment; store repo-relative spelling.
- Never source/eval receipt content.

### Atomicity and concurrency

- One latest file per `(kind, subject_type, subject_id)`.
- Acquire a same-subject lock before semantic mint, live execution, or a hard
  transition consuming that subject. Hard consumers hold it from validation
  through graph/harness/removal side effects.
- Hard consumers also hold the auto-policy lock from state validation through
  those side effects, so `auto stop`/refresh cannot race a partially authorized
  transition.
- Lock order is: shared auto-policy lock, then subject locks sorted by
  `(subject_id, kind)`, then existing runner/workspace mutation lock. A caller
  that already holds a later lock must release and reacquire in this order.
- Write temp in destination, `chmod 600` best-effort, then `mv`.
- Auto/check callers read one snapshot while holding the subject lock.
- Before live spawn, write
  `.flow/attestations/live_verify/card-C-NNN.attempt` with bounded nonce/PID/start
  metadata. Consumers reject any marker. A later invocation may auto-recover
  only when the same-host PID/start identity is provably dead, first publishing
  a fail result, then starting anew. Ambiguous/cross-host markers require
  Must-ask `flow attest recover C-NNN --mark-failed`, which writes fail before
  clearing the marker; it never restores green.
- Concurrent writes across different subjects remain independent. No append log
  participates in the gate path.
- A valid semantic `fail` replaces an older semantic pass.
- Once a valid live attempt starts, latest attempt wins: timeout, cap breach,
  signal, spawn failure, or non-zero result atomically replaces an older pass
  with `fail`. Usage/schema rejection before execution leaves the prior receipt
  untouched.

## File inventory

| Action | File | Intended change | Rough size | Test impact |
|---|---|---|---:|---|
| Create | `/home/manhquy/Downloads/flow-skill/skills/flow/runner/attestations.sh` | State root, fingerprints, receipts, live execution | 350-500 LOC | Dedicated suite |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/runner/flow.sh` | Source library, dispatch/help/log classification | 20-45 LOC | Runner/concierge |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/references/attestations.md` | Final CLI examples and failure table | 30-60 LOC | Contract suite |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/references/command-dispatch.md` | Must-ask classification for minting; status may-run | 10-20 LOC | Concierge contract |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/references/ground-truth-gates.md` | Receipts as auto ground-truth keys | 15-25 LOC | Docs contract |
| Create | `/home/manhquy/Downloads/flow-skill/tests/test_flow_attestations.sh` | Parser, hash, stale, worktree, command execution | 320-480 LOC | Register in run_all |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/test_flow_concierge.sh` | New verb classification | 10-20 LOC | Focused |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/test_flow_monorepo_root.sh` | Main-state root parity/subproject ownership | 20-50 LOC | Focused |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/run_all.sh` | Register suite | <5 LOC | Full |

## Interface checklist

- [ ] `attest semantic --stage` rejects card-only flags.
- [ ] `attest semantic --card` requires base/head identity.
- [ ] Both semantic and live commands require a committed owner manifest.
- [ ] `attest live-verify` accepts no caller-defined command after `--`.
- [ ] No command string is passed through `eval` or `sh -c`.
- [ ] Repository object format is recorded and verified.
- [ ] Untracked files are included in the dirty guard.
- [ ] `.flow` and CLI-owned status/Evidence are the only documented dirty
  exclusions.
- [ ] Evidence refs cannot escape project root.
- [ ] Receipt parser never sources the file.
- [ ] Worktree/main state owner matches Python resolver on supported shapes.
- [ ] Separate-git-dir/submodule behavior is explicit, safe, and tested.
- [ ] Failed live executions overwrite a current pass with latest-attempt red;
  invalid invocation before execution does not mutate the prior receipt.
- [ ] Unresolved live attempt marker blocks every hard consumer.
- [ ] Attempt recovery can only publish fail; ambiguous owners require explicit
  Must-ask recovery.
- [ ] Semantic fail overwrites semantic pass, and same-subject concurrency
  cannot reorder final state.

## Dependency map

```text
phase 1 schema -----------------------------+
phase 2 timeout/redaction ------------------+--> attestations.sh
existing git/worktree helpers --------------+       |
                                                     +--> semantic receipts
                                                     +--> live receipts
                                                     +--> status/currentness
                                                     +--> phase 5 enforcement
```

## Test scenario matrix

| Priority | Scenario | Expected |
|---|---|---|
| Critical | Duplicate `verdict` with pass last | Invalid; cannot forge |
| Critical | Receipt contains shell payload/path traversal | Parsed as invalid; never executed/read outside root |
| Critical | Edit stage after semantic pass | Receipt stale |
| Critical | Edit card Scope/Allowed files/Verify after review | Receipt stale |
| Critical | Edit or replace semantic/live owner or revision oracle | Receipt stale |
| Critical | Edit only Evidence/status | Semantic receipt remains current |
| Critical | Dirty tracked or untracked card worktree | Semantic mint refuses |
| Critical | Live command exits non-zero | No pass receipt |
| Critical | Live command times out/output exceeds cap | No pass receipt; temp/process cleanup |
| Critical | Live owner runs `true` but card owner manifest names another probe | Refuse before execution |
| Critical | Revision oracle reports another deployment OID | Terminal fail; no pass |
| Critical | Runner SIGKILL after spawn with old pass present | Attempt marker blocks old pass |
| Critical | PID reused or marker came from another host | No auto-reclaim; explicit recovery publishes fail |
| Critical | Consumer validates pass while concurrent fail waits | Consumer lock serializes transition and writer |
| Critical | Current pass followed by failed valid attempt | Receipt becomes red; another successful run is required |
| Critical | Invalid invocation while a pass exists | Exit 2; existing receipt remains intact |
| Critical | Two same-subject attempts overlap | Second is refused or serialized; older slow completion cannot win later |
| High | SHA-256 Git repository | Correct object-format prefix and validation |
| High | Two linked worktrees mint different cards concurrently | Both receipts land in one main state root |
| High | Receipt/event command contains opaque secret/private endpoint | Neither receipt nor project/global event log contains it |
| High | Checkout has no `.gitignore` and receipt already exists | `.flow` does not make subject dirty |
| High | Relative/absolute evidence ref tricks | Reject traversal/absolute paths |
| High | Python absent | Mint/read/status still work |
| Medium | CRLF receipt | Deterministic policy: accept normalized or reject consistently |
| Medium | Interrupted atomic write | Old complete receipt remains readable; no partial file accepted |

## Implementation steps

1. Add parser/fingerprint/state-root tests before library code.
2. Create `attestations.sh`; keep helpers namespaced and no side effects on
   source.
3. Implement conservative state-root resolver and parity fixtures.
4. Implement canonical projection extractors and Git-object fingerprints.
5. Implement strict receipt parser and currentness validator.
6. Implement atomic writer and permissions.
7. Implement semantic mint commands.
8. Implement committed semantic/live owner execution, revision oracle, target
   identity, attempt marker, and Phase 2 supervisor integration.
9. Implement subject lock consumption helpers and explicit lock ordering.
10. Wire `cmd_attest`, fail-only recovery, help, privacy-safe logging, and
    concierge classification.
11. Add docs/examples and run ShellCheck if configured; do not introduce it as
    a new release dependency.
12. Run dedicated suite, graph/worktree/monorepo/runner suites, no-Python
    degradation, then full suite.

## Todo

- [ ] State-root resolver + parity tests
- [ ] Strict parser + atomic writer
- [ ] Stage/card semantic fingerprints
- [ ] Live argv execution + result fingerprint
- [ ] CLI/help/docs wired
- [ ] Focused/full/no-Python tests green

## Success criteria

- [ ] Receipts are validatable with Bash and Git only.
- [ ] Every subject mutation described above produces the correct
  current/stale result.
- [ ] No raw output or secret-shaped content persists.
- [ ] Worktree receipts survive worktree removal on supported linked-worktree
  layouts.

## Risk assessment

| Risk | Mitigation |
|---|---|
| Bash parser injection | Never source/eval; exact key allowlist; size/control-char guards |
| Fingerprint collisions from ambiguous concatenation | Canonical manifest with explicit boundaries, then Git object hash |
| Worktree state split | Conservative resolver + Python parity + linked-worktree concurrency tests |
| Live timeout leaves process | Process-group TERM/KILL/wait; unsupported supervisor refuses |
| Receipt writer/consumer race | Same subject lock spans validation and irreversible side effects |
| Interrupted run preserves old pass | Pre-spawn attempt marker is fail-closed |

## Security considerations

- Actor/engine fields are labels, not identity proofs.
- Parser/fingerprint checks detect malformed or subject-inconsistent receipts;
  they cannot detect a filesystem writer that fabricates a complete unsigned
  receipt. v0.28 is a workflow-integrity layer, not a hostile-host boundary.
- Never persist environment values or raw verification output.

## Rollback

Stop auto mode before reverting Phase 4/5. Older runners ignore
`.flow/attestations`. Removing receipt state is safe but loses audit history.

## Next steps

Phase 5 consumes only the public validation helpers; it must not duplicate
receipt parsing or fingerprint logic.

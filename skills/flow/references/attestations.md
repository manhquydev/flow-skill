# Attestations — risk, receipts, and auto trust (v0.28)

Canonical owner for **card risk**, **attestation receipts**, **subject
fingerprints**, and **auto-active policy state**. Other docs link here; do not
duplicate full schemas.

Fingerprints detect **staleness** of a reviewed/verified subject. They do **not**
authenticate a human or model. Actor/engine labels and unsigned receipt files
are forgeable by a filesystem/repository owner. This layer is workflow integrity,
not a hostile-host or cryptographic identity boundary.

## Risk fields (card markdown)

```text
risk: standard|security-class|unknown
risk-reason: <single line, 1..256 bytes once classified>
risk-ack: none|git:<full repository object id>
```

Rules:

- Missing legacy fields normalize to `unknown`, empty reason, `none` (compat).
- Duplicate anchored fields are **invalid** (not last-wins).
- `standard` requires a non-placeholder reason and `risk-ack: none`.
- `security-class` requires a non-placeholder reason; auto validates `risk-ack`.
- `unknown` requires `risk-ack: none`.
- New cards scaffold `risk: unknown` / empty reason / `risk-ack: none`.

### Security acknowledgement (auto only)

`risk-ack: git:<full-oid>` is accepted only when:

1. OID shape matches repository object format (`sha1` or `sha256`).
2. Commit exists and is an ancestor of current integration `HEAD`.
3. `git show <oid>:<project-prefix>DEBT.md` succeeds.
4. The blob contains exactly one open line beginning
   `- [ ] DEBT: security-class <card-id> --`.
5. `git blame --line-porcelain` at that commit yields `author-mail` **distinct**
   (normalized lowercase, no angle brackets) from `git var GIT_AUTHOR_IDENT`.
6. Missing / ambiguous / same identity → fail closed for auto.

Residual: Git identity is forgeable by a repository/config owner.

### Semantic override (auto, semantic_gate only)

`verdict: override` requires an ancestor DEBT open line:

```text
- [ ] DEBT: semantic-override <00-idea|01-research|02-scope|03-prd|04-adr|05-contract|C-NNN> -- <reason> -- close before: <condition>
```

Same author-distinct rule as security-class. Auto never accepts
`live_verify: override`.

## Committed producer manifests

Pass cannot be minted from caller-supplied verdict/argv alone. Subjects reference
a committed, repo-relative owner:

```text
schema: flow-attestation-owner/v1
kind: semantic_gate|live_verify
subject_id: <closed stage name or C-NNN>
target_id: none|<lowercase [a-z0-9._-], 1..64 bytes>
command: repo:<repo-relative executable>
revision_oracle: none|repo:<repo-relative executable>
```

- `semantic_gate`: `target_id: none`, `revision_oracle: none`.
- `live_verify`: non-`none` target and revision oracle.
- Executables must be tracked regular files at `subject_revision`, inside the
  project, stable object/mode, invoked directly (no shell re-parse).

Runner-constructed argv only:

```text
<command> --subject-id <id> --subject-revision <oid> --subject-fingerprint <fp>
<revision_oracle> --subject-id <id> --subject-revision <oid> --target-id <target>
```

Semantic producer stdout (strict):

```text
schema: flow-semantic-result/v1
subject_fingerprint: <exact requested fingerprint>
verdict: pass|fail
critical_count: <0..999>
high_count: <0..999>
evidence_ref: none|repo:<relative-path>
```

`pass` requires both counts zero. `override` is never producer output.

Live revision oracle stdout: exactly one full repository-format OID equal to the
requested deployed revision.

## Receipt schema (`flow-attestation/v1`)

Path layout under main state root:

```text
<main-state-root>/.flow/attestations/
  semantic_gate/stage-05-contract.receipt
  semantic_gate/card-C-001.receipt
  live_verify/card-C-001.receipt
  live_verify/card-C-001.attempt
```

Required keys, **canonical order**, single-line `key: value`:

```text
schema: flow-attestation/v1
kind: semantic_gate|live_verify
subject_type: stage|card
subject_id: <closed stage name or C-NNN>
subject_fingerprint: git-<sha1|sha256>:<object-id>
verdict: pass|fail|override
actor: <sanitized, <=128 bytes>
engine: <sanitized, <=128 bytes>
evidence_ref: none|repo:<relative-path>
timestamp: <UTC YYYY-MM-DDTHH:MM:SSZ>
override_ref: none|git:<full-object-id>
owner_ref: repo:<repo-relative owner manifest>
owner_fingerprint: git-<sha1|sha256>:<object-id>
```

Kind-specific (also required when present):

- stage `semantic_gate`: `subject_revision`
- card `semantic_gate`: `subject_base`, `subject_revision`, `subject_tree`
- `live_verify`: `subject_revision`, `command_fingerprint`, `result_code`,
  `result_fingerprint`, `duration_ms`, `target_id`, `revision_oracle_ref`,
  `revision_oracle_fingerprint`

`result_code` closed set:
`exit:<0..255>|timeout|output-cap|signal:<1..64>|spawn-error`.

`result_fingerprint` hashes outcome metadata (status, byte counts, argv digest,
duration bucket) — **never** stdout/stderr bytes.

Parser rules:

- Reject blank/unknown keys, duplicates, missing required keys, multiline
  values, NUL/control chars, oversized values, path traversal.
- Never source/eval receipt content.
- CRLF normalized on read.
- Invalid CLI/schema input does **not** overwrite an existing receipt.

Atomic write: temp in destination dir → `chmod 600` best-effort → rename.
Latest assessment wins: valid semantic `fail` and terminal live red replace
older `pass`. Pre-spawn live attempt marker is fail-closed until dead-owner
recovery or Must-ask `flow attest recover C-NNN --mark-failed`.

### Scalar grammar

- `actor` / `engine` / `activated_by`:
  `[A-Za-z0-9][A-Za-z0-9._@/-]{0,127}`
- `evidence_ref`: `none` or `repo:<normalized relative path>`, ≤256 UTF-8 bytes,
  no `.` / `..` / empty segment / symlink escape
- `target_id`: `[a-z0-9][a-z0-9._-]{0,63}`
- Absent optional refs use literal `none`
- Integers: no signs, spaces, leading plus, or overflow
- Subject IDs: six stage names
  (`00-idea`…`05-contract`) or normalized `C-NNN`

## Subject projections and fingerprints

| Subject | Canonical projection |
|---|---|
| Stage semantic | Exact committed Git blob bytes for the stage path |
| Card semantic | `deps`, `implements`, risk fields, Scope, Allowed files, Verify, Done-evidence + base/head/tree OIDs |
| Card live | Verify + Done-evidence + owner manifest + target + deployed revision + argv digest |

Mutable `status` and `Evidence` are **excluded** from card semantic projection
so CLI-owned completion updates do not invalidate a still-current review.

Cleanliness for mint/consume (auto):

- Fail closed on dirty tracked, index, or untracked files **except** skill-owned
  `.flow/` run-state and CLI-owned card `status`/`Evidence` projection fields.
- Do **not** mutate `.gitignore` to achieve cleanliness.

### Stage fingerprint

1. Validate stage name against closed set.
2. Resolve revision to full commit; require clean tracked artifact.
3. Blob OID for stage path at that commit; prefix `git-<format>:`.

### Card semantic fingerprint

1. Git repo + explicit base + head.
2. Clean worktree including untracked (with `.flow` / status-Evidence exclusions).
3. Canonical card-contract projection + base/head/tree OIDs + sorted
   changed-path manifest (`base..head`, excluding card markdown path).
4. Hash via `git hash-object --stdin`.

Currentness after ancestry-preserving merge: reviewed revision is ancestor of
integration HEAD; projection still matches; every reviewed changed path
(except card md) has same object/mode at HEAD. Squash/rebase or code-path edit
→ stale.

### Live fingerprint

Deployed revision + Verify/Done-evidence projection + owner/oracle object/mode
+ target + argv digest. Oracle must return exact deployed OID before probe may
pass.

## Auto-active state

```text
<main-state-root>/.flow/auto-state
```

```text
schema: flow-auto/v1
status: active
activated_at: <UTC RFC3339>
activated_by: <sanitized <=128>
integration_branch: <validated branch name>
risk_fingerprint: git-<sha1|sha256>:<object-id>
contract_fingerprint: git-<sha1|sha256>:<object-id>
```

Activation (`flow auto`) requires, atomically after full preflight:

- Git repo; main worktree on attached integration branch (linked/detached refuse)
- Reliable process-group supervisor capability (else refuse live auto)
- Planning complete + ≥1 card
- Full risk set valid (no `unknown`, valid security ack)
- Current accepted Stage 05 `semantic_gate` receipt

Card/live receipts are later transition gates, not activation prerequisites.
`flow auto stop` clears state. Status/resume show `INACTIVE|ACTIVE|STALE|INVALID`.

### Enforcement matrix

| Boundary | Auto inactive | Auto active/current | Auto stale/invalid |
|---|---|---|---|
| `next` | Warn on stage receipt | Warn only | Warn only |
| `check` todo | Warn | Require card semantic pass/override | Block |
| `check` done | Warn | Semantic + live pass | Block |
| `card done` | Existing + warn | Same hard checks; validate before status mutation | Block |
| `ready` | Existing + advisory | Done deps need both receipts | No BUILDABLE; non-zero |
| merged `workspace remove` | Warn | Both receipts | Block |
| unmerged remove | Existing abandon | Allow without receipts | Allow |

No hidden bypass flag. Manual continuation: `flow auto stop`.

## Main state-root resolution

Bash must match Python `_db.default_db_path` intent:

1. Explicit `FLOW_PROJECT_ROOT` is project root.
2. Resolve Git worktree top + first/main worktree.
3. Linked worktree subpath → equivalent main-worktree subpath.
4. Submodule / `--separate-git-dir` ambiguity → current root + local receipts
   warning; never place `.flow` inside Git internals.
5. Receipts readable without Python.

## CLI surface

```text
flow attest semantic --stage <stage> --revision <rev> --owner <manifest>
flow attest semantic --card <id> --base <rev> --revision <rev> --owner <manifest>
flow attest live-verify <id> --revision <rev> --owner <manifest>
flow attest status [<stage|card>]
flow attest recover <C-NNN> --mark-failed
flow auto
flow auto stop
```

Exit codes:

- `0` — valid / pass / current accepted
- `1` — missing / stale / red policy result
- `2` — invalid usage / schema
- Timeout / cap / signal → non-zero; never pass

## Process supervisor (attestation only)

Argv-safe: fixed cwd = logical checkout root, process group ownership,
streaming stdout/stderr independent + combined caps, TERM → grace → KILL → wait.
Capability probe: if reliable process-group supervisor unavailable, live
verification and auto activation fail closed (never unbounded fallback).

Usage/event logs for attestation record only subcommand, subject ID, result
class, duration bucket — never argv after `--`, raw output, or secrets.

## Locks

Order: shared auto-policy mutex → subject locks sorted by `(subject_id, kind)`
→ existing runner/workspace mutation lock.

Hard consumers hold locks from validation through irreversible side effects
(graph/harness/removal).

## Backward compatibility

- Manual/teach/work without auto state: warnings only; pre-v0.28 exit codes.
- Planning `next` never hard-enforced in v0.28.
- Bash + Git floor; Python/SQLite optional and never required to parse receipts.
- Harness `risk_lane` remains separate advisory taxonomy (no silent sync).

## Rollback

`flow auto stop`, then revert enforcement. Receipt files under `.flow/` are
run-state; remove for audit loss only — does not corrupt cards/DB.

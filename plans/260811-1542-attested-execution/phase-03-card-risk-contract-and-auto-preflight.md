---
phase: 3
title: "Card risk contract and auto preflight"
status: completed
priority: P1
effort: "1-1.5d"
dependencies: [1]
---

# Phase 3: Card risk contract and auto preflight

## Context links

- [Plan overview](./plan.md)
- [Phase 1 contract](./phase-01-contract-freeze.md)
- `skills/flow/_templates/card.md:1-26`
- `skills/flow/references/auto-run.md:3-21,107-111`
- `skills/flow/references/adversarial-review.md:8-50`
- `skills/flow/references/debt-and-halts.md:6-24`
- `skills/flow/runner/flow.sh:395-423,1200-1237,1511-1550,1610-1669,1744-1771`
- `skills/flow/harness/graph_executor.py:591-626,698-720`
- `tests/test_flow_graph_executor.sh:113-154`
- `skills/flow/harness/_domain.py:80-113`

## Overview

Make card risk a persisted, parseable state and turn `/flow auto` preflight
from “planning + cards exist” into a real fail-closed risk gate. Keep manual
work backward compatible and keep the operator—not a model—as the authority for
security-class exposure.

## Requirements

### Functional

- New card template includes `risk`, `risk-reason`, and `risk-ack`.
- New cards start `risk: unknown`; classification is never inferred silently.
- A single strict parser returns normalized state or a structural error.
- `/flow ready`, `status`, and `resume` show risk and actionable block reasons.
- One shared risk-set helper enumerates every `cards/C-*.md` file, including
  done cards that can satisfy dependencies. `/flow auto` refuses:
  - missing/invalid/duplicate risk fields;
  - `risk: unknown`;
  - `security-class` without a valid committed acknowledgement.
- Standard manual `check` remains compatible with legacy cards and reports a
  warning rather than a hard failure solely for missing risk metadata.

### Non-functional

- Bash + Git only.
- Security trigger vocabulary and committed-DEBT provenance remain aligned
  with Tier-C/graph concepts. Identity authorization is intentionally stricter:
  graph currently records same-identity as audit and resumes; auto risk refuses.
- No model-driven automatic downgrade from security-class to standard.
- Card risk is the auto authority. Harness `risk_lane` remains a separate
  optional durable/advisory taxonomy in v0.28; do not create silent two-way sync.

## Architecture

### Strict card-field parser

Add shared helpers in `flow.sh`:

```text
_card_field_once <file> <field>
card_risk <file>
card_risk_reason <file>
card_risk_ack <file>
_card_risk_validate <file> <manual|auto>
```

The parser:

- counts exact anchored field occurrences;
- rejects duplicates;
- strips CRLF;
- enforces byte limits and single-line values;
- returns missing legacy risk as `unknown` only in compatibility mode.

### Security acknowledgement

`risk-ack: git:<full-oid>` is valid only when all checks pass:

1. OID length/hex shape matches repository object format.
2. Commit exists and is an ancestor of current integration `HEAD`.
3. `git show <oid>:<project-prefix>DEBT.md` succeeds.
4. The committed blob contains an exact open line beginning
   `- [ ] DEBT: security-class <card-id> --`.
5. Exactly one matching line exists. `git blame --line-porcelain` at that
   referenced commit yields its `author-mail`; compare normalized lowercase
   email with `git var GIT_AUTHOR_IDENT`. They must differ. This
   is a new fail-closed auto rule; the current graph executor’s
   `author_distinct` value is audit-only and must not be cited as existing
   enforcement.
6. Missing/ambiguous identity fails auto with a manual-continuation instruction.

Residual: an agent controlling Git config/history can forge authorship. This is
explicitly documented; v0.28 does not claim cryptographic operator identity.

### Preflight output

```text
BLOCK C-001 risk=unknown: classify risk + reason
HALT  C-002 risk=security-class: risk-ack missing
HALT  C-003 risk-ack stale/not-ancestor/DEBT line absent
READY C-004 risk=standard: bounded reason
```

No auto-active state is written until the entire card set passes.

The same sorted all-card set is the only input domain for preflight,
`risk_fingerprint`, auto-state currentness, and active readiness. No caller may
substitute a todo-only or dependency-only interpretation.

## File inventory

| Action | File | Intended change | Rough size | Test impact |
|---|---|---|---:|---|
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/_templates/card.md` | Add risk fields with unknown default | 5-10 LOC | Many card fixtures need compatibility |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/runner/flow.sh` | Strict parser, ack verifier, ready/status/resume/auto preflight | 140-220 LOC | Runner/auto/ready suites |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/references/auto-run.md` | Persisted risk and ack workflow | 30-50 LOC | Docs contract |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/references/adversarial-review.md` | Use persisted risk as lens input | 10-20 LOC | Docs contract |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/references/debt-and-halts.md` | Exact ack commit contract | 20-35 LOC | Graph/security tests |
| Create | `/home/manhquy/Downloads/flow-skill/tests/test_flow_card_risk.sh` | Parser, migration, preflight, ack matrix | 220-320 LOC | Register in run_all |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/test_flow_auto_done_path.sh` | Auto path remains compatible outside active auto | 20-40 LOC | Focused |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/test_flow_status_legibility.sh` | Risk display | 15-30 LOC | Focused |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/test_flow_resume.sh` | Risk summary in resume | 15-30 LOC | Focused |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/run_all.sh` | Register suite | <5 LOC | Full |

## Interface checklist

- [ ] Risk values are exactly `standard|security-class|unknown`.
- [ ] Duplicate fields are invalid.
- [ ] Legacy missing fields normalize to unknown only where documented.
- [ ] `standard` cannot carry a non-none ack.
- [ ] `unknown` cannot carry an ack.
- [ ] Security ack uses full OID and exact card matching.
- [ ] Monorepo project prefix is used for `HEAD:<prefix>DEBT.md`.
- [ ] Uncommitted DEBT changes never satisfy committed acknowledgement.
- [ ] Auto preflight prints all blockers in one pass.
- [ ] Preflight, latch fingerprint, currentness, and readiness call one all-card
  risk-set helper.
- [ ] Harness lane is not silently treated as card risk authority.

## Dependency map

```text
phase 1 risk grammar
        |
        v
card template -> strict parser -> risk display
                              -> security ack verifier
                              -> auto preflight
                                       |
                                       v
                              phase 5 auto activation
```

## Test scenario matrix

| Priority | Scenario | Expected |
|---|---|---|
| Critical | Legacy card has no risk fields | Manual warning; auto blocks as unknown |
| Critical | Legacy done dependency lacks risk fields | Auto blocks before activation |
| Critical | Duplicate `risk:` lines | Structural failure; auto blocks |
| Critical | Unknown card with fabricated ack | Auto blocks |
| Critical | Security card with reviewer “green” but no DEBT commit | HALT |
| Critical | Ack commit exists but DEBT line names another card | HALT |
| Critical | Ack commit is not ancestor / OID wrong object format | HALT |
| Critical | DEBT is only uncommitted | HALT |
| High | Security ack authored by executing identity | HALT/manual continuation per authority contract |
| High | Standard card with valid bounded reason | Preflight pass |
| High | Mixed set has one unknown among many standard | Entire preflight fails and lists all |
| Medium | CRLF card | Parses identically |
| Medium | Long/multiline reason | Reject |

## Implementation steps

1. Add focused failing tests for the complete risk/ack matrix.
2. Extend the card template with unknown defaults.
3. Implement exact single-field parser and risk validator.
4. Implement Git object-format and monorepo-aware DEBT acknowledgement checks;
   reuse the graph tests’ closed-target/committed-provenance fixtures, but add
   explicit same/missing/ambiguous-author refusal rather than copying the
   graph’s audit-only identity behavior.
5. Add risk lines to `ready`; add concise totals/blockers to `status`/`resume`.
6. Replace `cmd_auto`’s current two-check preflight with one all-card risk-set
   enumeration reused by Phase 5 fingerprint/currentness/readiness.
7. Keep auto preflight read/validate-only in this phase; Phase 5 combines it
   with the current Stage 05 receipt check and writes auto-active state. Card
   semantic/live receipts are later gates and do not exist at activation time.
8. Update Tier-C/security docs to reference persisted fields.
9. Run focused risk, project-type, graph executor, ready/auto, status/resume
   suites, then full suite because template changes affect broad fixtures.

## Todo

- [ ] Card template updated
- [ ] Parser + risk validator complete
- [ ] Security ack verifier complete
- [ ] Ready/status/resume/auto output updated
- [ ] Focused and full suites green

## Success criteria

- [ ] No card can enter auto with unknown risk.
- [ ] No security-class card can enter auto without the exact committed
  acknowledgement contract.
- [ ] Manual legacy projects are not hard-broken.
- [ ] Risk reason/blocker is visible without Python.

## Risk assessment

| Risk | Mitigation |
|---|---|
| Model self-classifies risky work as standard | Persist reason, semantic review still challenges; corpus includes misclassification cases |
| Git-author distinct guard deadlocks solo setups | Fail safe with explicit manual continuation; document residual |
| Template addition breaks old fixtures | Parser compatibility + targeted fixture helpers |
| Dual risk taxonomies drift | Card risk is auto authority; harness lane explicitly separate |

## Security considerations

- Never use regex interpolation with unvalidated card IDs or OIDs.
- Use literal matching after closed-set validation.
- Strip inherited Git directory environment before acknowledgement checks.

## Rollback

Older runners ignore the new card lines. Reverting parser/preflight restores
old auto behavior; no destructive migration.

## Next steps

Phase 5 combines this risk gate with Phase 4 receipts and writes auto-active
state only after all preflight checks pass.

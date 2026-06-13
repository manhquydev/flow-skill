# Adversarial review (the Review gate)

Before a card merges, it is reviewed by a reviewer whose job is to **find issues** — not to
bless. "No 'looks good' allowed. Zero findings triggers a halt: re-analyze, or explain why
nothing was found." (BMAD adversarial-review pattern.) Prefer `bmad-code-review` when
present; else `code-reviewer`; else run the three lenses yourself as separate passes.

## Three layers (information asymmetry — each sees less, so each catches different things)

| Layer | Sees | Hunts for |
|---|---|---|
| **Blind Hunter** | the diff ONLY (no context) | bugs visible on the diff surface; smells |
| **Edge Case Hunter** | diff + repo read access | every branch/boundary/empty/error path |
| **Acceptance Auditor** | diff + `flow/05-contract.md` + `flow/03-prd.md` + the card | contract-shape violations, PRD acceptance gaps, missing specified behavior |

Run them as separate scoped subagents (or separate passes) so no single context biases the
others. The Acceptance Auditor is the one that catches producer/consumer drift — it checks
the diff's shapes against the contract.

## Triage
Group every finding by severity x actionability:
- **Must-fix (correctness/contract/security)** -> Tier-B repair by a FRESH subagent before merge.
- **Should-fix (maintainability)** -> fix now if cheap, else note.
- **Observation** -> record, proceed.
Two-strikes: a second red review on the same card -> escalate to the operator, don't loop.

## Apply your own decision rules (do not blindly accept findings)
- Validate each finding against what the code actually does and protects. "Theoretically
  yes, practically no" findings are documented, not blindly fixed.
- A verified decision is not reversed by a review opinion alone — only by a NEW issue the
  verification missed, or changed context. Surface conflicts to the operator with the source.
- Security-class findings (auth/authz/data/payments) are never waved through — they are
  Tier-C: operator decides, in writing (`debt-and-halts.md`).

## Output
A short report: findings by layer, triage, and the verdict (green / repair-needed /
escalate). On green, proceed to `flow.sh check` -> merge -> deploy -> live verify. Record a
`trace`; on a red that overrode an agent, record an `intervention`.

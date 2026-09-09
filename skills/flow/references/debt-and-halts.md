# Debt & halts

Reordering or skipping a gate is a legitimate OPERATOR call (demo-first, riskiest-first).
But a skipped gate is a loan, and loans get written down. (buildflow CLAUDE.md "Debt".)

## The DEBT.md ledger
Every deliberate skip opens one line (create `DEBT.md` on first use). Use the runner:
```
bash <skill>/runner/flow.sh debt add "<what was skipped>" "<the exposure, concretely>" "<close before: named condition>"
bash <skill>/runner/flow.sh debt list      # open debts
```
Line shape:
```
- [ ] DEBT: <what was skipped> -- <exposure> -- close before: <named condition> -- opened <date> (cards: C-NNN...)
```

## Security-class skips (never silent, never planner-decided)
auth · authorization · admin-surface exposure · tenancy · payments · data loss/migration ·
removing/weakening validation.
- The OPERATOR explicitly accepts the exposure, in writing, in the DEBT line. The host does not
  decide it for them. Children MUST NOT resolve Tier-C, open/close DEBT, or skip — parent/operator
  only. Docs-only; the runner does not refuse child `debt`/`skip` this wave.
- In `/flow auto` this is a **Tier-C HALT** — stop and ask.
- Closing a run with open security debt requires explicit operator acknowledgment.
  "Temporary" is one forgotten step from production.

## Close conditions
Checked at every `/flow retro` and before ANY real user touches the build. A card blocked
by a debt stays `todo` with PARTIAL evidence naming the debt — never half-done, never
rounded up to done.

## Halts (when the run stops itself)
A run HALTS and reports — never silently continues — on any of:
- A hard-stop cap exceeded (iterations/tokens/wall-clock). (`loop-harness-2026-principles.md`)
- A red ground-truth signal that can't be repaired in two strikes. (`adversarial-review.md`)
- A Tier-C security-class touch. (above)
- A merge conflict during parallel builds (the allowed-files overlap check was gamed —
  stop and re-plan). (`auto-run.md`)
- `BLOCKED` / `NEEDS_CONTEXT` from a subagent that more context can't resolve, or a child report missing `STATUS` (treat as BLOCKED).

## Halt report template

On halt, emit this block (docs contract; runner does not parse it):
```
whatStopped: <cap | red-after-two-strikes | Tier-C | merge-conflict | child-BLOCKED>
doneSoFar: <cards/stages complete>
openDebtOrBlocker: <DEBT line or child blocker>
options:
1. <operator accepts exposure in DEBT.md>
2. <re-plan / shrink the card>
3. <repair with a fresh scoped brief>
4. <stop the run (`flow auto stop`)>
AutoDecision: halt
STATUS: BLOCKED
```
Let the operator pick — don't patch around a regression.

See also: `references/attestations.md` for security-class **risk-ack** auto contract (v0.28).

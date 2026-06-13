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
- The OPERATOR explicitly accepts the exposure, in writing, in the DEBT line. You do not
  decide it for them.
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
- `BLOCKED` / `NEEDS_CONTEXT` from a subagent that more context can't resolve.

On halt: state what stopped it, what's done so far, the open debt/blocker, and the 2-4
concrete options for the operator. Let them decide — don't patch around a regression.

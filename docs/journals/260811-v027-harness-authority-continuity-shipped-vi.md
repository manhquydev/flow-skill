# Journal — v0.27.0 harness authority continuity

**Date:** 2026-08-11  
**Skill:** 0.27.0 · **npm:** 0.4.0  
**Plan:** `plans/260811-1405-flow-harness-authority-continuity/`

## What shipped

- Live authority = flow-owned Python durable layer + flow.sh + gate-rules (EOL harness-cli pins out of hot path).
- GAP-MATRIX SUPERSEDED / no upstream schema sync; historical archive 0.1.22 noted.
- Contract tests flipped; story-complete trust greps preserved.
- R-IMPROVE-HARNESS native ritual (6th); native-rituals tests 5→6.
- Brownfield Evidence ledger + gate-rules Brownfield assess + material-authority stop 02/03/05.
- harness-skill redirects to `/flow harness`; complete-only kept.
- Full `tests/run_all.sh` green (~176s). Preflight PASS.

## Emotion / honesty

Relief closing the lying-pin narrative after upstream ADR 0027. Residual risk: npm publish needs tag push + OIDC environment approval — not complete until `latest` points at 0.4.0 on registry.

## Next

- `git tag v0.27.0` + `npm@0.4.0` + push → publish workflow.
- Confirm `npm view @manhquy/flow-skill version` == 0.4.0.

# /flow auto — autonomous build run

`/flow auto` drives the card-building phase autonomously. Preflight via
`flow.sh auto` (planning complete + cards exist), then YOU (Claude) orchestrate per the
principles below. Operator chose: **Tier-A auto-merge green cards; halt at security-class.**

## Tiers (decide per card before acting)

| Tier | What | Action |
|---|---|---|
| **A** | Card built, review green, verify-live passed, no security-class concern | **Auto-merge without asking.** Log PR URL + merged SHA in `AUTO-LOG.md`. |
| **B** | Built but review found fixable issues, or verify ambiguous | One repair pass by a **fresh** subagent (two-strikes). **If the codex tier is eligible, prefer a Codex fresh-engine repair** (`codex:codex-rescue` — a different model breaks deadlocks the same model re-hits; see `codex-integration.md`). Still red after the second strike → escalate to operator. |
| **C** | Security-class touch (auth, authorization, admin exposure, tenancy, payments, data migration, removing validation) OR a debt skip | **HALT.** Operator must accept the exposure in writing in `DEBT.md`. Never planner-decided. |

## Loop per card (serial by default; parallel only when `/flow ready` says safe)

```
for each todo card in card-number order:
  0. tier-classify. If Tier-C -> HALT, write DEBT line, ask operator. Do not proceed.
  1. spawn ONE scoped subagent (agent-stage-mapping.md) in its own worktree
     git worktree add ../<project>-C-NNN -b card/C-NNN
  2. agent builds to contract, touches only allowed files, runs ## Verify for real
  3. review the diff (code-reviewer or bmad-code-review 3-layer; see adversarial-review.md).
       On a security-class card with the codex tier eligible, add the Codex cross-model lens.
       red -> Tier-B repair by a FRESH subagent, preferring a Codex fresh-engine repair when
              eligible (two-strikes); second red -> escalate
       green -> continue
  4. flow.sh check C-NNN must PASS (mechanical) + gate-rules semantic check
  5. merge to main in card order; deploy; VERIFY ON LIVE URL (merge != shipped)
  6. paste world-state evidence into the card; status: done
  7. flow.sh harness story update --status implemented + trace; log AUTO-LOG.md
  8. remove worktree
```

## Hard stops (mandatory — see loop-harness-2026-principles.md in Phase 4)
- Iteration cap per card (e.g. 2 repair attempts), token budget, wall-clock cap. Exceed any
  -> HALT + report. A loop with no cap is an antipattern.
- Ground-truth gates only at decision points: `flow.sh` exit, `## Verify` real runs, story
  `verify_command`, deploy + live check. Never advance on an agent's self-assessment alone.

## AUTO-LOG.md schema (one line per card)
```
- C-NNN | <title> | tier=A | review=green | PR=<url> | merged=<sha> | live=<verified-url> | <date>
- C-NNN | <title> | tier=C HALT | reason=<security-class> | DEBT opened | <date>
- C-NNN | <title> | tier=B | repair=codex:codex-rescue | result=green | PR=<url> | <date>
```
When a Codex engine drafted/repaired/reviewed a card, name it in the line (`repair=` / `review=`)
and log the durable metric (`flow.sh harness intervention add`) per `codex-integration.md` §Durable metric.

## Parallel groups
`/flow ready` lists todo cards with deps met AND no allowed-files overlap. Only those run in
parallel, each in its own worktree/session. Merge back in card-number order, one at a time,
running the merged app once between merges. A merge conflict means the overlap check was
gamed — stop and re-plan. Cards needing the deployed app (contract-tests, e2e) are serial.

## Security-class halt (never silent, never planner-decided)
auth · authorization · admin-surface exposure · tenancy · payments · data loss/migration ·
removing/weakening validation. On any: stop, write the `DEBT.md` line with the concrete
exposure + close condition, and get explicit operator acknowledgment before continuing.
Closing a run with open security debt requires the operator to acknowledge it in writing.

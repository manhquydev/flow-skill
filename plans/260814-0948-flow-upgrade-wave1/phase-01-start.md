---
phase: 1
title: "Identity ADR"
status: pending
priority: P1
effort: "0.5-1d"
dependencies: []
---

# Phase 1: Identity ADR

## Overview
Write the constitution the wave builds under: flow's identity as a discipline layer, as ONE document
in the repo (not scattered across DEBT.md/quality-metrics.md, not left in a worktree report).

## Requirements
- Functional: a single ADR document capturing every load-bearing rule from the identity decision.
- Non-functional: readable cold by a future model generation; no dependence on session context.

## Architecture
New home: `docs/adr/0001-discipline-layer-identity.md` (create `docs/adr/`; `DESIGN.md` is UI law,
architecture law needs its own home). Source content: `plans/reports/brainstorm-260814-0933-flow-identity-decision.md`
(final resolutions section) — the ADR is the durable rewrite, not a copy-paste.

## Related Code Files
- Create: `docs/adr/0001-discipline-layer-identity.md`
- Modify: `docs/system-architecture.md` (one pointer line to the ADR), `README.md` (identity sentence
  if a natural slot exists — do not force)

## Implementation Steps
1. Draft ADR with sections, all in one document:
   - **Identity statement:** "Flow owns the gates and the receipts, never the runtime… flow never
     holds the process token."
   - **Testable invariant:** every flow byte executes because a hosting agent or the operator invoked
     it, and flow terminates when that invocation returns. Mechanically forbidden: daemons/residents,
     own agent loop, tool-execution wrappers/interposition, servers. Explicitly inside the boundary:
     choosing/paying for cross-model judge models.
   - **5 flip-tripwires** (host primitives hostility; measured compliance drift; host ships opinionated
     gated-build product; capture-time provenance demand; capacity >2 FT maintainers/funding). 2+
     concurrent = strong flip signal; each alone = decision review.
   - **Eval floor:** proportional — "at most one fixture mismatch per batch" (never a hardcoded
     count; manifest grows). Baseline recorded: 100% (canonical v0.21.0 block, judge claude-opus-4-7).
     Sound-fixture false-block → fixture autopsy FIRST (precedent: f01a 260710 dirty fixture — gate
     was right); breach only if fixture clean. Floor is a flip-tripwire threshold ONLY — the CI exit
     contract stays strict all-match (exit 1 on any mismatch). Single-mismatch batch at floor =
     normal operation, not incipient breach; breach requires two consecutive host-model generations
     despite prompt fixes.
   - **Judge re-baseline rule:** any judge-model change triggers a full batch re-baseline
     (today: 9 artifact fixtures × `--n 3` = 27 judge calls + 1 probe; grows when the manifest
     grows — never hardcode 21) before numbers count toward the tripwire.
   - **Replay boundary:** replay verdicts NEVER count toward the eval floor or tripwire 2 — only live
     batches with fresh nonces are compliance evidence (recorded nonce + committed stripped
     transcripts are hand-editable in a PR; integrity there = code review). The macOS DEBT *mechanism
     diagnosis* may remain unconfirmed; the Phase 6 **refuse-guard** still ships before A3 (wave
     order 6→7). A3 confinement: live `_eval_engine_run` body + `_run_with_timeout` untouched; a
     `cmd_eval` replay prelude (skip probe, pin nonce) is required and allowed. If the live engine
     body or timeout helper must change, STOP and revert to close-before-A3.
   - **Fixture-pair rule:** any wave adding a gate-enforced rule adds ≥1 hollow/sound fixture pair.
   - **Monetization cap (accepted):** standard+services-shaped moat; no near-term revenue goal;
     revisit only at tripwire 5.
   - **Consequences:** C1/C2 (Cordis-style platform, event-sourced core) closed as rejected-per-ADR;
     plan `260726-1718` graph default-on reconsideration must satisfy the invariant.
2. Add pointer from `docs/system-architecture.md`.
3. Run `bash skills/flow/runner/flow.sh coherence` (or repo equivalent) + `scripts/check-release-coherence.sh`
   to confirm no doc-drift flags.

## Success Criteria
- [x] ADR merged at `docs/adr/0001-discipline-layer-identity.md` containing every section in
      Implementation Step 1 (identity, invariant, 5 tripwires, eval floor + autopsy + CI-separation,
      judge re-baseline, replay boundary, fixture-pair, monetization cap, consequences). Do not
      treat "seven bullets" as a count — the list is the contract.
- [x] `docs/system-architecture.md` points to it.
- [x] Coherence checks pass.

## Risk Assessment
Low. Pure docs. Main risk is under-specifying the floor rules — mitigate by lifting exact wording
from the decision report's "Final resolutions" section.

<!-- Updated: Red Team R1 - replay boundary: guard-before-A3; cmd_eval prelude allowed -->
<!-- Updated: Validation Session 1 - re-baseline call census; drop "seven bullets" count -->

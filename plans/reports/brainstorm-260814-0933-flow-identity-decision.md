# Flow identity decision — answer to synthesis unresolved Q1

- **Date:** 2026-08-14 09:40
- **Question:** flow's 5-year identity — (a) discipline layer on commodity agents vs (b) grow own runtime.
- **Decision:** **(a), settled** — with a testable invariant, recorded tripwires, and sequencing guards.
- **Process:** builder position + kongming advisory review (full counsel in session; key points absorbed below).
- **Feeds:** identity ADR in repo (to be authored before B1), A1–A5/B1 upgrade wave planning.

## Decision statement (for the future ADR)

> **Flow owns the gates and the receipts, never the runtime: a host-agnostic discipline layer that
> turns any coding agent into an evidence-gated, kill-honest build process — flow never holds the
> process token.**

**Invariant (testable, not prose-vibes):** every flow byte executes because a hosting agent or the
operator invoked it, and flow terminates when that invocation returns. Mechanically forbidden:
daemons/residents, own agent loop, tool-execution wrappers/interposition, servers. Explicitly
*inside* (a): choosing and paying for cross-model judge models (DF-2 duty) — judge selection is not
loop ownership.

## Why (a)

1. Runtime space is commoditizing + brutally competitive; dsh's bill of materials (219 pkgs, 4
   release trains, no measured agent layer) is the exhibit. Solo maintainer = (b) capacity-forbidden.
2. Flow's moat is exactly what runtimes lack: gated process, evidence integrity, kill culture,
   *measured* semantic gate (dsh has no benchmark; flow eval is ahead).
3. Host-agnostic = rides every host improvement free; zero-dep degrade-friendly portability is the
   adoption wedge and stated design defense.
4. DF-2 (same-model blind spot) does NOT force (b): cross-model judge through the host closes it
   (evidence: quality-metrics.md:604 — cross-model engine caught contract-stage false-pass).

## Accepted costs (named honestly)

- **Rented enforcement:** semantic-gate authority drifts with host model updates; mechanical layer is
  advisory on hosts that ignore hooks. → eval becomes *existential sensor*, cadence ≥ per host-model
  major release; record pass-rate floor (~80% on fixture set) NOW.
- **No telemetry loop at scale:** structurally conceded; sqlite durable layer stays the consented
  local substrate for opt-in signals.
- **Plaintext moat:** defensibility = maintained corpus (58 suites × 3-OS, nonce eval, attestation
  format, upkeep) — standard/reputation-shaped; monetization likely caps at standard+services.
- **Shelf owned by substitutes** (npm + host marketplaces); counterweight: vendors ship mechanism,
  not opinionated policy.

## Slope guards (the 3 slip points)

1. **B1 evidence lineage:** flow may *re-run and verify*, never sit in the execution path. Evidence
   is declared then re-verified (attestation model already works this way).
2. **A3 replay:** fixtures are eval-harness-built transcripts, never captured live traffic. The eval
   harness is the one bounded runtime-sliver; macOS timeout DEBT is the canary — **close it before A3
   expands the harness**.
3. **Durable layer:** invoked-by-host, never resident. No "flush before model request" watchers.

## Tripwires → reopen review (2+ concurrent = strong flip signal)

1. 2 of 3 major hosts break/remove/paywall needed primitives (skills/hooks/subagent) >1 release cycle.
2. Eval pass-rate < recorded floor across two consecutive model generations despite prompt fixes.
3. A host ships an *opinionated* gated-build product (Idea→Retro spine + evidence receipts), not mechanism.
4. A real adopter needs tamper-evident capture-time provenance post-hoc re-verify cannot provide.
5. Capacity: >2 FT maintainers or funding (until then (b) forbidden regardless of 1–4).

## Consequences / sequencing

- **GO on A1–A5 + B1.** A1/A2/A4/A5 identity-neutral; A3/B1 carry guards above.
- Order: close macOS eval DEBT → identity ADR (invariant + tripwires + eval floor number; needs its
  own home — DESIGN.md is UI law, not architecture law) → A3 → B1 (design review cites no-interposition).
- Synthesis Q3 (replay vs live authority): live judge stays authoritative, replay = regression net;
  revisit at first real eval bill.
- C1/C2 (runtime reopeners): close as "rejected per identity ADR", not left ambient.
- 12-month success metrics: zero invariant-violating features without explicit ADR reopen; eval floor
  never breached silently; DF-2 lens widened to Contract gate (quality-metrics.md:633) with no
  resident process.

## Final resolutions (2026-08-14 second kongming round — GO on all, amendments absorbed)

1. **Eval floor (tripwire #2):** proportional wording — "at most one fixture mismatch per batch"
   (not hardcoded 6/7; manifest will grow). Sound-fixture false-block → **fixture autopsy first**
   (history: f01a 260710 was a dirty fixture, gate was right); breach only if fixture clean.
   Floor = flip-tripwire threshold ONLY; CI exit contract stays strict all-match. Judge-model change
   → full batch re-baseline (~21 calls) before numbers count. Single-mismatch batch at floor =
   normal operation, not incipient breach. Baseline recorded: 100% (canonical v0.21.0 block).
2. **macOS DEBT:** A3 replay proceeds (keyless, plugs behind `_eval_engine_run()` seam — if impl
   bypasses the seam, guard reverts to close-before-A3). One bounded DEBT card, exit artifact =
   updated DEBT.md naming confirmed-or-abandoned mechanism + shipped guard. Live eval on macOS
   without real timeout binary: **refuse by default, explicit opt-in flag** (not warn).
3. **Monetization:** no near-term revenue goal; ADR states the accepted standard+services cap;
   revisit only at tripwire 5.
4. **B1-S:** ground-truth-gates.md addendum ("every done-evidence item names its artifact/command"),
   **must ship with ≥1 hollow/sound fixture pair in the eval manifest** (unmeasured discipline =
   unmeasurable escalation trigger). ADR rule: any wave adding a gate-enforced rule adds ≥1 fixture pair.
5. **MCP (Q4):** defer; reopen = concrete blocked card (tripwire-4 class).
6. **Website (Q5):** build + dead-link CI gate, light version; **out of wave-1 scope** (belongs to
   feat/flow-website lifecycle).
7. **Python coverage (Q6):** none now; revisit >~5k lines or external API consumer.
8. **Attestation substrate (Q7):** git-blob-only; hybrid reopens only on B1 escalation AND
   tripwire-4 adopter demand.
9. **i18n (Q8):** EN+VI blob-hash record only; glossary at a third language.

**A2 scope addition (kongming blind spot 4):** CI parity check between `skills/flow/` and the
duplicated `npm-wrapper/skills/flow/` tree — only accidentally in sync today.
**ADR completeness rule:** invariant + 5 tripwires + proportional floor/autopsy/CI-separation +
monetization cap all in ONE document.

## Unresolved questions

None. Cleared to /ak:plan (wave 1, worktree branch `research/deepseek-harness-upgrade`).

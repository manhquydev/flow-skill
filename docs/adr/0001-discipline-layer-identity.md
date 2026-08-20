# ADR 0001 — Discipline-layer identity

- **Status:** Accepted
- **Date:** 2026-08-14
- **Deciders:** flow maintainer; kongming advisory review absorbed
- **Source:** `plans/reports/brainstorm-260814-0933-flow-identity-decision.md` (Final resolutions)

This is the constitution the upgrade wave builds under. Read it cold. Session context is not
required and must not be assumed.

## Identity statement

Flow owns the gates and the receipts, never the runtime: a host-agnostic discipline layer that
turns any coding agent into an evidence-gated, kill-honest build process — flow never holds the
process token.

The alternative — grow an owned runtime (own agent loop, tool scheduler, servers) — is rejected
until a flip-tripwire review reopens this ADR.

## Testable invariant

Every flow byte executes because a hosting agent or the operator invoked it, and flow terminates
when that invocation returns.

Mechanically forbidden:

- daemons / resident processes
- an owned agent loop
- tool-execution wrappers or interposition (flow may re-run and verify; it never sits in the
  execution path)
- servers

Explicitly inside the boundary: choosing and paying for cross-model judge models. Judge selection
is a measured-gate duty, not loop ownership.

The durable layer is invoked-by-host, never resident. No watchers that flush before a model
request.

## Flip-tripwires

Any single tripwire is a decision review. Two or more concurrent tripwires are a strong flip
signal toward reopening identity (runtime growth is otherwise capacity-forbidden).

1. **Host-primitives hostility.** Two of three major hosts break, remove, or paywall needed
   primitives (skills / hooks / subagent) for more than one release cycle.
2. **Measured compliance drift.** Eval pass-rate falls below the recorded floor across two
   consecutive host-model generations despite prompt fixes. See Eval floor and Replay boundary:
   only live batches with fresh nonces count.
3. **Host ships an opinionated gated-build product** — Idea→Retro spine plus evidence receipts —
   not merely mechanism.
4. **Capture-time provenance demand.** A real adopter needs tamper-evident capture-time
   provenance that post-hoc re-verify cannot provide.
5. **Capacity.** More than two full-time maintainers, or funding at that scale. Until then,
   growing an owned runtime is forbidden regardless of tripwires 1–4.

## Eval floor

The floor is proportional: **at most one fixture mismatch per batch**. Never a hardcoded count;
the eval manifest grows.

- **Baseline recorded:** 100% on the canonical v0.21.0 block (judge `claude-opus-4-7`).
- **Sound-fixture false-block → fixture autopsy first.** Precedent: f01a (2026-07-10) was a dirty
  fixture; the gate was right. A mismatch is a floor breach only after the fixture is shown
  clean.
- **Floor vs CI.** The floor is a flip-tripwire threshold only (tripwire 2). The CI exit
  contract stays strict all-match: exit 1 on any mismatch.
- **Single-mismatch batch at the floor** is normal operation, not an incipient breach. Breach
  requires two consecutive host-model generations despite prompt fixes.

## Judge re-baseline rule

Any judge-model change triggers a full artifact-batch re-baseline before numbers count toward
tripwire 2.

Census is measured from the live artifact manifest, never a hardcoded call count. Today that is
9 artifact fixtures × `--n 3` = 27 judge calls + 1 probe. The census grows when the manifest
grows. Do not treat "~21" (a stale 7×3 figure) as the rule.

## Replay boundary

Replay verdicts never count toward the eval floor or tripwire 2. Only live batches with fresh
nonces are compliance evidence.

Recorded nonce plus committed stripped transcripts are hand-editable in a PR; integrity there is
a code-review problem, not a compliance measurement.

The macOS DEBT *mechanism diagnosis* may remain unconfirmed. The Phase 6 refuse-guard still
ships before A3 (wave order 6→7). Live eval on macOS without a real timeout binary refuses by
default (explicit opt-in, not a warning).

A3 confinement:

- the live `_eval_engine_run` body and `_run_with_timeout` stay untouched
- a `cmd_eval` replay prelude (skip probe, pin nonce) is required and allowed
- if the live engine body or timeout helper must change, stop and revert to close-before-A3

Fixtures used for replay are eval-harness-built transcripts, never captured live traffic.

## Fixture-pair rule

Any wave that adds a gate-enforced rule adds at least one hollow/sound fixture pair to the eval
manifest. Unmeasured discipline is an unmeasurable escalation trigger.

## Monetization cap

Accepted shape: a standard-plus-services moat (maintained corpus, nonce eval, attestation
format, upkeep). No near-term revenue goal. Revisit only at tripwire 5.

## Consequences

- **C1 (Cordis-style plugin platform) and C2 (event-sourced session core)** are rejected per
  this ADR, not left ambient. Reopening either is an identity reopen, not a local design tweak.
- Plan `260726-1718` (graph-executor default-on reconsideration) must satisfy the process-token
  invariant before it can proceed. Graph default-on that holds a process token, interposes on
  tool execution, or becomes resident is out of bounds.
- Features that would violate the invariant require an explicit reopen of this ADR first.
  Twelve-month success: zero invariant-violating features without that reopen; eval floor never
  breached silently.

Deferred (not rejected; reopen only on the stated trigger):

- MCP client bridge — concrete blocked card of tripwire-4 class
- Website CI / dead-link gate — `feat/flow-website` lifecycle, not this wave
- Python coverage floors — revisit above ~5k lines or an external API consumer
- Attestation substrate stays git-blob-only; hybrid reopens only on B1 escalation **and**
  tripwire-4 adopter demand
- i18n: EN+VI blob-hash record only; glossary at a third language
- Own orchestration runtime (`flow-orch`) — a SEPARATE product for extensibility; reopen only on a named flip-tripwire **and** capacity (tripwire 5). flow-skill stays the discipline layer that talks to it the same way it talks to any host

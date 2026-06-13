# Loop & harness engineering principles (2026)

The principles `/flow` enforces during loops and autonomous runs. Distilled from current
agentic-engineering practice and mapped to concrete flow points. We apply the **principles**;
where a source cited a specific number, treat it as illustrative and verify in context.
(Source: `research-report-agent-orchestration-2026.md`.)

## 1. Harness-first, not prompt-first
Quality comes from the scaffold (gates, loop control, durable state, budget), not from
prompt tuning. `/flow` IS that scaffold: `flow.sh` gates + `harness/` durable records +
the AUTO loop. When a run goes wrong, fix the harness (open a `backlog` item), don't just
re-prompt. -> `flow.sh harness backlog add` (growth rule).

## 2. Hard stops are mandatory
Every loop/auto run declares caps: **max iterations per card**, **token budget**,
**wall-clock**. Exceed any -> HALT + report, never continue silently. A loop with no
termination criterion is an antipattern. -> see `auto-run.md` "Hard stops".

## 3. Ground-truth verification at decision points
At a gate that decides "advance/merge/done", trust a mechanical signal, not the model's
self-assessment: `flow.sh` exit code, story `verify_command` exit, the card's `## Verify`
run for real, the deploy + live-URL check. LLM-as-judge is advisory only, never the gate.
-> `ground-truth-gates.md`.

## 4. Adversarial verification before committing
Before a card merges, an independent reviewer (or 3, with information asymmetry) must try
to REFUTE it. "Must find issues; zero findings -> re-analyze." -> `adversarial-review.md`.

## 5. Context isolation fights context rot
Model accuracy degrades as the window fills. Keep each subagent's context small and scoped
(task + files + acceptance + relevant law excerpts — no session history), and push durable
state OUT to `harness/` (external memory) and `flow/` + `cards/` (on-disk artifacts). One
card = one fresh, small context. -> `agent-detection.md` context rules.

## 6. Spec/contract-first prevents drift
The #1 AI-build failure is producer/consumer drift (backend ships one shape, UI assumes
another, both green). The contract (stage 05) written before code, asserted against the
live spec by the contract-test card, is the cheap fix. "Contract is the seam."

## 7. Make truncation legible
If a run bounds coverage (top-N cards, skipped a gate, sampled), SAY so. A silent cap reads
as "covered everything". Debt is the ledger for deliberate skips -> `debt-and-halts.md`.

## Mapping to flow points
| Principle | Enforced at |
|---|---|
| Hard stops | `/flow auto` loop (iteration/token/time caps) |
| Ground-truth | every gate decision (`flow.sh` exit, verify runs, live check) |
| Adversarial | Review step before merge (`code-reviewer` / `bmad-code-review`) |
| Context isolation | per-card scoped subagent brief + `harness/` external memory |
| Contract-first | stage 05 + contract-test card |
| Legible truncation | `DEBT.md` + `AUTO-LOG.md` + announce path/verdict |

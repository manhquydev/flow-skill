# Adversarial review (the Review gate)

Before a card merges, it is reviewed by a reviewer whose job is to **find issues** — not to
bless. "No 'looks good' allowed. Zero findings triggers a halt: re-analyze, or explain why
nothing was found." (BMAD adversarial-review pattern.) Prefer `bmad-code-review` when
present; else `code-reviewer`; else run the three lenses yourself as separate passes.

## Security-class lens selection

When a card is **security-class** (auth, authorization, admin exposure, tenancy, payments,
data migration, removing/weakening validation — same trigger as `auto-run.md` Tier-C),
the Review gate uses the **`security-reviewer` AGENT** (STRIDE/OWASP, secrets, injection,
SSRF) as the primary acceptance lens, **layered with `code-reviewer`**. Non-security cards
stay with the generic `code-reviewer` — no change to that path.

**Agent vs skill:** `security-reviewer` is an **AGENT** (`Task(subagent_type="security-reviewer")`)
invoked in subagent isolation — it sees the diff, contract, and acceptance only. `ck-security`
is a **SKILL** (main-context Skill tool, no subagent isolation); it may be used as an optional
inline pass by the orchestrator, but it is **never** the delegated review subagent.

**Portability degrade rung** (detect-first, gate identical on every rung):
1. `security-reviewer` AGENT present → run it layered with `code-reviewer` (primary path).
2. `security-reviewer` absent → `code-reviewer` runs an explicit STRIDE/OWASP checklist
   covering the Tier-C keyword list (auth, authz, tenancy, payments, injection, secrets, SSRF).
3. Neither available → inline security review against the Tier-C keyword list by the orchestrator.

**Gate parity — the lens INFORMS triage; it NEVER auto-fails or auto-passes a card.** A
`security-reviewer` "looks fine" verdict is advisory evidence fed into the same triage table
below. The Review gate still decides.

**Critical: the lens NEVER releases the Tier-C operator HALT.** The security-class HALT
(`auto-run.md:13,57`) is triggered by CLASSIFICATION and resolved ONLY by written operator
acknowledgment in `DEBT.md`. A `security-reviewer` clean verdict can NEVER substitute for, or
auto-release, that HALT — it is advisory evidence for the operator, not a gate key.

**No-defang rule applies to the security dispatch.** Hand the `security-reviewer` the diff,
the contract, and the card's acceptance — never add "don't flag X" or "treat as minor at
most". The same defang prohibition above governs the security dispatch equally.

## Don't defang the reviewer (controller-side input)

The "must find issues" rule above governs the reviewer's **output**. It is defeated at the source if
you hand the reviewer a **poisoned prompt**. When you construct a review dispatch, you may not
pre-judge its findings:

- Never write "don't flag X", "treat it as Minor at most", "the plan already chose this", or any
  steer that tells the reviewer what NOT to find. If you believe a finding would be a false
  positive, let the reviewer raise it and adjudicate it in triage — do not pre-empt it.
- The card's own example/scaffold code is a starting point, not evidence its weaknesses were
  intentional. Do not present it to the reviewer as "the chosen design".
- Hand the reviewer the diff as a file (or scoped repo read), the contract, and the card's
  acceptance — not your opinion of the diff. The reviewer's lens is acceptance + contract + the
  three hunts, nothing you added to spare yourself a review loop.

A reviewer told what not to find is not adversarial. If the dispatch you are writing contains any
"do not flag" steer, stop — that is the failure this gate exists to prevent, one layer up.

## Three layers (information asymmetry — each sees less, so each catches different things)

| Layer | Sees | Hunts for |
|---|---|---|
| **Blind Hunter** | the diff ONLY (no context) | bugs visible on the diff surface; smells |
| **Edge Case Hunter** | diff + repo read access | every branch/boundary/empty/error path |
| **Acceptance Auditor** | diff + `flow/05-contract.md` + `flow/03-prd.md` + the card | contract-shape violations, PRD acceptance gaps, missing specified behavior |

Run them as separate scoped subagents (or separate passes) so no single context biases the
others. The Acceptance Auditor is the one that catches producer/consumer drift — it checks
the diff's shapes against the contract.

## Optional 4th lens — Codex cross-MODEL reviewer (different vendor, not just different context)

The three lenses above differ by *information* but share one *model* (Claude) → correlated blind
spots. When the codex tier is USABLE (`codex-integration.md`), add a **cross-model** lens: run
`codex-companion.mjs review|adversarial-review [--base <ref>] [--scope working-tree|branch]`
(review/adversarial-review go through `codex-companion.mjs` — the `codex:codex-rescue` subagent
only forwards to `task`, so it is NOT a review path). A different engine (GPT-5.x) catches failure modes a
same-model panel structurally can't — cross-model review markedly outperforms same-model
self-review (gemini-cli study: 43% → 91% merge-ready), and same-model judges carry systematic
self-bias.

- **It INFORMS, never decides.** Codex returns a `ReviewResult` (`verdict`, `findings[]` with
  severity/confidence, `next_steps`). Feed its findings into the SAME triage below. The gate still
  judges; a Codex `needs-attention` never auto-fails a card and a Codex `approve` never auto-passes
  one. Apply the "do not blindly accept findings" rules to Codex output too.
- **When to spend it (cost gate — the SAME three triggers as `codex-integration.md`).** Run the
  Codex lens only on: a **security-class card review** (which also triggers the `security-reviewer`
  specialist lens — see `## Security-class lens selection` above), a **two-strikes** review deadlock, or an
  **explicit operator opt-in** — and only when the tier is USABLE. A suspicious same-model "all
  clear" (zero findings) is a good reason to *ask the operator to opt in* to a cross-check, **not**
  an automatic trigger — auto-firing on every zero-findings card would blow past the cost gate.
  Codex calls are billable (`codex-integration.md` §Cost gate).
- **Record the durable metric (S2).** Log whether the cross-model lens AGREED or surfaced a class
  the same-model panel missed: `flow.sh harness intervention add` (disagreement = a caught miss) or
  `intake`. This feeds the cross-model-catch-rate in `docs/quality-metrics.md` — the measured
  justification for keeping the lens.

## Optional 5th lens — Antigravity (Gemini-3) cross-vendor reviewer (a third vendor)

When the Antigravity tier is USABLE (`antigravity-integration.md`), add Gemini-3 as a further
cross-vendor lens — the SAME three triggers and cost/data gate as Codex. With Claude × GPT-5.x ×
Gemini-3 you get a **three-model** gate; three vendors rarely share one blind spot. Run it AFTER
Codex on a two-strikes deadlock (a third independent engine before escalating to the operator), or
in parallel on a security-class card / explicit opt-in. **Usability is stricter here:** `agy`'s exit
code lies (exit 0 + empty stdout even when unauthenticated), so route ONLY on non-empty expected
output, prefer the **interactive** path (IDE Agent Manager / real `agy` terminal, paste the
`ReviewResult` back), and treat an empty Gemini result as **"review unavailable", never an approval**.
Same parity rule: it INFORMS, never auto-passes/auto-fails. Log the same durable metric.

## Triage
Group every finding by severity x actionability:
- **Must-fix (correctness/contract/security)** -> Tier-B repair by a FRESH subagent before merge.
- **Should-fix (maintainability)** -> fix now if cheap, else note.
- **Observation** -> record, proceed.
Two-strikes: a second red review on the same card -> try the next USABLE cross-vendor engine
(Codex, then Antigravity) as a fresh-engine pass; if none usable or still red, escalate to the
operator, don't loop.

## Apply your own decision rules (do not blindly accept findings)
- Validate each finding against what the code actually does and protects. "Theoretically
  yes, practically no" findings are documented, not blindly fixed.
- A verified decision is not reversed by a review opinion alone — only by a NEW issue the
  verification missed, or changed context. Surface conflicts to the operator with the source.
- Security-class findings (auth/authz/data/payments) are never waved through — they are
  Tier-C: operator decides, in writing (`debt-and-halts.md`).
- No performative agreement. When a finding lands, do not answer "you're absolutely right" /
  "great catch" and then comply — that reflex launders a wrong finding into a change. State the
  adjudication: confirmed (→ fix) or refuted-with-reason (→ documented). Agreement is a verdict you
  reach, not a courtesy you extend.

## Output
A short report: findings by layer, triage, and the verdict (green / repair-needed /
escalate). On green, proceed to `flow.sh check` -> merge -> deploy -> live verify. Record a
`trace`; on a red that overrode an agent, record an `intervention`.

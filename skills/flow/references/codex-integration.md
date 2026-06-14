# Codex — cross-vendor second engine (the seam)

`/flow` reaches OpenAI **Codex (GPT-5.x)** through the `openai-codex` Claude Code plugin
(detected, never required). Codex is a *second engine*, not a replacement for the ck:→bmad→
built-in ladder: a genuinely different model used at the moments where that is worth more than
another Claude pass. This file is the single source of truth for the seam; `agent-detection.md`
(detection + priority), `agent-stage-mapping.md` (per-stage use), `adversarial-review.md`
(cross-model review), and `auto-run.md` (Tier-B escalation) point here for the shapes.

## Why a second vendor (the measured gap)

A single-vendor harness makes the builder and the reviewer share one model → correlated blind
spots pass green gates (this project's own review-pass-#4 caught an auth-skip a same-model pass
missed — `docs/quality-metrics.md`). Cross-model review empirically catches markedly more (a
gemini-cli study: single-model review 43% merge-ready vs cross-model iteration 91%). A different
engine is the cheapest way to close a same-vendor gate without weakening any gate.

## Detection (I1) — two states: INSTALLED vs USABLE (never route on "installed" alone)

Detection has **two states**, because "installed" does not mean "works" — a plugin can be present
with no valid auth (common in headless/CI — see Codex issue #9253) or a broken companion script.
Routing into Codex on mere presence would spend a billable repair/review attempt and then fail at
invocation — that violates "absence never breaks a run". So:

- **INSTALLED** — `codex:codex-rescue` is in the host agent registry, OR the plugin dir exists
  (`~/.claude/plugins/cache/openai-codex` / `.../marketplaces/openai-codex`). Necessary, not sufficient.
- **USABLE** — INSTALLED **and** a cheap, non-billable liveness/auth check passes:
  `codex-companion.mjs status [--json]` returns cleanly (or a confirmed prior successful call this
  session). Run this check **before the first time** you would route work to Codex.

**Selection rule:** only select the Codex tier when state = **USABLE**. If INSTALLED-but-not-USABLE
(or absent): **degrade** to ck:→bmad→built-in, announce `"codex tier unavailable (installed but
not authenticated / not reachable) — degraded to <path>"`, and record the reason (durable metric).
Never select Codex on INSTALLED alone. Degrading is silent-but-announced, never an error, never a
gate change. Downstream docs (`agent-detection.md`, `auto-run.md`, `adversarial-review.md`) all
mean **USABLE** wherever they say "eligible".

## Cost gate (F-D) — when Codex is allowed to fire

Codex calls are **billable** external GPT-5.x. Fire them ONLY at high-value moments:
- a **two-strikes deadlock** (a same-model agent BLOCKED twice),
- a **security-class card review** (auth/authorization/tenancy/payments/data-migration), or
- an **explicit operator opt-in** (e.g. "draft this stage on Codex", "/flow ... codex").

Never call Codex on every stage by default. Default engine stays ck:.

## Invocation surfaces (from flow/05-contract.md — do not improvise other shapes)

| Use | Invocation | Effects | Returns |
|---|---|---|---|
| **Handoff / rescue / primary-draft** | `Task(subagent_type="codex:codex-rescue", prompt=<ScopedBrief>)` | writes code (`--write` default), billable | stdout + status line |
| **Cross-model review** | `node "$CODEX/scripts/codex-companion.mjs" review\|adversarial-review [--wait\|--background] [--base <ref>] [--scope auto\|working-tree\|branch] [focus]` | read-only review, billable | `ReviewResult` JSON |
| **Task (non-interactive)** | `node "$CODEX/scripts/codex-companion.mjs" task [--background] [--write] [--model <m\|spark>] [--effort <none..xhigh>] <prompt>` | writes if `--write`, billable | stdout + job id |
| **Job control** | `... status [job-id] [--all] [--json]` · `result [job-id] [--json]` · `cancel [job-id]` | read-only / cancel | job/result JSON |

`$CODEX` = the plugin root (`~/.claude/plugins/cache/openai-codex/codex/<ver>`). Prefer the
`codex:codex-rescue` **subagent** for handoffs (it owns prompt-shaping + foreground/background
choice); use `codex-companion.mjs` directly only for `review`/`adversarial-review`/job-control.

### ScopedBrief (context isolation — orchestration-protocol)
Give Codex ONLY: `task` (one goal) · `read_for_context` (contract, law, the card, playbook) ·
`files_to_modify` (the card's Allowed files ONLY) · `acceptance` (the stage gate / card Verify) ·
`constraints` (contract is the seam; Vietnamese user-facing copy; touch only allowed files) ·
`return` (artifact + status). **Never** the session history.

### ReviewResult (verbatim from `schemas/review-output.schema.json`)
```
{ verdict: "approve"|"needs-attention", summary: string,
  findings: [ { severity:"critical"|"high"|"medium"|"low", title, body,
                file, line_start>=1, line_end>=1, confidence:0..1, recommendation } ],
  next_steps: [ string ] }
```

### Status protocol (handoff return)
`DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT` — handle BLOCKED/NEEDS_CONTEXT before retry.

## Gate parity (absolute) & auth (delegated)

- **Gate parity.** Codex DRAFTS or CRITIQUES; the identical stage gate (`flow.sh` + `gate-rules.md`)
  still judges. A cross-model review INFORMS triage — it never auto-passes or auto-fails a card.
- **Auth.** Delegated entirely to the plugin (`codex login` / `OPENAI_API_KEY` / ChatGPT
  subscription). `/flow` never reads, stores, or logs Codex credentials.

## Durable metric (S2)

After a Codex tier use, log it so the quality loop can read the trend (no new schema):
`flow.sh harness intervention add` (e.g. cross-model review found a class same-model missed) or
`intake` / `decision add`. This is the "thông số" that drives skill upgrades — see
`docs/quality-metrics.md` (cross-model-catch rate, rescue deflection rate).

## Announce the path

Always tell the operator which engine ran: `"review via Codex cross-model lens (needs-attention,
2 findings)"` / `"rescue via codex:codex-rescue after two strikes"` / `"codex tier unavailable —
degraded to code-reviewer"`. A run must stay legible.

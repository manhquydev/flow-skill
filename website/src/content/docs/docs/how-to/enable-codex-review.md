---
title: "Enable Codex cross-model review"
description: "Add OpenAI Codex as an optional second engine for review, and understand the cost and data trade-off first."
---

With the `openai-codex` plugin installed and authenticated, `flow` can route a few
high-value moments to a genuinely different vendor. It distinguishes *installed* from
*usable*: installed means the agent or plugin directory is present, usable additionally
requires a cheap non-billable probe reporting ready and logged in. Only a usable engine gets
routed to; otherwise `flow` degrades silently-but-announced to its normal ladder, so absence
never breaks a run. Because Codex calls are billable, exactly three triggers open the gate: a
two-strikes deadlock where a same-model agent blocked twice, a security-class card review,
and an explicit operator opt-in. Gate parity is absolute — Codex drafts or critiques, and the
identical stage gate still judges; a cross-model review informs triage and never auto-passes
or auto-fails a card. Read the trust boundary before enabling this on sensitive code:
authentication is delegated entirely to the plugin, and selecting Codex sends the diff and
contract or PRD excerpts to OpenAI under your plan's retention terms.

Detection, cost gate, result shape, and trust boundary:
[`skills/flow/references/codex-integration.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/codex-integration.md)

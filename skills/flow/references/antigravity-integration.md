# Antigravity — cross-vendor third engine (the seam)

`/flow` reaches Google **Antigravity (Gemini-3)** through the `agy` CLI and/or the Antigravity IDE
(detected, never required). Antigravity is a *third engine* alongside the ck:→bmad→built-in ladder
and the Codex (GPT-5.x) second engine — a genuinely different vendor's model used where a third
independent perspective is worth more than another Claude or Codex pass. This file is the single
source of truth for the seam; `agent-detection.md` (detection + priority) and `adversarial-review.md`
(cross-model review) point here for the shapes. It mirrors `codex-integration.md`; read that first.

## Why a third vendor

Cross-model review empirically catches more than single-model (a gemini-cli study: 43% vs 91%
merge-ready). flow already crosses Claude × Codex; adding Gemini-3 gives a **three-model** adversarial
gate — three vendors rarely share the same blind spot. Antigravity also runs natively as the
operator's daily IDE/CLI, so flow installed there is a portability win even before any review use.

## Detection — two states: INSTALLED vs USABLE (never route on "installed", and NEVER on exit code)

Antigravity needs the **strictest** usability check of any tier, because of a measured platform fact:

> **The `agy` exit code lies.** `agy -p "<prompt>"` returns **exit 0 with empty stdout** even when it
> is unauthenticated ("You are not logged into Antigravity") — the error surfaces only in
> `--log-file`. Non-TTY stdout capture is also empty (raw pipe and `winpty` both yield nothing on
> Windows Git Bash). Verified 2026-06-16. So exit code 0 means **nothing** here; only **non-empty,
> expected output** proves usability.

- **INSTALLED** — `agy` is on `PATH` (or `~/AppData/Local/agy/bin/agy`), or the IDE
  (`~/AppData/Local/Programs/Antigravity`), or `~/.gemini/` exists. Necessary, not sufficient.
- **USABLE** — INSTALLED **and** a liveness probe returns a **non-empty response containing an
  expected sentinel token** (e.g. ask `agy -p` to echo `FLOWPONG` and require that token in stdout).
  **Never** treat exit 0 as success; **never** treat empty stdout as success. If the probe is empty
  or the log shows "not logged into Antigravity" → state = NOT USABLE.

**Selection rule:** only select the Antigravity tier when state = **USABLE**. INSTALLED-but-not-USABLE
(unauthenticated, or non-TTY capture returns empty — common in headless/CI and in agent harnesses
that pipe stdout) or absent → **degrade** to Codex / ck:→bmad→built-in, announce
`"antigravity tier unavailable (installed but not authenticated / no capturable output) — degraded
to <path>"`, record the reason. Degrading is silent-but-announced, never an error, never a gate change.

## Headless capture is unreliable → interactive is the supported default

Because non-TTY `agy -p` capture is empty on this platform, the **supported** way to run a Gemini-3
cross-model review is **interactive**: the operator runs the review in the Antigravity IDE (Agent
Manager) or a real `agy` terminal and pastes the `ReviewResult` back to flow. The **headless** path
(`agy -p` from flow's runner) is offered ONLY behind a passing liveness probe; if the probe is empty,
flow must NOT fall back to "no findings = pass" — an empty Gemini result is **"review unavailable"**,
never an approval. This is the loud-degrade rule applied to a vendor whose exit code can't be trusted.

## Cost / data gate — when the Antigravity tier is allowed to fire

Gemini-3 calls are **billable** external inference and **send the diff + specs to Google's API**
(governed by the operator's Google/Gemini plan and its retention/training terms). Fire ONLY at
high-value moments, same closed set as Codex:
- a **two-strikes deadlock** (after Codex, if both a same-model and the second engine stall),
- a **security-class card review** (auth/authorization/tenancy/payments/data-migration), or
- an **explicit operator opt-in** (e.g. "review this on Antigravity", "/flow ... antigravity").

Never call Antigravity on every stage by default. Default engine stays ck:; second engine stays Codex.
For a sensitive/regulated/NDA'd codebase the operator must opt in knowingly — the code and specs leave
the machine to a third vendor.

## Invocation surfaces (do not improvise other shapes)

| Use | Invocation | Notes |
|---|---|---|
| **Liveness probe (USABLE check)** | `agy -p "echo token FLOWPONG" --print-timeout 30s` | require `FLOWPONG` in non-empty stdout; exit code is ignored (it lies) |
| **Interactive review (supported default)** | operator runs Antigravity IDE Agent Manager / real `agy` terminal, pastes back `ReviewResult` | the only path not blocked by non-TTY capture |
| **Headless review (gated on liveness)** | `agy -p "<review brief>" --log-file <f> --print-timeout <t>` | only if liveness passed; require non-empty output; empty = review-unavailable, NEVER a pass |
| **Skill install homes** | flow's installer deploys to CLI `~/.gemini/antigravity-cli/skills/flow` + IDE `~/.gemini/config/skills/flow`. Antigravity also recognizes shared `~/.gemini/skills/` and project `<root>/.agents/skills/flow`, but the installer does NOT write those (use them only for a manual/project copy). | same `SKILL.md` bundle Antigravity reads (no restructuring) |

`agy inspect` lists the config + skills Antigravity has loaded — use it to confirm flow is discovered.

### ScopedBrief / ReviewResult / Status protocol
Identical to `codex-integration.md`: give the engine ONLY task · read-for-context · files-to-modify ·
acceptance · constraints · return (never session history). Review output is coerced to the same
`ReviewResult` shape (verdict / summary / findings[] / next_steps). Handoffs return
`DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT`.

## Gate parity (absolute) & auth (delegated)

- **Gate parity.** Antigravity DRAFTS or CRITIQUES; the identical stage gate (`flow.sh` +
  `gate-rules.md`) still judges. A Gemini-3 review INFORMS triage — it never auto-passes or
  auto-fails a card.
- **Auth.** Delegated entirely to `agy`/the IDE (interactive `agy` login). `/flow` never reads,
  stores, or logs Antigravity credentials. An unauthenticated `agy` is NOT USABLE (see detection).

## Durable metric & announce

After an Antigravity tier use, log it (`flow.sh harness intervention add` / `decision add`) so the
quality loop can read the three-model-catch trend. Always announce which engine ran:
`"review via Antigravity (Gemini-3) cross-model lens (needs-attention, 2 findings)"` /
`"antigravity tier unavailable (not authenticated) — degraded to Codex"`. A run stays legible.

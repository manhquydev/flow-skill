# Stage 05 — Interface Contract (the seam)

Project type **skill**: the seam is the **agent-orchestration interface** between the `/flow`
semantic layer (Claude) and the Codex engine (`openai-codex` plugin v1.0.4). Build cards wire TO
this table; nothing improvises a Codex call shape outside it. Shapes are ground-truth (read from
the plugin's `--help` + `schemas/review-output.schema.json`).

## Gate — check ALL before `/flow next`
- [x] Every PRD feature maps to at least one INTERFACE below
- [x] Every interface has its INPUT and OUTPUT shapes written
- [x] Access/effects column filled for every interface
- [x] No FILL placeholders remain in this file

## OpenAPI / Swagger rule  (web only — N/A here)
N/A for `skill`. The "no producer/consumer drift" equivalent is the done-evidence: detection
selects the right tier, a live Codex call returns the contracted shape, and gate parity holds.

## Interfaces (the Codex seam — how `/flow` reaches the engine)

| Interface | Name / invocation | Access/Effects | Input shape | Output shape |
|---|---|---|---|---|
| **I1 Detect** | INSTALLED check (registry `codex:codex-rescue` OR `openai-codex` plugin dir) **then a REQUIRED non-billable `codex-companion.mjs setup --json` probe** (`ready` + `auth.loggedIn`) before first routing | read-only; no side effects | none (runtime registry/glob + setup probe) | `codex_usable: bool` (INSTALLED **and** auth-live) + reason; drives announce-the-path |
| **I2 Rescue / handoff** (F-A, F-C) | `Task(subagent_type="codex:codex-rescue", prompt=<scoped brief>)` | writes code (Codex `--write` default); external API call (billable) | scoped brief: task + files + acceptance + law/contract excerpts (NO session history) | agent stdout (Codex run result) + status line `DONE/DONE_WITH_CONCERNS/BLOCKED/NEEDS_CONTEXT` |
| **I3 Cross-model review** (F-B) | `node codex-companion.mjs review \| adversarial-review [--wait\|--background] [--base <ref>] [--scope auto\|working-tree\|branch] [focus]` | read-only review; external API call (billable) | git diff scope (base/scope) + optional focus text | JSON `ReviewResult` (see shapes) — `verdict`, `findings[]`, `next_steps[]` |
| **I4 Primary drafter** (F-E, opt-in) | same as I2 (`codex:codex-rescue --write`) OR `codex-companion.mjs task --write [--model] [--effort] <prompt>` | writes the stage artifact / card; external API call (billable) | the stage's scoped brief (acceptance = that stage's gate) | drafted artifact (file edits) + status line |
| **I5 Job control** | `codex-companion.mjs status [job-id] [--all] [--json]` · `result [job-id] [--json]` · `cancel [job-id]` | read-only / cancel | optional job-id | job state / result JSON |
| **I6 Durable metric** (S2) | `flow.sh harness intervention add` / `intake` / `decision add` after a Codex tier use | writes `.flow/harness.db` | tier used, stage, agreement/disagreement vs same-model | durable row (feeds quality-metrics loop) |

## Shared shapes (objects used by multiple interfaces)

```
ReviewResult (I3 — verbatim from schemas/review-output.schema.json):
  {
    verdict: "approve" | "needs-attention",
    summary: string,
    findings: [ {
        severity: "critical"|"high"|"medium"|"low",
        title: string, body: string,
        file: string, line_start: int>=1, line_end: int>=1,
        confidence: number 0..1,
        recommendation: string
    } ],
    next_steps: [ string ]
  }

ScopedBrief (I2/I4 — the delegation contract, per orchestration-protocol):
  task: one stage/card goal
  read_for_context: [ flow/05-contract.md, law/*, the card file, playbooks/<stack> ]
  files_to_modify: [ card ## Allowed files ONLY ]
  acceptance: the stage gate (gate-rules.md) or card ## Verify steps
  constraints: contract is the seam; Vietnamese user-facing copy; touch only allowed files
  return: drafted artifact + status

StatusProtocol (I2/I4 return):  DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT

Detection rule (I1):  codex tier is USABLE iff INSTALLED ((codex:codex-rescue in agent registry)
  OR (openai-codex plugin dir present)) AND a non-billable `codex-companion.mjs setup --json`
  probe reports ready + auth.loggedIn. INSTALLED alone is NOT sufficient (it would route then
  fail at the real call). If not USABLE -> degrade to ck:→bmad→built-in, announce "codex tier
  unavailable". Cost gate: I2/I3/I4 fire only at high-value moments (two-strikes deadlock,
  security-class review, or explicit operator opt-in) — never every stage. (Seam: codex-integration.md.)
```

## Feature → interface map

- **F-A** (rescue tier) → I1 (detect) + I2 (handoff) + I6 (log).
- **F-B** (cross-model review) → I1 + I3 (review JSON) + I6 (agreement/disagreement metric).
- **F-C** (auto Tier-B escalation) → I1 + I2 (fresh-engine repair) + I5 (job control in auto) + I6.
- **F-D** (graceful absence + cost discipline) → I1 (the degrade decision) + the cost gate on I2/I3/I4.
- **F-E** (opt-in primary drafter) → I1 + I4, gated by the identical stage gate; default ck:.

# Stage 04 — ADR (architecture decisions)

## Gate — check ALL before `/flow next`
- [x] Each decision has a one-line "why" and a one-line "what I rejected"
- [x] The NOT-doing list is written
- [x] Decisions cover: data storage, auth approach, deploy target
- [x] No FILL placeholders remain in this file

## Decisions

| # | Decision | Why | Rejected alternative |
|---|---|---|---|
| 1 | **Codex is a 4th tier in the existing detection ladder** (ck:→bmad→built-in→**codex**), selectable, not a replacement | reuses the proven detect-and-degrade contract; one design, no parallel system | A separate "vendor router" config — YAGNI, adds surface; rejected (S1 cut) |
| 2 | **Invoke via the plugin's own surface**: `Task(subagent_type="codex:codex-rescue")` for handoffs, `codex-companion.mjs review/adversarial-review` for cross-model review | the plugin already owns auth, background/foreground, JSON schema — don't re-implement | Hand-rolled `codex` CLI strings — duplicates the plugin, breaks on its updates; rejected |
| 3 | **Gate parity is absolute**: Codex drafts/critiques; the identical stage gate (flow.sh + gate-rules.md) still judges. Codex review *informs* triage, never auto-fails | `/flow`'s whole value is one honest gate per stage; a vendor path must not fork the gate | Letting Codex "approve/block" a card — would create two gates + sycophancy risk; rejected |
| 4 | **Data storage = the existing harness** (`.flow/harness.db`): log Codex tier use + cross-model review agreement/disagreement as `intake`/`intervention`/`decision`. No new schema | metrics-as-byproduct; feeds the upgrade loop the operator asked for | A new metrics file/table — duplicates the durable layer; rejected |
| 5 | **Auth = delegated to the plugin** (`codex login` / `OPENAI_API_KEY`, ChatGPT subscription). `/flow` never handles Codex credentials | secret-handling stays out of the skill; one less attack surface | `/flow` reading/storing an API key — violates secret-handling law; rejected |
| 6 | **"Deploy target" (skill analogue) = the change lands in `references/*.md` + `SKILL.md` + `README*`; runner untouched** | forbidden to edit `runner/flow.sh` mid-run; the integration is genuinely a semantic-layer concern | Editing the runner to add a native `flow codex` probe — forbidden during run; deferred to next release |
| 7 | **Codex-as-primary (F-E) is opt-in per stage; default stays ck:** | no regression for existing Claude-default users; widens vendor reach only when chosen | Codex-as-default — would surprise users + spend tokens unasked; rejected |

## NOT doing in v1 (and why it's safe to skip)

- **No per-stage cost router / cheapest-engine auto-selection** — one second engine at high-value
  moments is enough; routing is unproven need (YAGNI). Safe: adding it later is additive.
- **No native `runner/flow.sh` Codex probe / `flow doctor` Codex line** — forbidden to edit the
  runner during a run; documented at the semantic layer now, wired into the runner in a later
  release. Safe: detection works from the Claude/reference layer today.
- **No Codex credential handling in `/flow`** — the plugin owns auth. Safe: less surface, by design.
- **Codex not a default primary** — opt-in only. Safe: existing flows unchanged.

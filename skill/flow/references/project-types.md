# Project types — adapting the gates to what you're building

`/flow` was born web-shaped. Set the type with `flow.sh project-type <web|cli|library|skill>`
(stored in `PROJECT_TYPE`, default `web`). The type adapts three things: what the Contract
"seam" is, the standard card sequence, and — most importantly — what **done-evidence** means.
The *spirit* of every gate is unchanged ("done = proof in the world", "contract before
code"); only the shape of the proof changes.

## Per-type table

| Type | Contract seam (stage 05) | Done-evidence (the real proof) | Card sequence |
|---|---|---|---|
| **web** | HTTP endpoints (Method/Path/Auth/Request/Response); OpenAPI served | a live deployed URL + real curl output | scaffold+`/healthz` -> vertical slice (endpoint+page) -> backend -> contract-test -> UI mock -> frontend -> e2e |
| **cli** | commands + flags + output shapes + exit codes | the tool **installs and a real invocation returns the expected output + exit code** | scaffold+one real command -> subcommand groups -> tests -> install smoke on a clean dir |
| **library** | the public API surface (exported functions/types + their shapes) | the **public API imports + a usage example runs + coverage threshold met** | scaffold+core API -> rounds of API -> tests -> a runnable usage example -> publish dry-run |
| **skill** | the commands + files the agent reads (SKILL.md surface) | **installed into `~/.claude/skills` + a real run reaches its own done-definition** | scaffold+one runnable command -> references/law -> install -> a dogfood run |

## What stays the same (all types)
- Every PRD feature maps to an interface; every interface has its shapes written BEFORE code.
- "Tests pass" / "merged" is mid-pipeline, never done — done is the type's real-world proof above.
- The contract is the seam: producers build TO it, consumers FROM it; amend the contract first.

## Gate-wording note (known web-flavoring — see backlog #4)
The stage-05 gate text still says "endpoint" and "auth (public/token/admin)". For non-web
types, read "endpoint" as "interface/command" and replace the auth column with
"writes/side-effects" (the stage-05 preamble explicitly licenses this adaptation). The
`web`-only OpenAPI/Swagger rule is N/A for cli/library/skill — the equivalent "no drift"
check is the per-type done-evidence actually passing.

## Legitimate gate-skips
When a gate genuinely doesn't fit your type (e.g. the Research market-research items for an
internal tool), record it and skip honestly:
```
/flow debt add "skip 01-research" "<exposure>" "<close-before condition>"
/flow skip 01-research --reason "internal tool, no public market"
```
`skip` advances ONLY when an open DEBT line **names that exact stage** AND the reason is
non-security-class; `planning_complete` then tolerates that stage so `/flow card` is not
blocked forever. Guards (in order): the **contract (05) can never be skipped** — it is the
seam, adapt it per project type instead; a **security-class reason HALTS** (auth/authz/
admin/tenancy/payments/credential/permission/role/rbac/login/pii/data/migration/validation —
operator-only); and the DEBT must name the stage (an unrelated open DEBT will not unlock it).

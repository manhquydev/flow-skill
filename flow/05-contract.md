# Stage 05 — Interface Contract (the seam)

The contract is whatever sits between your core and its consumer. For a web app that's
API endpoints. For a CLI it's commands + flags + output shapes. Per the template's own
instruction ("keep the table's SPIRIT and adapt the columns to your project's shape"), the
table below is adapted to flow.sh COMMANDS. The "Auth" column is replaced with
"Writes/side-effects" (a local CLI has no auth surface).

## Gate — check ALL before `/flow next`
- [x] Every PRD feature maps to at least one endpoint below   (read "endpoint" as "command interface")
- [x] Every endpoint has request AND response shapes written  (read as "input + output/exit")
- [x] Auth column filled for every endpoint (public / token / admin)  (adapted to Writes/side-effects)
- [x] No FILL placeholders remain in this file

> DOGFOOD NOTE (finding #4, refined): the Contract PREAMBLE already adapts to CLI/plugin/
> pipeline — better than predicted. But the GATE WORDING ("endpoint", "auth: public/token/
> admin") and the entire "OpenAPI / Swagger rule" section below are web-only. A CLI builder
> is invited to adapt the table, then graded against HTTP vocabulary. The fix is project-type
> aware gate wording + a per-type done-evidence/contract note, not a rewrite of the stage.

## Commands (interface table, adapted from "Endpoints")

| Command (interface) | Feature | Input (flags) | Output + exit | Writes / side-effects |
|---|---|---|---|---|
| `flow.sh project-type` | F1 | (none) | prints current type (default `web`); exit 0 | none (read) |
| `flow.sh project-type <type>` | F1 | `web\|cli\|library\|skill` | `PASS: project type set to <type>`; exit 0; invalid -> exit 1 | writes `PROJECT_TYPE` file |
| `flow.sh skip <stage> --reason <text>` | F5 | stage id + reason | advances past the gate IF a matching open DEBT line exists AND stage is non-security-class; exit 0; else exit 1 + why | creates `flow/<next>.md`; marks stage debt-skipped |
| done-evidence guidance | F2 | reads `PROJECT_TYPE` | per-type text: web=live URL/curl; cli=install+invoke+exit code; library=public API+coverage; skill=install+a real /flow run | none (the Claude layer shows it) |
| contract guidance | F3 | reads `PROJECT_TYPE` | per-type "what the seam is": web=endpoints; cli=commands+flags+output; library=public API; skill=commands+files | none |
| card-sequence guidance | F4 | reads `PROJECT_TYPE` | per-type sequence (cli/skill: no /healthz/Swagger/deploy-URL; instead scaffold->one real command->tests->install smoke) | none |

## Shared shapes (objects used by multiple commands)

```
PROJECT_TYPE file: a single line, one of: web | cli | library | skill   (absent => web)
project_type contract (per type):
  web     -> { seam: "HTTP endpoints", done: "live URL + curl", sequence: "scaffold+/healthz -> slice -> backend -> contract-test -> mock -> frontend -> e2e" }
  cli     -> { seam: "commands+flags+output", done: "installs + invoke + expected exit codes", sequence: "scaffold -> one real command -> backend -> tests -> install smoke" }
  library -> { seam: "public API surface", done: "public API + coverage threshold + a usage example runs", sequence: "scaffold -> core API -> tests -> example/usage -> publish dry-run" }
  skill   -> { seam: "commands + files the agent reads", done: "install into ~/.claude/skills + a real /flow run reaches its own done", sequence: "scaffold -> one runnable command -> references -> install -> dogfood run" }
```

## Feature -> command map

- F1 (project type) -> `flow.sh project-type` (get/set)
- F2 (done-evidence) -> done-evidence guidance (reads PROJECT_TYPE)
- F3 (contract) -> contract guidance (reads PROJECT_TYPE)
- F4 (card sequence) -> card-sequence guidance (reads PROJECT_TYPE)
- F5 (skip) -> `flow.sh skip <stage> --reason`

## OpenAPI / Swagger rule  — N/A for project types web only

For `web`, the original OpenAPI rule applies (served spec = runtime artifact; contract-test
asserts agreement). For `cli`/`library`/`skill` there is no served spec; the equivalent
"no drift" check is the per-type done-evidence (the command actually runs / the API is
actually importable / the skill actually installs and runs). This N/A-for-non-web is itself
finding #4: the stage hard-codes a web artifact in its rule text.

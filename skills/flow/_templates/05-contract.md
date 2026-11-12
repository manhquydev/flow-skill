# Stage 05 — Interface Contract (the seam)

The contract is whatever sits between your core and its consumer. For a web app that's
API endpoints (the table below). For a CLI it's commands + flags + output shapes; for a
plugin it's hooks + filters; for a pipeline it's input/output file schemas. Keep the
table's SPIRIT — every feature maps to an interface, every interface has its shapes
written before code — and adapt the columns to your project's shape.

Written BEFORE any code. Backend cards build TO this table; UI cards consume FROM it.
The #1 AI-build failure is producer/consumer drift — backend ships one shape, UI assumes
another, both look green. This file is the cheap fix.

## Gate — check ALL before `/flow next`
- [ ] Every PRD feature maps to at least one INTERFACE below (web: endpoint · cli: command · library: public function · skill: command/file)
- [ ] Every interface has its INPUT and OUTPUT shapes written (web: request+response · cli: flags+output/exit code · library: args+return)
- [ ] Access/effects column filled for every interface (web: public/token/admin · non-web: writes/side-effects, or "none")
- [ ] No FILL placeholders remain in this file
- [ ] No unresolved open decisions (resolve via /flow clarify, or assume/cut)
- [ ] Every write interface names the failure shape (status or exit + body), not only the happy path
- [ ] Every interface that can return empty names the empty shape (empty list / 404 / exit 2), or an explicit `none`
- [ ] If this project declares a module/package system, the dependency-seam ledger below covers every cross-module/package reference; each required directed edge has a declared-graph cycle result
- [ ] If this project declares no module/package system, the dependency-seam ledger explicitly says `N/A`; do not invent owner facts
- [ ] Access/effects is a concrete token (web: public/token/admin · non-web: writes/side-effects or "none") — not a vibe word (secure, authenticated, restricted)

## OpenAPI / Swagger rule  (web only — N/A for cli/library/skill)

For non-web types there is no served spec; the equivalent "no producer/consumer drift" check
is the per-type done-evidence (the command runs / the API imports / the skill installs+runs).
For `web`:

This table is the PLANNING source of truth. If the framework serves a spec (FastAPI →
`/openapi.json` + `/docs`), the served spec is the RUNTIME artifact of this same contract:
- Path/method/shapes here and in the served spec must agree — the contract-test card
  asserts every endpoint in this table exists in the live `/openapi.json` with matching
  request/response shapes.
- Change flows ONE way: amend this file first, then the code, then the spec follows.
- **Docs land with the API, not after**: the served spec is live from the vertical-slice
  card onward, and every backend card's verify checks its endpoints appear in the live
  `/docs` with correct schemas. The contract-test card later asserts full agreement —
  but by then the docs have been growing card by card, never a catch-up task.
- Keep `/docs` enabled at least until v1 ships — it's the free human-readable contract.

## Interfaces  (web: endpoints · cli: commands · library: functions · skill: commands)

Adapt the columns to your project type. Web: Method/Path/Access(=auth: public/token/admin)/
Request/Response. CLI: Command/Flags/Access(=side-effects)/Input/Output+exit. Library:
Function/—/Access(=none)/Args/Return. The shared column below is "Access/Effects".

| Method/Interface | Path/Name | Access/Effects | Input shape | Output shape |
|---|---|---|---|---|
| GET | /healthz | public | none | 200 `{ok:true}` · empty: none · fail `{ok:false,error}` |
| [FILL] | [FILL] | [FILL] | [FILL] | [FILL] |

## Dependency-seam ledger (module/package systems only)

Use this section only when the project declares a module/package system (for example,
Odoo add-ons, workspace packages, plugins, or deployable modules). First record the declared
dependency graph that this contract relies on. Then ledger every cross-module/package symbol
reference before build. The ledger makes the host, symbol owner, and required direction reviewable
without guessing from names or code that does not exist yet. If the project declares no
module/package system, do not fill the table: write the explicit
`N/A — no module/package system declared` entry below instead.

| Host module/package | Referenced symbol/interface | Owning module/package | Required directed dependency | Creates a directed cycle in the declared graph? |
|---|---|---|---|---|
| [FILL] | [FILL] | [FILL] | `host -> owner` | [FILL: yes/no and the graph path] |

- Declared dependency graph: [FILL: module/package names and their direct dependencies]
- If a reference is local, write its owner as the host and its dependency as `same-module (N/A edge)`.
- If this project declares no module/package system, write `N/A — no module/package system declared`; do not infer owners from interface names.

## Shared shapes (objects used by multiple interfaces)

```
[FILL: e.g. (web)  Ticket { id, category, status: open|in_progress|resolved, created_at, ... }
       e.g. (cli)  --output json|table ; exit 0=ok 1=usage 2=error ]
```

## Feature → interface map

Reference each PRD feature by its `FRn` id so the mapping is machine-checkable
(`/flow consistency` flags any `FRn` with no interface here).

- [FILL: FR1 → interface(s) that serve it]

## Open decisions

Record unresolved product choices here (add a line like `- [ ] which tenant key?`). Do not invent auth, tenancy, retention, or billing to clear FILL. Resolve via /flow clarify, or assume/cut.

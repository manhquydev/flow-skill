# C-NNN — [FILL: one-line scope, ONE thing]

status: todo
<!-- status: todo|done (in-flight is cards/.inflight, not a status value) -->
deps: [FILL: card ids this depends on, e.g. "C-001, C-002" — or "none"]
implements: [FILL: PRD feature ids this card delivers, e.g. "FR1, FR2" — or "infra"/"none" for non-feature cards]
risk: unknown
<!-- risk: unknown|standard|security-class -->
risk-reason:
risk-ack: none

## Scope

[FILL: exactly what this card builds. If it's two things, split it.]

## Independent test

<!-- PASS: a user opens /g/demo-4person/balance and sees "Alice owes Bob $12.50". FLAG: unit tests pass -->
[FILL: one sentence — if only this card shipped, what can a user do? Or `infra` / `none` for scaffold/CI/contract-test/e2e plumbing. "Unit tests pass" is not an independent test.]

## Allowed files

[FILL: which files/dirs this card may touch — keeps the diff reviewable]

## Verify (run these before calling the card done)

- [ ] [FILL: command + expected output OR URL/path + observable user fact. Not "tests pass"]

## Done-evidence (world-state proof, named BEFORE building)

[FILL: what will be observable in the world when this is done — a URL you can click,
a curl output, a deployed page. "Tests pass" / "code merged" are NOT done-evidence.]
> Example of >=2 real world-state signals to paste under `## Evidence` when done: 1) live URL or created `.log`/`.txt`/image file path (e.g. `https://my-app.pages.dev/items` or `evidence/cli-smoke.log`) + 2) pasted command output & exit code (`$ mkdir -p evidence && node -e "console.log('ready')" > evidence/cli-smoke.log && cat evidence/cli-smoke.log` -> `ready`, `exit 0`), never just "I tested it".

## Evidence (paste the actual proof here when done)

<!-- Replace the placeholder line below completely with >=2 real world-state proofs (live URL or existing `.log`/`.txt`/image file path + re-run terminal output, see example above). Do not paste below the placeholder or quote the agent claiming tests ran. -->
(empty until done)

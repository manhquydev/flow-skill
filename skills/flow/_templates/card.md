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

## Evidence (paste the actual proof here when done)

<!-- Paste the re-run command output or re-read the path/URL. Do not quote the agent claiming tests passed. -->
(empty until done)

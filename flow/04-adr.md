# Stage 04 — ADR (architecture decisions)

Short. The most valuable section is what you are NOT doing and why.

## Gate — check ALL before `/flow next`
- [x] Each decision has a one-line "why" and a one-line "what I rejected"
- [x] The NOT-doing list is written
- [x] Decisions cover: data storage, auth approach, deploy target
- [x] No FILL placeholders remain in this file

## Decisions

| # | Decision | Why | Rejected alternative |
|---|---|---|---|
| 1 | Store the project type in a flat `PROJECT_TYPE` file at the project root | mirrors the existing `MODE` mechanism exactly; zero new deps; readable without python | a row in harness.db (heavier, needs python, breaks graceful-degrade) |
| 2 | Auth approach: NONE — flow.sh is a local gate runner with no network/secrets surface | there is nothing to authenticate; forcing an auth design would be cargo-culting | adding token/secret handling (pure overhead for a local CLI) |
| 3 | "Deploy target" for the skill type = `install.sh`/`install.ps1` copying into `~/.claude/skills/flow` | that IS how a Claude Code skill ships; the install + a working `/flow` run is its done-evidence | npm/plugin-marketplace publish (deferred; not needed to ship the fix) |

> DOGFOOD NOTE: decisions 2 and 3 are honest N/A-adaptations. The ADR gate mandates
> "auth approach" and "deploy target" for every project — sensible for a web app, mild
> friction for a local CLI where both are "none/install". Answerable, but it's a smaller
> instance of the same web-assumption. ("fits with adaptation".)

## NOT doing in v1 (and why it's safe to skip)

- Auto-detecting the project type — explicit `project-type` command first; a wrong guess is worse than asking.
- Per-type Research/PRD/ADR gate-template variants — bigger change; tracked as backlog #1.
- Automated done-evidence validators — v1 ships per-type guidance the Claude layer enforces; automation later.
- Editing the planning-stage templates — forbidden during a run; v1 adapts via the runner + references, not template edits.

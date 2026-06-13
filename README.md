# flow-skill — the `/flow` skill for Claude Code

Dev workspace for building **`/flow`**: a gated, harness-backed build process for Claude
Code that takes a product from **idea to a deployed URL** through honest gates. It
re-encodes the `buildflow` methodology and layers on durable harness records, agent
orchestration (ck: + bmad), and 2026 loop/harness-engineering principles.

> Status: **v1 complete** — Phases 1–6 done (engine, durable layer, agent integration,
> loop/harness principles, DESIGN law + playbooks, packaging). 46/46 tests green.
> See `plans/260613-1021-flow-skill-engine/plan.md`.

## What ships

```
skill/flow/
├── SKILL.md                  # command dispatch + semantic gatekeeper + agent orchestration
├── runner/flow.sh            # gate engine (exit 0/1): next/card/check/status/mode/ready/
│                             #   auto/retro/harness/debt/design
├── _templates/               # 00-idea .. 05-contract + card (verbatim buildflow)
├── law/                      # CLAUDE.md (build-session law), DESIGN.md (UI law), RETRO.md
├── references/               # 13 semantic playbooks (gates, agents, loop, adversarial,
│                             #   ground-truth, debt, design, ui-tcr, mode-work, auto-run)
├── harness/                  # durable layer: flow_harness.py + _db.py + _domain.py + schema
└── playbooks/                # 3 stack playbooks (read before / harvest after)
tests/run_all.sh              # 46 checks: runner(13) + harness(19) + scenarios(14)
install.sh / install.ps1      # install to ~/.claude or a project
```

## Try it without installing

```bash
# from any scratch directory you want to drive a build in:
export FLOW_PROJECT_ROOT="$(pwd)"
RUN="D:/project/flow/flow-skill/skill/flow/runner/flow.sh"
bash "$RUN" next        # unlock stage 00 (flow/00-idea.md) — fill it, check its gate boxes
bash "$RUN" next        # gate-check; advance on pass, list what's missing on fail
# ... walk stages 00..05 ...
bash "$RUN" card        # after all 6 gates pass: create cards/C-001.md
bash "$RUN" check C-001 # validate a card (status, sections, real done-evidence)
bash "$RUN" status      # where am I, what's blocking
```

The runner is the **mechanical layer** (catches unchecked gate boxes, `[FILL]`
placeholders, empty done-evidence). The **`/flow` skill** is the **semantic layer** — it
runs on top and catches what a script can't: fabricated research, grade-laundered scope,
pain↔feature gaps, world-state evidence vs "tests pass". A gate passes only when both agree.

## Install (Phase 6 will automate this)

Copy `skill/flow/` to one of:
- Global: `~/.claude/skills/flow/`  → usable in every project
- Per-project: `<project>/.claude/skills/flow/`  → versioned with the repo

Then in that project: type `/flow next`. (Windows: Git Bash is required for the runner.)

## Run the tests

```bash
bash tests/test_flow_runner.sh
```

## Provenance

Methodology: `ai20k-build-phase/buildflow` (Tony). Harness concepts: `repository-harness`.
Agents/packaging: `claudekit-engineer`. Method/review: `BMAD-METHOD`. 2026 principles:
`research-report-agent-orchestration-2026.md`.

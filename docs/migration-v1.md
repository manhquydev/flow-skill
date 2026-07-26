# Migration guide — flow v1 (graph executor)

**Status: not released.** This guide describes the breaking changes a future `v1.0.0`
will carry, written while the implementation is fresh. The current release still runs
with the graph executor **off by default** and still degrades gracefully without python.

## What changes at v1

### 1. Python becomes required

The durable layer and the graph executor are python (stdlib only — no third-party
packages, ever). Today a project without python still runs the mechanical engine; at v1
the executor becomes the ordering authority, so a missing interpreter is a hard stop
rather than a silent downgrade.

- **Measured floor: Python 3.7.** Not asserted — measured: the harness uses
  `subprocess.run(capture_output=…, text=…)` (3.7+) and nothing newer (no walrus, no
  `match`, no builtin generics). `scripts/release-preflight.sh` enforces this floor.
- Resolution accepts `python3` **or** `python` (Windows Git Bash commonly ships only
  `python`); a `python3`-only probe would brick working installs.
- Install: `apt install python3` / `brew install python` / python.org for Windows.

### 2. `FLOW_HARNESS_DISABLE` stops being an escape hatch

It currently disables all durable writes while the engine keeps running. Once the
executor owns ordering, "run but do not record" is a split-brain state, so the variable
becomes a startup error naming this guide. If you set it in a shell profile or CI, unset
it before upgrading.

### 3. Paused executions and topology upgrades

An execution records the topology hash it started under. If a skill upgrade changes the
shipped topology, `graph next` refuses rather than walking a chain recorded under
different semantics; `--force-retopology` forks onto the current topology and re-pins the
hash. Finish or fork in-flight runs before upgrading if you care about their journals.

## What does NOT change

- **Gate semantics.** `flow.sh` remains the mechanical ground truth; the executor records
  outcomes and computes ordering, never gate verdicts.
- **Skip governance.** `/flow skip` keeps its DEBT requirement, its security-class HALT,
  and its refusal to skip `05-contract`. The topology only *observes* `flow/.skipped`.
- **Card and stage file formats.** No card rewrite, no frontmatter change.
- **Zero third-party dependencies.**

## Rollback

Pin the previous major (`npm i -g @manhquy/flow-skill@0.x`, or check out the prior skill
tag). The schema is additive — a downgraded install ignores the graph tables, and no
existing row is modified — so a rollback loses executor journals but nothing else.

## Durable-state locations

`<project>/.flow/harness.db`, with one graph-era rule: a **linked git worktree** resolves
to its main worktree's DB, so parallel cards share one journal. Two shapes are
deliberately NOT translated (each keeps its own DB): submodules, and repos created with
`--separate-git-dir`, where git reports the git directory as the main worktree and the
checkout path is not discoverable — guessing there would put durable state inside `.git`.

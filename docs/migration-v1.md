# Migration guide — flow v1 (graph executor)

**Status: released as skill 1.0.0.** The breaking behavior was accepted on master (`794fd026141e23a29b5c79af072e7f4fd0bdc165`); the [GitHub `v1.0.0` release](https://github.com/manhquydev/flow-skill/releases/tag/v1.0.0) and [npm installer `1.0.0`](https://www.npmjs.com/package/@manhquy/flow-skill/v/1.0.0) are published, with npm `latest` at `1.0.0`.

## What changes at v1

### 1. Python becomes required

The durable layer and graph executor use Python's standard library only; no third-party
packages are required. At v1, Python is required for Flow product operations because the
graph executor owns ordering. Missing or too-old Python is an actionable refusal, never a
silent fallback to the legacy stage ladder. `flow doctor` remains available to diagnose
the missing prerequisite.

- **Measured floor: Python 3.7.** Not asserted — measured: the harness uses
  `subprocess.run(capture_output=…, text=…)` (3.7+) and nothing newer (no walrus, no
  `match`, no builtin generics). `scripts/release-preflight.sh` enforces this floor.
- Resolution accepts `python3` **or** `python` (Windows Git Bash commonly ships only
  `python`); a `python3`-only probe would brick working installs.
- Install: `apt install python3` / `brew install python` / python.org for Windows.

### 2. `FLOW_HARNESS_DISABLE` stops being an escape hatch

`FLOW_HARNESS_DISABLE` is not supported for product operations in v1. The runner refuses
startup and points to this guide rather than running without durable ordering/checkpoints.
Remove the variable from shell profiles and CI before upgrading. Help and doctor remain
available so the operator can identify the problem.

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

The last published pre-v1 pair is npm `0.7.16` (published 2026-10-22) with skill
`0.34.9`. To restore that pair, invoke the installer with its exact package pin, for example:
`npx @manhquy/flow-skill@0.7.16 --yes`; `npm install` alone does not copy or
replace installed skill files. Restart/reload the agent and run `flow doctor` to
verify the installed bundle. Confirm the release record for the exact
package-to-skill mapping before choosing a pin; do not infer skill version from
the npm package version. This restores the installer and bundled skill only; it
does not reverse database migrations.

The published v1 release passed the database backup and restore acceptance gate
before promotion; the [release changelog](../CHANGELOG.md) records the migration,
rollback, and CI evidence.
Schema additions alone do not prove rollback safety. Back up SQLite consistently
(including WAL state), retain the backup, stop active Flow workers before restoring, and
verify the restored database and project files. Do not overwrite newer user data blindly.
If a tested migration-specific restore is required, follow the exact released guide rather
than assuming reinstalling old installer bytes reverses database changes.

## Durable-state locations

`<project>/.flow/harness.db`, with one graph-era rule: a **linked git worktree** resolves
to its main worktree's DB, so parallel cards share one journal. Two shapes are
deliberately NOT translated (each keeps its own DB): submodules, and repos created with
`--separate-git-dir`, where git reports the git directory as the main worktree and the
checkout path is not discoverable — guessing there would put durable state inside `.git`.

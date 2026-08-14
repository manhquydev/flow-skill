---
title: "Versions: npm installer vs skill product"
description: "flow has two version numbers on purpose. One versions the installer CLI, the other versions the skill that gates your build."
---

`flow` publishes two version numbers, and they do not match. That is intentional, not drift.

| What | Current | What it versions |
|---|---|---|
| **Skill product** | `0.29.0` | The gates, `SKILL.md`, the runner, references, and templates — the thing that judges your build. |
| **npm installer** | `0.6.0` | The `@manhquy/flow-skill` CLI that copies the skill into your agent homes. |

Check both from your own machine rather than from any document:

```bash
npx @manhquy/flow-skill@latest --help
# flow-skill v0.6.0 (ships skill v0.29.0)

grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
# version: "0.29.0"
```

## Why two numbers

They version different artefacts with different change rates.

```
  monorepo skills/flow/  --npm run sync-->  npm-wrapper/skills/flow  --npm pack-->  registry
         |                                         |
         | install.sh / agent skill homes          | npx @manhquy/flow-skill@latest
         v                                         v
  ~/.claude/skills/flow                     same tree via installer CLI
```

The skill product is the harness itself. Its version drives the coherence check and the
telemetry field recorded in the durable layer, so a project can always say which gate
semantics it was built under. It changes whenever a gate, a stage, or a reference playbook
changes — which is often.

The npm package versions only the **installer CLI**: agent detection, the interactive
multi-select, where files get copied, the flags. That surface is small and stable. Publishing
a new installer version because a gate rule changed would be a lie about what changed, and
would force users to reason about a number that tells them nothing.

Collapsing the two would mean either bumping the installer for every gate change or freezing
gate versions to the installer's release cadence. Both are worse than explaining one table.

## The mistake this causes, and how to avoid it

The failure mode is pinning the wrong number:

```bash
# WRONG — 0.29.0 is the skill product, not a published npm package version
npx @manhquy/flow-skill@0.29.0

# Right — pin the installer if you need a fixed release
npx @manhquy/flow-skill@0.6.0

# Better for almost everyone
npx @manhquy/flow-skill@latest
```

Always use `@latest` when you want the newest skill. A bare `npx @manhquy/flow-skill` can be
served from the npx cache and quietly re-run an older copy. The `@rc` tag is retired; do not
use it.

## Which number matters to you

If you are **using** flow, the skill product version is the one that describes your
experience — it tells you which gates and which commands you have. The installer version only
matters when you are debugging an install or pinning a build.

If you are **reporting a problem**, give both. `--help` prints them together in one line,
which is why that line exists.

## Checking for drift inside a project

```
/flow coherence
```

This flags version drift across declared version fields — the cheap document-versus-code
slice of the drift lattice. It is advisory: it flags, it never auto-fixes.

## See also

- [Install CLI](/docs/reference/install-cli)
- [Install and first run](/docs/tutorials/install-and-first-run)
- [Changelog](/docs/reference/changelog)

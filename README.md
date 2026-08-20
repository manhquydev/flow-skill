# flow — gated build harness for coding agents

*Tiếng Việt: [README_VN.md](README_VN.md).*

[![npm](https://img.shields.io/npm/v/@manhquy/flow-skill?label=npm&color=cb3837)](https://www.npmjs.com/package/@manhquy/flow-skill)
[![website](https://img.shields.io/badge/website-flowskill.io.vn-1aa3c4)](https://flowskill.io.vn)
[![tests](https://img.shields.io/badge/tests-manifest.txt-brightgreen)](tests/manifest.txt)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions%20%C2%B7%203%20OS-blue)](.github/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Flow owns the gates and the receipts, never the runtime
([identity ADR](docs/adr/0001-discipline-layer-identity.md)). A mechanical
gate (`flow.sh`) and a semantic gate (`SKILL.md`) must both agree before a
stage advances. Kill at a gate is a valid, honored outcome.

`/flow` walks a product from idea to real done-evidence. Chat is the default
front door; typed verbs still work. Standalone — no AgentKit or claudekit
required.

| | |
|---|---|
| **Skill product** | **v0.31.0** |
| **npm installer** | [`@manhquy/flow-skill`](https://www.npmjs.com/package/@manhquy/flow-skill) **0.7.x** (`@latest` 0.7.0; `@next` prerelease 0.7.1-next.0 ships the skill above) |
| **Website** | **[flowskill.io.vn](https://flowskill.io.vn)** |
| **Tests / CI** | [`tests/manifest.txt`](tests/manifest.txt) · Ubuntu · macOS · Windows |
| **License** | MIT |

## Docs

[English](https://flowskill.io.vn/) ·
[Tiếng Việt](https://flowskill.io.vn/vi/) ·
[Docs](https://flowskill.io.vn/docs/) ·
[Tài liệu](https://flowskill.io.vn/vi/docs/)

## Install

**Requirement:** [Node.js](https://nodejs.org/) **≥ 22.14**.

```bash
npx @manhquy/flow-skill@latest
```

Always use `@latest`. Do not `npm i` the package alone — that does not copy
the skill. Do not pin `@0.31.0` on npm — that is the skill version, not the
installer.

Two version numbers (intentional): npm package = installer CLI; skill product
= `SKILL.md` `metadata.version`. `--help` prints both:
`flow-skill v0.7.1-next.0 (ships skill v0.31.0)`.

Walkthrough: [Install and first run](https://flowskill.io.vn/docs/tutorials/install-and-first-run/).
Flags: [npm-wrapper/README.md](./npm-wrapper/README.md).

## First run

Open a fresh agent session, say what you want to build, then type `/flow`
(Codex: `$flow`). Details:
[tutorial](https://flowskill.io.vn/docs/tutorials/install-and-first-run/).

## Everyday

```
/flow            status — where am I, what's blocking
/flow next       gate-check + unlock next stage
/flow assess     brownfield assessment
/flow card       create a build card
/flow check C-001  validate card (done = world-state proof)
/flow auto       autonomous build (halts on security-class)
/flow doctor     environment check
```

Full table: [`skills/flow/SKILL.md`](skills/flow/SKILL.md) ·
[docs/reference/commands](https://flowskill.io.vn/docs/reference/commands).

## Contribute

```bash
bash tests/run_all.sh    # suites from tests/manifest.txt
```

Release notes: [`CHANGELOG.md`](./CHANGELOG.md).

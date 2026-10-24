<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="brand/brand-lockup-dark.svg">
    <img src="brand/brand-lockup-light.svg" alt="flow — gated build harness for coding agents" width="560">
  </picture>
</p>

# flow — gated build harness for coding agents

*Tiếng Việt: [README_VN.md](README_VN.md).*

[![npm](https://img.shields.io/npm/v/@manhquy/flow-skill?label=npm&color=cb3837)](https://www.npmjs.com/package/@manhquy/flow-skill)
[![website](https://img.shields.io/badge/website-flowskill.io.vn-1aa3c4)](https://flowskill.io.vn)
[![tests](https://img.shields.io/badge/tests-manifest.txt-brightgreen)](tests/manifest.txt)
[![CI](https://github.com/manhquydev/flow-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/manhquydev/flow-skill/actions/workflows/ci.yml)
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
| **Skill product** | Release target **v1.0.0** (not a publication receipt) |
| **npm installer** | [`@manhquy/flow-skill`](https://www.npmjs.com/package/@manhquy/flow-skill) — release target **1.0.0**, intended channel `latest` (not a publication receipt) |
| **Website** | **[flowskill.io.vn](https://flowskill.io.vn)** |
| **Tests / CI** | [`tests/manifest.txt`](tests/manifest.txt) · Ubuntu · macOS · Windows |
| **License** | MIT |

## Docs

[English](https://flowskill.io.vn/) ·
[Tiếng Việt](https://flowskill.io.vn/vi/) ·
[Docs](https://flowskill.io.vn/docs/) ·
[Tài liệu](https://flowskill.io.vn/vi/docs/)

## Install

**Requirements:** [Node.js](https://nodejs.org/) **≥ 22.14** for installation; Flow v1 product operations require Python **≥ 3.7** (stdlib only). This is a pre-release target until the v1 implementation passes its acceptance gates.

```bash
npx @manhquy/flow-skill@latest
```

Always use `@latest`. Do not `npm i` the package alone — that does not copy
the skill. Historical skill versions are not necessarily npm package pins.

Skill product and npm installer now share one SemVer; `SKILL.md` is canonical.
`--help` preserves the compatible banner with equal versions:
`flow-skill v<package-version> (ships skill v<skill-version>)`.

Walkthrough: [Install and first run](https://flowskill.io.vn/docs/tutorials/install-and-first-run/).
Flags: [npm-wrapper/README.md](./npm-wrapper/README.md).

## First run

Open a fresh agent session in the top-level folder where Flow creates
`flow/` and `cards/` as you start using it (if you are
inside a subdirectory, move to the repository root first) — say what you want to build,
then type `/flow`
(Codex: `$flow`). Details:
[tutorial](https://flowskill.io.vn/docs/tutorials/install-and-first-run/).

## Everyday

```
/flow            status [--json] — where am I, what's blocking
/flow next       gate-check + unlock next stage
/flow assess     brownfield assessment
/flow card       create a build card
/flow check C-001  validate card (done = world-state proof)
/flow auto       autonomous build (halts on security-class)
/flow doctor     environment check
/flow resume    continue an existing Flow project in a fresh session (read-only)
```

Full table: [`skills/flow/SKILL.md`](skills/flow/SKILL.md) ·
[docs/reference/commands](https://flowskill.io.vn/docs/reference/commands).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for local dev setup, coding conventions, and PR flow.

```bash
bash tests/run_all.sh    # suites from tests/manifest.txt
```

## License

[MIT](LICENSE) © 2026 manhquydev.

Release notes: [`CHANGELOG.md`](./CHANGELOG.md).

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

## In plain words

Flow is a step-by-step quality checklist for your AI coding assistant
(**Idea -> Plan -> Small Tasks -> Real Working Proof**) so AI doesn't guess or
claim "done" when nothing works. Built for developers, students, and non-coders
learning Vibe Coding — chat naturally in English or Tiếng Việt.

| | |
|---|---|
| **Skill product** | Release target **v1.0.1** (not a publication receipt) |
| **npm installer** | [`@manhquy/flow-skill`](https://www.npmjs.com/package/@manhquy/flow-skill) — release target **1.0.1**, intended channel `latest` (not a publication receipt) |
| **Website** | **[flowskill.io.vn](https://flowskill.io.vn)** |
| **Tests / CI** | [`tests/manifest.txt`](tests/manifest.txt) · Ubuntu · macOS · Windows |
| **License** | MIT |

Publication status verified 2026-10-30: GitHub skill release v1.0.0 (2026-10-24) and npm installer 1.0.0 (2026-10-25); registry `latest` is 1.0.0. See the [migration guide](docs/migration-v1.md) for the verified pre-v1 rollback pair.

## Docs

[English](https://flowskill.io.vn/) ·
[Tiếng Việt](https://flowskill.io.vn/vi/) ·
[Docs](https://flowskill.io.vn/docs/) ·
[Tài liệu](https://flowskill.io.vn/vi/docs/)

## Install

**Requirements:**
- [Node.js](https://nodejs.org/) **>= 22.14** (to run the installer)
- [Python](https://www.python.org/) **>= 3.7** from python.org (`sqlite3` is built in, no `pip install`; on Windows, avoid the empty Microsoft Store `python` alias)
- **Git for Windows (includes Git Bash)** on Windows ([git-scm.com](https://git-scm.com/))

Run `/flow doctor` (Codex: `$flow doctor`) anytime to verify your setup.

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

1. Open your AI coding tool in your project's **main folder** (not a subfolder), where Flow uses or creates `flow/` and `cards/`.
2. Chat in plain English or Tiếng Việt (Codex: `$flow`): e.g. `/flow I want to build a class homework tracker web app` or `/flow mình muốn làm web nhắc bài tập cho lớp` (or `/flow assess` if the folder already has code).
3. Pick your pace: say **yes** to **`work` mode** (AI asks 5 quick questions, drafts stages `00–05`, pauses for your approval) or stay in **`teach` mode** (you fill files yourself: delete `[FILL: ...]` brackets completely, then change `- [ ]` to `- [x]`). Both modes enforce the exact same gates. Details: [tutorial](https://flowskill.io.vn/docs/tutorials/install-and-first-run/).

## Key terms in plain words

| Term | Plain meaning |
|---|---|
| `Gate` | Checkpoint before advancing; both script (`flow.sh`) and AI rules (`SKILL.md`) must pass. |
| `Kill at a gate` | Stopping a weak idea early to save wasted effort (does **not** delete your files). |
| `Card (C-001)` | One small, testable task created after planning stages `00–05` pass (or `debt-skip`). |
| `ADR & Contract` | Short notes on tech choices (`04-adr`) and agreed inputs/outputs (`05-contract`) before coding. |
| `World-state proof` | Real working proof (live URL or existing `evidence/cli-smoke.log` + command output & `exit 0`), replacing `(empty until done)`. |
| `Resume / Worktree` | `/flow resume` picks up where you left off; a worktree is a safe folder copy for parallel tasks. |

## Everyday

```
/flow            status [--json] — where am I, what's blocking
/flow next       gate-check + unlock next stage
/flow assess     brownfield assessment
/flow card       create a build card
/flow card done C-001  tick Verify [-x], replace (empty until done) with proof -> PASS done
/flow check C-001      validate current status (for done: set status: done + Verify + proof)
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

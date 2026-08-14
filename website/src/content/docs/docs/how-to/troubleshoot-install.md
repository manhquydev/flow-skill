---
title: "Troubleshoot an install"
description: "Fix the common flow install failures: no /flow command, a stale skill version, PowerShell path errors, and a disabled durable layer."
---

Work down this table first — most reports match one of these six rows.

| Symptom | Fix |
|---|---|
| No `/flow` after `npm i` | Run `npx @manhquy/flow-skill@latest`. You must **execute** the CLI; installing the package alone copies nothing into a skill home. |
| Old skill after a "reinstall" | Always use `@latest`. A bare package name can be served from the npx cache. |
| Claude or Codex does not list the skill | Fully restart the agent once after the first install. |
| `flow.sh: No such file` in PowerShell | Call `…/runner/flow.cmd`, not `bash`. |
| `durable layer DISABLED` | Install `python3`, or ignore it — the mechanical gates still run. |
| CRLF or "bad interpreter" | The repo enforces LF via `.gitattributes`; re-clone if line endings were mangled. |

## Start with doctor

```bash
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

`doctor` checks bash, python, grep, and git and reports the install paths it can see. A
`READY` result means the environment is fine and the problem is elsewhere — usually the agent
not having been restarted.

## "I installed it but there is no /flow"

Two distinct causes, in order of likelihood.

**You installed the package instead of running it.** `npm i @manhquy/flow-skill` adds a
package to a `node_modules` folder. It does not copy the skill tree anywhere an agent looks.
The installer is a CLI you execute:

```bash
npx @manhquy/flow-skill@latest
```

**You did not restart the agent.** Agents enumerate their skill directory at startup. Claude
Code needs a restart; Codex needs a restart and then `$flow` rather than `/flow`; Cursor and
Antigravity need a reload of the tool or IDE.

Confirm the files actually landed:

```bash
ls ~/.claude/skills/flow/SKILL.md
```

## "It installed an old version"

Check what you actually have, from the machine rather than from any document:

```bash
npx @manhquy/flow-skill@latest --help
# flow-skill v0.7.0 (ships skill v0.30.0)

grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
# version: "0.30.0"
```

If the installed skill version is behind the one `--help` reports, the copy step did not
reach that home — re-run the installer and select the agent explicitly.

Two pinning mistakes cause most stale installs:

- Pinning `@0.30.0` on npm. That is the **skill product** version, not a published npm
  package version. Pin the installer, for example `@0.7.0`, or use `@latest`.
- Using the `@rc` tag. It is retired and stale.

## Windows: PowerShell resolves the wrong bash

In PowerShell or cmd — including inside Codex — a bare `bash` usually resolves to WSL at
`C:\WINDOWS\system32\bash.exe`. WSL cannot read `C:/...` or `/c/...` paths, so it fails with
`No such file or directory` and the harness looks broken when it is not.

Use the launcher, which finds Git Bash and passes a path it accepts:

```powershell
& "$env:USERPROFILE\.codex\skills\flow\runner\flow.cmd" status
```

Only call `bash flow.sh` directly once you have confirmed that `bash` is Git Bash.

## "durable layer DISABLED"

This is a degraded mode, not a failure. The durable layer is a Python plus SQLite store for
intake, story, trace, decision, and backlog records. Without `python3` the mechanical gates
and every stage and card check still run — you lose cross-session memory, so `/flow recall`
has less to read back. Install `python3` to re-enable it.

## Installing without npm

For contributors or air-gapped machines, install from a git checkout:

```bash
bash install.sh global          # or: pwsh install.ps1 global  on Windows
bash install.sh project [dir]   # project-local Claude skill
```

The npm path is still the recommended one for everyone else. See
[Alternative install paths](/docs/how-to/alternative-install).

## Still stuck

Collect three things before asking for help: the full `doctor` output, the two version
numbers above, and the exact command with its error text. Open an issue at
[github.com/manhquydev/flow-skill](https://github.com/manhquydev/flow-skill/issues).

## See also

- [Install and first run](/docs/tutorials/install-and-first-run)
- [Install paths](/docs/reference/install-paths)
- [Install CLI](/docs/reference/install-cli)

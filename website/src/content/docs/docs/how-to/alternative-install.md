---
title: "Alternative install paths"
description: "Install flow from a git checkout, as a Claude plugin, or by hand when npm is not the right channel."
---

The npm installer, `npx @manhquy/flow-skill@latest`, is the recommended path for everyone.
The alternatives exist for contributors and air-gapped machines. From a git checkout,
`bash install.sh global` syncs every detected agent home and runs the doctor step, and
`bash install.sh project [dir]` installs a project-local Claude skill; on Windows use
`pwsh install.ps1 global` instead, since a bare `bash` in PowerShell is usually WSL and
cannot read Windows paths. Claude Code can also add the repository as a plugin marketplace
and install `flow@flow-marketplace`. The fully manual path is copying `skills/flow/` to
`~/.claude/skills/flow/` and making `runner/flow.sh` executable. Every channel writes the
same tree, so a project can switch between them without reissuing any gate or card.

Commands and platform notes:
[`README.md`](https://github.com/manhquydev/flow-skill/blob/master/README.md)

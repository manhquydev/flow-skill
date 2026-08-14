---
title: "Set the project type"
description: "Pick web, cli, library, or skill so the contract seam and done-evidence match what you are building."
---

`/flow project-type web|cli|library|skill` sets the type, stored in a `PROJECT_TYPE` file and
defaulting to `web`; running it with no argument prints the current value and the
done-evidence rule it implies. Set it before stage 05, because the type decides what the
contract describes — HTTP endpoints for web, commands and exit codes for a CLI, the exported
API surface for a library, the agent-readable command surface for a skill — and it decides
what proof the card gate will demand at the end. Changing it later means revisiting the
contract, so it is cheap now and expensive after.

Per-type seams, card sequences, and done-evidence:
[`skills/flow/references/project-types.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/project-types.md)

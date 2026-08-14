---
title: "Project types matrix"
description: "Contract seam, done-evidence, and card sequence for web, cli, library, and skill."
---

Set with `/flow project-type <web|cli|library|skill>`, stored in `PROJECT_TYPE`, default
`web`.

| Type | Contract seam (stage 05) | Done-evidence | Card sequence |
|---|---|---|---|
| `web` | HTTP endpoints — method, path, auth, request, response; OpenAPI served | A live deployed URL plus real `curl` output | scaffold and `/healthz`, vertical slice, backend, contract test, UI mock, frontend, e2e |
| `cli` | Commands, flags, output shapes, exit codes | The tool installs and a real invocation returns the expected output and exit code | scaffold plus one real command, subcommand groups, tests, install smoke on a clean directory |
| `library` | The public API surface — exported functions and types with their shapes | The public API imports, a usage example runs, coverage threshold met | scaffold plus core API, rounds of API, tests, a runnable usage example, publish dry-run |
| `skill` | The commands and files the agent reads | Installed into the skill home and a real run reaches its own done-definition | scaffold plus one runnable command, references and law, install, a dogfood run |

Constant across all four types: every requirement maps to an interface, every interface has
its shapes written before code, the contract is the seam, and "tests pass" or "merged" is
never done.

Source, including the known web-flavouring of some stage-05 gate wording:
[`skills/flow/references/project-types.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/project-types.md)

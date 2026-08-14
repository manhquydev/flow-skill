---
title: "System architecture"
description: "The three cooperating layers, the on-disk artifacts, and the two distribution channels."
---

`flow` is built as three cooperating layers plus on-disk artifacts, so that a fast
deterministic engine handles the cheatable mechanics while the model handles judgment and
durable records survive sessions. The semantic layer is `SKILL.md` and its reference
playbooks. It calls the mechanical layer, `runner/flow.sh`, whose exit code is ground truth,
and which owns the stage and card lifecycle, gate checks, the debt ledger, the design check,
and harness passthrough. Underneath, the durable layer is a flow-owned Python and SQLite CLI
holding intake and risk lane, story and proof, trace and tier, decisions, and backlog; it
degrades gracefully when Python is absent. The artifacts themselves live in the project being
built: `flow/00-idea.md` through `05-contract.md`, `cards/C-NNN.md`, the mode and ledger
files, and `.flow/harness.db`.

Distribution is two parallel channels feeding the same canonical tree. The npm installer is
the primary path, pure Node with no shell requirement, and the repository install script is
the reference implementation used in development and CI. Both write the same skill home, so a
project can switch channels without reissuing a gate.

Full diagrams and the component table:
[`docs/system-architecture.md`](https://github.com/manhquydev/flow-skill/blob/master/docs/system-architecture.md)

---
title: "Drift commands"
description: "The four advisory drift checks and the axis each one covers."
---

All four flag and never auto-fix. Together they form a lattice: versions, URLs, design
tokens, and whether the artifacts still trace to each other.

| Command | Axis | What it reports |
|---|---|---|
| `/flow coherence` | versions | Version drift across declared version fields — the cheap document-versus-code slice |
| `/flow contract` | URLs | Client base-URL versus served-path prefix drift, the double-`/api` and mixed-prefix class (web) |
| `/flow tokens` | design | `DESIGN.md` declared tokens against the CSS actually used: unused tokens, value mismatches, orphan variables |
| `/flow consistency` | traceability | Every PRD `FRn` claimed by a card and served by a contract interface, a numeric success metric, no leftover placeholders |

`/flow design <file>` is a related mechanical check on a single UI file rather than a
project-wide sweep. Run `consistency` and `coherence` after the contract gate and before
cutting cards; run `contract` and `tokens` while building the surfaces they describe.

Descriptions and timing:
[`README.md`](https://github.com/manhquydev/flow-skill/blob/master/README.md)

---
title: "Run drift checks"
description: "Four advisory checks that flag the ways documents and code quietly stop agreeing."
---

`/flow contract`, `/flow tokens`, `/flow coherence`, and `/flow consistency` each flag one
axis of drift and never auto-fix anything. `contract` catches client base-URL versus
served-path prefix drift — the double-`/api`, mixed-prefix class that schema diffing tools
miss. `tokens` compares tokens declared in `DESIGN.md` against the CSS actually used,
reporting unused tokens, value mismatches, and orphan variables. `coherence` flags version
drift across declared version fields, the cheap document-versus-code slice. `consistency`
audits whether the artifacts still trace to each other: every PRD requirement claimed by a
card and served by a contract interface, a numeric success metric present, no leftover
placeholders. Run the last two after the contract gate and before cutting cards.

Descriptions and when to run each:
[`README.md`](https://github.com/manhquydev/flow-skill/blob/master/README.md)

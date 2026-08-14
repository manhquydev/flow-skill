---
title: "Enable Antigravity cross-model review"
description: "Add Google Antigravity as an optional third engine, and why its review runs interactively by default."
---

Antigravity, via the `agy` CLI or the Antigravity IDE, is the third cross-vendor engine, used
at the same high-value moments as Codex so that a review can be judged by three models that
rarely share a blind spot. It gets the strictest usability check of any tier for a measured
reason: `agy -p` returns exit code 0 with empty stdout even when unauthenticated, with the
error landing only in the log file. So `flow` routes to Antigravity only on non-empty
expected output, never on the exit code, which lies. Because headless capture is unreliable,
the supported default is interactive — run the review in the IDE Agent Manager or a real
terminal and paste the result back. An empty Gemini result means "review unavailable" and is
never an approval. The same billable and data-leaves-the-machine cost gate and the same
absolute gate parity apply as with Codex.

Install homes, usability check, and review shape:
[`skills/flow/references/antigravity-integration.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/antigravity-integration.md)

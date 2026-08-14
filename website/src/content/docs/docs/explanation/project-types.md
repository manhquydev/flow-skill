---
title: "Project types"
description: "Why one harness can gate a web app, a CLI, a library, and a skill without weakening any gate."
---

`flow` was born web-shaped, and the honest way to support other kinds of software was not to
generalise the gates into vagueness but to name exactly which three things change. The
project type adapts the stage 05 contract seam, the standard card sequence, and what
done-evidence means. Everything else — every gate's spirit, "contract before code", "done is
proof in the world" — is untouched. That is why a CLI build is not a diluted web build: the
proof it must produce is just as concrete, it simply takes the shape of an installed tool and
a real exit code rather than a deployed URL.

There is one honest wrinkle worth knowing. Some stage-05 gate wording still says "endpoint"
and asks for an auth column, which is web flavouring. For other types you read "endpoint" as
"interface" or "command" and substitute writes and side-effects for auth — the stage preamble
explicitly licenses that adaptation, and the equivalent no-drift check is the per-type
done-evidence actually passing.

Per-type table, card sequences, and the gate-wording note:
[`skills/flow/references/project-types.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/project-types.md)

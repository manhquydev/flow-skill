---
title: "Unlock a stale session"
description: "Clear a flow/.lock left behind by a crashed session, without stomping a live one."
---

`flow` allows one session per project, because two sessions sharing one plan will overwrite
each other's state. The runner keeps a `flow/.lock`: mutating commands such as `next`, `card`,
`skip`, and `auto` refuse a fresh foreign lock, `status` warns, and the lock auto-reclaims
after its TTL — 900 seconds by default. If a terminal crashed or a session was abandoned,
`/flow unlock` clears it. If the other session might still be live, stop and coordinate
instead; never force past a running session. For hard protection rather than a warning,
export a stable `FLOW_SESSION_ID` once per session and pass it on every call — without it the
runner cannot prove a different session is running, so it can only warn and never self-block.

Lock semantics and environment overrides:
[`skills/flow/SKILL.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/SKILL.md)

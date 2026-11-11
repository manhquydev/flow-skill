---
name: flow
description: Use Flow to inspect project planning stages, execute scoped cards, and verify evidence-backed gates.
---

# Flow project skill pointer

For project Codex/Gemini discovery, this pointer lives in `.agents/skills/flow/SKILL.md`.
This target is only for repositories with the canonical Flow bundle checked into project-root `skills/flow`; global installs and `.claude/skills/flow` alone do not satisfy this prerequisite.
Read [the canonical skill](../../../skills/flow/SKILL.md) (`skills/flow/SKILL.md` from project root) before acting; it remains the source of truth. Do not copy its instructions here or treat this pointer as an additional runtime.

Set `<skill-dir>` to that canonical bundle directory (`skills/flow`). From the project root, invoke `bash <skill-dir>/runner/flow.sh <command>` using the hosting agent or operator; Flow does not own the runtime.
Follow the canonical skill dispatch, active card allowed files, gates, and evidence requirements. Keep Claude discovery in its separate `.claude/skills` path.

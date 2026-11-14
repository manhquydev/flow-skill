---
name: flow
description: Run the buildflow gated build process from idea to real done-evidence. Walk gated stages (Idea->Research->Scope->PRD->ADR->Contract->Cards->Build->Review->Deploy/Ship->Verify->Retro), each with a honest gate that must pass before advancing. Adapts to project type (web|cli|library|skill). Use when starting or driving a real product build, when the user types /flow, /flow next, /flow card, /flow check, or asks to scope/plan/ship a project through gates. Kill at any gate is a valid outcome.
---

# Flow project skill pointer

For project Codex/Gemini discovery, this pointer lives in `.agents/skills/flow/SKILL.md`.
This target is only for repositories with the canonical Flow bundle checked into project-root `skills/flow`; global installs and `.claude/skills/flow` alone do not satisfy this prerequisite.
Read [the canonical skill](../../../skills/flow/SKILL.md) (`skills/flow/SKILL.md` from project root) before acting; it remains the source of truth. Do not copy its instructions here or treat this pointer as an additional runtime.

Set `<skill-dir>` to that canonical bundle directory (`skills/flow`). From the project root, invoke `bash <skill-dir>/runner/flow.sh <command>` (macOS / Linux / Windows Git Bash) or `<skill-dir>\runner\flow.cmd <command>` (Windows PowerShell or cmd, including inside Codex; bare `bash` may resolve to WSL and cannot read `C:/` paths) using the hosting agent or operator; Flow does not own the runtime.
Follow the canonical skill dispatch, active card allowed files, gates, and evidence requirements. Keep Claude discovery in its separate `.claude/skills` path.

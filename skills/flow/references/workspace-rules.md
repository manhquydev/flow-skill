# Workspace Rule Scaffolding for Multi-Harness Integration

This document defines the exact rule templates and target file conventions for integrating Flow's build discipline into coding agent harnesses that do not yet have a dedicated runtime hook or native skill discovery engine.

> **Crucial Distinction: Rule Scaffolding vs Native Installation**  
> Rule scaffolding is **markdown instruction guidance**. It injects directives into the LLM's workspace context prompt. It does **not** install runner binaries, register native subagents, or execute hooks. Native execution still requires the hosting agent to invoke `bash skills/flow/runner/flow.sh <verb>` (or use `npm-wrapper` global skills).

### Overwrite Safety Contract
`flow rules <harness> --write` creates rule scaffolding only if the destination file does not yet exist. If the target file already exists (such as a customized `.aider.conf.yml`, `.roomodes`, or `.cursor/rules/flow.mdc`), `flow rules` **strictly refuses** with exit code 1 to avoid clobbering user configuration.

---

## 1. Harness Target Matrix

| Harness | Target Rule Path | Format / Convention | Purpose |
|---|---|---|---|
| **agent-skills** | `.agents/skills/flow/SKILL.md` | Standard skill pointer Markdown (Codex/Gemini discovery) | Points to the canonical project-local `skills/flow/SKILL.md` — not a runtime or a copy; requires the bundle checked into project root; Claude `.claude/skills` stays separate. |
| **agents-md** | `AGENTS.md` | Repository-level Markdown directives | Standing Flow build-discipline instructions for any harness that reads AGENTS.md. |
| **Cursor** | `.cursor/rules/flow.mdc` | MDC with YAML frontmatter + Markdown directives | Scopes Flow discipline to `flow/**`, `cards/**`, and source files. |
| **Windsurf** | `.windsurf/rules/flow.md` | Concise Markdown (< 3,000 characters) | Instructs Cascade to check gate status and card checklists before modifications. |
| **Roo Code** | `.roomodes` | JSON custom mode declaration | Declares a specialized `flow` mode with execute permissions for the runner. |
| **Cline** | `.clinerules` | Markdown directives | Standing system directives for autonomous Cline tasks. |
| **Aider** | `.aider.conf.yml` | YAML configuration | Configures `test-cmd` to run `flow check` as the auto-test gate. |
| **OpenHands** | `.openhands/microagents/flow.md` | Microagent Markdown with triggers | Guides OpenHands repository tasks to execute project-local runner inside Docker. |
| **GitHub Copilot** | `.github/copilot-instructions.md` | Repository-level Copilot Markdown | Guides Copilot Workspace and Copilot Chat to adhere to Flow card contracts. |

---

## 2. Rule Templates

### 2.1 agent-skills (`.agents/skills/flow/SKILL.md`)

Emits a standard skill pointer for project Codex/Gemini discovery. The pointer references the
canonical `skills/flow/SKILL.md` in the project root — never a runtime install or a content
copy — so Claude's separate `.claude/skills` home stays untouched. Requires the canonical
bundle checked into project-local `skills/flow` (`skills/flow/SKILL.md` +
`skills/flow/runner/flow.sh`); `--write` refuses without them. Per the Overwrite Safety
Contract above, `--write` creates the pointer only when the destination does not yet exist
and refuses an existing file or symlink.

### 2.2 agents-md (`AGENTS.md`)

Scaffolds repository-level `AGENTS.md` with Flow build-discipline directives (stage flow,
honest gates, card execution, ground-truth runner commands). `--write` creates it only when
`AGENTS.md` does not yet exist and refuses an existing file or symlink, per the Overwrite
Safety Contract above.

### 2.3 Cursor (`.cursor/rules/flow.mdc`)

```markdown
---
description: Flow buildflow discipline layer and gated execution engine
globs: flow/**,cards/**,*.md,src/**
alwaysApply: false
---

# Flow Discipline Rules for Cursor

You are operating inside a repository managed by Flow (`/flow`).
Flow turns coding agents into evidence-gated, kill-honest build processes.

## Rules of Engagement
1. **Never edit files without an active card.** Check in-flight cards via `bash skills/flow/runner/flow.sh status`.
2. **Always inspect gates before coding.** Run `bash skills/flow/runner/flow.sh next` or `bash skills/flow/runner/flow.sh check C-NNN`.
3. **Respect Allowed Files.** Only modify files explicitly listed in the active card's `## Allowed files` section.
4. **Never fake verify proof.** Paste real terminal output, exit codes, and URLs into `## Evidence`.
```

### 2.4 Windsurf (`.windsurf/rules/flow.md`)

```markdown
# Flow Discipline Rules for Windsurf Cascade

Cascade must respect Flow repository gates and evidence requirements.

1. **Orientation**: Before modifying code, run `bash skills/flow/runner/flow.sh resume` to inspect recent session transitions and active cards.
2. **Stage Progression**: Planning advances through stages (`00-idea` through `05-contract`). Do not advance without passing gates (`bash skills/flow/runner/flow.sh next`).
3. **Card Execution**: When implementing a card (`cards/C-NNN.md`):
   - Confine changes to `## Allowed files`.
   - Run verify commands listed in `## Verify`.
   - Verify card passage with `bash skills/flow/runner/flow.sh check C-NNN`.
4. **Clean Exit**: Do not claim work is complete until `flow check` returns exit code 0.
```

### 2.5 Roo Code (`.roomodes`)

```json
{
  "customModes": [
    {
      "slug": "flow",
      "name": "Flow Discipline",
      "roleDefinition": "You are a disciplined software engineer operating under Flow gates. You never write code without an active card and you verify all changes against card criteria.",
      "groups": [
        "read",
        ["edit", { "fileRegex": "^(cards/.*|src/.*|tests/.*|flow/.*)$", "description": "Flow and source directories" }],
        ["command", { "commandRegex": "^bash skills/flow/runner/flow\\.sh.*", "description": "Flow runner execution" }]
      ]
    }
  ]
}
```

### 2.6 Cline (`.clinerules`)

```markdown
# Flow Discipline Rules for Cline

1. Before starting tasks, execute `bash skills/flow/runner/flow.sh status` to identify the active stage and card.
2. If planning is in progress, do not modify application code. Complete stage artifacts in `flow/` first.
3. If building a card:
   - Read `cards/C-NNN.md`.
   - Strictly honor `## Allowed files`.
   - Execute verification tests with `bash skills/flow/runner/flow.sh check C-NNN`.
4. Never mark a card done without real, verified command output in `## Evidence`.
```

### 2.7 Aider (`.aider.conf.yml`)

```yaml
# Aider configuration for Flow discipline layer
test-cmd: "bash -c 'cid=$(tr -d \" \\r\\n\" < cards/.inflight 2>/dev/null); if [[ \"$cid\" =~ ^C-[0-9]+$ ]]; then bash skills/flow/runner/flow.sh check \"$cid\"; else bash skills/flow/runner/flow.sh status; fi'"
auto-test: true
```

### 2.8 OpenHands (`.openhands/microagents/flow.md`)

```markdown
---
name: flow
triggers:
  - "/flow"
  - "flow"
  - "card"
  - "gate"
---

# Flow Microagent for OpenHands

When working on this repository, execute all Flow commands using the project-local script inside the container:
`bash skills/flow/runner/flow.sh <command>`

Key commands:
- `bash skills/flow/runner/flow.sh status` — inspect current stage and in-flight cards.
- `bash skills/flow/runner/flow.sh next` — advance planning stage.
- `bash skills/flow/runner/flow.sh check C-NNN` — verify card criteria and gates.
```

### 2.9 GitHub Copilot (`.github/copilot-instructions.md`)

```markdown
# GitHub Copilot Instructions for Flow

This repository enforces Flow discipline:
- Planning artifacts live under `flow/` (`00-idea.md` through `05-contract.md`).
- Units of work are tracked as atomic markdown cards in `cards/C-NNN.md`.
- Never modify files outside a card's declared `## Allowed files`.
- Verification requires reproducible commands documented under `## Verify`.
- Mechanical ground truth is `bash skills/flow/runner/flow.sh check C-NNN`.
```

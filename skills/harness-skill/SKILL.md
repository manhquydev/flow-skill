---
name: harness
description: >-
  Cổng durable harness cho flow projects (Claude Code + Codex). Prefer /flow harness
  (Python). Complete-only story status. Optional legacy harness-cli binary is archive-only.
  Kích hoạt khi cwd có flow project hoặc scripts/bin/harness-cli(.exe) hoặc user gõ /harness.
  Không code.
---

# Harness — compliance gate (canonical in-repo)

**Live authority:** flow durable Python (`/flow harness` → `skills/flow/harness/flow_harness.py`)
+ mechanical `flow.sh` + semantic `gate-rules.md`.  
**Historical:** pre-EOL repository-harness protocol v1 is archive only (last published
`harness-cli-v0.1.22`). See `skills/flow/harness/GAP-MATRIX-0.1.17.md` (SUPERSEDED).

Install optional copy to `~/.agents/skills/harness` for global discovery; this file is the
**CI-tested** source of truth under `flow-skill/skills/harness-skill/`.

## Scope guard

- Prefer **flow projects**: use `/flow harness …` (Python backend).
- If cwd has **neither** a flow project (`.flow/` or `flow/`) **nor**
  `scripts/bin/harness-cli` / `harness-cli.exe` → early-exit (not a harness task).
- Non-dev questions → early-exit; do not force intake.

## Before any mutation

1. On flow projects: `flow.sh harness query matrix` (or `/flow harness query matrix`).
2. Legacy archive binary (if present): optional `harness-cli query contract --json` —
   **not** required; not a live product pin.
3. Read-only requests (explain, review, status) must **not** intake/trace/bootstrap.

## Story status (trust)

- **Forbidden:** `story update --status implemented`
- **Required:** `story complete` with proof **or** flow-native  
  `story complete --id … --proof-source card_markdown_gate|manual|verify_command`
- Never forge shell verify pass from markdown alone.

## SQL

- If using `query sql` on an archive binary: treat as **read-only**. Mutating SQL is a trust violation.

## Lane (FEATURE_INTAKE spirit)

Hard gates (auth, authz, data model, audit, external provider behavior, removing validation) → high_risk.  
Scout files before classifying; draft → user confirm → CLI.

## Trace

Match TRACE_SPEC tier to lane. Link `--intake` id. Honor-system: only `outcome completed` with real evidence.

## Flow projects

If project uses `/flow` durable Python layer (`.flow/harness.db` with usage lineage):  
**do not** set `FLOW_HARNESS_BACKEND=rust` — refuse-forward protects schema collision (009–012).  
See `skills/flow/harness/GAP-MATRIX-0.1.17.md`.

## Menu (empty invoke)

- Start task → intake + lane  
- Complete task → story complete + trace  
- Decision / friction / status (`query matrix`)  
- Improve skill guidance → ritual **R-IMPROVE-HARNESS** (`native-rituals.md`)

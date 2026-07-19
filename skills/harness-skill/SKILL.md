---
name: harness
description: >-
  Cổng tuân thủ harness (Claude Code + Codex). Intake → lane → (agent implements) → trace.
  Pin CLI harness-cli-v0.1.17 (protocol floor v0.1.14). Complete-only story status.
  Kích hoạt khi cwd có scripts/bin/harness-cli(.exe) hoặc user gõ /harness. Không code.
---

# Harness — compliance gate (canonical in-repo)

**Authority:** [repository-harness](https://github.com/hoangnb24/repository-harness)  
**Pins:** protocol floor `harness-cli-v0.1.14` · trust CLI **`harness-cli-v0.1.17`** · **never** `0.1.16` assets.

Install optional copy to `~/.agents/skills/harness` for global discovery; this file is the **CI-tested** source of truth under `flow-skill/skills/harness-skill/`.

## Scope guard

- If cwd has **neither** `scripts/bin/harness-cli` / `harness-cli.exe` **nor** a flow project using `/flow harness` → early-exit (not a harness task).
- Non-dev questions → early-exit; do not force intake.

## Before any mutation

1. Prefer: `harness-cli query contract --json` (discover protocol / schema / capabilities).
2. Require awareness of protocol_version 1 when using machine orchestration.
3. Read-only requests (explain, review, status) must **not** intake/trace/bootstrap.

## Story status (trust)

- **Forbidden:** `story update --status implemented`
- **Required:** `story complete` with proof (upstream) **or** flow-native  
  `story complete --id … --proof-source card_markdown_gate|manual|verify_command`
- Never forge shell verify pass from markdown alone.

## SQL

- If using `query sql`: treat as **read-only**. Mutating SQL is a trust violation on modern CLI.

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

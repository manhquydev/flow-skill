---
title: flow durable-layer trust-align with repository-harness 0.1.17
description: >-
  Align flow's durable layer + skills with repository-harness authority (protocol
  floor harness-cli-v0.1.14, trust CLI harness-cli-v0.1.17, never 0.1.16). Honest
  proof_source on card gate, STRICT durable-write modes, canonical harness skill,
  gap matrix + contract tests. No schema 006-013 merge, no rust unfreeze.
status: completed
priority: P1
branch: master
tags:
  - flow-skill
  - harness
  - trust-align
  - repository-harness
created: '2026-07-18T08:40:00.000Z'
createdBy: reconstructed-2026-07-19
source: skill
---

# flow durable-layer trust-align with repository-harness 0.1.17

> **Provenance:** this plan file was reconstructed on 2026-07-19 during a verification/cook
> pass, because the CHANGELOG `0.24.0` (formerly labelled `0.23.0`) entry cited this path but
> the directory was missing on disk (finding F4). The implementation was already complete and
> fully test-green when reconstructed; content below reflects the shipped change, not a forward plan.

## Overview

Make flow's durable (harness) writes **honest and non-forging** and align pins with the
`repository-harness` authority. Scope is trust + provenance, **not** a schema/protocol merge.

## Requirements / acceptance criteria

- `story update --status implemented` no longer used from the card path; `/flow check` on a
  `done` card calls `story complete --proof-source card_markdown_gate`.
- Card markdown gate records `proof_source=card_markdown_gate` in notes and **does not** forge
  `last_verified_result=pass` — only shell `story verify` may set a pass. (Verified live: DB row
  shows `last_verified_result=None`, `notes=proof_source=card_markdown_gate / verify_stamp=not_shell`.)
- `FLOW_HARNESS_STRICT` modes: unset → soft warn (engine stays 0); `1` → louder warn; `fail` →
  propagate nonzero from card/check durable writes.
- Auto-trace enrichment on check-done without faking `--lane tiny`.
- Canonical harness skill `skills/harness-skill/SKILL.md`, CI-tested, optional install to
  `~/.agents/skills/harness`.
- Gap matrix documenting flow-vs-0.1.17 schema/CLI deltas.

## Files changed

- `skills/flow/runner/flow.sh` — `_harness_run` / `harness_call` / `harness_call_checked` /
  `_harness_or_fail`; card + check call sites.
- `skills/flow/harness/flow_harness.py` — trust boundary on story complete/update.
- `skills/flow/harness/README.md`, `references/agent-stage-mapping.md`, `references/auto-run.md`
  — stop teaching bare `implemented` updates.
- `skills/flow/harness/GAP-MATRIX-0.1.17.md` (new), `skills/flow/harness/pins/` (sha256 sidecar).
- `skills/harness-skill/SKILL.md` (new).
- Version bump to `0.24.0` across `SKILL.md` / `plugin.json` / `portable-manifest.json`.

## Tests / validation

- New: `test_flow_harness_lineage_contract`, `test_flow_harness_strict`,
  `test_flow_harness_trust_complete`, `test_flow_skill_harness_docs_contract`,
  `test_harness_cli_optional_smoke`.
- Full suite `bash tests/run_all.sh` → **ALL SUITES PASSED** (39 suites, 1896s, 2026-07-19).
- `bash skills/flow/runner/flow.sh coherence` → PASS (manifests agree at 0.24.0).

## Risks / rollback

- Durable-write STRICT=fail can now block card/check when harness is broken — mitigated by
  default soft mode. Rollback = revert flow.sh harness_call block + restore version.

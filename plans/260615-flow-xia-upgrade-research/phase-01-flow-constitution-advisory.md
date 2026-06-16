# Phase 01 — `/flow constitution` advisory command

## Context links
- Decision report: `flow-xia-upgrade-decision-report.md` (item #1, score 4.3)
- Red-team A (overlap): GENUINELY-NEW, 92% — no `constitution|invariant|non-negotiable` concept
  exists in flow (grep clean across `skills/flow`); `law/*.md` are skill-level + immutable
  (`flow.sh:132-139`); `consistency` covers a different axis (FR traceability only).
- Red-team B (cost): DESCOPE — "every gate" framing = hot-path LLM tax → make it a **standalone
  advisory command** like `cmd_consistency` (`flow.sh:988-1086`), `cmd_contract` (`804-844`).

## Overview
- **Priority:** High (flagship win of this plan).
- **Status:** Planned.
- **What:** an operator-authored, per-project file of non-negotiable invariants
  (`flow/constitution.md`), validated by a new advisory command run at the scope/PRD/contract
  seam — NOT wired into the `/flow next` hot path. Two-layer like every flow gate: mechanical
  structure + optional grep-markers, then a semantic challenge of artifacts against the invariants.

## Key insights (from red-team, do not re-litigate)
- The genuinely-uncovered surface is: operator-authored project law that is (a) loaded at init,
  (b) checked across stages (not per-stage like `gate-rules.md` challenges), (c) semantically
  challenged. flow has none of (a)+(b)+(c) today.
- Mechanical grep can only enforce invariants the operator gives an explicit marker for; the
  semantic weight is the expensive part → keep it operator-invoked, never per-`next`.
- Overlaps the hardcoded Tier-C security-class halt list (`flow.sh:610`,
  `auth|authoriz|admin|tenan|payment|...`). The constitution is **advisory and does NOT replace**
  that halt — document this so operators don't treat advisory as enforced.

## Requirements
**Functional**
- `flow.sh constitution` validates `flow/constitution.md`: file exists; no `[FILL]` left; each
  invariant row has a stable ID + an "applies-at" stage tag + (optional) a grep-marker pattern.
- For each invariant carrying a grep-marker, advisory-scan the project and WARN on unmet markers.
- Exit code: `1` only on structural failure (`[FILL]`, missing ID); `0` with warnings for unmet
  markers (advisory, mirrors `cmd_design`/`cmd_tokens`). Auto-skip cleanly if no constitution file.
- `gate-rules.md` gains a "Constitution challenge" section: when the operator runs it at
  scope/PRD/contract, Claude challenges each artifact against each invariant.
- `flow recall` surfaces the active constitution so it is not forgotten mid-build.

**Non-functional**
- Pure bash; Codex `.cmd` parity; new command body ≲ ~80 LOC; zero coupling to `cmd_next`.

## Architecture
- New `cmd_constitution()` in `runner/flow.sh`, modeled on `cmd_consistency` (standalone,
  operator-invoked, advisory). Dispatch case + usage string added alongside existing commands.
- New artifact template `_templates/constitution.md`. Invariant table columns:
  `ID | invariant | applies-at (stages) | grep-marker (optional) | rationale`.
- Two-layer: mechanical (`cmd_constitution`) + semantic (`gate-rules.md` section, operator-run).
- Recall surfacing reuses the existing read path in `cmd_recall` (`flow.sh:710-737`).

## Related code files
**Modify**
- `skills/flow/runner/flow.sh` — add `cmd_constitution` + dispatch case + usage; add constitution
  to `cmd_recall` output.
- `skills/flow/references/gate-rules.md` — new "Constitution challenge" semantic section.
- `skills/flow/references/command-dispatch.md` — map `/flow constitution` → runner + duties.
- `skills/flow/SKILL.md` — commands table row + reference-files list + version bump.
**Create**
- `skills/flow/_templates/constitution.md` — the operator template.
- `tests/test_flow_constitution.sh` — fixture suite (mirror `test_flow_consistency.sh`).

## Implementation steps
1. Draft `_templates/constitution.md`: header instructions + invariant table + `[FILL]` markers
   + a worked example (e.g. "all PII facility-scoped").
2. Add `cmd_constitution` to `flow.sh`: locate `flow/constitution.md`; validate structure
   (`[FILL]`, IDs, stage tags); run operator grep-markers; print advisory warnings; correct exits.
3. Add dispatch `case` + usage-string entry.
4. Surface the constitution's invariants in `cmd_recall` output.
5. Add the "Constitution challenge" section to `gate-rules.md` (scope/PRD/contract seam).
6. Update `command-dispatch.md` + `SKILL.md` (commands table + reference list).
7. Write `tests/test_flow_constitution.sh`: clean→exit0; `[FILL]`→exit1; missing-ID→exit1;
   unmet-marker→exit0+warn; no-file→graceful skip. Register in `run_all.sh`.
8. Bump version metadata + run `flow coherence` to clear version drift.

## Todo
- [ ] `_templates/constitution.md` drafted
- [ ] `cmd_constitution` + dispatch + usage
- [ ] recall surfacing
- [ ] `gate-rules.md` semantic section
- [ ] `command-dispatch.md` + `SKILL.md` updated
- [ ] `tests/test_flow_constitution.sh` + registered in `run_all.sh`
- [ ] version bumped + `flow coherence` clean

## Success criteria
- Exits per spec across all 5 fixture cases; new suite + full `run_all.sh` green.
- **Grep `flow.sh` confirms `cmd_constitution` is never called from `cmd_next`** (no hot-path
  coupling) — this is the load-bearing red-team correction.
- `flow recall` shows the constitution; Codex `.cmd` path runs the command.

## Risk assessment
- *Scope creep back into per-gate enforcement* → mitigate with a code comment stating the WHY
  (mechanical-first/cheap law; advisory by design) — NOT a phase reference.
- *`flow.sh` growth* → keep the command lean and cohesive with sibling advisory commands.

## Security considerations
- Constitution often encodes security invariants (PII-scoping, no-uncontracted-API). The command
  is **advisory** — it must not be mistaken for enforcement and does **not** replace the Tier-C
  security-class halt (`flow.sh:610`). State this explicitly in the template + `gate-rules.md`.

## Next steps
- After merge, dogfood on CMC Odoo (a real "PII facility-scoped" invariant) as live validation.

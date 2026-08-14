# Validate R2 — flow upgrade wave1

- **Date:** 2026-08-14
- **Target:** `plans/260814-0948-flow-upgrade-wave1/` (`plan.md` + 8 phases)
- **Workflow:** `ak-plan/references/validate-workflow.md`. Operator interview forbidden; self-answer from evidence. Convergence: impl-impact edits only; cosmetic leftovers are notes.
- **Prior gates:** red-team R1 (14), validate R1 (13), red-team R2 (12). Product code untouched.

## Job this round

1. Verify R2's 12 fixes do not contradict Validate R1 pins.
2. Whole-plan consistency sweep across all 9 files.
3. Confirm COOK-READY (no `[FILL]` gaps; every phase has files/steps/success criteria; plan.md ↔ phases agree).

## R2 vs Validate R1 pins

No R1 pin was reversed. Three were refined (already logged as R2 supersessions):

| R1 pin | R2 change | Compatible? |
|---|---|---|
| Installer `--yes --project --dir "$DEST"` | Pin `RUN="$DEST/.claude/skills/flow/runner/flow.sh"`; drop `$INSTALLED`; `package/` prefix; ROOT-anchor | Yes — completes the R1 pin. `cli.mjs:128` / `help.mjs:21` write `$DEST/.claude/skills/flow`. |
| Shared JS `shouldShip` via `--compare` | `--compare` must argv-branch **before** `sync.mjs:43-64` copy; sibling-import dropped | Yes — R1's "or a sibling that imports `shouldShip`" was not callable (`shouldShip` is not exported). |
| cmd_eval: `--report` → prelude → guard → `:4203` | `--report` → Phase 6 guard → wrap `:4203-4218`; reject window after `:4160` before `:4173`; feed only `:4315/:4345` | Yes — Session 1 compose could not pin nonce `:4214` or skip `_eval_cli_version` `:4218`. Log Q5 already superseded. |

The other ten R1 pins (27+probe / 33 re-record; no `gtimeout`-on-PATH; flag-only argparse; named ADR sections; `HEAD:<path>` only; `--record|--replay` + `FLOW_EVAL_UNBOUNDED=1`; `fcdd`/`fcde`; master-base PR; law/`CLAUDE.md` + measured budgets; Phase 2 `needs` grows) are intact. R2 F5–F12 close leftovers of those pins (Test H OR; Requirements `hash-object`; forced-skip *cell*; Phase 3/7 master-base; Phase 5 dep + help `:4508`; Windows stub; `--record` hits the guard; suite-count homes / budget bumps).

## DEST / `$INSTALLED` compose (R2 F1) — verified clean

Phase 3 now has one path, azure-shaped:

- Pack from `"$ROOT/npm-wrapper"`; tarball `manhquy-flow-skill-*.tgz`.
- `--compare` walks extracted `package/skills/flow` vs `"$ROOT/skills/flow"`.
- Installer: `<tmp>/node_modules/.bin/flow-skill --yes --project --dir "$DEST"`.
- `RUN="$DEST/.claude/skills/flow/runner/flow.sh"`; `test -f "$RUN"`; `bash "$ROOT/tests/e2e-installed-drive.sh" "$RUN"`.
- Explicit: there is no `$INSTALLED` variable. Zero-arg e2e is a job bug.
- plan.md rehearsal SC uses the same `$DEST/.claude/skills/flow/runner/flow.sh` string.

No leftover `$INSTALLED` in Implementation / Architecture / Success Criteria (only the "there is no `$INSTALLED`" prohibition and the R2 table).

## Applied this round (impl-impact only)

### 1. Phase 6 Related Code Files still told implementers H "will hit the new refusal"
- **File:** `phase-06-macos-debt-bounded-card.md`
- **Why impl-impact:** R2 F5 and Phase 6 Implementation/SC say: H keeps PASS via `FLOW_EVAL_UNBOUNDED=1` only in H; add a **new** refusal case; do not rewrite H. Related Code Files still said H "will hit the new refusal" — that is the same OR that deletes the watchdog.
- **What changed:** Related Code Files now matches Implementation/SC.

## Notes (not edited)

- plan.md Goal 5 and Phase 1 ADR still say `cmd_eval` "prelude". Phase 7 owns the wrap (`:4203-4218`). R2 N5: constitution-level wording, no impl fork.
- Phase 7 Related Code Files still says "prelude"; Architecture/Steps already specify the two windows + artifact feed. Same class as N5.
- Phase 3 Architecture repeats the `--compare`-before-copy rule twice. Redundant, not contradictory.
- Validation Log Q5 historical answer left in place (R2 N6); Confirmed Decisions carry the supersession.
- Phase 2 step 3 still says "59th suite" for *that* phase's new file — correct; wave-end freeze is already forbidden.

## COOK-READY

- No `[FILL]` / "name at impl" / TBD gaps in requirements, steps, or success criteria.
- All 8 phases name create/modify files, numbered steps, and checkboxed success criteria.
- plan.md goals, order, and wave SCs match the phase files after R2 + this leftover.
- Operator *actions* (not questions): branch-protection flip; billable Phase 7 `--record` (27+probe) on a host with real `timeout`/`gtimeout` or `FLOW_EVAL_UNBOUNDED=1` for that run; Phase 8 live `--n 3` + 33+probe re-record. None need a new decision.

## Whole-plan consistency sweep

- Files reread: all 9 after the Session 2 edit.
- Decision deltas checked: 13 R1 pins + 12 R2 fixes + 1 Session 2 leftover.
- Reconciled stale references: 1 (Phase 6 Related Code Files Test H).
- Unresolved contradictions: 0.

## CLI

`ak plan validate plans/260814-0948-flow-upgrade-wave1` run after edits (structural CK convention check).

## Recommendation

Cook-ready. One leftover of R2 F5 was aligned; no new operator forks.

VERDICT: FINDINGS_APPLIED n=1

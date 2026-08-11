# Independent review (parallel) — hollow-done implementation

**Date:** 2026-08-11  
**Mode:** independent, hostile, 3 parallel lenses (spec / correctness / tests-docs) + live probes  
**Then:** `--fix` applied for Critical/High; full suite re-verified  

## Verdict

| Before fix | After fix |
|------------|-----------|
| HOLD — Critical URL-as-C false PASS; ready≠check Verify; dual scorer drift; phantom graph asserts | **Ship-ready for P1 floor** with residual honesty still required |

**Overall:** Implementation matches plan intent; first independent review found real forgeries and weak tests. Fixes applied. Residual multi-signal decoy (fcdc) remains intentional.

## Parallel review findings → disposition

### Critical / High (fixed)

| ID | Finding | Fix |
|----|---------|-----|
| C1 | Category C matched inside URLs (`https://…/ok` → A+C=2) | Strip URLs before C-token match (bash+python) |
| H1 | Denylist bypass via `:port` / trailing dots | Host normalize: strip userinfo/port/dots |
| H2 | ready/graph weaker than check (unchecked Verify) | `_card_done_evidence_ok` also requires no `- [ ]` / no `[FILL]` |
| H3 | card_done trap continues after INT | trap restores `todo` + `exit 130`; fail always forces `todo` |
| H4 | `fail`/`failed` awarded C | Positive tokens only: pass/passed/ok |
| H5 | Bare fence ≥2 lines awarded C | Fence awards C only with positive tokens |
| H6 | bare `id=1 ok` E+C forge | E no longer matches bare `id=`; rows/SELECT/sqlite/inserted only |
| H7 | Graph success asserts phantom | Assert `"ready": ["C-002"]` + `"deps_met": ["C-002"]` + hollow missing |
| H8 | auto-path suite phantom | Require blocked + world-state note; unchecked Verify case |

### Medium (partial / accepted residual)

| ID | Finding | Disposition |
|----|---------|-------------|
| M1 | Dual bash/python scorers (no single source) | Accepted residual; vectors shared via tests; prefer shared later |
| M2 | fcdb still default billable FLAG fixture | Accepted: mechanical FAIL + historical FLAG text; fcdc is residual class |
| M3 | `$` line-start prompt | Fixed `(^|[[:space:]])\$[[:space:]]` |
| M4 | gate-eval six/19-call stale | Updated to seven/22-call where targeted |
| M5 | process_fail_rate not a named metric | Residual: process-only covered by shell asserts; name later |

### Spec compliance (post-fix)

| SC/D | Status |
|------|--------|
| Process-only FAIL, multi-signal PASS | PASS |
| ready + graph re-validate | PASS (incl. Verify) |
| fcdb FAIL / fcdc residual | PASS |
| Standalone, no AgentKit | PASS |
| Phase 4 out of ship | PASS |
| Residual honesty | PASS (updated ground-truth-gates) |

## Live probes (author)

| Input | Expect | Result |
|-------|--------|--------|
| `https://staging…/ok` alone | FAIL | FAIL after fix (was PASS) |
| `https://app.example.com` + PASS | FAIL | FAIL |
| fence 2 lines no tokens | FAIL | FAIL |
| G-PASS curl+PASS | PASS | PASS |

## Verification after fix

```
bash tests/test_flow_done_evidence.sh  → 27/0
bash tests/test_flow_auto_done_path.sh → 8/0
bash tests/run_all.sh                  → ALL SUITES PASSED (re-run after fix)
```

## Residual (do not oversell)

- Decoy staging URL + real-looking `PASS` log still mechanical PASS → **fcdc / semantic offline**
- Category F `skills/flow` + another signal can still forge
- Dual implementation drift risk if only one side is patched later
- 3-OS CI green only when GitHub Actions runs on push (local suite green)

## Recommendation

1. Commit the full change set when ready  
2. Optional follow-up: extract shared scorer (single source)  
3. Optional: drop fcdb from default billable eval loop  
4. Do not claim “auto cannot hollow-done” — claim **process-prose + hand-edit Verify/evidence floor closed**

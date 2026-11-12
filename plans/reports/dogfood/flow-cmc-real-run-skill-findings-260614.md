# /flow skill — improvement findings from the real CMC run (2026-06-14)

Driving `/flow` end-to-end on a large brownfield Odoo ERP (CMC) produced real operating data. This is the "cải thiện/sửa/nâng cấp skill dựa trên số liệu thật" deliverable. Sibling: `flow-assess-cmc-odoo-dogfood-findings-260614.md` (early findings DF1–DF6).

## Real metrics from the run

| Metric | Value |
|---|---|
| Gates passed | assess(00-inspect) + 6 planning (idea→research→scope→prd→adr→contract) |
| Cards | 5 created · **4 done** (C-001/002/003/004) · 1 todo (C-005) |
| Mapping workflow | 40 subagents · **3,071,121 output tokens** · ~917s · 32/36 addons (4 vendored rate-limited) |
| Build/review subagents (main loop) | ~6 (3 build + 1 review for safe cards; 1 build + 1 review for C-004) |
| Empirical proof | leak: **6 tests FAIL→PASS** on live `cmc_erp`; 1 dependency cycle discovered+navigated; 2 review findings fixed |
| Harness | lane=high_risk · 3 durable decisions · traces stuck at **tier 1/3** (below required 2) |

## What WORKED (keep / lean into)

- **No-install external drive at scale** — global runner + `FLOW_PROJECT_ROOT` + stable `FLOW_SESSION_ID` held across an entire assess→plan→build→verify cycle on a real ERP. Confirms the C2-App-001 pattern.
- **Test-first card (C-001) before the fix** — writing the leak-proof tests FIRST surfaced that the model is `op.certificate` (not `cmc.certificate`) and that 4/5 models scope via `student_id.facility_id` traversal — corrected the plan BEFORE any rule was written. Highest-leverage single behavior of the run.
- **Tier-C halt** — correctly stopped before an authorization + data-migration change on minors' data, got written operator acceptance. The safety design did its job.
- **Adversarial code-review as a distinct layer** — caught a real BGĐ-board regression and an `group_system`-bypass misconception that the build agent + static checks missed. Multi-layer gate works.
- **"Validate audit findings against evidence"** — the review claimed the rules "never activate on upgrade" (noupdate); the live test disproved it (they activated). Applied the convention fix but corrected the overstated framing rather than accepting it blindly.

## Skill gaps to FIX (ranked)

### DF7 — [HIGH] Contract gate locks names but not module dependency-direction (the headline)
On Odoo (a module-dependency system) the contract's exact-name lock (`facility_id`, `cmc_facility_ids`) was correct, but it did NOT capture **which module owns each symbol** or **the dependency direction**. Result: a real load-time **cycle** (`cmc_multi_facility → openeducat_admission → cmc_test_booking → cmc_multi_facility`) that passed XML/AST static checks AND code-review, and only surfaced at Odoo runtime (`-u`). 
**Fix:** for module/package-system stacks, the Stage-05 contract gate (`references/gate-rules.md` + `_templates/05-contract.md`) should add a "owning module + dependency direction" note per interface, and a semantic challenge: "does any new rule/field reference a symbol from a module the host doesn't (and can't) depend on? any cycle?" A cheap `depends`-graph cycle check would have caught this pre-build.

### DF1 — [MEDIUM] assess auto-scan is root-only / JS-centric
Missed the operator's whole domain (Odoo/Python in `src/odoo/addons/*/__manifest__.py`, pnpm-workspace, `docker-compose.dev.yml`). **Fix:** extend `flow.sh assess_scan` with bounded-depth detection for `**/__manifest__.py` (odoo), `pnpm-workspace.yaml`/`nx.json`/`turbo.json`, `docker-compose*.y?ml` glob, `**/schema.prisma`.

### DF4 — [MEDIUM] assess template too thin for large systems
The 6 fixed sections had no home for module-map / permission-matrix / logic-gap deliverables — had to invent a `flow/assess/` dir. **Fix:** document an `assess/` deliverables convention (or optional sub-sections) as first-class.

### DF8 — [MEDIUM] durable trace under-capture
`flow check` auto-records a trace but it stays at tier 1/3 (below the lane's required 2) — it doesn't auto-gather intake_id / agent / files_changed. The capture→reuse loop under-fills, so `/flow recall` has less to surface on the next slice. **Fix:** richer card-build auto-trace, or a one-line `flow trace` prompt at card-done.

### DF9 — [LOW-MED] encode common stack gotchas as a playbook
The build agent encoded a wrong Odoo assumption (`group_system` auto-bypasses record rules — false; only the true superuser does). Only the adversarial layer caught it. **Fix:** `/flow promote` an `odoo-multi-facility-isolation` playbook to the cross-project KB capturing: `facility_id` traversal vs owned-field; `group_system ≠ superuser` + explicit admin-bypass; record-rule OR/AND combination across groups; `noupdate=0` for security rules; the `cmc_multi_facility ↔ admission ↔ test_booking` cycle. Then `recall` surfaces it on the next Odoo run.

### DF2 — [LOW] SKILL.md frontmatter version still 0.2.0 vs released 0.3.0.

## Net
`/flow` delivered a correct, empirically-verified security fix (cross-facility leak closed, proven) on a real ERP, with the gate/Tier-C/adversarial-review discipline catching real issues at each layer. The one HIGH gap (DF7: contract dependency-direction for module systems) is the most valuable upgrade — it's the only thing that let a real defect (cycle) reach runtime.

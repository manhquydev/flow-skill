# /flow dogfood — live run on CMC Odoo ERP (brownfield assess)

**Date:** 2026-06-14
**Target:** `D:\project\CMC` (CMC education ERP — Odoo 17 + Next.js LMS/Internal + Fastify sync; 36 Odoo addons)
**Skill version under test:** global `~/.claude/skills/flow` (verified byte-identical to source `D:\project\flow\flow-skill\skills\flow`)
**Drive pattern:** no-install — global runner + `FLOW_PROJECT_ROOT=/d/project/CMC` + stable `FLOW_SESSION_ID` (F1 lock)
**Mode:** work · **Stage:** 00-inspect (brownfield `flow assess`)

This file tracks defects/gaps in the **flow skill itself** observed while doing real work.
Sibling to `D:\project\flow\flow-skill-test-report-c2-app-001-260614.md` (the SecuSense run, findings F1–F7).
CMC-specific *product* findings live under `D:\project\CMC\flow\assess\` instead.

---

## Findings

### DF1 — `assess_scan` stack detection is root-only + JS-centric (MEDIUM, enhancement)
On CMC the auto-scan seeded into `flow/00-inspect.md` printed only:
```
stack:
  - node (package.json)
  - CI: github actions (.github/workflows)
context files present: README.md, AGENTS.md, CLAUDE.md, docs, tests
```
It **missed the operator's entire problem domain** and the real architecture:
- **Odoo / Python** — `runner/flow.sh:891` checks only `$ROOT/pyproject.toml` / `$ROOT/requirements.txt`. CMC's Python is `src/odoo/addons/*/__manifest__.py` (36 addons) → Python/Odoo invisible.
- **pnpm monorepo** — `pnpm-workspace.yaml` at root not detected → the 6-package workspace (lms/internal/website/sync-middleware/odoo/shared) is unseen.
- **Docker** — `flow.sh:895` matches exact `Dockerfile` / `docker-compose.yml`; CMC uses `docker-compose.dev.yml` → Docker missed.
- (Deeper, lower-priority: Prisma `schema.prisma`, Next.js, Fastify — coarse stack lines don't reach these.)

Auto-scan is documented "best-effort" (the human/Claude fills real detail), so this is an **enhancement, not a bug**. But for a brownfield ERP the seeded scan is close to empty, which weakens the gate's starting signal.

**Fix (proposed):** in `assess_scan`, add:
- `pnpm-workspace.yaml` / `nx.json` / `turbo.json` → "monorepo (workspaces)" + enumerate `packages`/`src/*`.
- glob `docker-compose*.y?ml` (not just exact name).
- Odoo signal: `src/**/__manifest__.py` present or an `addons/` dir → "odoo (N addons)".
- shallow (depth ≤3) python signal so subdir Python is seen, not only root.
- Prisma: `**/schema.prisma`.
Keep it fast/best-effort (bounded depth, no full recursive find).

### DF2 — SKILL.md version drift vs release (LOW)
`skills/flow/SKILL.md` frontmatter `metadata.version: "0.2.0"`, but the release is **v0.3.0** (plugin.json + portable-manifest bumped; annotated tag `v0.3.0` pushed). The skill's own `flow coherence` command exists to catch version drift — running it on the flow-skill repo would flag this. **Fix:** bump SKILL.md `metadata.version` → `0.3.0`; consider having `coherence` include SKILL.md frontmatter in its version-field scan.

### DF3 — no-install external drive scales to a large brownfield repo (POSITIVE)
`flow.sh doctor` green (durable layer ENABLED via hermes venv python 3.11), `assess` scaffolded cleanly, `mode work` / `status` / session-lock all functional against an external `FLOW_PROJECT_ROOT` on a big polyglot monorepo. Confirms the C2-App-001 no-install pattern holds at CMC scale.

---

### DF4 — assess template too thin for a large brownfield system (MEDIUM, enhancement)
The 6 fixed sections (detected / what-is / functionality / UI-UX / risks / tests / verdict) had **no natural home** for the operator's actual deliverables — *module-relationship map*, *permission matrix*, *business-logic-vs-test gaps*. I had to create a sibling `flow/assess/` dir with 4 deliverable files and reference them from `00-inspect.md`. **Fix idea:** document a "deliverables/" convention for `assess` on large systems (or add optional sub-sections: Module map, Permission/RBAC, Decomposition), so the pattern is first-class instead of ad-hoc.

### DF5 — gate behaved correctly under work-mode authoring (POSITIVE)
Authored a 36-addon `00-inspect.md` in `work` mode, checked the 7 evidence boxes, **left only the human-review box unchecked** → `flow assess` correctly reported RED with exactly that one box. Mechanical gate + operator-gate separation held: I did not (and the runner did not let me silently) pass the human sign-off. The `0 [FILL]` check also passed. Good discipline signal.

### DF6 — workflow resilience: 4/36 extract agents rate-limited (INFRA, not skill)
4 vendored light-pass agents died on transient API rate-limiting; `parallel()` returned them as null and the run completed on the other 32. Acceptable here (all 4 were vendored base addons; cmc→base edges captured from the cmc side). Not a flow-skill defect — noting for the dogfood record. If precise vendored manifests matter, resume/re-extract those 4.

---

## Verdict on this dogfood run
`/flow assess` **worked end-to-end on a large polyglot brownfield repo** and produced genuinely useful, evidence-cited output (caught a real CRITICAL data-isolation class + a false-positive PIT claim via the adversarial layer). Real skill gaps to fix: **DF1** (polyglot/monorepo auto-scan) and **DF4** (deliverables convention for big-system assess); plus cosmetic **DF2** (SKILL.md version). None block usage. Real *product* value delivered to CMC independent of the skill test.

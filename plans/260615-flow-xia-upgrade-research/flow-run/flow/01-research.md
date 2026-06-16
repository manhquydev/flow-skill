# Stage 01 — Research (inspect first)

Internal tool (project-type: skill) — non-web framing. Evidence = the 4 researcher reports +
red-team in `../`/`../research/`, and first-party dogfood friction. Not market research.

## Gate — check ALL before `/flow next`
- [x] I actually OPENED 3 existing tools/competitors (links below, with one honest note each)
- [x] (non-web) I named the concrete first-party friction / observed pain that justifies this
- [x] (non-web) what people spend AROUND this problem today (time, a worse tool, manual work)
- [x] (non-web) who benefits and how they hear about it; "no market channel" is NOT a kill signal
- [x] I wrote why those users would pick this over the status quo (one honest paragraph)
- [x] I wrote what is technically free vs hard for this idea
- [x] No FILL placeholders remain in this file

## What exists already (3 — opened via the research reports)

1. **GitHub Spec Kit** (github.com/github/spec-kit) — `/constitution` (machine-enforced project
   principles) + `/analyze`. flow ALREADY ported `/analyze`→`flow consistency`; it has NOT taken
   `/constitution`. Falls short: IDE/Python-workflow bound. (`research/researcher-01-*.md`)
2. **Aider** (github.com/Aider-AI/aider) — tree-sitter PageRank repo-map ranks code surfaces by
   reference count. Strong at surfacing high-value files; needs tree-sitter. flow's `assess` scan
   is flat globs with no ranking. (`research/researcher-04-*.md`)
3. **Mem0 / Letta / Zep / Cognee** — memory layers (usage-weighting, temporal graphs). Powerful
   but ALL require a vector DB / embeddings / server → break flow's portability law. flow already
   has local SQLite + ACE + deterministic ≥2 consolidation. (`research/researcher-03-*.md`)

## First-party friction (the real, observed pain)

1. > CMC Odoo brownfield `assess`: the **cross-facility leak of minors' data** (top finding R1)
   ranked nowhere in the flat file scan — a human had to spot it. (`memory: flow-cmc-odoo-assess`,
   `researcher-04` ties repo-map to exactly this.)
2. > flow's gates **cannot enforce an operator rule** like "all PII facility-scoped" — grep proved
   no `constitution|invariant` concept exists anywhere in `skills/flow` (red-team A, 92%).
3. > `flow recall` **cannot distinguish a reused decision from a never-recalled one** — no usage
   signal; `cmd_recall` (`flow.sh:710-737`) is read-only, never increments (red-team A, 95%).

## GTM & business reality (non-web)

### Who pays / what people spend AROUND this today
- Hosted memory layers (Mem0 — reported $24M-backed; Zep) → recurring spend on vector-DB infra +
  embeddings to get usage-weighted memory. flow's alternative = $0 new deps (SQLite column).
- Catching unranked-scan blind spots today = manual senior review time (the CMC leak was found by
  hand). Ranked `assess` substitutes deterministic signal for that scarce attention.

### Who benefits / how they hear (non-web — no market channel needed)
flow users + the maintainer. Discovery via `SKILL.md` command table + release notes. "No market
channel" is expected for an internal skill and is NOT a kill signal.

### Why switch (vs status quo)
The status quo is either (a) heavyweight trending products that break flow's portability/determinism
laws, or (b) flow's current flat scan + unenforced operator rules. These 3 upgrades are
dependency-free, run on Windows Git Bash + Codex, and degrade gracefully — they extend flow's own
two-layer-gate DNA rather than bolt on infra flow deliberately refuses. That fit, not novelty, is
the reason to move.

## Technically free vs hard
- **Free** (solved by existing patterns): advisory-command scaffolding (reuse the
  `consistency`/`contract`/`tokens` pattern), the SQLite versioned-migration framework
  (`_db.py:91-102`), glob fallback for `assess`.
- **Hard** (custom work, real risk): a tree-sitter optional-import that NEVER raises on Windows
  Git Bash / Codex (must degrade to globs); keeping `/constitution` OFF the `cmd_next` hot path;
  guaranteeing `accessed_count` NEVER prunes a rare-but-critical security row.

# /flow knowledge-loop upgrades — research + roadmap (2026-06-14)

Grounding for the "capture → reuse → improve" upgrades. Each design is tied to current
(2025–2026) core tech (cited), per an internet research pass. Order is sequential because
every item touches `flow.sh`/harness (no parallel-safe file split).

## New core concepts captured (the learning)

| Term | One-line | Source |
|---|---|---|
| **Reflexion** | feedback → verbal reflection stored in episodic memory → next-iteration context (no weight updates) | arxiv 2303.11366 |
| **Agentic Context Engineering (ACE)** | evolve memory as a playbook via Generator→Reflector→Curator; incremental, not regenerated | arxiv 2510.04618 |
| **Episodic vs semantic vs procedural memory** | keep full traces (episodic); consolidate by cluster+count, not summarize (which destroys signal) | atlan.com/know/types-of-ai-agent-memory |
| **Grounded > intrinsic self-correction** | anchor audits in execution/test evidence; never trust the agent's own verdict | zylos.ai 2026-05 |
| **Calibration / Brier score** | predicted_impact vs actual_outcome; gap = miscalibration OR confound | PMC12818272 |
| **Specification gaming / reward hacking** | agents optimize the proxy; keep the outcome loop advisory, decouple from auto-priority | arxiv 2601.04170 |
| **AGENTS.md (Linux Foundation std, 2025)** | machine-readable operational contract; w/o it agents hallucinate ~40% more on brownfield | github.blog copilot agents.md |
| **Path-resolution drift** | client base + endpoint path don't compose to the served spec path (double/missing prefix) — a confirmed 2026 tooling GAP | github.com/oasdiff/oasdiff |
| **Design-system drift** | declared tokens (DESIGN.md/Figma) ≠ shipped CSS; detect via declared-vs-used set-diff, never auto-fix | overlayqa.com/blog/design-system-drift |

**Design principles adopted:** deterministic count-based consolidation (≥2), advisory not auto-applied,
grounded in real evidence, graceful degradation, no new schema where existing tables suffice.

## Status

- ✅ **Cluster A — read-back loop** (`flow recall`; status/card/next surfacing) — merged.
- ✅ **Cluster B — gate-fired capture** (intake@01, decision-reminder@04, trace-tier@card-done) — merged.
- ✅ **Option B — self-improvement loop** (`harness audit`/`propose`/`decision outcome`/`query decisions`;
  retro→propose, recall→audit health) — merged. Faithful port of repository-harness propose/audit (ACE GRC,
  deterministic ≥2, entropy weights), predicted-vs-actual closed.

## Next — sequential

### F3 — contract path-resolution drift check (effort: low) [IN PROGRESS]
Research-confirmed GAP: oasdiff/Pact/Spectral/Schemathesis all miss client-base/prefix-vs-spec drift.
**Design:** `flow.sh contract` (web only) → a small python helper that (1) extracts client base(s)
(`VITE_API_BASE`, `API_BASE`, axios `baseURL`) from `.env*`/frontend, (2) reads served paths from
`openapi.json`/`flow/05-contract.md` endpoint table (or greps server route decorators), (3) composes
`base + client-path`, (4) flags double-prefix / missing-prefix / version-mismatch. Normalize trailing
slashes + `{var}` wildcards; auto-skip if no spec. Advisory (warn), like `cmd_design`. Pitfall guard:
needs an explicit client-config source (don't blind-grep), and a non-REST auto-skip.

### F4 — design-token divergence gate (effort: low)
**Design:** extend `flow.sh design` (or `flow.sh tokens`) → parse DESIGN.md declared tokens (CSS var
names/values in the "tokens (locked)" table), scan implemented CSS for `--var` usage, set-diff:
(a) declared-but-unused (dead tokens), (b) orphan CSS vars (used, not declared = drift), (c) value
mismatch. Advisory + "record a dated DESIGN.md amendment if the swap is intentional" (the law's process).
Never auto-fix (drift is often intentional). Pitfall: DESIGN.md may not be source-of-truth (Figma) → warn.

### F2 — brownfield / assessment mode (effort: high) [PLAN ONLY this round]
Today flow assumes greenfield (Idea→…→Ship). Brownfield needs scan→interview→assess BEFORE planning.
**Design (per AGENTS.md std + spec-driven-brownfield research):**
- `flow.sh assess` (or `/flow mode brownfield`) adds a `00-inspect` pre-stage with a gate:
  - **Scan:** detect stack/frameworks/CI/key files + dependency map (tree-sitter optional; fallback file globs); seed `harness intake --type maintenance`.
  - **Interview:** auto-draft a minimal AGENTS.md candidate (build/test/lint cmds, 2–3 non-obvious gotchas, don't-touch zones) — human-reviewed.
  - **Assess:** current-state evaluation (functionality/UI/UX vs product, test coverage, risk), DORA-ish baseline; emit `flow/00-inspect.md` (the artifact this whole session's C2-App-001 review was, by hand).
- Gate: planning (01+) unlocks only after assessment is human-marked reviewed. Seeds the harness warm so Option B's propose() has real historical signal (avoids cold-start).
- Why high-effort: touches the stage state machine, a new template, SKILL/dispatch, and a new gate; deserves its own /cook with its own cards.

## Open (from the C2-App-001 test report, not yet scheduled)
F7 doc-vs-code coherence challenge in the research gate; cross-project knowledge tier (`~/.claude/flow/`).

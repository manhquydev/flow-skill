# Phase 03 — `assess` repo-map symbol ranking (Aider-style, optional tree-sitter)

## Context links
- Decision report: `flow-xia-upgrade-decision-report.md` (item #8, PLAN → promoted by red-team C)
- Red-team C (missed value): the **only** candidate tied to a real observed flow failure (CMC
  cross-facility-leak detection, `researcher-04:198`) AND already on the committed backlog
  (`260614-flow-knowledge-upgrades-roadmap.md:40`, "tree-sitter optional; fallback file globs").
- Reference implementation to study: Aider repo-map (tree-sitter symbol extraction + PageRank-style
  ranking). `researcher-04-coding-agent-harnesses-eval.md`.

## Overview
- **Priority:** Medium-High (highest real-world warrant; also highest dependency risk).
- **Status:** Planned.
- **What:** enhance `flow.sh assess` so its scan emits a **ranked repo-map** (most-referenced
  symbols/files first) into `flow/00-inspect.md`, giving the scope stage the high-value surfaces
  up front. Tree-sitter is **optional** — graceful fallback to the current file-glob behavior.

## Key insights
- This is a backlog item, not a novel idea — so the work is *implementation + portability*, not
  *should we*. The value is concrete: ranked surfaces help spot leak-class risk during `assess`.
- The binding constraint is **portability**: tree-sitter is a heavier dep. It MUST be an optional
  import that degrades to globs on Windows Git Bash + Codex when unavailable — never required, never
  an error path that breaks a run.

## Requirements
**Functional**
- When tree-sitter is available, `assess` produces a ranked repo-map (symbol → references,
  PageRank-style) and seeds a "ranked surfaces" section in `flow/00-inspect.md`.
- When tree-sitter is absent, fall back to the existing file-glob scan with a one-line note that
  ranking was unavailable. No error, no broken gate.
- The `00-inspect.md` gate behavior is unchanged otherwise (operator still reviews + marks).

**Non-functional**
- Optional-import discipline: a missing/incompatible tree-sitter never raises; it routes to glob
  fallback. Pure-python ranking helper in `harness/`; bash wiring stays thin.
- Codex `.cmd` parity; tested both WITH and WITHOUT tree-sitter present.

## Architecture
- New optional python helper (e.g. `harness/repo_map.py`): try-import tree-sitter; if present,
  extract symbols + build a reference graph + rank; else signal "unavailable" so the caller falls
  back. Pure-stdlib ranking (no numpy).
- `cmd_assess` in `flow.sh` calls the helper; on "unavailable" or non-zero, uses the current glob
  scan. Output merged into the `00-inspect.md` seed.
- `_templates/00-inspect.md` gains a "Ranked surfaces" section placeholder.

## Related code files
**Modify**
- `skills/flow/runner/flow.sh` — `cmd_assess` calls the helper, merges ranked output, falls back.
- `skills/flow/_templates/00-inspect.md` — add "Ranked surfaces (most-referenced first)" section.
- `tests/test_flow_assess.sh` — add with/without-tree-sitter cases.
- `SKILL.md` / `references` assess docs — note the optional ranking + fallback.
**Create**
- `skills/flow/harness/repo_map.py` — optional tree-sitter ranker with glob fallback signal.

## Implementation steps
1. Build `harness/repo_map.py`: optional `import tree_sitter`; on success, extract symbols + rank
   by reference count (PageRank-style); on any failure, return a clear "unavailable" result.
2. Wire `cmd_assess` to call it; merge ranked output into the `00-inspect.md` seed; fall back to
   the existing glob scan + print the "ranking unavailable" note when the helper signals so.
3. Add the "Ranked surfaces" section to `_templates/00-inspect.md`.
4. Update assess docs (`SKILL.md` / references) — optional dep + graceful degradation stated.
5. Write `tests/test_flow_assess.sh` cases: with tree-sitter present (ranked section appears);
   with it absent/uninstallable (glob fallback, exit 0, note printed, no error). Register in
   `run_all.sh`. CI must pass in the no-tree-sitter case (the default environment).
6. Bump version + run `flow coherence`.

## Todo
- [ ] `harness/repo_map.py` optional-import ranker + fallback signal
- [ ] `cmd_assess` wiring + merge + glob fallback
- [ ] `_templates/00-inspect.md` "Ranked surfaces" section
- [ ] assess docs note the optional dep + degradation
- [ ] `test_flow_assess.sh` with/without tree-sitter; registered in `run_all.sh`
- [ ] version bumped + `flow coherence` clean

## Success criteria
- Ranked repo-map appears in `00-inspect.md` when tree-sitter is present.
- **With tree-sitter absent, `assess` still passes cleanly (no error) — verified in CI**, which has
  no tree-sitter by default. This is the load-bearing portability requirement.
- Existing assess tests still green; Codex `.cmd` path works.

## Risk assessment
- *Tree-sitter optional-import leaks an exception on some platform* → wrap all tree-sitter use in
  the helper; the bash caller treats any non-success as "fall back to globs". Test the absent case
  as the DEFAULT.
- *Highest-effort phase* → build last (risk-ascending order); keep ranking simple (reference count
  first; defer fancier graph weighting).

## Security considerations
- Ranked surfaces are an analysis aid only; no new data is written beyond `00-inspect.md`. No
  secret exposure (do not rank/print file *contents*, only symbol/reference structure).

## Next steps
- After merge, re-run `assess` on CMC Odoo to confirm the ranking surfaces the cross-facility
  data-flow files the manual review found — the real-world validation that justified promotion.

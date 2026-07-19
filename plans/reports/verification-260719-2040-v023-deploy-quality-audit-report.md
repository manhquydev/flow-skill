# Verification: v0.23 deploy result + quality (since v0.22)

**Date:** 2026-07-19 20:40 · **Scope:** flow-skill `D:\project\flow\flow-skill` · **Type:** verify-only (no code changed)
**Trigger:** verify v0.23 upgrade result & quality; check latest plan + codebase since v0.22; note "v0.22 release missing on GitHub".

## TL;DR

- **Implementation quality = GOOD** (tests green, coherent, careful code).
- **Deployment status = NOT DONE.** Neither v0.22 nor v0.23 is properly shipped. Operator's mental model ("v0.23 đã triển khai") is **ahead of git reality**.
- The user's note is **CONFIRMED**: v0.22 has no tag and no GitHub release.
- **"v0.23" does not exist as a deployed artifact — it is uncommitted working-tree only.**

## Release-state matrix (git/gh/npm-verified)

| Layer | Committed + pushed | Git tag | GitHub release | npm |
|---|---|---|---|---|
| flow **v0.21.0** | ✅ | ✅ `v0.21.0` | ✅ **Latest** | — |
| flow **v0.22.0** | ✅ `dbce976` (HEAD=origin/master) | ❌ **none** | ❌ **MISSING** | content folded into wrapper rc.3 |
| flow **v0.23.0** | ❌ **uncommitted WT only** | ❌ | ❌ | ❌ |
| npm wrapper | rc.3 committed | `npm@0.1.0-rc.3` | — | published rc.1/rc.2/**rc.3** |

## Findings

### F1 — v0.22 release missing on GitHub (CONFIRMS operator note)
- v0.22.0 **code** is committed + pushed (`dbce976`, HEAD == origin/master; committed `plugin.json` = 0.22.0).
- **No `v0.22.0` tag, no GitHub release.** Latest GH release = `v0.21.0` (2026-07-11).
- Installer plan `260717-0925-cross-agent-installer-expansion` is `status: completed`, but its sub-task **A1 explicitly required "cut a v0.22.x release (operator-gated tag)"** — never executed. Plan marked done with the release step open → **provenance gap** (operator-gated manual tag was skipped).

### F2 — "v0.23" is NOT deployed; it is uncommitted local edits (CRITICAL)
- `plugin.json` / `portable-manifest.json` / `SKILL.md` bumped to **0.23.0 but all `M` (uncommitted)**.
- Diff: 11 files `+236/-19`; untracked: `skills/harness-skill/`, `harness/pins/`, `GAP-MATRIX-0.1.17.md`, 5 new test files.
- **Not committed, not pushed, not tagged, not released, not on npm.** At risk of loss.

### F3 — Two different workstreams both labelled "v0.23" (semantic drift)
- Operator/memory "v0.23" = **cross-agent installer** (Cursor + Antigravity restart-guidance), plan `260717`. That work actually shipped as **npm `rc.2`/`rc.3`** — the flow skill version **stayed 0.22.0**, no skill bump.
- Uncommitted CHANGELOG "0.23.0" = **harness trust-align** (repository-harness 0.1.17), a *different* effort.
- The two collide on the "0.23" label → version story needs a decision.

### F4 — CHANGELOG 0.23.0 cites a non-existent plan
- Uncommitted CHANGELOG: `Plan: plans/260718-0840-harness-v017-flow-skill-trust-align/`.
- **That directory does not exist.** Most recent real plan = `260717-0925-cross-agent-installer-expansion`.
- → 0.23.0 harness work has **no persisted plan** (violates flow's own plan-first gate) or the plan was lost/misnamed. Honesty defect in the changelog.

### F5 — npm dist-tag inversion (live UX defect)
- `latest → 0.1.0-rc.2` (older); `rc → 0.1.0-rc.3` (newer).
- Default `npm install @manhquy/flow-skill` pulls **stale rc.2**. Known OIDC `E401` (publish token can't add dist-tags), but the defect is live for users.

## Quality of the uncommitted 0.23.0 work (what IS there)

- **Coherence:** PASS — 3 manifests agree at 0.23.0.
- **Tests:** 11 suites run green — 5 new harness-trust suites (`lineage_contract`, `strict`, `trust_complete`, `skill_harness_docs_contract`, `cli_optional_smoke`) + 6 core regression suites in the `harness_call` blast radius (`runner`, `harness`, `harness_args`, `concurrency_lock`, `card_lifecycle`; `usage_log` slow but not failed). **No regressions.** (Full 39-suite run not completed — Windows bash-suite ≈30 min.)
- **Code (`flow.sh` refactor):** solid. STRICT modes (`unset`/`1`/`fail`), secret-shaped stderr redaction, honest `proof_source=card_markdown_gate`, drops the faked `--lane tiny`, rc captured without flipping `set -e`, `mktemp` fallback. Matches CHANGELOG claims.

**Verdict:** the *code* is good; the *deployment + provenance* is the problem.

## Recommended remediation (operator decision required)

1. **Resolve version label** (F3): is the harness work `0.23.0`, or `0.22.1`/`0.24.0` given the installer already consumed "0.23" in operator's mind.
2. **Commit** the harness-trust work (currently at-risk, uncommitted).
3. **Fix CHANGELOG plan ref** (F4): create/restore the cited plan or point to the real one.
4. **Cut the missing v0.22.0 tag + GitHub release** (F1, the skipped operator-gated step).
5. **Tag + release** the harness version after commit.
6. **Promote npm `rc.3` → `latest`** (F5) via granular-token workaround (OIDC can't).

## Unresolved questions
- Should v0.22 and the harness version get separate releases, or fold v0.22 content into one combined release note?
- Is the harness-trust 0.23.0 work intended to ship now, or is it still mid-flight (no plan on disk suggests it may be incomplete)?

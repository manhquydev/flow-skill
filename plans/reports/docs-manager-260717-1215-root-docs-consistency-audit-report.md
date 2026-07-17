# Root Docs Consistency Audit Report — docs-manager-260717-1215

**Date:** 2026-07-17 12:15  
**Scope:** Advisory audit (read-only, no edits)  
**Status:** DONE_WITH_CONCERNS  
**Finding Count:** 5 stale references (HIGH severity)

---

## Executive Summary

Cross-check of root-level documentation against actual repository state revealed **5 factual inaccuracies**, all tied to npm version staleness. The current published npm version is **0.1.0-rc.2** (live as of 2026-07-17), but four documentation files still reference **0.1.0-rc.1**. Additionally, `docs/quality-metrics.md` header claims a stale skill version v0.21.0 instead of the current v0.22.0.

**Ground-truth verification performed:**
- `npm view @manhquy/flow-skill dist-tags` confirmed rc is 0.1.0-rc.2 (not rc.1)
- Test suite count: 34 suites / 926 checks (matches README/CHANGELOG claims)
- Semantic playbooks count: 21 .md files in `skills/flow/references/` (matches claim)
- Version fields coherence: SKILL.md, plugin.json, portable-manifest.json all show 0.22.0
- All key relative links verified as existing

---

## Findings (by Severity)

### HIGH: Stale npm Version References (5 locations)

#### Finding 1: README.md Status Table — Outdated rc.1 Link

**File:** `README.md`  
**Line:** 47  
**Current text:**
```
| npm package | [`@manhquy/flow-skill@0.1.0-rc.1`](https://www.npmjs.com/package/@manhquy/flow-skill) — LIVE |
```

**Evidence:**
```bash
npm view @manhquy/flow-skill dist-tags
{ latest: '0.1.0-rc.2', rc: '0.1.0-rc.2' }
```

**Correct replacement:**
```
| npm package | [`@manhquy/flow-skill@0.1.0-rc.2`](https://www.npmjs.com/package/@manhquy/flow-skill) — LIVE |
```

**Risk:** Users following README's direct link land on the latest package, but the visible version string contradicts npm's actual dist-tags, creating trust confusion.

---

#### Finding 2: README_VN.md Status Table — Outdated rc.1 Link

**File:** `README_VN.md`  
**Line:** 48  
**Current text:**
```
| npm package | [`@manhquy/flow-skill@0.1.0-rc.1`](https://www.npmjs.com/package/@manhquy/flow-skill) — LIVE |
```

**Correct replacement:**
```
| npm package | [`@manhquy/flow-skill@0.1.0-rc.2`](https://www.npmjs.com/package/@manhquy/flow-skill) — LIVE |
```

**Risk:** Vietnamese-language users receive outdated version claim.

---

#### Finding 3: docs/quality-metrics.md Line 4 — Stale Skill Version + npm Version

**File:** `docs/quality-metrics.md`  
**Line:** 4  
**Current text:**
```
Updated as the skill evolves. Current: **v0.21.0** (2026-07-11), **npm-wrapper v0.1.0-rc.1** LIVE on npm.
```

**Evidence:**
- Skill version: `grep "version:" skills/flow/SKILL.md` → `version: "0.22.0"`
- npm version: `npm view @manhquy/flow-skill dist-tags` → `rc: '0.1.0-rc.2'`
- v0.22.0 release date: `grep "## 0.22.0" CHANGELOG.md` → 2026-07-16

**Correct replacement:**
```
Updated as the skill evolves. Current: **v0.22.0** (2026-07-16), **npm-wrapper v0.1.0-rc.2** LIVE on npm.
```

**Risk:** Quality metrics header claims outdated skill version (off by one release), misleading anyone checking if the metric doc is current.

---

#### Finding 4: docs/quality-metrics.md Section Header Line 6 — Stale npm Version + Old Date

**File:** `docs/quality-metrics.md`  
**Line:** 6  
**Current text:**
```
## npm-wrapper v0.1.0-rc.1 — cross-platform npm distribution (2026-07-12, LIVE)
```

**Evidence:**
- `npm view @manhquy/flow-skill dist-tags` → `rc: '0.1.0-rc.2'`
- v0.1.0-rc.2 publish date: 2026-07-17 (per task context)

**Correct replacement:**
```
## npm-wrapper v0.1.0-rc.2 — cross-platform npm distribution (2026-07-17, LIVE)
```

**Risk:** Section title references outdated version, discouraging operators from trusting the documented metrics as current.

---

#### Finding 5: docs/quality-metrics.md Table Line 12 — Stale Version in Metrics Table

**File:** `docs/quality-metrics.md`  
**Line:** 12  
**Current text (within npm-wrapper metrics table):**
```
| **Version** | 0.1.0-rc.1 | LIVE on npm, `@manhquy/flow-skill@rc` |
```

**Evidence:**
- `npm view @manhquy/flow-skill dist-tags` → `rc: '0.1.0-rc.2'`

**Correct replacement:**
```
| **Version** | 0.1.0-rc.2 | LIVE on npm, `@manhquy/flow-skill@rc` |
```

**Risk:** Metrics table's "Version" row claims rc.1, directly contradicting the live npm registry.

---

## Ground-Truth Verification Summary

| Check | Result | Evidence |
|---|---|---|
| **npm current version** | rc.2 ✓ | `npm view @manhquy/flow-skill dist-tags` |
| **Test suite count** | 34 suites ✓ | `tests/run_all.sh` for-loop contains 34 entries |
| **Test check count** | 926 checks ✓ | CHANGELOG.md § 0.22.0 |
| **Semantic playbooks** | 21 files ✓ | `ls skills/flow/references/*.md \| wc -l` = 21 |
| **Skill version** | 0.22.0 ✓ | `grep "version:" skills/flow/SKILL.md` |
| **Plugin.json version** | 0.22.0 ✓ | `grep "version" .claude-plugin/plugin.json` |
| **portable-manifest version** | 0.22.0 ✓ | `grep "version" portable-manifest.json` |
| **"5 target agents" claim** | ✓ Present | README.md lines 167, 174 (NOT "4 targets") |
| **Dead links** | None found | All key relative paths exist |

---

## No Issues Found

The following checks passed:
- **Directory structure**: All paths referenced in docs exist
- **Version coherence**: SKILL.md / plugin.json / portable-manifest.json are aligned at 0.22.0
- **Test count accuracy**: README.md badge "34 suites / 926 checks" matches actual suite list
- **Playbooks count**: "21 semantic playbooks" is accurate (21 .md files, 1 .tsv catalog)
- **Install target count**: Correctly mentions "5 target agents" (claude, codex, agents, antigravity, cursor)
- **Release date**: v0.22.0 date 2026-07-16 consistent across README / CHANGELOG / codebase-summary

---

## Recommendations (Priority)

**Immediate (HIGH):**
1. Update README.md line 47: change `0.1.0-rc.1` → `0.1.0-rc.2`
2. Update README_VN.md line 48: same change
3. Update docs/quality-metrics.md line 4: change `v0.21.0` → `v0.22.0` and `rc.1` → `rc.2`
4. Update docs/quality-metrics.md line 6: change `0.1.0-rc.1` → `0.1.0-rc.2` and date `2026-07-12` → `2026-07-17`
5. Update docs/quality-metrics.md line 12: change `0.1.0-rc.1` → `0.1.0-rc.2`

**Follow-up process:**
- Consider a post-release docs sync checklist: `npm dist-tags` verify → update all rc/version references
- RETRO.md already documents the recurring "stale count" class (line 14–17); extend pattern to npm version staleness

---

## Unresolved Questions

None. All findings have direct evidence from ground-truth checks.

---

**Status:** DONE_WITH_CONCERNS  
**Summary:** 5 stale npm version references found and pinpointed for correction; no other factual inaccuracies detected.

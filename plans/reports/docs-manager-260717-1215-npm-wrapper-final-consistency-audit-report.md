# npm-wrapper Final Consistency Audit Report
**Date:** 2026-07-17 | **Auditor:** docs-manager | **Scope:** Advisory audit only (NO edits applied)

---

## Executive Summary

Audit of v0.1.0-rc.2 release documentation (README.md, README_VN.md, CHANGELOG.md, RELEASE_CHECKLIST.md, SECURITY.md, src/help.mjs, bin/cli.mjs) against ground truth (package.json version, TARGETS array, RESTART_HINTS map).

**Finding count:** 3 HIGH + 1 MEDIUM severity issues

---

## Ground Truth (Verified)

| Item | Source | Value |
|---|---|---|
| Release version | `package.json` line 3 | `0.1.0-rc.2` |
| Install target count | `src/constants.mjs` lines 3–58 | 5 targets (claude, codex, agents, antigravity, cursor) |
| Restart hints | `bin/cli.mjs` lines 154–166 | 5 keys with guidance text for each target |
| Dist-tags status | CHANGELOG.md line 5 + RELEASE_CHECKLIST.md line 60 | BOTH `latest` AND `rc` point to 0.1.0-rc.2 (confirmed via manual bootstrap-token flow) |
| Provenance status | CHANGELOG.md lines 71–97 + SECURITY.md line 58 | v0.1.0-rc.2 LIVE with SLSA Build Level 2 attestation (first CI-published version with provenance) |

---

## Finding 1: Stale Version Number in JSONL Contract Example (HIGH)

**File:** `npm-wrapper/README.md`  
**Line:** 96  
**Severity:** HIGH — Shows outdated example in public documentation  

**Current text (lines 92–100):**
```
## JSONL contract

`--json` streams one JSON object per line:

```jsonl
{"event":"plan","version":"0.1.0-rc.1","dryRun":false,"scope":"global","targets":["claude","codex"]}
```

**Ground truth:** package.json line 3 specifies version `0.1.0-rc.2`  
**Evidence:** 
- CHANGELOG.md line 5: Release date 2026-07-17, version 0.1.0-rc.2 (LIVE)
- RELEASE_CHECKLIST.md line 60: "0.1.0-rc.2 promoted to latest"
- bin/cli.mjs line 290: `PKG_VERSION` is read from package.json at runtime

**Correct text should be:**
```jsonl
{"event":"plan","version":"0.1.0-rc.2","dryRun":false,"scope":"global","targets":["claude","codex"]}
```

---

## Finding 2: Missing Path Qualifier in "After install" Agents Guidance (HIGH)

**File:** `npm-wrapper/README.md`  
**Line:** 61  
**Severity:** HIGH — User guidance inconsistent with actual CLI output  

**Current text:**
```markdown
- Agents home: restart/reload your tool if it does not auto-detect new skills.
```

**Ground truth:** bin/cli.mjs line 159–160 (RESTART_HINTS map)
```javascript
agents: 'Agents home (~/.agents/skills/): restart/reload your tool if it does not auto-detect new skills',
```

**Evidence:**
- The RESTART_HINTS value explicitly includes the path `(~/.agents/skills/)`
- doneLine() at line 168–171 assembles these hints verbatim for display
- README text should match what users will actually see in the CLI output

**Correct text should be:**
```markdown
- Agents home (~/.agents/skills/): restart/reload your tool if it does not auto-detect new skills.
```

---

## Finding 3: Missing RC-Window Exception in README_VN Provenance Section (HIGH)

**File:** `npm-wrapper/README_VN.md`  
**Lines:** 105–111  
**Severity:** HIGH — Vietnamese docs missing critical context about v0.1.0-rc.1 bootstrap exception  

**Current text (entire Provenance section):**
```markdown
## Provenance

Mỗi phiên bản publish có [npm provenance](https://docs.npmjs.com/generating-provenance-statements) attestation. Verify:

```
npm view @manhquy/flow-skill@<version> dist.attestations.provenance
```
```

**Ground truth:** README.md lines 122–130 (full Provenance section, includes RC-window exception)

**Evidence:**
- README.md lines 126–128 explicitly state: "RC-window exception: v0.1.0-rc.1 was published manually... All subsequent versions (v0.1.0-rc.2 onward) publish through the workflow and are attested."
- SECURITY.md line 58: "v0.1.0-rc.1 exception: this bootstrap version was published manually (Trusted Publisher requires the package to already exist before it can bind) and carries no attestation."
- Users installing rc.1 directly (for historical reasons) need to know it has no provenance
- Parity with English README: Vietnamese version should include this context

**Correct text should be (Vietnamese translation required):**

Add after the npm view code block:
```markdown

> **Ngoại lệ RC-window**: `v0.1.0-rc.1` được publish thủ công từ máy developer để bootstrap npm's Trusted Publisher (TP không thể bind tới package không tồn tại). npm không sinh provenance cho publish ngoài supported CI. Tất cả phiên bản sau (`v0.1.0-rc.2` trở đi) được publish qua workflow với attestation.
```

(Exact phrasing should match README.md lines 126–128 translated by a Vietnamese speaker)

---

## Finding 4: Documentation Organization Inconsistency Between Versions (MEDIUM)

**File:** `npm-wrapper/README_VN.md`  
**Scope:** Section ordering and completeness  
**Severity:** MEDIUM — Parity gap but may be intentional  

**Issues identified:**

### 4a. Section Order Reversal
- **README.md:** After install → Uninstall → **Troubleshooting** → **JSONL contract**
- **README_VN.md:** After install → Uninstall → **JSONL contract** → **Troubleshooting**

**Evidence:** Line numbers confirm sequence is reversed in Vietnamese version.

### 4b. JSONL Contract Section Truncated
- **README.md lines 91–116:** Full JSONL contract with "### Event contract" subsection (table) + exit codes table + additive contract note
- **README_VN.md lines 83–92:** Condensed version with note "Xem [README.md § JSONL contract](./README.md#jsonl-contract) cho bảng đầy đủ event/field/exit code" (See README.md for full table)

**Assessment:** This appears intentional (cross-reference pattern for Vietnamese brevity), but creates parity gap. Users reading README_VN don't have the full table without switching to English.

---

## Checks Passed

| Check | Status | Evidence |
|---|---|---|
| **1. Version mentions** | ✓ PASS | All other version refs correctly state 0.1.0-rc.2 (README.md lines 8, 13; README_VN.md lines 8, 13; CHANGELOG.md line 5; SECURITY.md line 58) |
| **2. Target count** | ✓ PASS | All docs correctly reference 5 targets; help.mjs uses dynamic count from TARGETS.length (line 18, 39) to prevent future drift |
| **3. All 5 targets in restart hints** | ✓ PASS (with Finding 2 exception) | README "After install" covers all 5 targets; claude, codex, antigravity, cursor guidance matches RESTART_HINTS; agents guidance present but missing path qualifier |
| **4. Provenance claims** | ✓ PASS | No stale "not yet live" or "pending" language; README.md line 8 correctly says "starting with rc.2"; SECURITY.md line 58 says "confirmed live"; CHANGELOG.md explains CI guard fix and OIDC success |
| **5. Dist-tag claim accuracy** | ✓ PASS | CHANGELOG.md line 5 "latest + rc both point here" matches RELEASE_CHECKLIST.md evidence of manual promotion (line 60) and is confirmed by worktree memory |
| **6. README_VN parity (sections present)** | ✓ PASS (with Finding 3 exception) | Both docs have Install, Non-interactive, Targets, After install, Uninstall, JSONL contract, Requirements, Provenance, Security, License; exception: RC-window note in Provenance only in English |

---

## Cross-Reference Validation

| Reference | Source → Target | Status |
|---|---|---|
| README.md § After install → bin/cli.mjs RESTART_HINTS | README guides should match printed output | ✗ FAIL: Agents path missing (Finding 2) |
| help.mjs targetCount → TARGETS.length | Should always match | ✓ PASS: Dynamic count at lines 18, 39 |
| CHANGELOG line 5 dist-tags → RELEASE_CHECKLIST line 60 | Release claim vs implementation log | ✓ PASS: Both confirm rc.2 promoted to latest |
| SECURITY.md provenance → CHANGELOG provenance explanation | Threat model consistency | ✓ PASS: Both correctly state rc.1 manual, rc.2+ have attestation |
| package.json version → PKG_VERSION usage | Runtime version must match | ✓ PASS: bin/cli.mjs line 290 reads from package.json |

---

## Summary Table

| Finding | File | Line | Severity | Category | Evidence |
|---|---|---|---|---|---|
| Stale JSONL version | README.md | 96 | HIGH | Version number | Shows 0.1.0-rc.1, should be 0.1.0-rc.2 |
| Missing agents path | README.md | 61 | HIGH | User guidance | RESTART_HINTS includes path; README omits it |
| Missing RC exception | README_VN.md | 105–111 | HIGH | Documentation completeness | Parity gap vs README.md lines 126–128 |
| Section order & JSONL truncation | README_VN.md | 83–92 | MEDIUM | Organization/parity | Troubleshooting/JSONL reversed; full table behind cross-ref |

---

## Validation Commands (for reference, not executed in advisory mode)

To verify findings would be fixed:
```bash
# Check version in JSONL example
grep -n '0.1.0-rc.1' npm-wrapper/README.md  # Should return line 96 only (JSONL example)

# Check Agents path in After install section
grep -A 5 "^- Agents home" npm-wrapper/README.md  # Should see (~/.agents/skills/) after fix

# Compare RESTART_HINTS text
grep -A 4 "const RESTART_HINTS" npm-wrapper/bin/cli.mjs | grep agents
# Output: agents: 'Agents home (~/.agents/skills/): restart/reload...'

# Verify README_VN missing RC exception
grep -c "RC-window\|bootstrap" npm-wrapper/README_VN.md  # Should return 0 or 1 before fix
```

---

## Recommendations for Editor

No edits are being applied per audit scope. When updates are made:

1. **Finding 1:** Replace `0.1.0-rc.1` with `0.1.0-rc.2` in JSONL example (README.md:96)
2. **Finding 2:** Add `(~/.agents/skills/)` to agents guidance (README.md:61)
3. **Finding 3:** Translate and add RC-window exception block to README_VN.md Provenance section
4. **Finding 4 (optional):** Consider whether Vietnamese section reorganization is intentional or should match English; clarify truncation rationale in cross-reference comment

---

**Status:** DONE_WITH_CONCERNS

**Summary:** 3 HIGH severity stale content issues + 1 MEDIUM documentation organization gap found. All other cross-checks passed. Provenance, version, and target-count claims are accurate; dist-tag promotion confirmed live.

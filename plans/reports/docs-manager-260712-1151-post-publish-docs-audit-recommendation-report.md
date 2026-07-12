# Post-Publish Docs Audit — Recommendations

**Date:** 2026-07-12 · **Status:** Report only (no changes made) · **Scope:** Coherence audit after npm-wrapper v0.1.0-rc.1 publish

---

## Audit Summary

Package `@manhquy/flow-skill@0.1.0-rc.1` went live on npm 2026-07-12 11:47. The repo now has two parallel distribution channels: the reference `install.sh/install.ps1` (in repo root) and the new npm-wrapper installer (in `npm-wrapper/` monorepo subdir). Docs are **incoherent post-publish** — most reference docs ignore npm entirely, and README.md claims npm is "coming soon."

---

## File-by-File Audit

### 1. **README.md** (repo root) — **UPDATE RECOMMENDED**

**Current state (lines 256–298):**
- Section A (npm) labeled "coming soon"
- Section B (git + bash) is the detailed reference
- Ordering suggests git-clone is still the primary install path

**Gap:** npm is now live but README still advertises it as future.

**Concrete diff:**
1. Swap sections A & B positions → npm becomes install method 1 (primary)
2. Update section A status: remove "coming soon", add "rc.1 active, stable v0.1.0 pending 7-day validation window"
3. Add version pinning guidance: `@rc` vs `@0.1.0-rc.1` (pre-release tuples don't match semver ranges)
4. Add one-line cross-reference to `npm-wrapper/README.md` for non-interactive/CI flags + SECURITY.md
5. Keep section B (git install) as method 2, relabel "from git repo (upstream reference)"
6. One-sentence note: "Repo is the single source of truth; re-run `bash install.sh global` after updates"

**Why:** New users landing on GitHub should see npm first. The npm-wrapper README already covers CI/non-interactive; main README shouldn't duplicate it, just point to it.

---

### 2. **docs/codebase-summary.md** — **UPDATE RECOMMENDED**

**Current state (lines 6–31):**
- Layout section lists `skills/flow/`, `tests/`, `install.sh`, `docs/`, `plans/`
- No mention of `npm-wrapper/`

**Gap:** npm-wrapper is now a core distribution artifact, but codebase summary omits it.

**Concrete diff:**
1. Add entry after `install.sh` line:
   ```
   ├── npm-wrapper/              # npm installer for the skill
   │   ├── index.mjs             # CLI entry point
   │   ├── installer.mjs         # core install logic (4 homes, semantics parity)
   │   ├── detector.mjs          # detect installed harnesses
   │   ├── cli.mjs               # interactive + JSONL output
   │   ├── tests/                # 26/26 node:test suite (cross-OS CI)
   │   ├── package.json          # @manhquy/flow-skill + 1 dep (clack)
   │   ├── .github/workflows/    # publish workflow (OIDC Trusted Publisher)
   │   └── README.md + SECURITY.md
   ```

**Why:** npm-wrapper is now load-bearing infrastructure for v0.1 users; codebase summary must acknowledge it.

---

### 3. **docs/system-architecture.md** — **UPDATE RECOMMENDED**

**Current state (lines 1–81):**
- Describes three cooperating layers (Semantic / Mechanical / Durable)
- Control flow details how `/flow` is invoked
- No mention of distribution channels or npm

**Gap:** Distribution is a tier-0 user-visible architectural choice, but architecture doc ignores it.

**Concrete diff:**
1. Add new section after "Layers" (before "Why this shape"):
   ```
   ## Distribution channels
   
   `/flow` ships via two concurrent paths:
   
   | Channel | Entry point | Notes |
   |---|---|---|
   | **npm** | `npx @manhquy/flow-skill@rc` | Primary (cross-OS Node, no bash needed); monorepo `npm-wrapper/` |
   | **git + bash** | `bash install.sh global` | Reference install (fine-grained control, script-readable) |
   | **git + PowerShell** | `pwsh install.ps1 global` | Windows preferred (avoids WSL path confusion) |
   | **Plugin marketplace** | `/plugin marketplace add <repo-url>` | Team/shared machine install |
   | **Manual copy** | copy `skills/flow/` to `~/.claude/skills/flow` | Minimal (no doctor, no auto-detection) |
   
   The repo is single source of truth; the npm installer (`npm-wrapper/`) is the semantic wrapper that keeps both paths in parity (same cleanup dirs, same preservation logic, same chmod).
   ```

**Why:** A user picking an install method needs to understand the trade-offs. npm is low-friction and cross-OS; bash is transparent and scriptable. Both ship the same skill.

---

### 4. **docs/quality-metrics.md** — **UPDATE RECOMMENDED**

**Current state:**
- Tracks v0.21.0 (skill engine) quality extensively
- No mention of npm-wrapper or npm-installer test coverage
- Quality section lists test coverage "31 suites / 799 checks" — this counts only flow-skill tests

**Gap:** npm-wrapper has 26 tests and cross-OS CI, but quality-metrics.md doesn't report it.

**Concrete diff:**
1. Add new subsection at the end (after v0.21.0 section):
   ```
   ## npm-wrapper v0.1.0-rc.1 — installer quality (2026-07-12)
   
   Standalone npm package (`@manhquy/flow-skill`) for cross-OS, cross-terminal install.
   
   | Component | Metric | Value |
   |---|---|---|
   | Installer code | LOC | ~350 (index.mjs, installer.mjs, detector.mjs, cli.mjs) |
   | Test coverage | Suites / assertions | 26 green (node:test) |
   | Test scope | Coverage | installer + detector + CLI smoke + cross-platform |
   | Dependencies | Count | 1 (clack/prompts for interactive) |
   | CI matrix | OS × Node version | ubuntu/macos/windows × Node 22/24 |
   | Red-team findings | Round 1 | 26 raw → 16 accepted (1 Critical: atomic-swap-destroy, now designed out) |
   | Red-team findings | Round 2 | 28 raw → 13 accepted (4 obsoleted by redesign) |
   | Security: Publish | Method | OIDC Trusted Publisher (rc.2+); rc.1 manual bootstrap |
   | Security: Provenance | SLSA level | L2 signing (rc.2+) |
   | Install homes tested | Count | 4 (Claude Code, Codex CLI, Agents home, Antigravity 2-dest) |
   | Monorepo sync | Status | atomic tag (npm@X.Y.Z for installer, v0.X for skill) |
   
   **Stability note:** RC phase (7-day validation window before `v0.1.0` stable). See `npm-wrapper/README.md` for pre-release pinning guidance.
   ```

**Why:** npm-wrapper is now a product surface; its quality must be tracked alongside the skill itself.

---

### 5. **npm-wrapper/README.md** — **NO CHANGE NEEDED**

**Current state:** 130 lines, comprehensive.

**Assessment:**
- Self-contained, well-structured, linked from npm registry
- SECURITY.md cross-linked explicitly
- Targets + detection table is clear
- JSONL contract documented
- Troubleshooting + uninstall instructions present

**Note:** If a user lands from npmjs.com, they get everything they need. Linking this from the main repo README (as recommended in #1) is sufficient. No edit required.

---

### 6. **docs/journals/** — **NO CHANGE NEEDED**

**Current state:**
- `260712-flow-skill-npm-wrapper-v0.1.0-rc.1-shipped-vi.md` — comprehensive post-mortem (128 lines)
- `260712-flow-skill-npm-published-announcement-drafts-vi.md` — distribution checklist + announcement templates
- `260711-v021-eval-trust-hardening-shipped-vi.md` — skill v0.21.0 changelog

**Assessment:** Journals are detailed and honest. They're meant to capture **why** and **how** decisions were made, not to be in the reference docs. Readers interested in the story should land here. No edit needed.

---

## Coherence Verdict

**Before audit:** Docs are **incoherent post-publish**
- README.md (public-facing) says npm is "coming soon"
- Core docs (codebase-summary, system-architecture) ignore npm-wrapper entirely
- Quality metrics has no npm-wrapper data
- Journals have the full story but aren't linked from reference docs

**After recommended edits:** Docs will be **coherent and user-ready**
- README.md correctly positions npm as primary install method
- Codebase-summary reflects the monorepo structure
- System-architecture acknowledges distribution as a design choice
- Quality-metrics tracks npm-wrapper alongside the skill
- Journals remain the deep-dive source for historical context

---

## Recommended Edit Sequence

1. **README.md** — swap A/B, update A status, add cross-reference (medium complexity; 10 lines changed)
2. **docs/codebase-summary.md** — add npm-wrapper layout entry (low complexity; 8 lines added)
3. **docs/system-architecture.md** — add Distribution section (medium complexity; 20 lines added)
4. **docs/quality-metrics.md** — add npm-wrapper v0.1.0-rc.1 section (low complexity; 25 lines added)

**Estimated total edits:** ~60 lines across 4 files. No deletions, only additions + reordering.

---

## Unresolved Questions

None. All gaps are actionable with concrete diffs. Journals contain the full decision narrative if deeper context is needed (e.g., why npm-wrapper is in a monorepo, why OIDC was chosen, why rc.1 gates admission to stable).

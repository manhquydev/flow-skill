# Research Report: npx installer — Antigravity fix + cross-agent expansion (Cursor/Windsurf/Cline)

Date: 2026-07-17 · Scope: `npm-wrapper/` (the `npx @manhquy/flow-skill` installer)

## Executive Summary

**Problem 1 (Antigravity "doesn't work" via npx)** — root cause found, no code bug in the
detect/copy/dual-dest logic itself. `npm-wrapper/skills/flow/` (the content actually bundled
into the published npm tarball) is **stale**: last synced 2026-07-11 (v0.21.0), missing every
v0.22 file (`concierge.md`, `native-rituals.md`, `forge-idea.md`, `flow-catalog.tsv`,
`eval/fixtures/routing/`). `npm run sync` was never re-run + republished after v0.22 shipped.
Anyone installing via `npx @manhquy/flow-skill@rc` — for ANY target, not just Antigravity —
gets 5-day-old content. This alone plausibly explains "feels broken" if the operator expected
v0.22 behavior. Detection, the 2-destination copy, retry-on-lock, and live skill discovery by
the real `agy` CLI were all verified working end-to-end on this machine (see §1).

**Problem 2 (expand to Cursor/Windsurf/etc.)** — the market has converged hard on
**AGENTS.md** as the cross-tool lowest-common-denominator (OpenAI-authored Aug 2025, now under
the Linux Foundation's Agentic AI Foundation alongside MCP; read natively by 28+ tools incl.
Cursor, Windsurf, Cline, Copilot, Aider, Zed, Devin, Jules, Amp, and now Claude Code itself).
Above that floor, each tool has its OWN richer, incompatible rules/skills format — Cursor
`.mdc` under `.cursor/rules/` (+ `.cursor/skills/`), Windsurf `.windsurfrules` /
`.windsurf/rules/`, Cline `.clinerules` / `.clinerules/`. Several third-party installers
already solve exactly this fan-out (skills-hub.ai, `agent-skills-cli`, `sdlc-skills`) —
recommend using them as the pattern reference, not reinventing detection heuristics per tool.

## Research Methodology
- Local: read `npm-wrapper/src/{constants,detect,installer}.mjs`, ran the local dev CLI and
  the REAL published `npx @manhquy/flow-skill@rc` against this machine (which has a genuine
  Antigravity install), live-tested `agy -p` skill discovery.
- Web: 5 searches (AGENTS.md standard, Cursor rules/skills, Windsurf rules, Cline rules,
  existing multi-agent installers). Sources cited inline.

## Key Findings

### 1. Antigravity npx investigation (local, reproduced live)

| Check | Result |
|---|---|
| `detectAll()` markers (`.gemini/antigravity-cli`, `.gemini/config/skills`) | Present on this machine; `detected: true` correctly |
| Local dev CLI, `--target antigravity --dry-run` | Correct plan, both destinations |
| Local dev CLI, `--target antigravity` (real run) | `install:done`, `success: true`, both dests written |
| **Published** `npx @manhquy/flow-skill@rc --target antigravity --dry-run` | Same correct plan — mechanical layer is fine on the real registry package too |
| `agy -p "do you have a flow skill? describe it"` | **Real answer, correctly describes SKILL.md content** — skill discovery genuinely works, no manifest-registration blocker (the `.datacloud_skills_manifest` in `~/.gemini/config/skills/` is Google's own bundled GCP skill pack — `bigquery-data-transfer-service`, `gcp-dataflow`, etc. — unrelated to user-dropped skills) |
| `npm-wrapper/skills/flow/SKILL.md` version | **`0.21.0`**, mtime 2026-07-11 — vs source-of-truth `skills/flow/SKILL.md` = `0.22.0`, mtime 2026-07-16 |
| `npm-wrapper/skills/flow/references/{concierge,native-rituals,forge-idea}.md` | **Missing entirely** |
| `npm view @manhquy/flow-skill dist-tags` | `rc: 0.1.0-rc.1`, single published version — never republished after v0.22 |

`installAntigravity()` (installer.mjs:207) is already well-engineered for the 2-destination
case: mirrors `install.sh`'s no-rollback-on-partial-failure behavior deliberately (a prior
review finding, per the code comment), reports which dest succeeded, lets the user re-run.
`withRetry()` already retries `EBUSY`/`EPERM`/`ENOTEMPTY` (the codes Windows throws when an
agent — Claude Code, Codex, **or Antigravity** — holds an open file handle in the destination)
with exponential backoff. No bug found here.

**Conclusion**: the concrete, reproducible defect is a **release-process gap**, not a
detection/install-logic bug: `scripts/sync.mjs` (dev-only, copies `../skills/flow` →
`npm-wrapper/skills/flow`) was not re-run + `npm publish` was not re-cut after v0.22 shipped
on 2026-07-16. Fix is operational (run sync, bump `npm-wrapper/package.json` version, publish),
not a code change — flagged here for the operator's decision on when to cut that release; not
applied in this research pass.

**Unresolved**: this explains a stale-content symptom but I could not reproduce a hard
Antigravity-specific *failure* (exit code, exception, "not found") from the description alone.
If the operator saw a specific error message, re-run with `--json` and share the
`install:done`/`error` field — the mechanical layer already surfaces per-destination errors
structurally; nothing here needed guessing beyond what the JSON event stream already reports.

### 2. Cross-tool agent landscape (2026)

| Tool | Native format | Location | Notes |
|---|---|---|---|
| **AGENTS.md** (standard) | Plain Markdown, no schema/frontmatter | Repo root (nearest-file-wins for subprojects) | OpenAI-authored, now Linux Foundation AAIF; 28+ tools, 60k+ repos. Read natively by Codex CLI, Copilot, **Cursor**, **Windsurf**, Amp, Devin, **Aider**, Zed, Jules, VS Code, JetBrains Junie. Claude Code now reads it too (CLAUDE.md stays its richer native format). Gemini CLI still GEMINI.md-only. [[AGENTS.md](https://agents.md/)] |
| **Cursor** | `.mdc` files (YAML frontmatter + markdown, path-scoped) under `.cursor/rules/`; skills under `.cursor/skills/` or `~/.cursor/skills/` | Repo (`.cursor/rules/`) or global (`~/.cursor/skills/`) | Legacy single-file `.cursorrules` still read but superseded. "Rules load every conversation; skills load on-demand by trigger" — distinct concepts. [[Cursor Docs — Rules](https://cursor.com/docs/rules)] |
| **Windsurf** (Cascade) | `.windsurfrules` (legacy, still read) or `.windsurf/rules/*.md` (current, path/activation-scoped) | Repo root or `.windsurf/rules/` | 12,000-char cap per workspace rule file, 6,000-char global. Must be committed (not gitignored) for team parity. [[Windsurf Cascade Memories](https://docs.windsurf.com/windsurf/cascade/memories)] |
| **Cline** | `.clinerules` (single file) or `.clinerules/*.md` (directory, merged) | Repo root | All `.md`/`.txt` in `.clinerules/` merged into one context block; conditional activation via YAML frontmatter; workspace rules win over global. [[Cline Docs — Rules](https://docs.cline.bot/customization/cline-rules)] |

### 3. Existing multi-agent installers (pattern reference, not to copy verbatim)

- **skills-hub.ai** — `npx @skills-hub-ai/cli install <skill>` detects the tool, converts
  SKILL.md → the target's native format (e.g. auto-converts to Cursor `.mdc`), writes to the
  right path, no restart needed. [[skills-hub.ai](https://skills-hub.ai/)]
- **`agent-skills-cli`** — installs to Claude, Cursor, Copilot, Windsurf, Cline + 37 more,
  detecting per-tool presence the same way flow's own `detect.mjs` already does (marker-file
  presence).
- **sdlc-skills**, **claude-skills** (alirezarezvani) — same fan-out pattern for Claude Code /
  Cursor / Windsurf / Copilot / Codex, MIT-licensed reference implementations worth a closer
  read (not fetched in depth this pass — budget-capped at 5 searches).

## Comparative analysis — what flow-skill would need per new target

flow already ships a single `SKILL.md` + `references/*.md` bundle designed to be read verbatim
by any markdown-reading agent (that's *why* Codex/Antigravity already work — they just read
`SKILL.md` directly, same as Claude). Two integration tiers are possible:

1. **Cheap tier — AGENTS.md-compatible targets** (Cursor, Windsurf, Aider, Copilot, Zed,
   Devin, Amp, Jules): these already read AGENTS.md-format content. Flow's `SKILL.md` is
   already plain Markdown with a frontmatter block Claude-specific tools use for
   registration — the BODY is agent-agnostic prose. A `detect.mjs` marker + a destTemplate of
   `AGENTS.md` (repo root) OR `.cursor/rules/flow.mdc` / `.windsurf/rules/flow.md` /
   `.clinerules/flow.md` per tool would work with the SAME copy-and-strip-frontmatter
   mechanism the installer already has (`installer.mjs`'s `install()` is generic file-copy;
   only `constants.mjs`'s `TARGETS` array needs new entries + a lightweight per-tool
   frontmatter-strip if the target format forbids Claude's YAML block).
2. **Rich tier — dedicated skill dirs** (what Claude/Codex/Antigravity/Agents already get):
   only worth it for tools with an actual on-demand skill-loading mechanism, not just
   always-on rules. Cursor's `.cursor/skills/` (global) is exactly this — same shape as
   flow's existing `~/.claude/skills/flow` target, could reuse `installAntigravity`-style
   dual/multi-dest logic almost unchanged.

Cline has no separate "skill" concept (only always-loaded rules) — flow's full ~20-file
reference tree would need collapsing into the single-context-block `.clinerules/` shape,
which is a content-adaptation problem, not an installer-mechanics one.

## Implementation Recommendations (not applied — research only)

### Quick wins (installer-mechanics only, no content redesign)
1. **Fix the republish gap first** — `npm run sync && npm version <next> && npm publish
   --tag rc` after any skill-content release. This is the actual "antigravity doesn't work"
   fix and blocks nothing else. Consider a CI guard: fail `ci.yml`'s publish workflow if
   `npm-wrapper/skills/flow/SKILL.md`'s `version:` field doesn't match the root
   `skills/flow/SKILL.md` (mirrors the existing `flow.sh coherence` version-agreement check).
2. **Add Cursor as a 5th target** — highest ROI: real skill-dir support (`.cursor/skills/`),
   not just always-on rules, and largest install base per the search results. Marker:
   `.cursor` presence (parity with how `claude`'s marker is just `.claude`).

### Medium-effort (needs a frontmatter-strip step)
3. **AGENTS.md as a shared 6th target** — one new destTemplate (`AGENTS.md` at repo root,
   project-scope only, same restriction as today's `claude`-project-scope-only rule) would
   cover Windsurf + Aider + Copilot + Zed + Devin + Amp + Jules simultaneously without 6
   separate integrations. Content = `SKILL.md` body minus the Claude-specific YAML
   frontmatter block.

### Skip / low priority
4. **Cline** — real demand unclear, and the merge-all-files-into-one-context-block model
   fights flow's ~20-file reference architecture (would need genuine content restructuring,
   not just path changes). Revisit only if there's user demand signal.

## Resources & References
- [AGENTS.md](https://agents.md/) — canonical spec site
- [AGENTS.md Spec Guide 2026](https://www.morphllm.com/agents-md-guide)
- [Cursor Docs — Rules](https://cursor.com/docs/rules)
- [Cursor community — "Skills are installed as Rules"](https://forum.cursor.com/t/skills-are-installed-as-rules/152793)
- [Windsurf Cascade Memories (official docs)](https://docs.windsurf.com/windsurf/cascade/memories)
- [Cline Docs — Rules](https://docs.cline.bot/customization/cline-rules)
- [skills-hub.ai](https://skills-hub.ai/)
- [alirezarezvani/claude-skills (GitHub, multi-agent reference impl)](https://github.com/alirezarezvani/claude-skills)

## Unresolved questions
1. Operator's exact Antigravity failure symptom (error text / exit code) — not provided;
   the staleness theory is the most likely explanation found, but not 100% confirmed as
   THE complaint without the original error.
2. Priority order for new targets (Cursor first is my read of ROI; confirm before scoping
   a plan) — and whether AGENTS.md should be opt-in (checkbox in the interactive installer)
   or bundled into the existing `claude`/`alwaysInclude` default.
3. Whether to version-gate the npm republish now (fix v0.22 staleness) as a prerequisite
   before scoping the Cursor/AGENTS.md expansion, or bundle both into one release.

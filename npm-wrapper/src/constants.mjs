// Install targets. Antigravity has 2 destinations (CLI + IDE) driven by one target.
// Marker paths are relative to os.homedir() — no leading slash/backslash.
export const TARGETS = [
  {
    name: 'claude',
    label: 'Claude Code',
    // any presence of ~/.claude counts — Claude is `alwaysInclude` regardless
    markers: ['.claude'],
    destTemplates: ['~/.claude/skills/flow'],
    alwaysInclude: true,
    projectScopeAllowed: true,
  },
  {
    name: 'codex',
    label: 'Codex CLI',
    markers: ['.codex/skills'],
    destTemplates: ['~/.codex/skills/flow'],
    alwaysInclude: false,
    projectScopeAllowed: false,
  },
  {
    name: 'agents',
    // v0.23: this is also the universal Agent-Skills home — the open standard
    // (agentskills.io) directory 32-40 spec-compliant tools (incl. Cursor, Devin) read.
    label: 'Agents home (~/.agents) — universal Agent-Skills home (Zed, Antigravity, Open Runtimes)',
    markers: ['.agents/skills', '.config/zed'],
    destTemplates: ['~/.agents/skills/flow'],
    alwaysInclude: false,
    projectScopeAllowed: false,
  },
  {
    name: 'antigravity',
    label: 'Antigravity (CLI + IDE)',
    // Never stat bare ~/.gemini — that dir is shared by non-Antigravity Google Gemini CLI.
    markers: ['.gemini/antigravity-cli', '.gemini/config/skills'],
    destTemplates: [
      '~/.gemini/antigravity-cli/skills/flow',
      '~/.gemini/config/skills/flow',
    ],
    alwaysInclude: false,
    projectScopeAllowed: false,
  },
  {
    name: 'cursor',
    label: 'Cursor',
    // v0.23 — red-team C1: bare `.cursor` is shared by unrelated editor config (settings,
    // argv.json, caches) that exists for every Cursor user; a bare marker would false-positive
    // `detected:true` and silently auto-install under `--yes` for users who never asked. The
    // skills subdir is the real signal — mirrors the antigravity bare-`.gemini` guard above.
    // Path confirmed by a live probe (not web research): this machine's real
    // `~/.cursor/skills/find-skills` is a symlink into `~/.agents/skills/find-skills`,
    // confirming `~/.cursor/skills/<name>` as Cursor's actual read location.
    markers: ['.cursor/skills'],
    destTemplates: ['~/.cursor/skills/flow'],
    alwaysInclude: false,
    projectScopeAllowed: false,
  },
  {
    name: 'omp',
    label: 'OMP (~/.omp/agent/skills)',
    // Same false-positive discipline as cursor/antigravity: bare `~/.omp` exists for every OMP
    // runtime user (logs, cache, run state — none of it skills-related), so the marker must be
    // the genuine skills dir `.omp/agent/skills`. Live probe (this host, 2026-10-13): the real
    // skills home is `~/.omp/agent/skills/` (kit skills installed there, e.g. ak-*), while
    // `~/.omp/skills` does not exist; ak adapter docs describing `.omp/skills/ak-<slug>` are a
    // distribution convention, not this runtime's on-disk layout. Explicit `--target omp` still
    // installs even when the home is absent (created on demand, same as explicit codex).
    markers: ['.omp/agent/skills'],
    destTemplates: ['~/.omp/agent/skills/flow'],
    alwaysInclude: false,
    projectScopeAllowed: false,
  },
  {
    name: 'widelai',
    label: 'WidelCode (~/.widelai/skills)',
    // Vendor docs (widelai.com/blog/widelcode-cli-vs-code-extension-release):
    // skills live under `.widelai/skills`, personal defaults under `~/.widelai/` with the
    // same layout; rules are read from `.widelai/rules/*.md`. WidelCode does NOT read the
    // universal `~/.agents/skills` home, so a dedicated target is required. Marker
    // discipline mirrors cursor/omp: bare `~/.widelai` holds credentials.json for every
    // WidelCode user, so the marker must be the genuine skills dir `.widelai/skills`.
    // The rules file + AGENTS.md pointer line are placed by installWidelaiExtras
    // (installer.mjs) from the generated sibling payload (sync.mjs).
    markers: ['.widelai/skills'],
    destTemplates: ['~/.widelai/skills/flow'],
    alwaysInclude: false,
    projectScopeAllowed: false,
  },
];

export const TARGET_NAMES = TARGETS.map((t) => t.name);
export const CLI_NAME = 'flow-skill';

// WidelCode rules pointer line (T1): the single line the installer appends to
// the user's ~/.widelai/AGENTS.md (idempotent, only if absent). Home for the
// exact wording is here; installer.mjs reads it from this module.
export const RULES_POINTER_LINE = 'FlowSkill rules: see .widelai/rules/flowskill.md';

// F3 fix: read version from package.json at runtime so `npm version` bumps propagate to the
// JSON `plan` event without a hand-edit here.
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
const __dirname = dirname(fileURLToPath(import.meta.url));
const pkgRoot = resolve(__dirname, '..');
const pkgJson = JSON.parse(
  readFileSync(resolve(pkgRoot, 'package.json'), 'utf8')
);
export const PKG_VERSION = pkgJson.version;

// Skill product version (SKILL.md metadata.version) is a SEPARATE axis from the npm
// installer package version. Surface both so `npx … --help` / plan events cannot be
// misread as "stale skill" when the user expected 0.22.x and saw 0.1.0-rc.N.
function readSkillVersion() {
  const skillMd = resolve(pkgRoot, 'skills', 'flow', 'SKILL.md');
  if (!existsSync(skillMd)) return null;
  const text = readFileSync(skillMd, 'utf8');
  // Frontmatter only — first `version: "x.y.z"` under metadata (or any YAML version line).
  // Indented under `metadata:` in YAML frontmatter (two spaces typical).
  const m = text.match(/^\s*version:\s*["']?([0-9][0-9A-Za-z.+-]*)["']?\s*$/m);
  return m ? m[1] : null;
}
export const SKILL_VERSION = readSkillVersion();

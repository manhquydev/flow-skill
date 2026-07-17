// 5 install targets. Antigravity has 2 destinations (CLI + IDE) driven by one target.
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
    label: 'Agents home (~/.agents) — universal Agent-Skills home',
    markers: ['.agents/skills'],
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
];

// Subdirs the installer cleans out before merge-copying — parity with install.sh:25.
export const CLEANUP_SUBDIRS = [
  'runner',
  '_templates',
  'law',
  'references',
  'harness',
  'playbooks',
];

export const TARGET_NAMES = TARGETS.map((t) => t.name);
export const CLI_NAME = 'flow-skill';

// F3 fix: read version from package.json at runtime so `npm version` bumps propagate to the
// JSON `plan` event without a hand-edit here.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
const __dirname = dirname(fileURLToPath(import.meta.url));
const pkgJson = JSON.parse(
  readFileSync(resolve(__dirname, '..', 'package.json'), 'utf8')
);
export const PKG_VERSION = pkgJson.version;

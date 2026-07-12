// 4 install targets. Antigravity has 2 destinations (CLI + IDE) driven by one target.
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
    label: 'Agents home (~/.agents)',
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

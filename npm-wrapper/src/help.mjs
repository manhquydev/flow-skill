import { CLI_NAME, PKG_VERSION, SKILL_VERSION, TARGETS } from './constants.mjs';

export function renderHelp() {
  const targetRows = TARGETS.map((t) => `    ${t.name.padEnd(12)} ${t.label}`).join('\n');
  const targetCount = TARGETS.length;
  const skillBit = SKILL_VERSION ? ` (ships skill v${SKILL_VERSION})` : '';
  return `${CLI_NAME} v${PKG_VERSION}${skillBit}

Install the flow skill into your coding agent(s).

USAGE
  npx @manhquy/flow-skill@latest

  Always use @latest so npx fetches the newest release.
  Bare "npx @manhquy/flow-skill" may reuse a stale cache.

OPTIONS
  -y, --yes                    Skip prompts; install to default selection (detected + Claude)
  -t, --target <name>          Explicit target (repeatable, comma-separated also OK)
      --all                    Install to all ${targetCount} targets regardless of detection
      --project                Project scope (Claude only) — writes to <dir>/.claude/skills/flow
      --dir <path>             Project directory (implies --project). Default: cwd
      --json                   Emit JSONL events (plan, install:start, install:done, summary)
      --dry-run                Print the plan; do not touch disk
  -h, --help                   Show this help

TARGETS
${targetRows}

  Notes:
  - Antigravity writes 2 destinations (CLI + IDE skill homes).
  - --project supports only "claude".
  - "npm i" alone does not install the skill — you must run this CLI.
  - Installer version (this package) ≠ skill product version (SKILL.md).

EXAMPLES
  npx @manhquy/flow-skill@latest
  npx @manhquy/flow-skill@latest --yes
  npx @manhquy/flow-skill@latest --yes --all
  npx @manhquy/flow-skill@latest --yes -t claude -t codex
  npx @manhquy/flow-skill@latest --yes --project --dir .
  npx @manhquy/flow-skill@latest --yes --all --dry-run --json

MORE
  Docs:     https://github.com/manhquydev/flow-skill#readme
  Security: https://github.com/manhquydev/flow-skill/blob/main/SECURITY.md
`;
}

import { CLI_NAME, PKG_VERSION, TARGETS } from './constants.mjs';

export function renderHelp() {
  const targetRows = TARGETS.map((t) => `    ${t.name.padEnd(12)} ${t.label}`).join('\n');
  return `${CLI_NAME} v${PKG_VERSION}

Install the flow skill into your coding agent(s).

USAGE
  npx @manhquy/flow-skill [options]

OPTIONS
  -y, --yes                    Skip prompts; install to default selection (detected + Claude)
  -t, --target <name>          Explicit target (repeatable, comma-separated also OK)
      --all                    Install to all 4 targets regardless of detection
      --project                Project scope (Claude only) — writes to <dir>/.claude/skills/flow
      --dir <path>             Project directory (implies --project). Default: cwd
      --json                   Emit JSONL events (plan, install:start, install:done, summary)
      --dry-run                Print the plan; do not touch disk
  -h, --help                   Show this help

TARGETS
${targetRows}

  Notes:
  - Antigravity target writes 2 destinations: ~/.gemini/antigravity-cli/skills/flow AND ~/.gemini/config/skills/flow.
  - --project scope supports only "claude" (agent-contract limitation).
  - Non-detected targets can still be forced via --target or --all.

EXAMPLES
  npx @manhquy/flow-skill                                  # interactive multi-select
  npx @manhquy/flow-skill --yes                            # non-interactive; default selection
  npx @manhquy/flow-skill --yes --all                      # force all 4 targets
  npx @manhquy/flow-skill --yes -t claude -t codex         # explicit targets
  npx @manhquy/flow-skill --project --dir .                # project-scoped install (Claude only)
  npx @manhquy/flow-skill --yes --all --dry-run --json     # CI JSONL preview

MORE
  Docs:     https://github.com/manhquy/flow-skill-npm#readme
  Security: https://github.com/manhquy/flow-skill-npm/blob/main/SECURITY.md
`;
}

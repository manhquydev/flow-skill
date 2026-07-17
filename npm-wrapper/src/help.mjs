import { CLI_NAME, PKG_VERSION, TARGETS } from './constants.mjs';

export function renderHelp() {
  const targetRows = TARGETS.map((t) => `    ${t.name.padEnd(12)} ${t.label}`).join('\n');
  // v0.23 H5 (red-team): derive the count from TARGETS.length so a future target addition can
  // never again leave a stale hardcoded number in the help text.
  const targetCount = TARGETS.length;
  return `${CLI_NAME} v${PKG_VERSION}

Install the flow skill into your coding agent(s).

USAGE
  npx @manhquy/flow-skill [options]

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
  - Antigravity target writes 2 destinations: ~/.gemini/antigravity-cli/skills/flow AND ~/.gemini/config/skills/flow.
  - Agents home (~/.agents/skills/) is the universal Agent-Skills home — the open standard
    (agentskills.io) directory that spec-compliant tools beyond this installer's named targets
    (e.g. Cursor also reads it) can pick up from.
  - --project scope supports only "claude" (agent-contract limitation).
  - Non-detected targets can still be forced via --target or --all.

EXAMPLES
  npx @manhquy/flow-skill                                  # interactive multi-select
  npx @manhquy/flow-skill --yes                            # non-interactive; default selection
  npx @manhquy/flow-skill --yes --all                      # force all ${targetCount} targets
  npx @manhquy/flow-skill --yes -t claude -t codex         # explicit targets
  npx @manhquy/flow-skill --project --dir .                # project-scoped install (Claude only)
  npx @manhquy/flow-skill --yes --all --dry-run --json     # CI JSONL preview

MORE
  Docs:     https://github.com/manhquydev/flow-skill#readme
  Security: https://github.com/manhquydev/flow-skill/blob/main/SECURITY.md
`;
}

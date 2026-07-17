#!/usr/bin/env node
import { parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';
import { join, resolve } from 'node:path';
import { existsSync } from 'node:fs';

import { TARGETS, TARGET_NAMES, PKG_VERSION, SKILL_VERSION } from '../src/constants.mjs';
import { defaultSelection, detectAll } from '../src/detect.mjs';
import { renderHelp } from '../src/help.mjs';
import { install, installAntigravity } from '../src/installer.mjs';
import { isInteractive } from '../src/tty.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const pkgRoot = resolve(__dirname, '..');
const bundledSkillDir = join(pkgRoot, 'skills', 'flow');

// F5 — runtime Node version guard. `engines` in package.json is advisory only; npm >=8 respects
// it during install but `npx --yes` (and standalone `node`) do not. Fail loudly instead.
// Floor is Node 22.14 for two reasons: (1) Node 20 EOL passed April 2026, (2) our publish
// workflow requires npm >=11.5.1 which ships bundled with Node 22.14.0+ (needed for OIDC
// Trusted Publisher handshake). Users on Node 20 will still install because npm engines is
// advisory, but they get a loud error here rather than a mysterious runtime failure later.
const MIN_NODE = [22, 14, 0];
function checkNodeVersion() {
  const parts = process.versions.node.split('.').map((n) => parseInt(n, 10));
  for (let i = 0; i < MIN_NODE.length; i++) {
    if (parts[i] > MIN_NODE[i]) return;
    if (parts[i] < MIN_NODE[i]) {
      process.stderr.write(
        `flow-skill requires Node.js >=${MIN_NODE.join('.')} (running ${process.versions.node}).\n`
      );
      process.exit(2);
    }
  }
}
checkNodeVersion();

function parseCliArgs(argv) {
  const { values } = parseArgs({
    args: argv,
    allowPositionals: false,
    options: {
      yes: { type: 'boolean', short: 'y', default: false },
      target: { type: 'string', short: 't', multiple: true, default: [] },
      all: { type: 'boolean', default: false },
      project: { type: 'boolean', default: false },
      dir: { type: 'string' },
      json: { type: 'boolean', default: false },
      'dry-run': { type: 'boolean', default: false },
      help: { type: 'boolean', short: 'h', default: false },
    },
  });
  // Split comma-form (-t claude,codex) into individual entries. mri wouldn't do this;
  // parseArgs preserves the raw string, so we normalize here.
  const targets = values.target
    .flatMap((t) => String(t).split(','))
    .map((t) => t.trim())
    .filter(Boolean);
  return {
    yes: values.yes,
    targets,
    all: values.all,
    project: values.project,
    dir: values.dir,
    json: values.json,
    dryRun: values['dry-run'],
    help: values.help,
  };
}

function emit(event, jsonMode) {
  if (jsonMode) {
    process.stdout.write(JSON.stringify(event) + '\n');
  }
}

function log(msg, jsonMode) {
  if (!jsonMode) process.stdout.write(msg + '\n');
}

function warn(msg, jsonMode) {
  if (!jsonMode) process.stderr.write(msg + '\n');
}

function errorExit(msg, code, jsonMode) {
  if (jsonMode) {
    process.stdout.write(
      JSON.stringify({ event: 'error', message: msg, exitCode: code }) + '\n'
    );
  } else {
    process.stderr.write(`Error: ${msg}\n`);
  }
  process.exit(code);
}

function validateTargetNames(names) {
  const invalid = names.filter((n) => !TARGET_NAMES.includes(n));
  if (invalid.length) {
    return `unknown target(s): ${invalid.join(', ')}. Valid: ${TARGET_NAMES.join(', ')}`;
  }
  return null;
}

// Non-interactive selection: --all wins, else explicit -t, else default (alwaysInclude || detected).
function selectNonInteractive({ entries, targets, all }) {
  if (all) return entries.map((e) => e.name);
  if (targets.length) return targets;
  return defaultSelection(entries);
}

// L15/R2-A: project scope allows only projectScopeAllowed=true targets.
function enforceProjectScope(selectedNames, project) {
  if (!project) return { ok: true, kept: selectedNames, dropped: [] };
  const kept = selectedNames.filter(
    (n) => TARGETS.find((t) => t.name === n)?.projectScopeAllowed
  );
  const dropped = selectedNames.filter((n) => !kept.includes(n));
  return { ok: kept.length > 0, kept, dropped };
}

// Build the concrete install plan (target -> destination list).
function buildPlan(selectedNames, entries, { project, dir }) {
  const projectDir = dir || process.cwd();
  return selectedNames.map((name) => {
    const t = entries.find((e) => e.name === name);
    if (!t) throw new Error(`internal: no entry for ${name}`);
    const dests = project ? [join(projectDir, '.claude', 'skills', 'flow')] : t.dests;
    return { target: name, label: t.label, dests };
  });
}

function humanPlan(plan, scope, dir) {
  const lines = [`Install plan (scope: ${scope}${scope === 'project' ? `, dir: ${dir}` : ''})`];
  for (const step of plan) {
    lines.push(`  - ${step.target.padEnd(12)} ${step.label}`);
    for (const d of step.dests) lines.push(`      -> ${d}`);
  }
  return lines.join('\n');
}

function humanResult(target, result) {
  const status = result.success ? '✔' : '✗';
  const dests = Array.isArray(result.dests)
    ? result.dests.join(', ')
    : result.dest || '';
  const err = result.success ? '' : `  (${result.error})`;
  return `${status} ${target} -> ${dests}${err}`;
}

// v0.23 A0 fix — the reported symptom: a user installs to a non-Claude agent, opens it, types
// /flow, and sees nothing, because a freshly-installed skill isn't discovered until the agent
// reloads. The old static message only told Claude+Codex users what to do; every installed
// target now gets its own line so nobody is left guessing why /flow doesn't show up.
const RESTART_HINTS = {
  claude: 'Claude Code: type /flow',
  codex: 'Codex CLI: type $flow (restart Codex once to load a new skill)',
  antigravity:
    'Antigravity: restart/reload the IDE (or restart `agy`) to load the new skill, then type /flow',
  agents:
    'Agents home (~/.agents/skills/): restart/reload your tool if it does not auto-detect new skills',
  // Cursor has no headless CLI probe (unlike Antigravity's `agy -p` or Codex's `codex exec`) to
  // independently verify the runner loads post-install — restart/reload guidance is still the
  // correct advice (same discovery-on-reload mechanism), just without our own live confirmation
  // that the Agent panel picks it up. See README's "After install" section for the caveat.
  cursor: 'Cursor: restart/reload Cursor to load the new skill, then check the Agent panel for flow',
};

function doneLine(targets) {
  const hints = targets.map((t) => RESTART_HINTS[t]).filter(Boolean);
  return `Done. ${hints.join('  |  ')}`;
}

async function main() {
  const rawArgs = process.argv.slice(2);
  let opts;
  try {
    opts = parseCliArgs(rawArgs);
  } catch (err) {
    process.stderr.write(`Error: ${err.message}\nRun with --help for usage.\n`);
    process.exit(2);
  }

  if (opts.help) {
    process.stdout.write(renderHelp());
    process.exit(0);
  }

  // Confirm the bundled skill exists — sync must have run before packaging.
  if (!existsSync(join(bundledSkillDir, 'SKILL.md'))) {
    errorExit(
      `bundled skill not found at ${bundledSkillDir}. If running from a dev checkout, run 'npm run sync' first.`,
      3,
      opts.json
    );
  }

  const invalid = validateTargetNames(opts.targets);
  if (invalid) errorExit(invalid, 2, opts.json);

  const entries = detectAll();

  // Interactive path: only when no flags force a decision AND we have a real TTY on both ends.
  // --dry-run + interactive is fine (we'll still prompt so the user can preview the plan).
  const useInteractive =
    !opts.yes &&
    !opts.all &&
    !opts.targets.length &&
    !opts.project &&
    !opts.json &&
    isInteractive();

  let selected;
  let scope;
  let projectDir;

  if (useInteractive) {
    const { promptTargets, promptScope, promptConfirm, filterProjectScope, intro, outro, cancel } =
      await import('../src/prompt.mjs');
    intro('flow-skill installer');

    const t = await promptTargets(entries);
    if (t.cancelled) {
      cancel('cancelled');
      process.exit(130);
    }
    selected = t.targets;

    const s = await promptScope(process.cwd());
    if (s.cancelled) {
      cancel('cancelled');
      process.exit(130);
    }
    scope = s.scope;
    projectDir = process.cwd();

    if (scope === 'project') {
      const { kept, dropped } = filterProjectScope(selected);
      if (dropped.length) {
        warn(
          `Project scope drops non-claude targets: ${dropped.join(', ')}`,
          false
        );
      }
      if (!kept.length) {
        errorExit(
          `--project scope supports only 'claude' target and no claude target selected.`,
          2,
          false
        );
      }
      selected = kept;
    }

    const c = await promptConfirm({ count: selected.length });
    if (c.cancelled || !c.ok) {
      cancel('cancelled');
      process.exit(0);
    }
    outro('installing...');
  } else {
    selected = selectNonInteractive({
      entries,
      targets: opts.targets,
      all: opts.all,
    });
    const scopeCheck = enforceProjectScope(selected, opts.project);
    if (!scopeCheck.ok) {
      errorExit(
        `--project scope supports only 'claude' target. Invalid: ${scopeCheck.dropped.join(', ') || '(none selected)'}.`,
        2,
        opts.json
      );
    }
    if (scopeCheck.dropped.length && !opts.json) {
      warn(
        `Warning: project scope drops non-claude targets: ${scopeCheck.dropped.join(', ')}`,
        false
      );
    }
    selected = scopeCheck.kept;
    scope = opts.project ? 'project' : 'global';
    projectDir = opts.dir || process.cwd();
  }

  const plan = buildPlan(selected, entries, { project: scope === 'project', dir: projectDir });

  emit(
    {
      event: 'plan',
      version: PKG_VERSION,
      // Additive: skill product version (SKILL.md). `version` stays the npm package version
      // for back-compat with existing JSONL consumers.
      skillVersion: SKILL_VERSION,
      dryRun: opts.dryRun,
      scope,
      targets: plan.map((p) => p.target),
    },
    opts.json
  );

  if (opts.dryRun) {
    log(humanPlan(plan, scope, projectDir), opts.json);
    process.exit(0);
  }

  // F4 — declare `results` BEFORE the SIGINT handler that closes over it. Const-after-handler
  // would TDZ-throw if the user presses Ctrl+C before we ever get to the loop.
  const results = [];
  let aborted = false;

  // SIGINT: flip a flag that the loop reads BETWEEN install() calls, after each install's
  // finally-block has released its lock. We cannot preempt a synchronous cpSync/rmSync — Node
  // signal handlers only fire when the JS stack unwinds. So this handler only affects
  // multi-target runs (it stops the next iteration). Single-target Ctrl+C during copy relies
  // on Node's default (exit 130 at loop unwind). No second-strike hard-exit — that was
  // aspirational and would have leaked the current install's lock.
  const onSigint = () => {
    aborted = true;
  };
  process.on('SIGINT', onSigint);
  for (const step of plan) {
    if (aborted) break;
    emit(
      { event: 'install:start', target: step.target, dests: step.dests },
      opts.json
    );

    let result;
    if (step.target === 'antigravity') {
      result = installAntigravity({ sourceDir: bundledSkillDir, dests: step.dests });
    } else {
      // Non-antigravity targets always have exactly one destination.
      result = install({ sourceDir: bundledSkillDir, destDir: step.dests[0] });
    }

    results.push({ ...result, target: step.target, dests: step.dests });

    emit(
      {
        event: 'install:done',
        target: step.target,
        dests: step.dests,
        result: result.success ? 'success' : 'failed',
        error: result.error ?? null,
        warnings: result.warnings ?? [],
      },
      opts.json
    );

    log(humanResult(step.target, { ...result, dests: step.dests }), opts.json);

    if (!result.success) break; // fail-fast
    if (aborted) break; // Ctrl+C received; installer.mjs's finally already released the lock
  }

  process.off('SIGINT', onSigint);

  const success =
    !aborted && results.length === plan.length && results.every((r) => r.success);
  emit(
    {
      event: 'summary',
      success,
      total: plan.length,
      attempted: results.length,
      installed: results.filter((r) => r.success).length,
      failed: results.filter((r) => !r.success).length,
      skipped: plan.length - results.length,
      aborted,
    },
    opts.json
  );

  if (!opts.json && success) {
    log(`\n${doneLine(plan.map((p) => p.target))}`, false);
  }

  // If aborted mid-loop, exit 130 (matches shell convention) instead of the generic failure.
  if (aborted) process.exit(130);
  process.exit(success ? 0 : 1);
}

main().catch((err) => {
  // F2 — a crash inside main() must not truncate JSONL: emit a machine-parseable summary
  // before exit so CI consumers can distinguish "crashed" from "hung".
  // Argv fallback: `--json` is a boolean flag with no alias in parseArgs config, so a raw
  // string match on process.argv is safe today; if the flag ever gets an alias or
  // `--json=true` form, hoist `jsonMode` to module scope from parseCliArgs instead.
  const isJson = process.argv.includes('--json');
  const message = err?.message ?? String(err);
  if (isJson) {
    process.stdout.write(
      JSON.stringify({
        event: 'summary',
        success: false,
        total: 0,
        attempted: 0,
        installed: 0,
        failed: 0,
        skipped: 0,
        aborted: false,
        error: message,
      }) + '\n'
    );
  }
  process.stderr.write(`Fatal: ${err?.stack ?? err}\n`);
  process.exit(1);
});

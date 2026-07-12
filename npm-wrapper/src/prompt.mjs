// @clack/prompts wrapper — kept small so Phase-1 non-interactive path never has to load it.
import { cancel, confirm, intro, isCancel, multiselect, outro, select } from '@clack/prompts';

import { TARGETS } from './constants.mjs';

// Present the 4 targets as a checkbox list. Detected targets (and Claude via alwaysInclude) are
// pre-checked. Not-detected entries still appear so the user can force-add.
export async function promptTargets(entries) {
  const options = entries.map((e) => ({
    value: e.name,
    label: `${e.label}${e.detected || e.alwaysInclude ? '' : ' (not detected)'}`,
    hint: e.dests.join(', '),
  }));
  const initialValues = entries
    .filter((e) => e.alwaysInclude || e.detected)
    .map((e) => e.name);

  const selected = await multiselect({
    message: 'Install to which harnesses?',
    options,
    initialValues,
    required: true,
  });
  if (isCancel(selected)) return { cancelled: true };
  return { cancelled: false, targets: selected };
}

// Global vs project scope. Project scope is Claude-only (agent contract).
export async function promptScope(defaultDir = process.cwd()) {
  const scope = await select({
    message: 'Scope?',
    options: [
      { value: 'global', label: 'Global (all agents that were selected)' },
      { value: 'project', label: `Project (${defaultDir}) — Claude only` },
    ],
    initialValue: 'global',
  });
  if (isCancel(scope)) return { cancelled: true };
  return { cancelled: false, scope };
}

// Apply project-scope filtering with a visible warning about dropped targets.
export function filterProjectScope(selected) {
  const kept = selected.filter(
    (n) => TARGETS.find((t) => t.name === n)?.projectScopeAllowed
  );
  const dropped = selected.filter((n) => !kept.includes(n));
  return { kept, dropped };
}

export async function promptConfirm(summary) {
  const ok = await confirm({
    message: `Install ${summary.count} target(s)?`,
    initialValue: true,
  });
  if (isCancel(ok)) return { cancelled: true };
  return { cancelled: false, ok };
}

export { cancel, intro, isCancel, outro };

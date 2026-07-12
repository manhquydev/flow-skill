import { statSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

import { TARGETS } from './constants.mjs';

// Resolve a `~/foo/bar` template against a home dir using OS-native separators.
// String `.replace('~', home)` would leave a mixed-separator path on Windows
// (`C:\Users\x/.claude/skills/flow`) which then leaks into `--json` output and
// breaks downstream CI consumers that key on path strings.
function resolveDest(template, home) {
  if (!template.startsWith('~/')) return template;
  const rest = template.slice(2).split('/');
  return join(home, ...rest);
}

// Return one entry per target with marker-based detection + resolved absolute destinations.
export function detectAll({ home = homedir() } = {}) {
  return TARGETS.map((t) => {
    const detected = t.markers.some((m) => {
      try {
        statSync(join(home, m));
        return true;
      } catch {
        return false;
      }
    });
    const dests = t.destTemplates.map((d) => resolveDest(d, home));
    return { ...t, detected, dests };
  });
}

// alwaysInclude || detected — mirrors install.sh:40 contract for Claude and preserves user-facing detection for others.
export function defaultSelection(entries) {
  return entries.filter((e) => e.alwaysInclude || e.detected).map((e) => e.name);
}

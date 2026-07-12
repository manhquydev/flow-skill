import { statSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

import { TARGETS } from './constants.mjs';

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
    const dests = t.destTemplates.map((d) => d.replace('~', home));
    return { ...t, detected, dests };
  });
}

// alwaysInclude || detected — mirrors install.sh:40 contract for Claude and preserves user-facing detection for others.
export function defaultSelection(entries) {
  return entries.filter((e) => e.alwaysInclude || e.detected).map((e) => e.name);
}

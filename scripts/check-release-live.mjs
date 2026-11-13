#!/usr/bin/env node
// Fail-closed post-publication coherence check across all 6 release axes.
// Invoked by `bash scripts/release-preflight.sh --strict-published` or directly
// via `node scripts/check-release-live.mjs`. Never publishes, tags, or mutates state.
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { compareSemver, parseSemver } from '../npm-wrapper/scripts/semver.mjs';

const PACKAGE = '@manhquy/flow-skill';
const PUBLIC_REGISTRY = 'https://registry.npmjs.org/';
const REPO = process.env.GITHUB_REPOSITORY || 'manhquydev/flow-skill';
const root = resolve(process.env.FLOW_RELEASE_ROOT || join(dirname(fileURLToPath(import.meta.url)), '..'));

const failures = [];
const ok = (msg) => console.log(`OK: ${msg}`);
const fail = (msg) => {
  console.error(`FAIL: ${msg}`);
  failures.push(msg);
};

function quoteWinArg(arg) {
  const s = String(arg);
  if (/[,\s&<>()@^|"]/.test(s)) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function runCmd(cmd, args, opts = {}) {
  if (process.platform === 'win32' && cmd !== 'git') {
    const cmdLine = [cmd, ...args.map(quoteWinArg)].join(' ');
    return spawnSync('cmd.exe', ['/d', '/c', cmdLine], {
      cwd: root,
      encoding: 'utf8',
      timeout: 30_000,
      maxBuffer: 8 * 1024 * 1024,
      windowsVerbatimArguments: true,
      ...opts,
    });
  }
  return spawnSync(cmd, args, {
    cwd: root,
    encoding: 'utf8',
    timeout: 30_000,
    maxBuffer: 8 * 1024 * 1024,
    ...opts,
  });
}

function readHeadFile(relPath) {
  const res = runCmd('git', ['show', `HEAD:${relPath}`]);
  if (res.status === 0) {
    return res.stdout;
  }
  const full = join(root, relPath);
  if (existsSync(full)) {
    return readFileSync(full, 'utf8');
  }
  return null;
}

function assertClean(relPaths) {
  const res = runCmd('git', ['status', '--porcelain', '--', ...relPaths]);
  if (res.status === 0 && res.stdout.trim().length > 0) {
    const dirty = res.stdout.trim().split(/\r?\n/).map((l) => l.trim()).join(', ');
    fail(`working tree dirty for release docs: ${dirty}`);
    return false;
  }
  return true;
}

function readJson(relPath) {
  const text = readHeadFile(relPath);
  if (text === null) {
    fail(`missing ${relPath}`);
    return null;
  }
  try {
    return JSON.parse(text);
  } catch (e) {
    fail(`invalid JSON in ${relPath}: ${e.message}`);
    return null;
  }
}

function escapeRe(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function hasChangelogHeading(relPath, version) {
  const text = readHeadFile(relPath);
  if (text === null) {
    fail(`missing ${relPath}`);
    return false;
  }
  const re = new RegExp(`^##\\s+\\[?v?${escapeRe(version)}\\]?(?:\\s|$)`, 'm');
  return re.test(text);
}

// --- Local version & intent baseline ---
const pkg = readJson('npm-wrapper/package.json');
const plugin = readJson('.claude-plugin/plugin.json');
const portable = readJson('portable-manifest.json');
const intent = readJson('docs/release-intent.json');

let skillV = null;
const skillMdText = readHeadFile('skills/flow/SKILL.md');
if (skillMdText === null) {
  fail('missing skills/flow/SKILL.md');
} else {
  const m = skillMdText.match(/^\s*version:\s*["']?([0-9][.0-9A-Za-z+-]*)["']?\s*$/m);
  skillV = m ? m[1] : null;
  if (!skillV || !parseSemver(skillV)) fail(`invalid or missing version in skills/flow/SKILL.md (${skillV})`);
}

const npmV = pkg?.version || null;
if (!npmV || !parseSemver(npmV)) fail(`invalid or missing version in npm-wrapper/package.json (${npmV})`);
if (plugin && skillV && plugin.version !== skillV) fail(`.claude-plugin/plugin.json (${plugin.version}) != SKILL.md (${skillV})`);
if (portable && skillV && portable.version !== skillV) fail(`portable-manifest.json (${portable.version}) != SKILL.md (${skillV})`);

let skillVersion = skillV;
if (intent) {
  if (intent.schema_version !== 1) fail(`docs/release-intent.json schema_version must be 1 (got ${intent.schema_version})`);
  if (typeof intent.intent !== 'boolean') fail('docs/release-intent.json intent must be boolean');
  if (intent.intent === true) {
    if (npmV && intent.npm_version !== npmV) fail(`docs/release-intent.json npm_version (${intent.npm_version}) != package.json (${npmV})`);
    if (intent.skill_version !== null && intent.skill_version !== skillV) {
      fail(`docs/release-intent.json skill_version (${intent.skill_version}) != SKILL.md (${skillV})`);
    }
    skillVersion = intent.skill_version;
  }
}

if (skillVersion !== null && npmV && npmV !== skillVersion) {
  fail(`unified version mismatch: npm (${npmV}) != skill (${skillVersion})`);
}

if (npmV && parseSemver(npmV)) {
  const parsedNpm = parseSemver(npmV);
  const channel = parsedNpm.prerelease ? 'next' : 'latest';
  if (intent?.intent === true && intent.channel !== channel) {
    fail(`docs/release-intent.json channel (${intent.channel}) != expected (${channel})`);
  }

  // HEAD commit SHA
  const headRes = runCmd('git', ['rev-parse', 'HEAD']);
  const headSha = headRes.status === 0 ? headRes.stdout.trim().toLowerCase() : '';
  if (!/^[0-9a-f]{40}$/.test(headSha)) {
    fail(`cannot resolve HEAD commit SHA: ${(headRes.stderr || headRes.stdout || '').trim()}`);
  } else {
    ok(`local HEAD SHA ${headSha.slice(0, 12)} (${npmV} on ${channel})`);
  }

  // (a) Live npm dist-tags + provenance
  const tagsRes = runCmd('npm', ['view', PACKAGE, 'dist-tags', '--json', `--registry=${PUBLIC_REGISTRY}`]);
  if (tagsRes.status !== 0) {
    fail(`npm dist-tags query failed: ${(tagsRes.stderr || tagsRes.error?.message || '').trim()}`);
  } else {
    try {
      const distTags = JSON.parse(tagsRes.stdout);
      if (!distTags || typeof distTags !== 'object' || distTags[channel] !== npmV) {
        fail(`npm dist-tag '${channel}' is '${distTags?.[channel] ?? 'missing'}', expected '${npmV}'`);
      } else {
        ok(`npm dist-tag ${channel} === ${npmV}`);
      }
    } catch (e) {
      fail(`npm dist-tags returned invalid JSON: ${e.message}`);
    }
  }

  const provRes = runCmd('npm', ['view', `${PACKAGE}@${npmV}`, 'dist.attestations.provenance', '--json', `--registry=${PUBLIC_REGISTRY}`]);
  if (provRes.status !== 0) {
    fail(`npm provenance query failed for ${PACKAGE}@${npmV}: ${(provRes.stderr || provRes.error?.message || '').trim()}`);
  } else {
    try {
      const raw = provRes.stdout.trim();
      const prov = raw ? JSON.parse(raw) : null;
      const entries = Array.isArray(prov) ? prov : (prov && typeof prov === 'object' ? [prov] : []);
      const validProv = entries.length > 0 && entries.some(
        (e) => e && typeof e === 'object' && ((typeof e.predicateType === 'string' && e.predicateType.length > 0) || (typeof e.url === 'string' && e.url.length > 0))
      );
      if (!validProv) {
        fail(`${PACKAGE}@${npmV} lacks dist.attestations.provenance`);
      } else {
        ok(`${PACKAGE}@${npmV} has dist.attestations.provenance`);
      }
    } catch (e) {
      fail(`npm provenance returned invalid JSON for ${PACKAGE}@${npmV}: ${e.message}`);
    }
  }

  // (b) Remote git tags on origin matching each other and HEAD commit SHA
  const tagRefs = [`refs/tags/npm@${npmV}`, `refs/tags/npm@${npmV}^{}`];
  if (skillVersion !== null) {
    tagRefs.push(`refs/tags/v${skillVersion}`, `refs/tags/v${skillVersion}^{}`);
  }
  const lsRes = runCmd('git', ['ls-remote', 'origin', ...tagRefs]);
  if (lsRes.status !== 0) {
    fail(`git ls-remote origin failed: ${(lsRes.stderr || lsRes.error?.message || '').trim()}`);
  } else {
    const refMap = {};
    for (const line of lsRes.stdout.split(/\r?\n/)) {
      const m = line.match(/^([0-9a-f]{40})\s+(\S+)$/i);
      if (m) refMap[m[2]] = m[1].toLowerCase();
    }
    const npmTagSha = refMap[`refs/tags/npm@${npmV}^{}`] || refMap[`refs/tags/npm@${npmV}`] || null;
    if (!npmTagSha) {
      fail(`remote tag npm@${npmV} missing on origin`);
    } else if (/^[0-9a-f]{40}$/.test(headSha) && npmTagSha !== headSha) {
      fail(`remote tag npm@${npmV} (${npmTagSha}) != local HEAD (${headSha})`);
    } else {
      ok(`remote tag npm@${npmV} matches HEAD (${npmTagSha.slice(0, 12)})`);
    }

    if (skillVersion !== null) {
      const skillTagSha = refMap[`refs/tags/v${skillVersion}^{}`] || refMap[`refs/tags/v${skillVersion}`] || null;
      if (!skillTagSha) {
        fail(`remote tag v${skillVersion} missing on origin`);
      } else if (npmTagSha && skillTagSha !== npmTagSha) {
        fail(`remote tag v${skillVersion} (${skillTagSha}) != npm@${npmV} (${npmTagSha})`);
      } else if (/^[0-9a-f]{40}$/.test(headSha) && skillTagSha !== headSha) {
        fail(`remote tag v${skillVersion} (${skillTagSha}) != local HEAD (${headSha})`);
      } else {
        ok(`remote tag v${skillVersion} matches npm@${npmV} and HEAD (${skillTagSha.slice(0, 12)})`);
      }
    }
  }

  // (c) GitHub Release view v${skillVersion}
  if (skillVersion !== null) {
    const ghRes = runCmd('gh', ['release', 'view', `v${skillVersion}`, '--repo', REPO, '--json', 'tagName,isDraft,isPrerelease']);
    if (ghRes.status !== 0) {
      fail(`GitHub Release v${skillVersion} missing or unreadable: ${(ghRes.stderr || ghRes.stdout || ghRes.error?.message || '').trim()}`);
    } else {
      try {
        const rel = JSON.parse(ghRes.stdout);
        if (rel.isDraft === true) {
          fail(`GitHub Release v${skillVersion} is still a draft`);
        } else if (rel.tagName && rel.tagName !== `v${skillVersion}`) {
          fail(`GitHub Release tagName (${rel.tagName}) != v${skillVersion}`);
        } else {
          ok(`GitHub Release v${skillVersion} published`);
        }
      } catch (e) {
        fail(`gh release view v${skillVersion} returned invalid JSON: ${e.message}`);
      }
    }
  }

  // (d) README Publication status verified lines must not report versions older than npm_v
  const readmeTargets = ['README.md', 'README_VN.md', 'npm-wrapper/README.md'];
  if (existsSync(join(root, 'npm-wrapper/README_VN.md'))) readmeTargets.push('npm-wrapper/README_VN.md');
  assertClean([...readmeTargets, 'CHANGELOG.md', 'npm-wrapper/CHANGELOG.md', 'docs/quality-metrics.md']);
  for (const relPath of readmeTargets) {
    const text = readHeadFile(relPath);
    if (text === null) {
      fail(`missing ${relPath}`);
      continue;
    }
    const lines = text.split(/\r?\n/);
    const pubLines = lines.filter((l) => /^(?:Publication status verified|Bản phát hành đã xác minh)\b/.test(l));
    if (pubLines.length === 0) {
      fail(`${relPath} missing Publication status verified line`);
      continue;
    }
    let lineFailed = false;
    for (const pubLine of pubLines) {
      const verMatches = [...pubLine.matchAll(/(?:^|[^0-9A-Za-z._-])v?(\d+\.\d+\.\d+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)/g)]
        .map((m) => m[1])
        .filter((tok) => parseSemver(tok) !== null);
      if (verMatches.length === 0) {
        fail(`${relPath} Publication status verified line has no valid SemVer (${pubLine})`);
        lineFailed = true;
        continue;
      }
      const older = verMatches.filter((v) => compareSemver(v, npmV) < 0);
      const hasExact = verMatches.some((v) => compareSemver(v, npmV) === 0);
      if (older.length > 0) {
        fail(`${relPath} Publication status verified still cites older version(s) [${older.join(', ')}] < ${npmV}`);
        lineFailed = true;
      } else if (!hasExact) {
        fail(`${relPath} Publication status verified does not cite current published version ${npmV}`);
        lineFailed = true;
      }
    }
    if (pubLines.length > 1) {
      fail(`${relPath} has duplicate publication-status declarations (${pubLines.length}; expected 1)`);
    } else if (!lineFailed) {
      ok(`${relPath} publication status matches ${npmV}`);
    }
  }

  // (e) CHANGELOG.md, npm-wrapper/CHANGELOG.md, docs/quality-metrics.md match
  if (skillVersion !== null) {
    if (hasChangelogHeading('CHANGELOG.md', skillVersion)) {
      ok(`CHANGELOG.md has heading for ${skillVersion}`);
    } else {
      fail(`CHANGELOG.md missing heading for ${skillVersion}`);
    }
  }
  if (hasChangelogHeading('npm-wrapper/CHANGELOG.md', npmV)) {
    ok(`npm-wrapper/CHANGELOG.md has heading for ${npmV}`);
  } else {
    fail(`npm-wrapper/CHANGELOG.md missing heading for ${npmV}`);
  }

  const qmText = readHeadFile('docs/quality-metrics.md');
  if (qmText === null) {
    fail('missing docs/quality-metrics.md');
  } else {
    const qmTop = qmText.split(/\r?\n/).slice(0, 20).join('\n');
    const hasNpmQm = new RegExp(`(^|[^0-9A-Za-z._+-])npm-wrapper v${escapeRe(npmV)}($|[^0-9A-Za-z._+-]|\\.($|[^0-9A-Za-z._+-]))`).test(qmTop);
    const hasSkillQm = skillVersion === null || new RegExp(`(^|[^0-9A-Za-z._+-])skill v${escapeRe(skillVersion)}($|[^0-9A-Za-z._+-]|\\.($|[^0-9A-Za-z._+-]))`).test(qmTop);
    if (hasNpmQm && hasSkillQm) {
      ok(`docs/quality-metrics.md matches published versions (${npmV})`);
    } else {
      fail(`docs/quality-metrics.md top section missing npm-wrapper v${npmV} or skill v${skillVersion}`);
    }
  }
}

if (failures.length > 0) {
  console.error(`STRICT PUBLISHED COHERENCE FAILED (${failures.length} check(s))`);
  process.exit(1);
}
console.log('PASS: strict published release coherence');

# Research Report: npx installer-CLI distribution UX (npm i vs npx, dist-tags, cache)

<!-- Conducted: 2026-08-01 -->

## Executive Summary

`@manhquy/flow-skill` is a **run-once installer CLI** (`bin: flow-skill`). For that
class of package the canonical, industry-standard invocation is
**`npx <pkg>@latest`** — never `npm i`. Two verified facts drive every
recommendation below:

1. **npx caches by bare name forever.** `npx pkg` reuses whatever version sits in
   the `_npx` cache and will NOT refetch; only `npx pkg@latest` (or a clean cache)
   forces the newest registry version. This is the #1 cause of "user reran it but
   still got the old build."
2. **A pre-release dist-tag must never point behind `latest`.** Ours currently
   does (`rc = 0.1.0-rc.3` < `latest = 0.2.0`), so anyone following the top-README
   `@rc` command silently downgrades. Standard practice: retire (`dist-tag rm`) or
   repoint the tag once GA ships.

## Key Findings

### 1. npx cache behavior (verified)
- npx stores each package in a central `_npx` cache; entries are effectively
  permanent (npx does not manage cache lifetime). Once `npx pkg` runs, later bare
  `npx pkg` calls reuse the cached copy and skip the registry. [npm/cli#7838, npm/rfcs#700]
- **`npx pkg@latest` bypasses this** — the version specifier forces npx to resolve
  against the registry and fetch the newest match. [npm/rfcs#700]
- Cache location: `npm config get cache` → `_npx/`. Bust with
  `npm cache clean --force` or remove the `_npx` dir. [clear-npx-cache, w3tutorials]
- **Implication:** to guarantee end-users get the newest skill, the documented
  command MUST carry `@latest`. Bare `npx pkg` is a "maybe-stale" command.

### 2. dist-tag conventions (verified)
- Moving target: publishing a normal release advances `latest`. Named tags
  (`rc`, `beta`, `next`) stay pinned to whatever version they were assigned — they
  do NOT auto-advance. [dev.to/nop33, npm docs]
- Pre-releases must always publish under a tag so they don't hijack `latest`;
  conversely, once GA ships you should **remove or repoint the pre-release tag** to
  avoid confusing users. [cloudfour, dev.to/nop33]
- A tag pointing to a version older than `latest` is a known foot-gun: users who
  followed old `@tag` docs get a downgrade. Fix via
  `npm dist-tag rm <pkg> rc` (retire) or `npm dist-tag add <pkg> <newer> rc` (repoint). [npm-dist-tag docs]

### 3. How the popular create-* CLIs tell users to install latest (verified)
- **create-vite:** official docs → `npm create vite@latest` (i.e. `@latest`
  explicit). [vite.dev/guide, npmjs/create-vite]
- **create-next-app:** official CLI docs → `npx create-next-app@latest`. [nextjs.org create-next-app]
- Pattern is unanimous: run-once scaffolders/installers are always documented with
  **`@latest`**, never `npm i`, and never a bare name in the primary CTA.

## Implementation Recommendations

### Canonical user command for flow-skill
```bash
npx @manhquy/flow-skill@latest        # always newest GA; cache-proof
```
- Drop `@rc` from the primary install CTA. Keep one clearly-labelled mention that
  `@rc` = pre-release channel (and only after rc is repointed >= latest, or retire it).
- Never present `npm i @manhquy/flow-skill` as an install path — it copies the CLI
  into `node_modules` but does NOT install the skill until the CLI is *run*.

### Registry hygiene (one-time)
```bash
npm dist-tag rm @manhquy/flow-skill rc     # retire stale rc  (OR)
npm dist-tag add @manhquy/flow-skill 0.2.0 rc   # repoint rc to GA
```

### Common pitfalls
- Documenting bare `npx pkg` and assuming users get the newest build — they get
  the cache. Always `@latest` in docs.
- Leaving a pre-release tag behind `latest` after GA.
- Telling users to `npm i` an installer CLI.

## Resources & References
- [npm/cli#7838 — npx does not fetch latest semver match](https://github.com/npm/cli/issues/7838)
- [npm/rfcs#700 — npx not getting latest version](https://github.com/npm/rfcs/issues/700)
- [clear-npx-cache (npm)](https://www.npmjs.com/package/clear-npx-cache)
- [How to clear the central npx cache — w3tutorials](https://www.w3tutorials.net/blog/how-can-i-clear-the-central-cache-for-npx/)
- [Using npm distribution tags the right way — dev.to/nop33](https://dev.to/nop33/using-npm-distribution-tags-the-right-way-562f)
- [How to Prerelease an npm Package — Cloud Four](https://cloudfour.com/thinks/how-to-prerelease-an-npm-package/)
- [npm-dist-tag docs](https://docs.npmjs.com/cli/dist-tag/)
- [create-vite (npm) / vite.dev guide](https://vite.dev/guide/)
- [create-next-app CLI — nextjs.org](https://nextjs.org/docs/app/api-reference/cli/create-next-app)

## Unresolved questions
- Does the flow team want to keep an `rc` channel at all going forward, or ship
  GA-only? (Decides retire-vs-repoint.) — a product call, not a technical one.

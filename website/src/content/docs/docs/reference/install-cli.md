---
title: "Install CLI"
description: "The npx command that installs the flow skill, the two version numbers it reports, and where the full flag table lives."
---

## The command

```bash
npx @manhquy/flow-skill@latest
```

Requires [Node.js](https://nodejs.org/) **22.14 or newer**. Always include `@latest` — a bare
`npx @manhquy/flow-skill` can be served from the npx cache and re-run an older copy.

## What it reports

```bash
npx @manhquy/flow-skill@latest --help
# flow-skill v0.7.0 (ships skill v0.30.0)
```

`0.7.0` is this installer CLI. `0.30.0` is the skill product it copies onto disk. See
[Versions: npm installer vs skill product](/docs/explanation/versions-npm-vs-skill).

## Full flag reference

The authoritative flag table — non-interactive runs, target selection, project-scoped
installs, dry runs, JSON output — is maintained with the installer itself:

**[npm-wrapper/README.md](https://github.com/manhquydev/flow-skill/blob/master/npm-wrapper/README.md)**

That file is the source of truth. It is not duplicated here, so it cannot drift out of date
here.

## Package

[`@manhquy/flow-skill` on npm](https://www.npmjs.com/package/@manhquy/flow-skill)

## See also

- [Install and first run](/docs/tutorials/install-and-first-run)
- [Install paths](/docs/reference/install-paths)
- [Troubleshoot an install](/docs/how-to/troubleshoot-install)

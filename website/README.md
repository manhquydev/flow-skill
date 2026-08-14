# flow website

Static Astro + Starlight site for the flow skill. English landing at `/`, Vietnamese at `/vi/`, docs at `/docs` and `/vi/docs`.

This directory is a **sibling** of `skills/` and `npm-wrapper/`. It is not an npm workspace member and must never appear in `npm-wrapper/package.json` `files`.

## Local

Node version is pinned in `.node-version` (22). From this directory:

```bash
npm ci
npm run build          # output: dist/
bash scripts/check-i18n-parity.sh
```

No `wrangler.toml` and no `@astrojs/cloudflare` adapter — the site is static `dist/`.

## Cloudflare Pages (dashboard)

Git-connected Pages only. Connect `manhquydev/flow-skill`. Do not create a Direct Upload project (that path cannot convert to Git later).

Dashboard: [Workers & Pages](https://dash.cloudflare.com/?to=/:account/workers-and-pages) → **Create** → **Pages** → **Import an existing Git repository** → `flow-skill`.

| Setting | Value |
|---------|-------|
| Production branch | **`master`** (override the dashboard default `main`) |
| Root directory | `website` |
| Build command | `npm ci && npm run build` |
| Build output directory | `dist` |
| Node | from `website/.node-version` (22) |
| Watch paths | `website/**` |

**Watch paths** = `website/**` so skill-only commits skip site builds. After Git connect: **Settings → Build → Build watch paths** → include `website/**` (Pages defaults to include `*`). See [Build watch paths](https://developers.cloudflare.com/pages/configuration/build-watch-paths/).

If **Root directory** is left blank, Pages runs `npm ci` at the **repo root**, where there is no `package.json` — the build fails with ENOENT (not a silent empty site).

### Preview env: no secrets

This is a public repo. Never put secrets in Cloudflare Pages **Preview** (or Production) environment variables for this project. The static site does not need them. GitHub Actions `.github/workflows/website.yml` also has `permissions: contents: read` and no deploy job / no `CLOUDFLARE_*` secrets — Pages Git integration owns deploys.

Preview deployments of feature branches are smoke-only. Do **not** paste a preview `*.pages.dev` hostname into the root README Website pointer.

### Custom domain

Public host: **`flowskill.io.vn`** (also `www.flowskill.io.vn`). Attached to Pages project `flow-website`.

DNS (same Cloudflare zone, proxied / orange cloud):

| Type | Name | Target |
|------|------|--------|
| CNAME | `@` (`flowskill.io.vn`) | `flow-website-apg.pages.dev` |
| CNAME | `www` | `flow-website-apg.pages.dev` |

Apex CNAME uses Cloudflare flattening. Until those records exist, Pages stays `initializing` (`CNAME record not set`). Do not paste a preview `*.pages.dev` hostname into the root README.

Required GitHub status checks for the `website` job remain operator-owned (branch protection), not this file.

## CI

`.github/workflows/website.yml` runs on `website/**`, the workflow file, and root `DESIGN.md`:

1. i18n parity
2. `npm ci && npm run build`
3. `dist/vi/**/*.html` must not contain Starlight’s “not available in your language yet” fallback
4. root `DESIGN.md` must match `origin/master` **only when the change set also touches `website/**`**
5. `npm-wrapper/package.json` `files` array JSON-equal to `origin/master`

Public URL in the root README is **[flowskill.io.vn](https://flowskill.io.vn)**. Never paste a preview `*.pages.dev` hostname there. The live project was created as Direct Upload (`flow-website`); do not recreate it. Git import later is optional and separate.

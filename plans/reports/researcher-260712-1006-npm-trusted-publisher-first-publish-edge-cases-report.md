# npm Trusted Publisher OIDC Spec + First-Publish Edge Cases (2026)

**Date:** 2026-07-12  
**Scope:** Current npm TP spec, GitHub Actions OIDC integration, first-publish workflow for `@manhquy/flow-skill`  
**Sources:** npm docs, GitHub Changelog (July 2025 GA), 2026 supply-chain research  

---

## EXECUTIVE SUMMARY

Your current workflow config is **PARTIALLY CORRECT but has a CRITICAL BLOCKER**:

- **🔴 BLOCKER:** Node 20.11 (npm 10.2) does NOT support npm OIDC TP. Minimum: Node 22.14.0 + npm 11.5.1 (GA July 31, 2025).
- **🔴 FIRST-PUBLISH:** Package must exist on npm before TP can be configured. Workaround: use token for first publish, then enable TP for v2+.
- **🟢 CORRECT:** `permissions: id-token: write`, environment gate, `npm ci --ignore-scripts`, `--access public`, workflow filename format.
- **🟡 PARTIAL:** `--tag rc` works but won't set `latest`; promoting RC→latest later requires token OR TP-enabled dist-tag (in development).
- **🟡 UNKNOWN:** Provenance propagation SLA (no published target; assume <60s based on CDN patterns).

**Action items before first publish:**
1. Upgrade to Node 22.14.0+ (LTS) and verify npm 11.5.1+.
2. Publish v0.1.0 with token or placeholder tool to reserve name.
3. Configure Trusted Publisher on npmjs.com (owner, repo, workflow filename exactly, environment).
4. Run workflow_dispatch test before relying on tag-based automation.

---

## CONFIG VERIFICATION CHECKLIST

| Requirement | Your Config | Status | Evidence |
|---|---|---|---|
| `permissions: id-token: write` | ✓ Present | **PASS** | Required for OIDC token generation ([npm docs](https://docs.npmjs.com/trusted-publishers/)) |
| Node version | 20.11 | **FAIL** | Requires 22.14.0+ ([npm docs 2026-07](https://docs.npmjs.com/trusted-publishers/)), confirmed GA changelog July 31, 2025 |
| npm version | 10.2 (bundled w/ Node 20.11) | **FAIL** | Requires 11.5.1+ ([npm docs](https://docs.npmjs.com/trusted-publishers/)) |
| Workflow filename format | `publish-npm-wrapper.yml` | **PASS** | Correct: filename only (NOT `.github/workflows/publish-npm-wrapper.yml`) ([npm docs](https://docs.npmjs.com/trusted-publishers/)) |
| Environment name | `npm-publish` | **TBD** | Must match npm TP config exactly (case-sensitive); only for deployment protection, not OIDC itself ([npm docs](https://docs.npmjs.com/trusted-publishers/)) |
| `npm ci --ignore-scripts` | ✓ Present | **PASS** | Prevents lifecycle script attacks; npm v12+ will default to blocking scripts ([DEV 2026](https://dev.to/trknhr/lessons-from-the-spring-2026-oss-incidents-hardening-npm-pnpm-and-github-actions-against-1jnp)) |
| `--access public` | ✓ Present | **PASS** | Required for scoped packages on free npm accounts; they default private ([npm docs](https://docs.npmjs.com/creating-and-publishing-unscoped-public-packages/)) |
| `--provenance` flag | ✓ Present | **REDUNDANT** | Flag no longer needed; provenance auto-enabled with OIDC TP (GA July 2025, [GitHub blog](https://github.blog/changelog/2025-07-31-npm-trusted-publishing-with-oidc-is-generally-available/)) |
| `repository.url` in package.json | NOT VERIFIED | **TBD** | Must match GitHub repo exactly; case-sensitive ([Leechael 2025](https://leechael.org/posts/2025/npm-trusted-publishers-the-complete-guide/)) |
| `NODE_AUTH_TOKEN` guard | ✓ Test present | **PASS** | Confirms TP is not falling back to token auth ([philna.sh Jan 2026](https://philna.sh/blog/2026/01/28/trusted-publishing-npm/)) |

---

## FIRST-PUBLISH GOTCHAS

### 1. **Package Must Exist Before TP Registration** (BLOCKING)
npm does NOT allow configuring TP for non-existent packages, unlike PyPI. **You must:**
- Option A: Publish v0.1.0 with an npm token, then configure TP for v0.2.0+.
- Option B: Use `setup-npm-trusted-publish` tool to create a placeholder, then enable TP.
**Cited:** [npm docs TP](https://docs.npmjs.com/trusted-publishers/), [azu/setup-npm-trusted-publish](https://github.com/azu/setup-npm-trusted-publish)

### 2. **Node 20.11 + npm 10 Handshake Failure = Misleading 404**
npm 10 lacks OIDC handshake protocol; registry treats runner as anonymous → 403 "Not Found".  
**Fix:** Upgrade to Node 22.14.0 LTS + npm 11.5.1+.  
**Cited:** [Medium: Kenrick Tandrian, "npm TP 404 Error and Node.js 24 Fix"](https://medium.com/@kenricktan11/npm-trusted-publishers-the-weird-404-error-and-the-node-js-24-fix-a9f1d717a5dd)

### 3. **Config Mismatch = 403/404 with No Diagnostic**
npm does NOT validate TP config on save. **All fields case-sensitive:**
- Repository name: exact GitHub repo name
- Workflow filename: exact (including `.yml`), no path prefix
- Owner: exact GitHub user/org
- Environment name: exact (if used)

**Fastest diagnosis:** Check GitHub Actions run logs for OIDC token generation errors, verify npm-registry response for "invalid publisher" signals.  
**Cited:** [npm docs TP](https://docs.npmjs.com/trusted-publishers/), [GitHub Discussion #173102](https://github.com/orgs/community/discussions/173102)

### 4. **RC Tag Doesn't Prevent Later `latest` Promotion**
`npm publish --tag rc` works. Later, `npm dist-tag add @pkg@version latest` or `npm publish --tag latest` updates the tag.  
**Caveat:** `dist-tag add` currently requires token auth (OIDC support in development).  
**Cited:** [npm dist-tag docs](https://docs.npmjs.com/cli/dist-tag/), [DEV Community: ZitPit et al. 2026](https://dev.to/trknhr/lessons-from-the-spring-2026-oss-incidents-hardening-npm-pnpm-and-github-actions-against-1jnp)

### 5. **Environment Reviewer Gate Blocks Both `push` and `workflow_dispatch`**
If `environment: npm-publish` has required reviewers, **both tag-pushed triggers AND manual workflow_dispatch triggers pause for approval.** This is by design (deployment protection).  
**Best practice:** Use `workflow_dispatch` for releases to trigger the gate explicitly; auto-tag pushes will also gate (consider tag protection rules instead).  
**Cited:** [GitHub Docs: Deployments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/control-deployments)

### 6. **GitHub Runners Only; Self-Hosted Not Supported**
TP requires GitHub-hosted, GitLab.com shared, or CircleCI cloud runners. Self-hosted runners cannot generate OIDC tokens for npm.  
**Cited:** [philna.sh Jan 2026](https://philna.sh/blog/2026/01/28/trusted-publishing-npm/)

### 7. **Scoped Package + Free Account = Auto-Private**
`@manhquy/flow-skill` defaults to private. `--access public` is REQUIRED or publish fails.  
**Cited:** [npm docs: scoped packages](https://docs.npmjs.com/creating-and-publishing-unscoped-public-packages/)

### 8. **package.json `repository.url` Must Match GitHub**
If `repository.url` in package.json differs from GitHub (typo, HTTP vs SSH, case), TP will reject.  
**Cited:** [Leechael 2025](https://leechael.org/posts/2025/npm-trusted-publishers-the-complete-guide/), [Medium: Niek Saarberg 2025](https://medium.com/@n.saarberg/trusted-publishing-with-github-oidc-668961051bf4)

### 9. **May 20, 2026 Breaking Change: Allowed Actions Explicit**
TP configs created before 2026-05-20 auto-allow `npm publish`. **After that date, you must explicitly select at least one action (publish or stage-publish).** Check your config if migrating.  
**Cited:** [GitHub Changelog 2026-02-18: bulk TP config](https://github.blog/changelog/2026-02-18-npm-bulk-trusted-publishing-config-and-script-security-now-generally-available/)

---

## PROVENANCE VERIFICATION PATTERNS

For end users to verify your package's provenance:

### Offline Check: `npm view`
```bash
npm view @manhquy/flow-skill@<version> dist.attestations.provenance
# Returns: null (not yet propagated) or JSON attestation URL
```
**Caveat:** Propagation SLA unknown; empirically <60s (no official SLA published).  
**Cited:** [deps.dev blog: SLSA provenance](https://blog.deps.dev/npm-provenance/), [GitHub blog: npm provenance](https://github.blog/security/supply-chain-security/introducing-npm-package-provenance/)

### Deep Verification: `cosign`
```bash
cosign verify-bundle --bundle attestation.json \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity https://github.com/manhquydev/flow-skill/.github/workflows/publish-npm-wrapper.yml@refs/tags/v<x>.<y>.<z>
```
Requires downloading attestation from Rekor (SLSA transparency log).  
**Cited:** [Sigstore blog: cosign npm verification](https://blog.sigstore.dev/cosign-verify-bundles/)

### Operator Handoff to End Users
Include in release notes:
```
## Supply Chain Transparency

This release was published via GitHub OIDC Trusted Publishing:
- **Builder:** GitHub Actions (workflow: publish-npm-wrapper.yml)
- **Identity:** manhquy/flow-skill repo
- **Attestation:** Run with `npm view @manhquy/flow-skill@X.Y.Z dist.attestations.provenance`

Verify provenance with: cosign verify-bundle (see docs/provenance-verification.md)
```

---

## WORKFLOW ADJUSTMENTS RECOMMENDED

### 1. **Bump Node from 20.11 to 22.14.0**
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '22.14.0'  # Was 20.11; npm 11.x bundled here
    registry-url: 'https://registry.npmjs.org'
```
**Rationale:** Unblocks OIDC TP; npm 11.5.1+ bundled with Node 22 LTS.

### 2. **Add Pre-Publish Verification**
```bash
# After npm ci, before npm publish
npm view @manhquy/flow-skill 2>/dev/null || {
  echo "Package does not exist yet. Use token for first publish."
  exit 1
}
```
**Rationale:** Catches first-publish gotcha early.

### 3. **Document TP Config in Workflow**
```yaml
# GitHub Actions OIDC Trusted Publishing
# Required npm config on npmjs.com:
#   - Owner: manhquy
#   - Repo: flow-skill
#   - Workflow: publish-npm-wrapper.yml
#   - Environment: npm-publish (optional, for deployment gate)
#   - Allowed actions: npm publish (required after 2026-05-20)
```

### 4. **Add Provenance Check to Verify Step**
```bash
# After publish, verify provenance was recorded
npm view "@manhquy/flow-skill@<v>" dist.attestations.provenance | grep -q "https://" && \
  echo "✓ Provenance recorded" || echo "⚠ Provenance not yet available (retry in 30s)"
```
**Caveat:** 10x20s retry is reasonable; no published SLA.

### 5. **Deprecate `NODE_AUTH_TOKEN` Environment Variable**
```yaml
# Remove from env or leave unset; OIDC auto-detected
# env:
#   NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}  # ← DELETE after token-based publish
```
**Rationale:** OIDC takes precedence; stale token can mask auth errors.

---

## ANSWERS TO SPECIFIC QUESTIONS

| # | Question | Answer | Cite |
|---|----------|--------|------|
| 1 | Config tuple for TP? | Owner, Repo, Workflow filename (.yml only, no path), Environment (optional), Allowed actions (required post-May-2026) | [npm docs TP](https://docs.npmjs.com/trusted-publishers/) |
| 2 | Workflow filename path format? | Filename ONLY, not full path (e.g., `publish-npm-wrapper.yml`, NOT `.github/workflows/publish-npm-wrapper.yml`) | [npm docs TP](https://docs.npmjs.com/trusted-publishers/) |
| 3 | First-publish via TP? | ❌ NO. Package must exist first. Option A: publish with token v0.1.0, enable TP v0.2.0+. Option B: use placeholder tool. | [npm docs TP](https://docs.npmjs.com/trusted-publishers/), [azu/setup-npm-trusted-publish](https://github.com/azu/setup-npm-trusted-publish) |
| 4 | npm CLI version required? | npm 11.5.1+ AND Node 22.14.0+ (npm 10.x bundled with Node 20 does NOT work) | [npm docs TP](https://docs.npmjs.com/trusted-publishers/) (GA July 31, 2025) |
| 5 | Common 403 causes? | Config mismatch (case-sensitive repo/workflow/owner), npm version <11.5.1, Node <22.14, package.json repository.url mismatch, runner type (must be GitHub-hosted) | [GitHub #173102](https://github.com/orgs/community/discussions/173102), [Medium: Kenrick](https://medium.com/@kenricktan11/npm-trusted-publishers-the-weird-404-error-and-the-node-js-24-fix-a9f1d717a5dd) |
| 6 | Provenance SLA? | **UNVERIFIED.** No published SLA; empirically <60s. Retry up to 200s is safe. | [deps.dev SLSA](https://blog.deps.dev/npm-provenance/) (no timing guarantee) |
| 7 | `--access public` for scoped/free? | ✓ YES. Scoped packages default to private; free accounts cannot publish private. REQUIRED. | [npm docs scoped](https://docs.npmjs.com/creating-and-publishing-unscoped-public-packages/) |
| 8 | `--tag rc` on first-publish? | ✓ YES. Works. Will NOT get `latest` tag. Later promote with `npm dist-tag add @pkg@v latest` (requires token; OIDC support in dev). | [npm dist-tag](https://docs.npmjs.com/cli/dist-tag/), [npm docs TP](https://docs.npmjs.com/trusted-publishers/) |
| 9 | `npm ci --ignore-scripts`? | ✓ YES. Best practice for CI; prevents lifecycle script attacks. No downside. | [DEV 2026: Spring incidents](https://dev.to/trknhr/lessons-from-the-spring-2026-oss-incidents-hardening-npm-pnpm-and-github-actions-against-1jnp) |
| 10 | TP config validation endpoint? | ❌ NO. npm does not validate TP config on save. Errors only appear on publish attempt. Test via `workflow_dispatch` before tagging. | [npm docs TP](https://docs.npmjs.com/trusted-publishers/) |
| 11 | Environment gate: `push` vs `workflow_dispatch`? | Both trigger gate if `environment:` has required reviewers. Best practice: use `workflow_dispatch` for releases (intentional), tag protection rules for branch guards. | [GitHub Docs: Deployments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/control-deployments) |
| 12 | RC→latest tag later? | ✓ YES. Can publish v1.0.0-rc.1 with `--tag rc`, then promote with `npm dist-tag add` or re-publish v1.0.0 with `--tag latest`. Caveat: dist-tag needs token (OIDC in dev). | [npm dist-tag](https://docs.npmjs.com/cli/dist-tag/), [Leechael 2025](https://leechael.org/posts/2025/npm-trusted-publishers-the-complete-guide/) |
| 13 | 2026 supply chain incidents + TP? | Yes: Shai-Hulud worm, Glassworm, axios (100M DL), RedHat namespace, TanStack attacks. TP + npm v12 (auto-block lifecycle scripts) + pnpm security defaults are hardening measures. | [Mondoo 2026](https://mondoo.com/blog/npm-supply-chain-security-package-manager-defenses-2026), [DEV 2026](https://dev.to/trknhr/lessons-from-the-spring-2026-oss-incidents-hardening-npm-pnpm-and-github-actions-against-1jnp), [Trend Micro 2026](https://www.trendmicro.com/en_us/research/26/c/axios-npm-package-compromised.html) |
| 14 | Tag protection bypass patterns? | No repo-specific exploits found. Best defenses: restrict tag creation to main branch only, require PR approval before merge, apply protections to admins. GitHub admin bypass exists but can be restricted with rulesets. | [GitHub Docs: Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule), [Mercari Engineering 2024](https://engineering.mercari.com/en/blog/entry/20241217-github-branch-protection/) |

---

## BONUS: CONTEXT FINDINGS

- **vercel-labs/skills:** No public npm publish workflow found in search; uses Vercel Actions (GitHub → Vercel deployment, not npm registry).
- **bmad-method:** AI-driven agile framework; uses GitHub Actions CI with schema/lint checks before release. Pattern: PR gate → version bump → publish (not OIDC-specific).
- **npm v12 Security (July 2026 release):** Will auto-block lifecycle scripts by default; blocks Git dependencies, remote URLs unless explicitly approved. Combined with OIDC TP, significantly hardens supply chain.

---

## UNRESOLVED QUESTIONS

1. **Provenance propagation SLA:** npm docs don't publish a target SLA for `dist.attestations.provenance` availability. Assume <60s (CDN backfill typical) but could be longer on registry congestion. Recommend retry logic in verification step.
2. **dist-tag OIDC support timeline:** OIDC for `npm dist-tag add` is in development; no ship date published. Workaround: automate tag promotion in the same workflow (before OIDC token expires).
3. **Tag protection rule specifics for npm tag publishing:** GitHub branch/tag protection rules can restrict tag creation, but npm tags are separate from Git tags. Clarify: should tag protect Git tags only (v0.1.0) or add a separate ruleset for "npm-publish" tags?

---

## STATUS

**Status: DONE_WITH_CONCERNS**

**Critical blocker:** Node 20.11 incompatible with npm OIDC TP. Upgrade to Node 22.14.0 LTS before first publish.

**Secondary blocker:** Package must exist on npm before TP can be configured. Use token for v0.1.0, then enable TP for v0.2.0+.

**Workflow config is otherwise sound** (id-token write, npm ci, --access public, --tag support correct).

Recommend staging this work in order:
1. Upgrade Node (lowest friction).
2. Publish v0.1.0 with token (one-time, reserves name).
3. Configure TP on npmjs.com (exact repo/workflow/owner match).
4. Test via workflow_dispatch before relying on tag-based automation.
5. Document provenance verification pattern for users.

Estimated effort: 1–2 days for v0.1.0 baseline + TP setup + testing.

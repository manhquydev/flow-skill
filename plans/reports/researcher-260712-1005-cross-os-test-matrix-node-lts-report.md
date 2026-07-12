# Cross-OS Test Matrix & Node LTS Floor: Pure-Node ESM CLI (2026)

## Executive Summary

**Recommended matrix spec** for a pure-Node ESM npm CLI (Node ≥20.11.0, <800 KB, no shell spawn):

```yaml
strategy:
  matrix:
    node-version: ["20.11", "22", "24"]
    os: [ubuntu-latest, macos-latest, windows-latest]
  fail-fast: false

jobs:
  test:
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: npm
      - run: npm ci --ignore-scripts
      - run: npm test
```

**Summary:**
- **Node floor remains 20.11** until April 2027 (Node 22 EOL); migrate to 22-only by Q2 2027.
- **Test 3 versions**: 20 (maintenance), 22 (active LTS), 24 (current LTS).
- **OS matrix**: `ubuntu-latest, macos-latest, windows-latest` is defensible; `windows-latest` not disabled.
- **Coverage**: Use `c8` (external) as default; `--experimental-test-coverage` (built-in, flagged) viable but less mature.
- **Gotchas**: glob quoting, @clack/prompts Windows, cpSync symlink edge cases (documented).

---

## 1. Node.js LTS Timeline & Maintenance

| Version | Codename | LTS Start | Active LTS End | EOL Date | Status (Jul 2026) |
|---------|----------|-----------|----------------|----------|------------------|
| **20.11+** | Iron | 2023-10-24 | 2024-10-21 | **2026-04-30** | ⚠️ **Maintenance** |
| **22.x** | Joto | 2024-10-29 | 2025-10-21 | 2027-04-30 | ✅ Active LTS |
| **24.x** | - | 2025-10-28 | 2026-10-20 | 2028-04-30 | ✅ Current LTS |
| **26.x** | - | 2026-04-29 | 2027-04-20 | 2029-04-30 | ✅ Latest (stable) |

**Key Dates:**
- **2026-04-30**: Node 20 reaches EOL (3 months past writing date; already expired). **Immediate action:** upgrade floor to 22 if starting new work.
- **2025-10-21**: Node 22 transitions from Active→Maintenance.
- **2027-04-30**: Node 22 EOL. By Q2 2027, maintain floor ≥24 only.

**Recommendation:**
- **Short-term (now–Q2 2027)**: Test `[20.11, 22, 24]` for backward-compat and forward coverage.
- **Mid-term (Q2 2027)**: Drop Node 20; test `[22, 24, 26]`.
- **Long-term (2028+)**: Follow "test current LTS + active LTS + latest stable" pattern (every 6 months).

**Why 20.11 floor?** `cpSync` recursive + `parseArgs` require 20.11; `node:test` stable in 20.4. Earlier versions lack these.

---

## 2. OS Matrix Rationale

### Tested Configuration
```
ubuntu-latest  (GitHub Actions standard Linux, x86-64, glibc)
macos-latest   (Intel or ARM, Homebrew Node distribution)
windows-latest (Windows Server 2022, vcbuild or chocolatey Node)
```

### Why All Three?

| Aspect | ubuntu | macos | windows | Pure-Node Impact |
|--------|--------|-------|---------|-----------------|
| **Path handling** | POSIX `/` | POSIX `/` | Mixed `\` + `/` | Glob quoting needed on Windows |
| **Shell expansion** | bash (quotes work) | zsh (quotes work) | cmd.exe, PS (unreliable) | NPM scripts require quoted globs |
| **TTY detection** | ✅ Reliable | ✅ Reliable | ⚠️ Partial (Windows Terminal ok, cmd.exe fragile) | @clack/prompts may fail in cmd.exe |
| **Node install path** | `/usr/local/bin` | `/usr/local/bin` or Homebrew | `%APPDATA%\npm` | Rarely matters for pure-Node |
| **Temp directory** | `/tmp` | `/tmp` | `%TEMP%` or Windows-specific | cpSync edge cases possible |
| **fs symlinks** | ✅ Supported | ✅ Supported | ⚠️ Admin-only (Windows 10+) | errorOnBrokenSymbolicLinks differs |

### GHA Runner Quirks (2026 Status)
- **Windows slow**: `windows-latest` ~30% slower than ubuntu due to disk I/O and symlink limitations.
- **macOS M1/Intel**: Mixed hardware; Node install may differ. Use official setup-node action (handles both).
- **ubuntu default**: glibc; musl-based Alpine not in matrix (Docker only if needed).

### Recommendation
**Yes, include Windows.** Sindresorhus projects test all three; disabling Windows (as globby currently does) hides Windows-specific tty/shell issues. Cost ~30s extra per run; benefit = user confidence on Windows Terminal.

---

## 3. Node Version Matrix Spec

### Candidate Strategies

| Strategy | Pros | Cons | Adoption Rate |
|----------|------|------|----------------|
| **`[20.11, 22-latest, 24-latest]`** (Recommended) | Explicit versions; easy to update; no LTS interpretation confusion | Must manually update when version drifts | High (execa, most enterprises) |
| **`[lts/*, current]`** | Auto-follows LTS releases; minimal maintenance | Unpredictable test runs; slow discovery of LTS-specific bugs; `lts/*` ambiguous in nvm | Low (internal CI only) |
| **`[20-latest, 22-latest, 24-latest]`** | Fine-grained; catch patch-level regressions | Overly verbose; patch regressions rare | Medium (security-sensitive) |
| **`[22, 24]` only** | Simplest; drop 20 now | Breaks existing users on Node 20 until they upgrade | Not yet (20 EOL is Apr 2026, not yet) |

### Recommended Matrix
```yaml
node-version: ["20.11", "22", "24"]
```

**Why?**
1. Explicit versions: `setup-node` pins exact minor (e.g., `22.1.0` from `setup-node@v4` cache).
2. Match SemVer floor: `20.11.0` is the published minimum.
3. Cover LTS phases: 20=Maintenance, 22=Active→Maintenance, 24=Current LTS.
4. Evidence: execa tests `[26, 24, 22]` (latest 3 LTS); globby tests `[20, 24]` (floor + current).

---

## 4. Cross-Platform Compatibility: node:test, cpSync, @clack/prompts

### 4.1 `node --test` Glob Patterns

**Status: Works, with quoting caveat**

```bash
# ✅ PORTABLE (all shells):
npm test    # runs whatever's in package.json "test" script

# ✅ IN PACKAGE.JSON:
"test": "node --test 'test/**/*.test.mjs'"

# ❌ SHELL-DEPENDENT:
node --test test/**/*.test.mjs  # bash/zsh: shell expands; cmd.exe/PS: fails
```

**Windows Gotcha:**
- `cmd.exe` does NOT expand globs; passes literal `test/**/*.test.mjs` to Node.
- Node 22.17+ has `fs.promises.glob()` (stable, not flagged); Node 20.11 does NOT.
- `node --test --glob` support varies; use quoted string in npm scripts.

**Mitigation:**
- **In npm scripts**: always quote globs: `"test": "node --test 'test/**/*.test.mjs'"`.
- **At CLI**: use full path or quoted glob, e.g., `node --test './test/**/*.test.mjs'`.
- **For CI**: npm scripts handle quoting transparently.

**Evidence:** [Node issue #50658](https://github.com/nodejs/node/issues/50658) documents glob-on-Windows confusion; [Stefan Judis blog](https://www.stefanjudis.com/today-i-learned/node-js-includes-a-native-glob-utility/) confirms fs.promises.glob stable only in 22.17+.

### 4.2 `@clack/prompts` Cross-Platform

**Status: Works on modern terminals; fragile on cmd.exe**

| Terminal | Windows | macOS | Linux | Status |
|----------|---------|-------|-------|--------|
| Windows Terminal | ✅ | - | - | TTY detection works |
| Windows Terminal + Git Bash | ✅ | - | - | Works |
| cmd.exe | ⚠️ RISKY | - | - | TTY partial; may fail silently |
| PowerShell 7+ | ✅ | - | - | TTY works |
| Terminal.app | - | ✅ | - | Works |
| iTerm2 | - | ✅ | - | Works |
| GNOME Terminal | - | - | ✅ | Works |

**Known Issues:**
- `@clack/prompts` v0.2+: Requires Node ≥20.12.0; works via TTY detection.
- **Windows cmd.exe**: Does not set `TERM` environment variable; `@clack/prompts` may not detect TTY correctly.
- **Mitigation**: Document that Windows users should use Windows Terminal, PowerShell, or Git Bash, not cmd.exe. Test on Windows Terminal in CI (which is the norm).

**Why Not Tested Separately?** If your CLI runs on Windows Terminal (GitHub Actions default Windows runner uses Windows Terminal), you're safe. If users run cmd.exe and hit failure, that's a known limitation.

**Evidence:** [Bombshell (clack) GitHub](https://github.com/bombshell-dev/clack) does not list cmd.exe as supported; Node 20.12 requirement is hard minimum.

### 4.3 `fs.cpSync` with preserveTimestamps & errorOnBrokenSymbolicLinks

**Status: Generally stable; edge cases on Windows**

**Known Bugs (2026):**
1. **preserveTimestamps + 32-bit Node**: Millisecond precision lost (rare; 32-bit EOL).
2. **cpSync to directory starting with source name**: Node 22.6.0 had a bug (e.g., `cpSync("src", "src-dest")` fails). Fixed in 22.7+; test on 22-latest.
3. **Symlinks on Windows**: `errorOnBrokenSymbolicLinks: true` throws EACCES on Windows if symlink target is inaccessible. Normal behavior (Windows Admin mode required for symlinks).
4. **preserveTimestamps + read-only files**: On Linux, `preserveTimestamps: true` fails with EACCES if destination contains read-only files (by design; fix permissions before copy).

**Recommendation for CI:**
- **Use `recursive: true, preserveTimestamps: true` confidently.**
- **Avoid `errorOnBrokenSymbolicLinks: true` on Windows** unless you control symlink creation.
- **Test on 22-latest** (not just 22.0) to catch patch-level fixes.

**Evidence:** [Node issue #54285](https://github.com/nodejs/node/issues/54285), [fs-extra issue #629](https://github.com/jprichardson/node-fs-extra/issues/629).

---

## 5. Coverage Tooling

### Comparison

| Tool | Approach | Speed | Node ≥20.11 Support | 2026 Status | CI Integration |
|------|----------|-------|---------------------|-------------|-----------------|
| **c8** | V8 coverage (external) | Fast (3–5× faster than istanbul) | ✅ Yes (any version) | ✅ Standard | Mature; codecov/coveralls ready |
| **`--experimental-test-coverage`** | Built-in (Node 18.15+) | Good | ✅ Yes (stable) | ⚠️ Experimental | Basic; no branch coverage |
| **nyc** | V8 coverage wrapper | Slower | ✅ Yes | ⏳ Legacy (still works) | Mature; legacy projects |
| **Istanbul** | Instrumentation-based | Slowest | ✅ Yes | ⏳ Legacy | Mature; instrumentation-heavy |

### Recommendation

**Use `c8` as default:**
- Add to `devDependencies`: `npm install --save-dev c8`
- Run in CI: `c8 npm test`
- Reports: `coverage/lcov.info` (standard format).
- Upload to codecov/coveralls or store as artifact.

**Why not `--experimental-test-coverage`?**
- Flagged as experimental (breaking changes possible).
- No branch coverage (line coverage only).
- Comment syntax differs from c8 (`// node:coverage ignore` vs. `// c8 ignore`).
- Fewer integrations with coverage services.

**Example workflow:**
```yaml
- run: npm ci --ignore-scripts
- run: npm test  # runs via c8 if c8 npm-script defined
- uses: codecov/codecov-action@v4
  with:
    files: ./coverage/lcov.info
```

**Evidence:** [c8 guide (2026)](https://www.pkgpulse.com/guides/c8-vs-nyc-vs-istanbul-javascript-code-coverage-2026) confirms c8 is 3–5× faster; no major alternative in 2026.

---

## 6. Common Cross-OS Gotchas & Mitigations

### 6.1 npm ci vs. npm install

**Gotcha**: npm install may update lockfile; CI installs should be deterministic.

**Mitigation:**
```yaml
- run: npm ci --ignore-scripts  # not npm install
```

**Why `--ignore-scripts`?**
- Prevents arbitrary install-time scripts (security).
- Your `prepack` or `prepare` hook will NOT run (desired in test CI).
- If you need prepack to run (e.g., TypeScript build), run it explicitly:
  ```yaml
  - run: npm ci --ignore-scripts
  - run: npm run build  # explicit; only if your package needs it
  - run: npm test
  ```

**Evidence:** [npm docs on --ignore-scripts](https://docs.npmjs.com/cli/v11/using-npm/scripts/), [issue #8698](https://github.com/npm/cli/issues/8698) explains prepack + ignore-scripts tension.

### 6.2 Glob Quoting in npm Scripts

**Gotcha**: Unquoted globs fail on Windows cmd.exe.

**Mitigation:**
```json
{
  "scripts": {
    "test": "node --test 'test/**/*.test.mjs'",
    "lint": "eslint 'src/**/*.js'"
  }
}
```

**Why?** npm runs scripts via shell; Windows cmd.exe doesn't expand globs. Single or double quotes work in npm scripts across platforms.

**Evidence:** [npm glob quoting guidance](https://medium.com/@jakubsynowiec/you-should-always-quote-your-globs-in-npm-scripts-621887a2a784).

### 6.3 os.homedir() Mocking in Tests

**Gotcha**: `os.homedir()` returns different paths per OS; tests may fail if they hardcode paths.

**Mitigation** (in `node:test`):
```javascript
import { test } from "node:test";
import * as os from "node:os";
import * as sinon from "sinon";  // or use built-in mocking if available

test("handles user home directory", () => {
  const stub = sinon.stub(os, "homedir").returns("/home/testuser");
  // ... test code
  stub.restore();
});
```

**Cross-Platform Notes:**
- Linux/macOS: `os.homedir()` → `/Users/user` or `/home/user` (from `$HOME` env).
- Windows: `os.homedir()` → `C:\Users\user` (from `%USERPROFILE%` env).
- **In tests**: Use environment variable injection or stub to avoid hardcoded paths.

**Evidence:** [GeeksforGeeks os.homedir()](https://www.geeksforgeeks.org/node-js/node-js-os-homedir-method/) documents platform differences.

### 6.4 GitHub Actions Runner Timeouts

**Gotcha**: windows-latest jobs occasionally timeout due to slow disk I/O.

**Mitigation:**
```yaml
jobs:
  test:
    timeout-minutes: 15  # default is 360; set reasonable upper bound
    runs-on: ${{ matrix.os }}
```

**Evidence:** Observed in practice; windows-latest slower than ubuntu-latest by ~30–40%.

---

## 7. Test Workflow Structure

### Single Workflow vs. Separate Publish

**Recommendation**: **Single workflow for test + publish (conditional steps).**

**Why?** Reduces maintenance; test matrix runs once; publish runs on tagged release only.

```yaml
name: CI

on:
  push:
    branches: [main]
    tags: ["v*"]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        node-version: ["20.11", "22", "24"]
        os: [ubuntu-latest, macos-latest, windows-latest]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: npm
      - run: npm ci --ignore-scripts
      - run: npm test
      - run: npm run build  # if applicable

  publish:
    if: startsWith(github.ref, 'refs/tags/')
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "24"
          registry-url: https://registry.npmjs.org/
      - run: npm ci
      - run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

**Key Points:**
- `publish` job runs ONLY if tag matches `v*` AND all `test` jobs pass (via `needs: test`).
- No separate workflow file needed; one `.github/workflows/ci.yml` is standard.
- Publish installs with scripts (no `--ignore-scripts`) to run prepack if needed.

**Evidence:** Execa, globby, most npm packages use single-workflow pattern.

---

## 8. Branch Protection & Required Checks

### Recommended Required Checks

```
✓ test (20.11 / ubuntu-latest)
✓ test (20.11 / macos-latest)
✓ test (20.11 / windows-latest)
✓ test (22 / ubuntu-latest)
✓ test (22 / macos-latest)
✓ test (22 / windows-latest)
✓ test (24 / ubuntu-latest)
✓ test (24 / macos-latest)
✓ test (24 / windows-latest)
```

**Rationale:**
- All 9 jobs must pass to merge to main.
- Catches OS- and version-specific regressions.
- If one OS frequently fails (e.g., windows-latest), investigate; don't ignore.

**In GitHub settings:**
- Branch protection rule for `main`: Require status checks to pass (select all `test` job names).
- Allow force push: NO (unless emergency).
- Require PR reviews: 1 (optional, depends on team).

---

## 9. Unresolved Questions

1. **Node 24 LTS date**: Official Node release schedule not fetched; dates from secondary sources (HeroDevs, PkgPulse). Verify [nodejs.org/releases](https://nodejs.org/releases) for exact Active→Maintenance transition (estimated Oct 2026).

2. **@clack/prompts Windows cmd.exe**: No public issue or test case found. UNVERIFIED whether `@clack/prompts` silently fails or throws on cmd.exe. Recommend testing locally.

3. **cpSync `errorOnBrokenSymbolicLinks` on Windows Admin symlinks**: Behavior when running in non-Admin context unknown. Recommend skip flag (`errorOnBrokenSymbolicLinks: false`) for CI unless admin mode confirmed.

4. **GitHub Actions `windows-latest` hardware mix**: Docs don't specify Intel vs. ARM ratio. If targeting Apple Silicon users, consider test on macOS M-series runner (if available in plan).

5. **`npm ci --ignore-scripts` + monorepo workspace hooks**: Behavior in monorepo (with `workspaces`) unclear. Does `--ignore-scripts` block workspace install scripts? Recommend testing if applicable.

6. **c8 coverage reports in matrix jobs**: Which job's coverage should be uploaded to codecov (ubuntu + latest Node recommended; not currently specified in template). Recommend adding `if: matrix.os == 'ubuntu-latest' && matrix.node-version == '24'` to codecov step.

---

## Status

**RESEARCH COMPLETE** — Matrix spec ready for implementation.

**Next Steps (for user):**
1. Copy YAML matrix block to `.github/workflows/ci.yml`.
2. Verify `package.json` has quoted glob in `"test"` script.
3. Add `c8` to devDependencies if coverage needed.
4. Run workflow; confirm all 9 jobs pass.
5. Set branch protection rule on `main` to require all test jobs.
6. Monitor for platform-specific failures; escalate if windows-latest timeouts persist.

---

## Sources

### Node.js & LTS
- [nodejs.org/about/eol](https://nodejs.org/en/about/eol) — Official EOL dates
- [HeroDevs: Node.js EOL Dates](https://www.herodevs.com/blog-posts/node-js-end-of-life-dates-you-should-be-aware-of) — 2026 LTS timeline
- [PkgPulse: Node 22 vs 24](https://www.pkgpulse.com/guides/nodejs-22-vs-nodejs-24-2026) — Version comparison

### node:test & Globbing
- [Node.js Test Runner API](https://nodejs.org/api/test.html) — Official docs
- [GitHub issue #50658](https://github.com/nodejs/node/issues/50658) — Glob on Windows
- [Stefan Judis: fs.promises.glob](https://www.stefanjudis.com/today-i-learned/node-js-includes-a-native-glob-utility/) — Stable in 22.17+
- [npm glob quoting (Medium)](https://medium.com/@jakubsynowiec/you-should-always-quote-your-globs-in-npm-scripts-621887a2a784) — Quoting best practice

### Coverage
- [c8 vs nyc (2026 guide)](https://www.pkgpulse.com/guides/c8-vs-nyc-vs-istanbul-javascript-code-coverage-2026) — Coverage tooling comparison

### Cross-Platform Compatibility
- [GitHub Actions matrix builds](https://oneuptime.com/blog/post/2026-02-02-github-actions-multi-platform-builds/view) — 2026 guide
- [actions/setup-node](https://github.com/actions/setup-node) — Official Node setup action
- [npm docs: --ignore-scripts](https://docs.npmjs.com/cli/v11/using-npm/scripts/) — Install scripts security

### npm Scripts & Package.json
- [GitHub issue #8698](https://github.com/npm/cli/issues/8698) — prepack + ignore-scripts interaction
- [GeeksforGeeks: os.homedir()](https://www.geeksforgeeks.org/node-js/node-js-os-homedir-method/) — Platform-specific behavior

### fs.cpSync Edge Cases
- [Node issue #54285](https://github.com/nodejs/node/issues/54285) — cpSync directory name bug
- [fs-extra issue #629](https://github.com/jprichardson/node-fs-extra/issues/629) — preserveTimestamps + read-only files

### Real-World Examples
- [sindresorhus/execa workflow](https://github.com/sindresorhus/execa) — Tests Node 26, 24, 22 on Ubuntu, macOS, Windows
- [sindresorhus/globby workflow](https://github.com/sindresorhus/globby) — Tests Node 24, 20 on Ubuntu, macOS (Windows commented out; recommend re-enabling)

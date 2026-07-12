# Security policy

## Threat model

`@manhquy/flow-skill` is a **file-copy installer** written in pure Node.js. When you run `npx @manhquy/flow-skill`, the process:

- copies files from the tarball into one or more agent home directories, and
- exits.

There are no network calls, no shell/PowerShell invocations, no `postinstall` hooks, and no long-running daemons.

## What the installer WILL NOT do

- Run any script from the Internet at install time.
- Touch `settings.json`, `permissions`, `allowedMcpServers`, hooks, or any marketplace config.
- Modify MCP config, shell rc, PATH, or environment variables.
- Log in to npm, mint tokens, or publish anything.
- Log, save, or commit tokens, passwords, OTPs, or private keys.
- Touch any path outside the explicit list below:
  - `<home>/.claude/skills/flow`
  - `<home>/.codex/skills/flow`
  - `<home>/.agents/skills/flow`
  - `<home>/.gemini/antigravity-cli/skills/flow`
  - `<home>/.gemini/config/skills/flow`
  - `<project>/.claude/skills/flow` when `--project` is used
- Spawn `bash`, `sh`, `pwsh`, `powershell.exe`, or any child process (pure Node `node:fs`).

## What the installer WILL do

For each destination the user selects, the installer performs (parity with the upstream `install.sh:24-27` contract):

1. Acquire a best-effort advisory lock: `<parent>/.flow-skill.installing.lock`. If the file exists and its recorded PID is alive, refuse and exit `2`.
2. Recursively scan the bundled source `skills/flow/`. If any symbolic link is present, refuse and exit — an upstream-planted symlink is treated as hostile.
3. `mkdir -p` the destination.
4. `rm -rf` these six subdirectories inside the destination (if present): `runner/`, `_templates/`, `law/`, `references/`, `harness/`, `playbooks/`.
5. Recursively copy `skills/flow/` into the destination with `dereference: false` and `errorOnBrokenSymbolicLinks: true`.
6. Rescan the destination for symlinks (defense-in-depth). Abort if any found.
7. `chmod 755` the destination's `runner/flow.sh` if it exists.
8. Release the lock.

Any file **outside those six subdirectories** at the destination is preserved. You may drop personal notes, custom playbooks in a different directory, etc., alongside the installed skill — the installer will not touch them.

## Known v0.1 limitations

These match the behavior of the upstream `install.sh`; they are documented rather than hidden.

- **Not atomic across a full run.** `SIGINT` (Ctrl+C) mid-copy or a hard crash may leave a destination in an inconsistent state. Re-running the installer fixes it. The advisory lock reduces (but does not eliminate) the risk of two concurrent runs racing.
- **Antigravity has two destinations.** If the first install succeeds and the second fails, the first is **not** rolled back — matching the upstream `install.sh:52-53` behavior. The `install:done` and `summary` JSONL events report the partial state.
- **Windows `EBUSY`.** If a running agent (Claude Code, Codex, Antigravity IDE) holds a file handle inside the destination, `rm`/`cp` retries 3× with backoff (100/300/900 ms). If it still fails, the installer reports the target and asks you to close the agent.

## Supply chain

- **Trusted publishing.** Every version is published from a tag-triggered GitHub Actions workflow (`.github/workflows/publish-npm-wrapper.yml`, or `workflow_dispatch` for validation) behind a required-reviewer environment gate. No long-lived npm token exists in CI; auth is via OIDC.
- **Provenance.** npm attaches an SLSA Build Level 2 attestation to every published version. Verify with:
  ```
  npm view @manhquy/flow-skill@<version> dist.attestations.provenance
  ```
- **Publisher account.** npm 2FA `auth-and-writes` is enabled as defense-in-depth for the git + npm identity behind the workflow.
- **Pin your version.** During the RC window use `@rc` (dist-tag) or an explicit `@0.1.0-rc.N`. After stable ships, pin `@0.1.x` (or a specific version). `@latest` invites blind updates on a package that writes to your agent home.
- **Completeness signal (not tamper detection).** The tarball ships `skills-manifest.json` recording the synced skill's file count + list. The publish workflow re-counts the checked-out tree against this manifest to catch an incomplete sync. It is **not** a supply-chain integrity proof — that role belongs to npm provenance above. `.integrity` SHA-256 sidecar was intentionally not adopted because it would have been generated from the same source it hashed (circular trust).
- **No `postinstall`.** `package.json` has no `postinstall` script. `prepack` (dev-only) is not in the shipped tarball.

## Reporting a security issue

- Preferred: [GitHub Security Advisory](https://github.com/manhquy/flow-skill/security/advisories/new)
- Email: `manhquy.mqy@gmail.com` (subject: `[flow-skill security]`)

Please do not publish exploits before a fix ships. Best-effort response SLA for v0.1.

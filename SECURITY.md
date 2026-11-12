# Security Policy

## Reporting a vulnerability

Please do **not** open a public GitHub issue for a security vulnerability.

Instead, either:

- use [GitHub's private security advisory](https://github.com/manhquydev/flow-skill/security/advisories/new), or
- email `manhquy.mqy@gmail.com` with a description, reproduction steps, and impact.

This is a solo-maintained project — no fixed SLA is promised, but reports are read and
acknowledged as soon as possible. Once a fix is available, a new release and an advisory
will be published; credit is given to the reporter unless anonymity is requested.

## Supported versions

Only the latest released version on `master` is supported.

## Attack surface

Flow is a discipline layer: mechanically, it is pure bash (`skills/flow/runner/flow.sh`)
invoked explicitly by the hosting agent or the operator. There is no daemon, no resident
process, and no automatic lifecycle hooks — flow runs because a host invoked it and
terminates when that invocation returns (ADR-0001). Its telemetry is local-only JSONL
under the project's `.flow/` directory and device-global `~/.claude/flow/`; it is never
transmitted anywhere.

## What flow deliberately refuses

Hooks-based policy gates and background watchers are rejected **by design**, not deferred.
The 2026 hook-escape class — configuration-based sandbox escape via hooks that execute
without extra permission or user notification, and skill-lifecycle C2 weaponizing a
benign-looking skill — is exactly the attack surface flow refuses to carry. Reopening
this requires a formal ADR: see `docs/adr/0001-discipline-layer-identity.md`.

## Integrity model (receipt = ownership + drift detection, NOT authenticity)

At prepack, `npm-wrapper/scripts/sync.mjs` writes `skills/flow/manifest-hashes.json` — a
SHA-256 map of the shipped tree. `flow doctor` compares installed bytes against that receipt
and fails loudly on drift ("the harness may have been modified mid-project").

Since the wave-2 transactional installer (npm channel), the receipt is also the **ownership ledger** used
at upgrade time:

- The installer refuses to proceed when a file the previous receipt owns has been edited
  in place (explicit conflict listing, no `--force`), when a receipted path is missing
  (root mismatch), when the destination tree contains symlinks or special files, or when a
  legacy (unreceipted) destination collides with differing bytes.
- User-created files — including inside previously-managed subdirs — are carried into the
  new candidate and reported; retired owned files are pruned only when unmodified, and
  preserved (never silently deleted) when the user modified them.
- Updates run as a transaction: private random staging dir in the destination's parent,
  rename-only backup of the old tree, rename-promote, verification of the promoted tree
  against the staged expectation, and only then backup removal. Promotion or verification
  failure restores the original; a failed restore keeps the backup and reports its path.
  No crash/`SIGKILL` atomicity is promised — guarantees hold for returned failures.

Limits: an attacker who rewrites both the runner **and** the receipt together is invisible
to `doctor`. The receipt is drift detection and self-declared ownership only — package
**authenticity** remains the job of npm provenance and the registry. The advisory lock path
is predictable and same-uid local processes can race path operations; no malicious-same-uid
filesystem safety is claimed. Empty directories are not carried across upgrades (files are).

## Install trusted path

- Preferred: `npx @manhquy/flow-skill@latest` (npm provenance applies).
- Direct: `bash scripts/install.sh` (POSIX) or `pwsh scripts/install.ps1` (Windows).
- Verify post-install: run `flow doctor` and check the `runner integrity: ok` line.

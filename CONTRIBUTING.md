# Contributing to flow

Thank you for your interest in contributing! `flow` is a gated build discipline skill and harness for coding agents, guiding software delivery from idea to real, verifiable world-state evidence. For higher-level overviews and tutorials, visit [flowskill.io.vn](https://flowskill.io.vn) or explore the [`docs/`](docs/) directory.

Contributors of all experience levels are welcome. Please read this guide and [`AGENTS.md`](AGENTS.md) (the repo standing orders) before opening a pull request.

## Developer Quickstart

Clone the repository and verify your local environment:

```bash
git clone https://github.com/manhquydev/flow-skill.git
cd flow-skill

# Run the primary bash test suite (must be green before opening a PR)
bash tests/run_all.sh

# When touching npm-wrapper installer or sync scripts
cd npm-wrapper && npm test && cd ..

# When editing documentation files
bash scripts/check-doc-budgets.sh
```

## Repository Conventions

Our contributor standards prioritize stability across operating systems and agent runtimes. Full standing orders live in [`AGENTS.md`](AGENTS.md) — follow its "one home per fact" rule:

- **Bash 3.2 compatibility:** All shell scripts must remain macOS / BSD grep compatible (`grep -E` without GNU-specific flags like `\b` or `grep -P`).
- **Zero new runtime dependencies:** The core skill runner runs on native host utilities; do not add external CLI/runtime requirements.
- **Test suite registration:** Every new bash suite must add `tests/test_<name>.sh` **and** a corresponding entry in `tests/manifest.txt` in the exact same change.
- **Doc budgets enforced:** Key markdown files are budgeted in `docs/doc-budgets.txt`. Verify with `bash scripts/check-doc-budgets.sh`.
- **Dual versioning:** Skill product (`skills/flow/SKILL.md`) and npm installer (`npm-wrapper/package.json`) versions are managed on separate release axes. Contributors should **never** bump version fields in PRs (see [`docs/release-process.md`](docs/release-process.md)).
- **Branch boundaries:** `website/` is managed on a dedicated branch (`feat/flow-website`). Never commit edits to `website/` on `master` PRs.
- **Evaluation STOP zones:** Never modify `_eval_engine_run` or `_run_with_timeout` in `skills/flow/runner/flow.sh`. If a task requires touching them, stop and discuss with maintainers first.
- **Conventional commits:** Follow conventional commit prefixes mirroring our git log (`feat`, `fix`, `docs`, `test`, `chore`).

## Pull Request Flow

1. **Fork and branch:** Create a descriptive branch from `master` (e.g., `fix/doctor-path-check`, `docs/clarify-cards`).
2. **Scope small:** Keep changes focused on a single concern. Match your test evidence to the surface touched (consult [`AGENTS.md`](AGENTS.md) test-evidence protocol).
3. **Use the PR template:** Fill out all checkboxes in [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md) including local test output.
4. **CI validation:** Automated CI runs cross-OS tests (Ubuntu, macOS, Windows Git Bash) and npm-wrapper matrices on `master`. Maintainers review and merge approved PRs into `master`. Note that GHA triggers on `master` pushes and PRs targeting `master`.

## Issue and PR Templates

- Report harness bugs via [Bug Report form](.github/ISSUE_TEMPLATE/bug_report.yml).
- Report installer bugs via [npm-wrapper Bug Report](.github/ISSUE_TEMPLATE/bug-report-npm-wrapper.yml).
- Propose enhancements via [Feature Request form](.github/ISSUE_TEMPLATE/feature_request.yml).
- Security vulnerabilities: **never** file a public issue. See [`SECURITY.md`](SECURITY.md) for private reporting channels.

## Code of Conduct

This project adheres to the Contributor Covenant. Please review [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) before participating in our community.

## GitHub maintenance

Maintainers: see [the Vietnamese GitHub workflow guide](docs/github-maintenance.vi.md) for security triage, dependency updates, and the branch protection workflow.

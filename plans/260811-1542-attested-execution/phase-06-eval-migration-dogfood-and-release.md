---
phase: 6
title: "Eval, migration, dogfood, and release"
status: completed
priority: P1
effort: "1-2d"
dependencies: [2, 3, 4, 5]
---

# Phase 6: Eval, migration, dogfood, and release

## Context links

- [Plan overview](./plan.md)
- [Auto enforcement](./phase-05-auto-review-and-live-verify-enforcement.md)
- `skills/flow/eval/manifest.tsv`
- `skills/flow/runner/flow.sh:2775-2873,3081-3200,3542-3775`
- `tests/test_flow_eval.sh`
- `tests/run_all.sh`
- `.github/workflows/ci.yml`
- `.github/workflows/publish-npm-wrapper.yml:4-75`
- `.github/workflows/nightly-registry-health.yml:37-60`
- `scripts/release-preflight.sh:61-94,131-201`
- `docs/release-process.md`
- `npm-wrapper/RELEASE_CHECKLIST.md`
- `npm-wrapper/package.json:3`
- `docs/quality-metrics.md:4-18`

## Overview

Close v0.28 with executable migration behavior, a deterministic adversarial
acceptance corpus, the first Stage 05 semantic eval pair, self-dogfood on a real
skill release path, and coherent distribution metadata. This phase does not
add new receipt kinds or integrations.

## Requirements

### Functional

- Legacy projects migrate without bulk rewriting:
  - missing risk fields read as unknown;
  - manual commands warn and retain prior behavior;
  - auto lists every legacy card as blocked until explicitly classified;
  - absent auto state means inactive;
  - old/unknown receipt schemas are invalid and must be re-minted;
  - existing done cards need current receipts only after auto is activated.
- Ship a deterministic acceptance corpus for missing, stale, structurally
  tampered, invalid-schema, dirty-tree, timeout, output-cap, signal/non-zero,
  security-ack, producer/oracle mismatch, latest-attempt, and merged-worktree
  failures.
- Extend semantic eval with one mechanically clean sound/hollow pair for
  `05-contract`.
- Dogfood the real active-auto sequence on this skill project or an isolated
  worktree of it, including an intentional red attempt before the green path.
- Add an offline release-coherence check and invoke it from release preflight.
- Make `next` the sole operational prerelease tag; preserve historical `rc`
  records but remove it from current workflows/runbooks/templates.
- Release skill product `0.28.0`, synchronized mirrors/bundle, and npm installer
  `0.5.0` after all gates pass.

### Non-functional

- No live/billable LLM call in default CI; eval tests use mocked engines.
- No network dependency in release-coherence tests; live registry remains a
  separately reported preflight/publish check.
- Existing 3-OS Bash suite, no-Python degradation, and npm Node 22/24 matrix
  remain required.
- No committed `.flow/auto-state`, receipts, raw eval output, secrets, or
  dogfood temp artifacts.
- No claim that actor labels or unsigned receipts prove human/model identity.

## Architecture

### Legacy migration table

| Existing state | Manual behavior | Auto behavior | Operator action |
|---|---|---|---|
| Card lacks risk fields | Warn; existing check/done usable | Block as unknown | Add all three risk fields |
| Card has invalid/duplicate risk | Structural warning/failure where parsed | Block | Repair card metadata |
| No `.flow/auto-state` | Inactive | Run `flow auto` to activate | None unless autonomy desired |
| Malformed/stale auto state | Status shows INVALID/STALE | Hard boundaries block | Fix blockers and rerun auto, or `auto stop` |
| No receipts | Warn | Required boundary blocks | Re-run semantic/live attestation |
| Unknown receipt schema/kind/key | Invalid; never auto-upgrade | Block | Remove/re-mint with current CLI |
| Done legacy card without risk/receipts | Existing manual readiness | Activation blocks unknown risk; active ready blocks stale receipts | Classify and re-attest current integrated/deployed revision |
| Squash/rebased reviewed commit | Semantic receipt stale | Block | Re-review/mint on final integrated revision |
| Card lacks committed owner manifest | Warn; existing manual behavior | Semantic/live pass cannot mint | Add reviewed repo-relative owner/oracle manifest |

Migration docs must state that `.flow` is run-state. Back up receipt files only
when their audit history matters; never commit them to source control.

### Acceptance corpus

Use ordinary temp Git repositories and the public CLI, not sourced private
helpers, for end-to-end cases. Low-level parser unit cases may source library
mode separately.

Required corpus groups:

1. **Risk/authority:** legacy unknown, duplicate risk, wrong-card DEBT,
   non-ancestor ack, same/ambiguous author, valid distinct-author ack.
2. **Receipt structure:** missing key, duplicate pass field, unknown key,
   oversized/control/multiline value, wrong object format, path traversal,
   malformed or subject-inconsistent verdict/fingerprint. Do not claim that an
   unsigned receipt-store writer changing all consistent fields is detectable.
3. **Staleness:** Stage 05 edit, card contract edit, branch revision/tree
   change, reviewed-path integration edit, verify owner/spec/target edit,
   deployed revision mismatch, squash/rebase.
4. **Execution:** success, non-zero, command-not-found, timeout, output-cap,
   process-tree cleanup, oracle mismatch, semantic/live pass followed by fail,
   SIGKILL attempt-marker recovery, writer/consumer concurrency, invalid
   invocation that preserves an older receipt.
5. **Lifecycle:** activation atomicity, state stale after risk/contract change,
   main-only activation, activation/stop race, inactive warnings with unchanged
   exits, integration-owned done, active check/done/ready, merged removal card
   mapping/block, unmerged abandon, `auto stop`.
6. **Portability/privacy:** Python absent, linked worktree shared state,
   SHA-256 repository when supported, reliable supervisor or fail-closed
   capability refusal, POSIX permissions, secret fixtures absent from receipt,
   project/global event sinks, DB, and dogfood report.

“Structurally tampered” means malformed or inconsistent with the exact subject.
A writer controlling the repository and receipt store can fabricate unsigned
labels/files; v0.28 does not claim hostile-host or actor-authentication
resistance.

### Stage 05 eval pair

Add:

```text
f05a  05-contract  flow/05-contract.md  PASS
f05b  05-contract  flow/05-contract.md  FLAG
```

Both fixtures must mechanically pass `scan_gate`. The hollow fixture is vague,
internally contradictory, or lacks executable interface/error ownership
despite checked boxes; its path/content must not leak the expected label or
eval sentinel. Extend `_eval_heading_pattern`, stage validation/help,
scorecard/filter tests, full-batch count, and injection/privacy guards.

CI proves fixture structure and mocked verdict math. A live N=3 semantic batch
is opt-in dogfood evidence and must never become a default CI dependency.

### Release coherence

Create `scripts/check-release-coherence.sh` as a deterministic offline owner.
It verifies:

- skill version equality across `SKILL.md`, plugin, portable manifest, bundled
  npm skill, root README status, and current quality-metrics entry;
- npm version equality across package/lock, npm README current status/help
  examples, and current npm changelog entry;
- bundled skill is freshly synchronized;
- every suite named by `tests/run_all.sh` exists;
- current operational prerelease surfaces use `next`, not `rc`;
- publish workflow routes prerelease semver to `next` and forbids `latest`;
- nightly checks `next` + `latest`;
- historical journals/changelog entries are outside the operational-tag check.

Operational inventory includes release preflight, publish/nightly workflows,
release process, root/npm READMEs, npm release checklist, npm security guide,
issue template, and `npm-wrapper/scripts/smoke.mjs`. Exclusions are explicit
historical sections/paths, never a repository-wide loose grep exemption.

`scripts/release-preflight.sh` calls the offline checker first. Its live registry
section reports `next` and `latest`; offline/network failures remain clearly
separate.

### Version and distribution decisions

- Skill product: `0.28.0`.
- npm installer/bundle: `0.5.0` (minor because shipped skill behavior changes;
  installer engine contract remains compatible).
- Stable publish: `npm@0.5.0` routes to `latest`.
- Any future prerelease: `0.5.x-next.N` routes to `next`.
- Do not resurrect or move `rc`; historical references remain history only.
- External tag/publish occurs only after operator authorization and green CI.
  Do not unpublish on rollback; move the appropriate dist-tag to a known-good
  version using the documented manual authorization path.

## File inventory

| Action | File(s) | Intended change | Rough size | Test impact |
|---|---|---|---:|---|
| Create | `/home/manhquy/Downloads/flow-skill/docs/migration-v028-attestations.md` | Legacy/manual/auto migration and rollback | 100-160 LOC | Docs contract |
| Create | `/home/manhquy/Downloads/flow-skill/tests/test_flow_attestation_acceptance.sh` | Public-CLI attack/lifecycle corpus | 380-560 LOC | Register in run_all |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/eval/manifest.tsv` + `fixtures/f05a`, `fixtures/f05b` | Stage 05 sound/hollow pair | 120-200 fixture LOC | Eval suite |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/runner/flow.sh` | `05` eval routing/help/filter | 15-35 LOC | Eval suite |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/SKILL.md`, `references/command-dispatch.md`, `references/gate-eval.md`, root `README.md`, `README_VN.md`, `docs/codebase-summary.md` | Keep all seven public `--stage` vocabulary surfaces coherent | 25-50 LOC | Contract + docs |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/test_flow_eval.sh` | Mechanical pair, batch count, mocked votes/privacy | 60-110 LOC | Focused |
| Create | `/home/manhquy/Downloads/flow-skill/scripts/check-release-coherence.sh` | Offline release/source-of-truth validator | 120-180 LOC | Dedicated suite |
| Create | `/home/manhquy/Downloads/flow-skill/tests/test_release_coherence.sh` | Green + deliberate drift fixture checks | 120-180 LOC | Register in run_all |
| Modify | `/home/manhquy/Downloads/flow-skill/scripts/release-preflight.sh` | Invoke offline check; `next/latest` live report | 30-60 LOC | Release |
| Modify | `/home/manhquy/Downloads/flow-skill/.github/workflows/ci.yml` | Relevant path filters + no-Python attestation smoke | 15-35 LOC | CI |
| Modify | `/home/manhquy/Downloads/flow-skill/.github/workflows/publish-npm-wrapper.yml` | `next/latest` prerelease routing/options | 15-30 LOC | Workflow review |
| Modify | `/home/manhquy/Downloads/flow-skill/.github/workflows/nightly-registry-health.yml` | Smoke `next/latest` | 10-20 LOC | Workflow review |
| Modify | `/home/manhquy/Downloads/flow-skill/docs/release-process.md`, `/home/manhquy/Downloads/flow-skill/npm-wrapper/RELEASE_CHECKLIST.md`, `npm-wrapper/SECURITY.md`, `npm-wrapper/scripts/smoke.mjs`, issue template | Remove operational `rc`; document selected `next` policy | 60-110 LOC | Coherence |
| Modify | `/home/manhquy/Downloads/flow-skill/skills/flow/SKILL.md`, `/home/manhquy/Downloads/flow-skill/.claude-plugin/plugin.json`, `/home/manhquy/Downloads/flow-skill/portable-manifest.json` | Skill `0.28.0` + command/docs surface | 30-60 LOC | Coherence |
| Modify | `/home/manhquy/Downloads/flow-skill/CHANGELOG.md`, root READMEs, architecture/summary/quality metrics | Public v0.28 behavior and limits | 100-180 LOC | Coherence |
| Modify | `/home/manhquy/Downloads/flow-skill/npm-wrapper/package.json`, lock, changelog, READMEs | npm `0.5.0`, ships skill `0.28.0` | 70-120 LOC | npm tests |
| Regenerate | `/home/manhquy/Downloads/flow-skill/npm-wrapper/skills/flow/`, `skills-manifest.json` | Exact synchronized bundle | Generated | npm sync tests |
| Create | `/home/manhquy/Downloads/flow-skill/dogfood/attested-execution-v028.md` | Redacted self-dogfood evidence | 60-100 LOC | Release review |
| Modify | `/home/manhquy/Downloads/flow-skill/tests/run_all.sh` | Register acceptance/coherence suites | <5 LOC | Full |

## Interface checklist

- [ ] No migration command silently classifies legacy risk.
- [ ] Unknown receipt schema never upgrades or passes.
- [ ] Acceptance tests use CLI boundaries for whole-path claims.
- [ ] Unsigned hostile-writer resistance is not asserted or tested.
- [ ] Stage 05 eval is a separate valid filter and appears in scorecards.
- [ ] Default CI makes zero billable semantic calls.
- [ ] Operational `rc` references are eliminated without rewriting history.
- [ ] Release-coherence test fails on each deliberately drifted surface.
- [ ] CI path filters include tests/scripts/version/release docs that own gates.
- [ ] npm sync runs before version/coherence checks and leaves no stale bundle.
- [ ] Dogfood report contains exact revisions/results but no raw secret/output.
- [ ] Publish/tag steps are distinguished from implementation-complete gates.

## Dependency map

```text
Phases 2-5 green
      |
      +--> legacy + attack acceptance corpus
      +--> Stage 05 semantic eval
      +--> real skill dogfood
      +--> release coherence
                 |
                 v
        3-OS CI + npm matrix
                 |
                 v
        v0.28.0 / npm 0.5.0 release
```

## Test scenario matrix

| Priority | Scenario | Expected |
|---|---|---|
| Critical | Legacy project activates auto without classification | Block every unknown card |
| Critical | Structurally edited/duplicate receipt attempts pass-last | Invalid; no transition |
| Critical | Valid pass then valid timed-out/non-zero attempt | Latest receipt red |
| Critical | Old pass + runner SIGKILL after new live spawn | Attempt marker blocks; dead-owner recovery records fail |
| Critical | Semantic/live caller substitutes `true` for committed owner | Refuse |
| Critical | Revision oracle reports another OID/target | No pass |
| Critical | Dirty/untracked reviewed subject | Mint/use refused |
| Critical | Security ack is wrong card/non-ancestor/same identity | Auto HALT |
| Critical | Active golden card sequence | Risk + Stage 05 + card semantic + live all pass |
| Critical | Stage 05 hollow fixture | Mechanical pass; mocked/live semantic expected FLAG |
| Critical | Operational workflow still routes prerelease to `rc` | Release coherence fails |
| High | Python removed from PATH | Risk/receipt/auto enforcement still works |
| High | Linked worktree removed after merged green path | Receipts survive in main state root |
| High | Stock platform lacks reliable supervisor | Deterministic auto/live refusal; no unbounded fallback |
| High | npm bundle not synced | Coherence/npm tests fail |
| High | README/quality/npm current version drift | Coherence fails |
| Medium | Historical `rc` journal/changelog text | Allowed; not treated as operational |

## Implementation steps

1. Write migration guide and acceptance matrix before changing release metadata.
2. Add the public-CLI acceptance suite and register it immediately.
3. Add `f05a/f05b`, extend eval’s closed stage map/help/filter, and update all
   full-batch/mechanical/privacy tests.
4. Run the deterministic corpus on Linux locally, including no-Python and
   linked-worktree cases.
5. Dogfood on an isolated flow-skill worktree:
   - classify a real scoped card;
   - prove auto activation fails before Stage 05 receipt;
   - commit exact semantic/live owner manifests and mint current Stage 05/card
     semantic receipts from them;
   - prove done fails before live verification;
   - run revision oracle plus install/CLI live verification against the
     integrated revision and explicit target;
   - run `card done` from the integration checkout, commit the status update,
     then remove the mapped merged worktree;
   - run `auto stop`;
   - write only redacted revision/result evidence to the dogfood report.
6. Create the offline release-coherence script and deliberate-drift tests; call
   it from release preflight.
7. Replace current operational `rc` paths with the selected `next` policy in
   workflow, nightly, preflight, runbook, READMEs, checklist, security guide,
   smoke script, and issue template; retain historical records.
8. Update CI path filters and no-Python attestation smoke.
9. Bump skill mirrors to `0.28.0`; update public docs/CHANGELOG.
10. Bump npm package/lock to `0.5.0`, run `npm run sync`, update npm docs and
    changelog, and verify bundle exactness.
11. Run:
    - focused attestation/risk/auto/eval/release suites;
    - `python -m py_compile skills/flow/harness/*.py`;
    - `bash scripts/check-release-coherence.sh`;
    - `bash scripts/release-preflight.sh`;
    - `bash tests/run_all.sh`;
    - `npm test` and `npm pack --dry-run --ignore-scripts --json`.
12. Require green Ubuntu/macOS/Windows Bash CI, no-Python job, and npm Node
    22/24 matrix before operator-authorized tags/publish.
13. After publish, verify provenance, `latest`, exact-version install, packaged
    skill `0.28.0`, and nightly target resolution. Record live evidence without
    secrets.

## Todo

- [ ] Legacy migration documented and executable
- [ ] Acceptance corpus green
- [ ] Stage 05 eval pair green
- [ ] Real skill dogfood complete
- [ ] Release coherence enforced
- [ ] `next` prerelease policy coherent
- [ ] Skill/npm bundle versions synchronized
- [ ] Full local + 3-OS + npm matrices green

## Success criteria

- [ ] All material missing/stale/tampered/dirty/execution/security cases fail at
  the documented boundary.
- [ ] Golden active-auto skill path completes end-to-end with no Python gate
  dependency.
- [ ] Stage 05 semantic fixtures are deterministic and default CI remains
  non-billable.
- [ ] Release coherence detects the current known npm/docs drift class and
  prerelease-tag drift.
- [ ] Skill `0.28.0` and npm `0.5.0` bundle/docs/tests agree.
- [ ] Ubuntu, macOS, Windows, no-Python, and Node 22/24 gates are green before
  publication.
- [ ] Live publish verification is recorded separately from local/CI success.

## Risk assessment

| Risk | Mitigation |
|---|---|
| Migration adds ceremony to old projects | Auto-only hard enforcement; explicit field/receipt repair guide |
| Eval fixture overfits prompt | Mechanically clean pair, nonce guards, mocked structure plus opt-in live N=3 |
| Release checker becomes a brittle global grep | Parse named current surfaces; explicit historical exclusions and tamper fixtures |
| Dogfood edits shared history | Isolated worktree/card and scoped report; no run-state committed |
| Publishing failure after code is green | Separate local/CI/release evidence; immutable version, no unpublish rollback |

## Security considerations

- Redact secrets before asserting their absence; never print matching secret
  fixtures into CI logs.
- Treat workflow/tag changes as supply-chain-sensitive and review their exact
  diff.
- Do not claim unsigned receipts authenticate actor/model identity.
- Provenance verification is post-publish evidence, not a substitute for local
  package-content checks.

## Rollback

- Runtime: `flow auto stop`; remove/re-mint receipts as needed.
- Code: revert v0.28 enforcement; risk fields remain harmless additive text.
- Distribution: do not unpublish. Restore `latest`/`next` to a known-good
  version through the documented authorized manual path.
- Docs/eval: revert with the code whose contract they describe; never leave
  release metadata claiming behavior that was rolled back.

## Next steps

After one release of telemetry and dogfood, start v0.29 Context Pack & Model
Economics using receipt fingerprints as stable context/cache identities.

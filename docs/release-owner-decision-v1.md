# Accepted v1 outcome contract

Owner decision at12:39 Bangkok23/10/2026: implement breaking changes already described by docs/migration-v1.md before declaring1.0. This supersedes the alternative proposal to stabilize current0.x behavior unchanged.

## Outcome

Skill1.0 makes Python required, graph ordering default and FLOW_HARNESS_DISABLE a clear startup refusal. Preserve current gate verdict authority in flow.sh, skip governance/securityHALT/05-contract refusal, card/stage formats, zero third-party dependencies and ADR0001 host-invocation/process-token invariant. A graph executor computes ordering; it is not a resident runtime or agentloop.

## Acceptance

- Resolve measured Python floor from source/preflight; test python3/python on supported OS. Missing/below-floor Python yields actionable refusal for applicable product operations; help/install/doctor behavior is deliberately specified.
- Graph ordering is default; topology/schema migration/fork behavior verified. Paused run/topology mismatch refuses safely and force-retopology stays explicit.
- FLOW_HARNESS_DISABLE refuses with migration pointer; no silent mechanical fallback or split-brain write/ordering.
- Preserve gates, skip governance and formats. Do not modify _eval_engine_run or _run_with_timeout without a distinct operator decision.
- Correct migration install/upgrade/rollback commands. Back up durable databases before migration, prove state/custom-file preservation and supported downgrade route.
- Public CLI/JSON/config/state contracts, supported hosts/platforms, experimental boundaries and breaking/deprecation policy match source; skill and npm installer versions remain separate.
- Independent review, scoped/affected cross-OS CI, exact-SHA release coherence/rehearsal/install smoke and canonical release policy. No stable1.0 label before acceptance.

## Execution and boundaries

OMP parent owns product delivery/integration; max2 disjoint builder lanes, QA reserved in6worker cap. Reuse accepted old plan evidence but refresh exactmaster and implementation gaps. Every checkout requires lease/cleanup. Controller owns local host helper/protocol fixes only. Preserve root WIP, website/recovery holds. No Flow daemon/scheduler/tool wrapper, global model/account changes, new thresholds, paid live Claude eval or claims of live quality from replay.

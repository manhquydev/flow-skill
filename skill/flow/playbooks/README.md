# Playbooks — paid-for stack knowledge

One playbook = one stack/integration, written AFTER it worked in a real project
(manual-first: the playbook wraps a successful run, never speculation). They exist so
the next card touching that stack starts from the gotchas instead of rediscovering them.

## Rules

1. **Read before build.** Any card whose scope touches a stack with a playbook here —
   the builder reads the playbook FIRST. In auto runs, the planner includes the relevant
   playbook in the subagent's brief (alongside the card + contract + CLAUDE.md).
2. **Harvest after build.** When a card pays for a non-obvious lesson (a gotcha, a quirk,
   a smoke test that saved the architecture), capture it: update the existing playbook or
   add a new one. The card's review isn't done until the lesson is filed.
3. **Shape:** name `<stack>-<thing>.md`; start with "When to use this"; put the critical
   gotcha at the TOP (the thing that breaks people first); include runnable smoke tests;
   end with provenance (which project, when).
4. **Smoke test before architecture.** If a playbook ships smoke tests, run them BEFORE
   committing to a design that depends on that stack behaving (see the Qwen tool-calling
   gotcha — caught live, before the agent framework was built on sand).

## Index

| Playbook | When to use |
|---|---|
| [cloudflare-ai-gateway-qwen.md](cloudflare-ai-gateway-qwen.md) | LLM feature in a Python/FastAPI backend via CF AI Gateway → Workers AI Qwen. CRITICAL: Qwen returns no real tool_calls — single structured-JSON calls, not agent frameworks. |
| [docker-deploy-stale-cache.md](docker-deploy-stale-cache.md) | Deployed route 404s though merged+deployed: layer cache served a stale image. Check live `/openapi.json` BEFORE debugging code; fix Dockerfile layer order. |

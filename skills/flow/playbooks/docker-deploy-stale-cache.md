# Playbook: Docker layer cache serving stale backend builds on deploy

## When to use this
Any Dockerized backend with auto-deploy where a newly added route/endpoint returns 404
on the deployed URL even though the code is merged and the deploy reported success.

## ⚠️ THE GOTCHA
The deploy "succeeds" but runs a STALE image: the layer cache reuses the old source
layer, so your new endpoint never registers. Symptom: merged + deployed + green, yet the
live `/docs` (or a curl) shows the route MISSING. Each occurrence reads like a code bug
and costs a false debugging detour.

**Diagnosis in one step:** check the live `/openapi.json` (or `/docs`) for the new route
BEFORE debugging code. Route absent from the spec = stale image, not your code.
(This is the swagger-lands-with-the-API rule earning its keep.)

## Fixes (pick one, in order of preference)
1. **Structure the Dockerfile so source COPY busts the cache**: dependencies layer first
   (`COPY requirements.txt` + install), then `COPY . .` for source — source changes then
   always rebuild the final layer while deps stay cached (fast AND fresh).
2. **Dev phase: bind-mount the source** into the container instead of baking it, so
   deploys don't depend on image rebuilds at all.
3. **Last resort: force `--no-cache`** on the rebuild (slow; treats the symptom).

## Smoke test
After any deploy that adds a route:
```bash
curl -s https://<live-url>/openapi.json | grep '<new-route-path>' || echo "STALE IMAGE"
```

---
*Provenance: ab-tickets, 2026-06 — cost ~4 false detours before the pattern was named.*

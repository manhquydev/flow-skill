# Code Review: hollow-done mechanical floor (phases 1–3)

**Plan:** `plans/260811-1120-flow-hollow-done-trust-eval`  
**Reviewer:** code-reviewer (production-readiness)  
**Date:** 2026-08-11  
**Scope:** uncommitted hollow-done trust changes (mechanical floor + ready/graph re-validate + corpus/fixtures)  
**Side effects:** **yes** (stricter `check`/`card done`/`ready`/graph deps-met; project-type lock; INT/TERM trap on `card done`)

## Score: **6.5 / 10**

Ship-bar intent is largely implemented and honesty docs are in place, but **D5 graph parity is untested**, denylist is forgeable via `*.example.com` subdomains, dual bash/Python scorers can drift, and project-type lock is stricter than the plan (locks default `web`). Not a rubber-stamp green for merge until High items are fixed or explicitly accepted.

---

## Scope

| Area | Files (primary) |
|------|-----------------|
| Runner | `skills/flow/runner/flow.sh` (helpers ~1238–1333, `cmd_card_done`, `cmd_check`, `cmd_ready`, `cmd_project_type`) |
| Graph | `skills/flow/harness/graph_executor.py` (`_evidence_*`, `compile_cards` deps-met) |
| Tests | `tests/test_flow_done_evidence.sh`, `test_flow_auto_done_path.sh`, corpus rewrites, `test_flow_eval.sh`, `run_all.sh` |
| Fixtures | `skills/flow/eval/fixtures/{fcda,fcdb,fcdc}`, `manifest.tsv` |
| Docs | `references/ground-truth-gates.md`, `auto-run.md`, `gate-eval.md` |
| Plan artifacts | `done-path-matrix.md`, `test-corpus-inventory.md` |

**LOC:** ~net +400–600 across runner/graph/tests/docs (estimate; uncommitted set)  
**Focus:** recent hollow-done mechanical floor  
**Scout findings:** ready/graph hand-edit bypass closed in code; residual decoy class remains; dual-rule drift risk; denylist host-tree hole; no Python evidence unit vectors

---

## Acceptance checklist (a–e)

| # | Criterion | Verdict |
|---|-----------|---------|
| (a) | multi-signal ≥2; process-only FAIL; ready re-validate; graph deps-met parity; fcdb mech FAIL; fcdc decoy FLAG corpus; corpus rewrite; scorecard policy; no AgentKit; residual honesty | **Mostly met** — graph parity **code yes / test no**; denylist weaker than residual narrative implies |
| (b) | No regression card lifecycle / harness trust / graph | **Likely OK** if suite green; lifecycle verbs preserved; graph ready semantics stricter (intentional) |
| (c) | Public contracts: check / card done / ready same verbs; new fail messages OK | **Met** |
| (d) | bash 3.2 / no GNU-only new deps | **Mostly met** — style matches existing `grep -oE`/`sed -E`; one case-pattern bug for `[::1]` |
| (e) | Tests green expectation | **Not executed in this review** — structure looks runnable; **must** `bash tests/run_all.sh` before ship. Plan.md already marks success `[x]` including run_all — **premature until verified** |

---

## Overall Assessment

This is a coherent atomic 02+03 delivery: shared score floor, ready re-validate, graph mirror, fcdb contract flip, fcdc residual corpus, focused + corpus tests, and residual-honesty docs. The main production risks are **trust-floor holes** (denylist / fence-C looseness), **untested graph path**, and **dual scorers without shared vectors** — not public API breakage.

---

## Critical Issues

*None that are definite ship-blockers on their own.*  
Treat the **High** section as merge-blocking until fixed or explicitly waived with residual doc updates.

---

## High Priority

### H1 — Graph deps-met hollow path has no test (D5 ship-bar hole)
- **File:** `tests/test_flow_graph_parallel_cards.sh` (section D ~79–85); `skills/flow/harness/graph_executor.py:988`
- **Issue:** Section D only reverts `status: todo` and asserts deps missing. It never asserts `status: done` + process-only Evidence → dependent **not** in `deps_met`/`ready`. Plan D5 and RT2 exist specifically for hand-edit hollow under `FLOW_GRAPH_EXECUTOR=1`. Bash ready is covered; Python path is not.
- **Impact:** Graph hollow bypass can regress silently while suite stays green.
- **Fix:** Add assertion, e.g.:

```bash
# after existing D block
card C-001 done none "src/a.ts" 'PR approved; CI green; release notes shipped.'
R3="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph cards)"
printf '%s' "$R3" | grep -q '"C-003"' && ! printf '%s' "$R3" | grep -q '"ready": \["C-002", "C-003"\]'
# stronger: missing includes C-001 while status remains done
has "$R3" '"missing": \["C-001"\]' "hollow done dep blocks graph ready"
```

### H2 — `example.com` denylist misses subdomains (forge kit)
- **File:** `skills/flow/runner/flow.sh:1267–1270`; `skills/flow/harness/graph_executor.py:823–838`
- **Issue:** Exact `example.com` / `*.example` suffix only. Hosts like `app.example.com`, `staging.example.org` score **category A**. Combined with any B/C token (`ok`, `curl`, `PASS`) → mechanical PASS. e2e already uses `https://app.example.com/healthz` as “real” evidence.
- **Impact:** Weakens stated denylist residual story; easy agent forge.
- **Fix (bash + python parity):**

```bash
# flow.sh _evidence_url_host_ok — after exact matches:
case "$h" in
  *.example.com|*.example.org) return 1 ;;
esac
# or: strip left labels until registrable denylist match
```

```python
# graph_executor.py _url_host_ok
for base in ("example.com", "example.org"):
    if h == base or h.endswith("." + base):
        return False
```

### H3 — Dual bash/Python scorers, no shared vectors (plan preferred single source)
- **File:** `flow.sh:1278–1320` vs `graph_executor.py:841–876`
- **Issue:** Plan phase-02: prefer bash helper subprocess or shared data + **same test vectors**. Implementation duplicates rules; only bash has `test_flow_done_evidence.sh`. Already diverged on IPv6 denylist handling (see M3).
- **Impact:** `ready` vs `graph cards` disagree under edge inputs → parallel auto dispatch inconsistency.
- **Fix options:**
  1. Prefer: Python shells out to `flow.sh` internal probe (or tiny shared `evidence_score` script), **or**
  2. Add `tests/test_flow_graph_done_evidence.sh` that feeds identical evidence strings through bash `_evidence_signal_score` (via check/ready) **and** `graph cards` / a small Python one-liner importing `graph_executor`.

### H4 — project-type lock over-broad vs plan D6
- **File:** `skills/flow/runner/flow.sh:1461–1471`
- **Issue:** Plan: lock when **`PROJECT_TYPE` file exists** and arg differs. Code locks whenever `get_project_type` ≠ arg after planning — and default is `web` with **no file**. First intentional `project-type cli` after planning always needs `FLOW_FORCE=1`.
- **Impact:** Workflow break for “set type once after planning”; surprises operators; RT5 mitigation over-applied.
- **Fix:**

```bash
if planning_complete 2>/dev/null && [ -f "$PROJECT_TYPE_FILE" ]; then
  cur="$(get_project_type)"
  if [ "$cur" != "$arg" ] && [ "${FLOW_FORCE:-0}" != "1" ]; then
    ...
  fi
fi
```

---

## Medium Priority

### M1 — Category C fence grants signal without PASS/ok tokens
- **File:** `flow.sh:1295–1299`; `graph_executor.py:855–865`
- **Issue:** Plan table v2: fenced block ≥2 lines **with** `ok`/`PASS`/`passed`. Code awards C for any ≥2 non-empty fenced lines.
- **Impact:** Residual decoy class larger than docs (`URL + arbitrary fence` not only `URL + PASS fence`).
- **Fix:** Only score C on fence if body matches token ERE, or drop fence branch and require tokens.

### M2 — ready blocked message lies when dep is done-but-hollow
- **File:** `flow.sh:1607–1616`
- **Issue:** Prints note about evidence fail, then `blocked … (deps not all done: …)` even when dep **is** done.
- **Fix:** `blocked $id (deps unmet or evidence floor: …)` / branch messages.

### M3 — bash `[::1]` case pattern is a character class, not IPv6 host
- **File:** `flow.sh:1269`
- **Issue:** `case` pattern `[::1]` matches one character `:` or `1`, not host `[::1]`. Python denylist includes `"[::1]"` correctly → **parity bug**.
- **Fix:** `\[::1\]` in case arm (and add shared vector).

### M4 — gate-eval cost/corpus counts still say “6 fixtures”
- **File:** `skills/flow/references/gate-eval.md:28–29,64–65,149`
- **Issue:** Manifest now has **7** rows (fcdc added). Tests correctly expect 7 (`test_flow_eval.sh:243,336`). Doc cost ceiling and “six” residual text stale.
- **Fix:** Update to 7 fixtures; cost 7×N=3 → 21 + probe; reword limitations.

### M5 — fcdb remains full LLM eval fixture with expected FLAG
- **File:** `skills/flow/eval/manifest.tsv`; `gate-eval.md:32–33`
- **Issue:** fcdb is mechanical FAIL now; production semantic layer never sees it. Full `eval` still bills N calls on fcdb for historical FLAG. Plan: CI process-only rate; LLM offline on **fcdc**.
- **Fix:** Drop fcdb from default manifest **or** document “inspection-only / --fixture fcdb”; keep fcdc as FLAG corpus.

### M6 — Category F `skills/flow` is trivial second signal
- **File:** `flow.sh:1315–1316`; `graph_executor.py:874–875`
- **Issue:** Any Evidence mentioning `skills/flow` scores F. + weak B/C → PASS.
- **Impact:** Skill-type forge path; residual honesty OK if documented, but not called out.
- **Fix:** Require path-existence under home, or pair F with install proof pattern only when type=skill (still always ≥2).

### M7 — `cmd_check` duplicates floor logic vs `_card_done_evidence_ok`
- **File:** `flow.sh:1387–1401` vs `1324–1333`
- **Issue:** Shared score helper, but check reimplements empty/score messaging; ready uses helper. Fine today; future drift risk.
- **Fix:** `if ! _card_done_evidence_ok "$file"; then … detailed score message …`.

### M8 — plan success criteria pre-checked including run_all green
- **File:** `plans/260811-1120-flow-hollow-done-trust-eval/plan.md:98–107`
- **Issue:** All ship-bar boxes `[x]` including full suite / 3-OS CI without evidence in this review.
- **Fix:** Re-open until `bash tests/run_all.sh` (and CI) actually green post-fixes.

### M9 — npm-wrapper skill tree not updated
- **File:** `npm-wrapper/skills/flow/**` (no hollow-done helpers)
- **Issue:** Expected per release process (`npm run sync` at publish). Not a product-root bug; **registry users lag** until npm release.
- **Fix:** Note in ship checklist; sync before npm tag.

---

## Low Priority / Suggestions

### L1 — Fragile default in graph parallel `card()` helper
- **File:** `tests/test_flow_graph_parallel_cards.sh:29`
- **Issue:** `"${5:-$ curl https://x/healthz -> 200 PASS healthcheck}"` relies on bare `$` not expanding. Works by accident.
- **Fix:** `"${5:-'$ curl https://x/healthz -> 200 PASS healthcheck'}"` or assign `GPASS=...` first.

### L2 — Error text says “for type 'web'” while floor is type-agnostic
- **File:** `flow.sh:1397`
- **Issue:** Score ≥2 for all types; type only affects hint. Message implies type-specific threshold.
- **Fix:** Drop “for type …” from score line; keep `done_def_for_type` hint only.

### L3 — No INT trap smoke test
- **File:** `cmd_card_done` trap `flow.sh:1174–1176`
- **Issue:** Plan wanted smoke if feasible; none present (hard to test portably). Acceptable residual.

### L4 — Empty `skills/flow/eval/fixtures/fcdc/flow/` directory
- Harmless; remove if not needed.

---

## Edge Cases Found by Scout

1. Hand-edit `status:done` + process prose → `ready` blocks dependent (**covered** by tests).
2. Same under graph executor → **implemented, untested** (H1).
3. Denylist URL alone → FAIL (**covered**); subdomain of example.com → **PASS hole** (H2).
4. Single allowed URL score 1 → FAIL (**covered**).
5. Decy URL + PASS fence → mech PASS / fcdc (**intentional residual**).
6. Fence without PASS + URL → may PASS via loose C (M1).
7. Type flip after planning without FORCE → FAIL (**covered** in done_evidence; over-broad H4).
8. INT during `card done` after successful check before trap clear → possible status flip back to todo (narrow race; trap design limit).
9. `card_markdown_gate` still durable floor only — documented (D10).
10. Dual scorer IPv6 / denylist divergence (M3/H3).

---

## Positive Observations (risk calibration only)

- Atomic fcdb FAIL + fcdc residual + corpus rewrite matches plan D3 (avoids mid-slice red eval contract).
- Residual honesty in `ground-truth-gates.md` / `auto-run.md` / runner comments correctly refuses “auto proven safe.”
- Public verbs unchanged; fail messages additive.
- No AgentKit/new runtime deps.
- Focused suites `test_flow_done_evidence.sh` + `test_flow_auto_done_path.sh` wired into `run_all.sh`.

---

## Recommended Actions (priority order)

1. **H1** — Add graph hollow-done deps-met test; run it green.
2. **H2** — Deny `*.example.com` / `*.example.org` in bash **and** Python.
3. **H3** — Shared vectors for bash↔Python score (minimum: same fixtures via graph test).
4. **H4** — Lock only when `PROJECT_TYPE` file exists (plan D6).
5. **M1** — Tighten fence C to require PASS/ok tokens (or document expanded residual).
6. **M3** — Fix `[::1]` case pattern; align Python.
7. **M4/M5** — Fix gate-eval counts; clarify fcdb eval role.
8. **Verify** `bash tests/run_all.sh` (do not trust plan `[x]`).
9. On npm ship: `cd npm-wrapper && npm run sync`.

### Concrete patch sketches (do not apply here)

**Denylist (bash):**
```bash
case "$h" in
  example.com|www.example.com|example.org|www.example.org) return 1 ;;
  *.example.com|*.example.org) return 1 ;;
  localhost|127.0.0.1|0.0.0.0|\[::1\]) return 1 ;;
  *.invalid|*.test|*.example|*.localhost) return 1 ;;
  invalid|test|example) return 1 ;;
esac
```

**Type lock (bash):**
```bash
if planning_complete 2>/dev/null && [ -f "$PROJECT_TYPE_FILE" ]; then
  cur="$(cat "$PROJECT_TYPE_FILE" | tr -d '\r' | awk 'NF{print; exit}')"
  if [ -n "$cur" ] && [ "$cur" != "$arg" ] && [ "${FLOW_FORCE:-0}" != "1" ]; then
    echo "FAIL: project type is locked to '$cur' ..."
    return 1
  fi
fi
```

**Fence C (bash) — require tokens:**
```bash
if printf '%s' "$ev_lc" | grep -qE '([^a-z]|^)(pass|passed|fail|failed|ok)([^a-z]|$)'; then
  score=$((score + 1))
elif printf '%s' "$ev" | awk '
  /^```/ {fence=!fence; next}
  fence && NF {body=body $0 "\n"}
  END {
    n=split(body,a,"\n"); c=0
    for(i=1;i<=n;i++) if(a[i] ~ /[^[:space:]]/) c++
    if(c>=2 && body ~ /(pass|passed|fail|failed|ok)/) print "yes"
  }' | grep -q yes; then
  score=$((score + 1))
fi
```

---

## Metrics

| Metric | Value |
|--------|-------|
| Type coverage | N/A (bash primary; Python untyped helpers) |
| Test coverage | Focused done-evidence + auto-path present; **graph hollow gap** |
| Linting issues | Not run |
| Suite execution | **Not run in this review** — required before ship |

---

## Unresolved Questions

1. Was over-broad type lock intentional product choice beyond D6 text?
2. Should fcdb leave the default billable eval manifest?
3. Confirm 3-OS CI after High fixes (plan claims green already).

---

## Plan task status (recommendation only — do not mutate plan)

| Phase | Appears | Recommendation |
|-------|---------|----------------|
| 1 inventory/matrix | Present | complete |
| 2 mechanical + ready + trap + type lock | Implemented | complete after H4 decision |
| 3 fixtures/corpus/scorecard | Implemented | complete after H1–H3 + run_all |
| 4 strategist/hooks | Out of bar | leave backlog |

**Ship recommendation:** **hold merge** until H1–H3 fixed (H4 fixed or explicitly waived). Then full `run_all` + residual doc pass.

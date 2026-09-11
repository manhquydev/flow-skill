# Coding law — buildflow projects

LAW for product code on every card. Read before implementing. If a change
conflicts, this rule wins — or amend this file with a dated note. Portable
only: no stack, no runtime.

1. **Explicit resolve.** MUST run a named `resolve` (or equivalent) before
   the handler. NEVER hide `??` / `||` defaults inside the handler.
   - Good: `spec = resolve(req); handle(spec)`
   - Bad: `handle({ port: req.port ?? 8080 })`

2. **Fail loud.** MUST throw a named error at the first resolvable point.
   NEVER silently default a missing required referent.
   - Good: `raise MissingConfig("DATABASE_URL")`
   - Bad: `url = env.DATABASE_URL or "postgres://localhost/app"`

3. **Tests name behavior.** MUST title tests by the observable fact they pin.
   NEVER "works correctly", "handles edge case", or "unit tests pass".
   - Good: `GET /healthz returns 200 {ok:true} when the process is up`
   - Bad: `health check works correctly`

4. **No empty catch.** NEVER swallow with an empty `catch` / `except`. If
   the body is empty, MUST name what it swallows and why nothing else can
   reach it; keep the try to one statement.
   - Good: `except AbortError:  # timeout cancelled the fetch; nothing else lands here`
   - Bad: `catch (_) {}`

5. **Cite the seam.** MUST cite `flow/05-contract.md`, an ADR path, or card
   id `C-NNN` for a product decision. NEVER "as discussed" / "as agreed".
   - Good: `// C-012 / 05-contract GET /healthz — empty: none`
   - Bad: `// as discussed, skip the empty list`

6. **Library over hand-roll.** MUST prefer a maintained library named in an
   ADR when the swap deletes owned parser code and its tests. NEVER keep a
   hand-rolled parser beside that library.
   - Good: ADR names `zod`; delete `parseJsonLoose` and its tests
   - Bad: keep `parseJsonLoose()` "just in case" after adopting zod

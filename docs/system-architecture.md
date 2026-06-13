# /flow — system architecture

`/flow` is a gated build harness: idea -> deployed URL through honest gates. It is built as
three cooperating layers plus on-disk artifacts, so a fast deterministic engine handles the
cheatable mechanics while the model handles judgment, and durable records survive sessions.

## Layers

```
+---------------------------------------------------------------+
|  Semantic layer  -  SKILL.md + references/  (Claude)          |
|  judgment: hollow content, grade-laundering, adversarial      |
|  review, agent orchestration, mode work, /flow auto tiers     |
+---------------------------------------------------------------+
              | calls (exit code = ground truth)
              v
+---------------------------------------------------------------+
|  Mechanical layer  -  runner/flow.sh  (bash, exit 0/1)        |
|  stage/card lifecycle, gate checks ([FILL]/box/evidence),     |
|  debt ledger, design check, harness passthrough               |
+---------------------------------------------------------------+
              | reads/writes (best-effort, graceful degrade)
              v
+---------------------------------------------------------------+
|  Durable layer  -  harness/flow_harness.py  (Python+sqlite3)  |
|  intake/risk-lane, story+proof, trace+tier, decision, backlog |
|  (Rust harness-cli power-path via FLOW_HARNESS_BACKEND=rust)  |
+---------------------------------------------------------------+

On-disk artifacts (in the project being built):
  flow/00-idea.md .. 05-contract.md   planning, gated
  cards/C-NNN.md                      shipping units
  MODE, RETRO.md, DEBT.md, AUTO-LOG.md, DESIGN.md
  .flow/harness.db                    durable records
```

## Why this shape
- **Two-layer gate (mechanical + semantic).** A script can't tell a real competitor quote
  from a fabricated one, but it can catch an unchecked box or empty evidence deterministically.
  Splitting them means the cheatable part is ground-truth-enforced and the judgment part is
  the model's, and a gate passes only when both agree. (This is the original buildflow design.)
- **Durable layer as external memory.** Story/trace/decision/backlog persist in SQLite so
  progress and friction survive across sessions and context windows — the antidote to context rot.
- **Agents are pluggable, gates are fixed.** Stages delegate to ck:/bmad agents when present,
  fall back to built-in; the gate is identical on every path, so a missing agent never lowers
  a gate.

## Control flow (a build)
1. `/flow next` walks stages 00->05; each gate = mechanical (flow.sh) + semantic (gate-rules.md).
2. After stage 05 passes, `/flow card` creates cards; each card is one scoped build session.
3. Cards build to the contract (the seam), are reviewed adversarially, verified on the LIVE
   URL (done = world-state, not "tests pass"), then marked done. `/flow auto` runs this loop
   autonomously with Tier-A/B/C and hard stops.
4. Every transition writes durable records; deliberate skips open a `DEBT.md` line.

## Components
| Path | Responsibility |
|---|---|
| `skills/flow/SKILL.md` | semantic-layer entry: dispatch + gatekeeper + orchestration |
| `skills/flow/runner/flow.sh` | mechanical engine: lifecycle, gates, debt, design, harness passthrough |
| `skills/flow/harness/` | durable layer (Python CLI + sqlite + Rust toggle) |
| `skills/flow/_templates/` | the 7 gated artifacts (verbatim buildflow) |
| `skills/flow/law/` | CLAUDE.md (build-session law), DESIGN.md (UI law), RETRO.md |
| `skills/flow/references/` | semantic playbooks (gates, agents, loop, design, auto) |
| `skills/flow/playbooks/` | paid-for stack knowledge (read before, harvest after) |
| `tests/` | 46 checks across runner / harness / scenarios |
| `install.sh` / `install.ps1` | install to ~/.claude or a project |

# Build journal — /flow skill v1 (2026-06-13)

One session, idea → installed skill. Built the missing buildflow `/flow` engine and layered
harness + agent orchestration on top.

## What was built (6 phases)
1. **Engine** — two-layer gate: `flow.sh` (deterministic, exit 0/1) + `SKILL.md` (semantic
   gatekeeper). Templates/laws copied verbatim from buildflow.
2. **Durable layer** — `flow_harness.py` (Python+sqlite3): intake/risk-lane/story/trace-tier/
   decision/backlog, ported from repository-harness; Rust power-path toggle; wired into flow.sh.
3. **Agent integration** — stage→agent map (ck: primary, bmad alt, built-in fallback),
   `mode work`, `/flow auto` (Tier-A/B/C).
4. **Loop/harness 2026** — principles, ground-truth gates, adversarial 3-layer review,
   `DEBT.md` ledger (`flow.sh debt`).
5. **DESIGN law + playbooks** — `flow.sh design` mechanical UI check, design checklist,
   7 UI patterns + T-C-R, 3 stack playbooks.
6. **Packaging** — install.sh/ps1, manifest, 46-test suite, docs.

## Decisions & rationale
- **Two-layer gate** (not skill-only): a script can't judge fabricated research, but it CAN
  catch unchecked boxes / empty evidence deterministically — ground-truth where it's cheap,
  judgment where it's needed. Faithful to the original buildflow design.
- **Python durable layer default** (Rust optional): Python+stdlib sqlite3 needs no install
  and is on the box; the Rust harness-cli isn't pre-built (needs cargo), so it's a power-path.
- **Detect-and-use agents**: portable everywhere, rich where ck:/bmad exist.

## What the reviews caught (and we fixed)
- **gap-bypass** (Phase 1): `current_stage_idx` returned highest-existing, so a stray future
  stage file could fake "PLANNING COMPLETE". Fixed to contiguous-from-00 — exactly the
  dishonest-gate-pass the harness exists to prevent.
- **migration atomicity** (Phase 2): `executescript` auto-commit could half-apply a migration
  and break re-run. Switched to per-statement transactions (PRAGMA outside), idempotent.
- **Windows specifics**: POSIX→Windows db path translation; `LC_ALL=C.UTF-8` for emoji grep
  (Git Bash defaults to C and `grep -P` rejects the ranges); `.gitattributes` LF on scripts;
  PS 5.1 fallback for `??`.

## Verification
46/46 tests (`bash tests/run_all.sh`), 4 code-review passes (general + python), installed
to `~/.claude/skills/flow` and run from the installed location.

## Honest gaps / next
- `/flow` hasn't yet driven a REAL end-to-end build (idea→deployed URL) — the engine and
  gates are tested, but a live run on a real idea is the true proof (buildflow's own creed:
  "done = proof in the world"). That's the natural next checkpoint.
- Semantic gate quality (catching fabricated research, grade-laundering) is enforced by the
  Claude layer per `gate-rules.md`; it's documented and exercised by design, not unit-tested
  (it's judgment, not mechanics).

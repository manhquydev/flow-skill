## Stage 05 — Contract (the seam)
Mechanical: every PRD feature -> >=1 interface, every interface has input+output shapes,
access/effects column filled, no FILL.
**The "interface" is the project type's seam** (`/flow project-type`): web=endpoint,
cli=command+flags+output/exit, library=public function+args+return, skill=command/file.
**Challenge — this is where producer/consumer drift is born (every type):**
- Shared OD/authority: `gate-shared.md`.
- Does every PRD feature map to at least one interface, and vice versa?
- Does every interface have BOTH input and output shapes, with field/flag names that will not
  drift (the #1 AI-build failure: backend ships `player_email`, UI assumed `email`, both green;
  the cli equivalent: `--out` vs `--output`)?
- Is the access/effects column real for every interface (web: public/token/admin · non-web:
  writes/side-effects or "none")? Do NOT let a web product blank the access column.
- Read each write interface as a reviewer of English, not of code: if the failure shape is missing or Access/effects is a vibe word (secure/authenticated/restricted), the seam is not written yet.
- One-way rule: this file is planning source of truth. For web the served spec
  (`/openapi.json`) is the runtime artifact of the SAME contract (amend file -> code -> spec).
  For non-web there is no served spec — the no-drift check is the per-type done-evidence.
- **Self-consistency pass (the contract is ground truth every downstream card trusts).** Before
  passing this gate, read the contract AGAINST any doc it names as its own source of truth and
  re-state each shared rule in your own words — a contradiction here ships as "passed" and every
  card inherits it. (This gate once passed an internally-inconsistent seam that only a later
  cross-model review caught — catch that class HERE, at its source, where it is cheapest.) When the
  **codex tier is USABLE**, an OPTIONAL opt-in **cross-model** check of the contract is the
  highest-value single Codex call in a run — a different engine breaks the same-model blind spot at
  the one artifact whose drift is most expensive downstream.
- **Offer the native edge-case ritual** (`native-rituals.md` §2 — the guaranteed
  baseline) to harden the seam: each case becomes an acceptance criterion + a per-type
  no-drift check, so the contract is exhaustive before any card trusts it. Complements
  `/flow consistency` (it *generates* cases; consistency checks *coherence*). INFORMS
  the gate; never auto-passes it.
- **If `ck-scenario` is installed**, it is a richer 12-dimension alternative to the
  native ritual (same INFORMS-only rule, opt-in-with-prompt — see
  `claudekit-skills.md`).

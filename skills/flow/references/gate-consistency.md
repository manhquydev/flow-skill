## Cross-artifact consistency (`/flow consistency`)
Run after the Contract gate and before building cards (advisory; never blocks the build path).
The runner does the **precise, ID-based** passes mechanically: every PRD `FRn` is claimed by a
card (`implements:`) and served by an interface, the success metric carries a number, no leftover
placeholders. **You do the passes that need judgment, not string-matching:**
- **Hollow coverage:** an `FRn` is "covered" by a card whose scope does not actually deliver it
  (the id is referenced but the work isn't there). Mechanical coverage can be gamed by pasting an
  id; read the card scope against the feature.
- **Conflicting requirements:** two artifacts state incompatible things (PRD says no-login, ADR
  decides OAuth; scope cut a feature the PRD still lists). The runner won't catch a contradiction
  expressed in different words — you must.
- **Cut-list contradiction:** a feature on the stage-02 cut list reappears (by name, not id) as a
  v1 PRD feature or a card. Scope drift in disguise.
- **Terminology drift:** the same entity named differently across artifacts (`ticket`/`issue`/
  `request`) — the seed of producer/consumer drift the contract gate guards against.
If you find any, report *"`consistency` passed mechanically, but <artifact> contradicts <artifact>
on <thing>"* and let the operator decide — same posture as every other gate.

**Canonical form the mechanical pass expects** (deviate and coverage silently can't map — the runner
then prints "no FR ids found" rather than a false pass, but be aware): FR ids are **uppercase `FRn`**,
declared in the PRD's **`## Features`** section (ids in prose or the pain table are intentionally
ignored so a legacy mention can't inflate the set). A blank success-metric body is the gate's job, not
this probe's (it only checks "if a metric exists, it carries a number"). When `consistency` reports
"no FR ids found", treat it as *coverage-unverified*, not *coverage-clean*.

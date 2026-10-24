# Owner decision: one shared SemVer

Decision date: 2026-10-25 (Asia/Bangkok). Authority: [unchanged owner record](../plans/261025-0023-unified-version/decision.md).

Skill product and npm installer now use one common SemVer. A change to either surface requires a common release version. `skills/flow/SKILL.md` is canonical; package and skill metadata mirrors must agree. Existing field names and the `flow-skill vX (ships skill vY)` banner remain compatible.

Initial alignment is **1.0.0**: npm advances from 0.8.0 while the skill remains 1.0.0. This changes release policy, not runtime behavior or skill content. Historical npm releases and tag `v1.0.0` remain immutable.

Ship may skip an existing skill tag only when its `skills/` git tree equals HEAD's tree. Missing or different hashes fail closed and demand the next common bump. Existing npm tags, provenance, review, CI and owner-authorization gates retain their protections. No tag may be moved or recreated.

Operational instructions: [release process](release-process.md). The linked authoritative record controls if this summary and the decision differ.

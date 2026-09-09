# Gate rules — semantic layer (index)

The runner (`flow.sh`) checks the mechanical gate: no `[FILL]`, no unchecked `- [ ]`,
valid card status, non-empty evidence. After mechanical PASS, load the **one** stage
file below (and `gate-shared.md` when the stage has open decisions). Report
*"mechanically passed, but qualitatively weak: <reason>"* — never silently advance a
hollow artifact, never silently block a sound one.

> Teach: report only; do not edit the artifact or tick boxes.
> Work: self-challenge before presenting.

> Authoring note: match the form to the failure. Discipline drift (grade laundering,
> fabricated quotes, "merge ≈ shipped") is a prohibition plus the rationalization it
> counters. A wrong-shaped artifact is a positive recipe, not a bare ban.

Open-decision / material-authority unique home: `gate-shared.md`.

| Stage | Mechanical | File | Examples |
|---|---|---|---|
| Assess | no FILL, boxes | `gate-assess.md` | — |
| 00 Idea | pitch, named person, no FILL | `gate-00.md` | — |
| 01 Research | 7 boxes, no FILL | `gate-01.md` | §01 |
| 02 Scope | Impact+Grade, no L-above-A in v1, cut, GO/KILL | `gate-02.md` | §02 |
| 03 PRD | numeric metric, pain table, no FILL | `gate-03.md` | §03 |
| 04 ADR | why+rejected, NOT-doing, storage/auth/deploy | `gate-04.md` | — |
| 05 Contract | feature→interface, both shapes, access/effects | `gate-05.md` | §05 |
| Card | no FILL, status, evidence if done | `gate-card.md` | §Card |
| Consistency | advisory ID coverage | `gate-consistency.md` | — |
| Constitution | table well-formed | `gate-constitution.md` | — |
| Debt | DEBT.md line | `gate-debt.md` | — |

Hot-path first check — compare to `gate-examples.md`:
- 01: §01 (PASS = named tool + link; FLAG = unsourced competitors).
- 02: §02 (PASS = C called C; FLAG = C-launder, realtime graded B).
- 03: §03 (PASS = numeric metric + pain table + FR1 action→result; FLAG = unquantified adjective or feature with no pain).
- 05: §05 (PASS = method/path/request/response/errors/owner; FLAG = vibe/auth-optional).
- Card: §Card (PASS names URL/curl/path; FLAG = process-only / artifact-less).

`flow.sh eval` extracts `## Stage 01` / `## Stage 02` / `## Card gate` from those files,
not this index. Rituals: `native-rituals.md`, `forge-idea.md`, `clarify.md`.

---
title: "Gates and semantic challenges"
description: "What the semantic half of each gate actually asks, and why it is per-stage rather than generic."
---

A mechanical pass means the file is structurally complete. It says nothing about whether the
content is true. The semantic challenge is the per-stage set of questions the model applies
after the script passes, and it is deliberately specific to each stage because each stage
invites a different lie. Research invites fabricated competitors and sourceless numbers.
Scope invites grade-laundering, where a feature you want to build is written up a grade above
what it earned. The PRD invites requirements with no owner and pain with no feature. The
contract invites an endpoint with no auth column. Cards invite evidence that describes
process rather than the world. A generic "is this good?" prompt catches none of these
reliably; a named challenge per stage does.

The instruction runs in both directions: never silently advance past a hollow artifact, and
never silently block a sound one. When something passes mechanically but reads weak, the
operator is told exactly that and decides. There is also a behavioral proof that this layer
works at all — `/flow eval` feeds hollow-but-mechanically-clean fixtures to a fresh judge and
scores whether they get flagged, which is a lower bound rather than a guarantee.

The per-stage challenges:
[`skills/flow/references/gate-rules.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/gate-rules.md)

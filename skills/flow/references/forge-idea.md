# Forge-idea ritual — pressure-test an idea before it locks (Idea/Scope)

Adapted from BMAD-METHOD's `bmad-forge-idea` skill, re-expressed here for flow's own
Idea/Scope stages and gate vocabulary (no BMad-specific plumbing — this ritual runs
in-conversation, with no external scripts or scaffold). The concept — persona-driven
interrogation until an idea hardens or dies cheaply — is exactly flow's own philosophy:
**"Kill at any gate is a valid, honored outcome."** No wired agent covers this verb;
`ck-predict` is ADR-only, and this ritual runs earlier, before there is even a decision
to debate.

Purpose: catch a weak idea while changing course is still cheap — before a Research
report or a Scope decision gets built on top of an unexamined assumption.

When: offered **opt-in**, with the operator's confirmation, at Stage 00 (Idea) or Stage
02 (Scope) — never auto-fired, never a condition either gate checks for.

## Steps

1. Ask the operator one question at a time: what is the idea, what do they want from
   this session (clarify it, test whether it holds up, or make it stronger), and is it
   new or a change to an existing project.
2. Interrogate through personas, one turn at a time — vary the voice, don't let one
   dominate: an architect, a skeptical user, a competitor, a cost-conscious reviewer, a
   domain expert. Each presses the current weak point or builds on the current strong
   point, never both applauds and moves on.
3. Do not let vague terms pass unexamined — if "user" could mean three different people,
   stop and pin down which one before continuing.
4. When a branch resolves, pause — give the operator a chance to raise a remaining
   concern before moving to the next one.
5. No performative agreement. Praise and continued engagement are not the goal; a
   sharper idea (or an honest kill) is.

## Exits — three valid outcomes

- **Hardened** — the idea is stronger and specific enough to act on. Summarize the
  decisions, the rejected alternatives, and why, in the operator's own words. Feed this
  straight into Stage 00/01/02 drafting.
- **Killed** — the idea does not hold up. Say so plainly and record why. This is not a
  failure of the session — it is flow's own kill-at-gate DNA doing its job at the
  cheapest possible point.
- **Clearer** — the operator understands the idea better, with no hardened idea to hand
  off yet. That is a complete outcome too; nothing forces a decision before it's ready.

Informs, never judges: this ritual is opt-in advisory conversation. It never passes the
gate and it is never required to advance — the Idea/Scope gates still check what they
always check (`gate-rules.md` Stage 00/02); a hardened or killed idea still goes through
the normal gate afterward.

---

## License of the adapted source

The persona-interrogation concept above is adapted from BMAD-METHOD's `bmad-forge-idea`
skill, MIT-licensed. Per the license's inclusion requirement, its full notice is
reproduced verbatim below (source: `BMAD-METHOD/LICENSE`).

```
MIT License

Copyright (c) 2025 BMad Code, LLC

This project incorporates contributions from the open source community.
See [CONTRIBUTORS.md](CONTRIBUTORS.md) for contributor attribution.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

TRADEMARK NOTICE:
BMad™, BMad Method™, and BMad Core™ are trademarks of BMad Code, LLC, covering all
casings and variations (including BMAD, bmad, BMadMethod, BMAD-METHOD, etc.). The use of
these trademarks in this software does not grant any rights to use the trademarks
for any other purpose. See [TRADEMARK.md](TRADEMARK.md) for detailed guidelines.
```

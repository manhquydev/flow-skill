# Stage 00 — Idea

## Gate — check ALL before `/flow next`
- [x] The pitch below is 3 sentences, no more
- [x] I can name at least ONE real person/group who has this pain (named below)
- [x] No FILL placeholders remain in this file

## Pitch (3 sentences: who, pain, what you'd build)

Developers who use /flow to build non-web products (CLIs, libraries, Claude Code skills) hit dead gates because /flow assumes every project is a web app.
The Contract stage demands an HTTP endpoint table, the standard card sequence demands a deployed URL with /healthz and Swagger, and "done" is defined as a live URL — none of which exist for a CLI or library, where the real proof is "installs and runs on a clean machine".
Build a project-type setting (web | cli | library | skill) that adapts the Contract stage, the standard card sequence, and the done-evidence definition to the kind of thing being built.

## One real person/group with this pain

Us, right now: we just built /flow (a Claude Code skill — bash + python, no API, no URL) and /flow cannot honestly describe or ship itself through its own gates. This dogfood run is the live evidence.

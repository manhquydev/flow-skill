# Gate eval — behavioral proof for the semantic layer (`flow.sh eval`)

`gate-rules.md` is the semantic layer: after the mechanical gate passes, an LLM applies a
per-stage challenge and can flag a mechanically-clean artifact as substantively hollow. Until
this verb existed, nothing measured whether that actually happens — a hollow-but-well-formed
artifact passes the mechanical gate BY DESIGN (`flow.sh:scan_gate`/`cmd_check`), and the
semantic layer's only proof was operator trust. `flow.sh eval` runs the real per-stage ritual
text against curated hollow/sound fixture pairs and majority-votes a nonce-protected verdict,
so gate erosion (CLI update, model swap, prose edit) shows up as a number, not a vibe.

## What it measures — and the honest limit on what it does NOT

The eval judge is a **fresh** LLM call: it receives the gate-rules.md challenge text plus one
fixture's content, cold, with no memory of authoring anything. This proves a **necessary, not
sufficient**, lower bound: if a fresh judge can't catch an obvious hollow artifact when
explicitly asked to, the semantic layer has failed outright. A green scorecard proves that
floor holds — it does **not** prove the semantic layer works during a real build.

The gap: in a real `/flow` session, the SAME model that just authored a stage artifact is the
one applying the challenge to it (`gate-rules.md:11` — "in `work` mode you authored it, so you
self-challenge before presenting"). That is a self-review, with the sunk-cost/authorship bias a
fresh judge never has. This eval does not reproduce that condition, and closing that gap is out
of scope for v1 (recorded design boundary, not an oversight). Read a green scorecard as "the
rule text is enforceable by *a* judge," not "this build's self-review caught everything."

## Fixtures and thresholds

Six shipped fixtures (`skills/flow/eval/fixtures/`, manifest `skills/flow/eval/manifest.tsv`):
sound/hollow pairs for Stage 01 (Research — fabricated quotes, vague "users"), Stage 02 (Scope —
grade laundering, a real C quietly graded B), and the card gate ("merge ≈ shipped" evidence).
Fixture content maps 1:1 to the failure modes already documented in `gate-rules.md`, not an
invented taxonomy. The v1 input set is **manifest-listed shipped fixtures only** — `eval` never
accepts a caller-supplied artifact path; widening that is a v2 change that reopens security
review (an unvetted artifact reaching an LLM judge is a different trust boundary).

Per fixture, N=3 judge calls (`--n`), majority vote: **healthy = hollow fixtures flagged at
≥2/3 majority, sound fixtures passed at majority**. More than 1/3 of a fixture's runs coming
back unparseable/timed-out makes that fixture's result `UNRELIABLE` (an infra failure, reported
separately from a real mismatch — never silently counted as a gate pass or fail).

## Cost

`eval` is **opt-in and billable** — it makes real `claude -p` API calls. Zero cost when the
`claude` CLI isn't on `PATH` (clean skip, exit 0). When present, exactly one minimal probe call
is made to confirm the CLI runs headless before any real judging starts; a probe failure means
one billable call was made, then a clean skip. A full default batch is 6 fixtures × N=3 = 18
judge calls + the 1 probe = 19 calls.

**Measured real cost** (this machine, 2026-07-10, default/unforced model, no `--bare` available
under an OAuth/subscription session — see the build's spike notes): roughly **$0.30–0.37 per
call**, driven almost entirely by this repo's large global `CLAUDE.md` + skill/agent/MCP
declarations loading as system-prompt context on every call (~50–60K cache-creation tokens),
not by the judging prompt itself. A full 19-call baseline batch is real money, order **$6–7**
on this setup — not the trivial "a token or two" a casual reader might assume from "opt-in".
Forcing a cheaper model (`--model haiku` on the underlying CLI, not currently plumbed as a flow
flag) cuts this roughly 5x, but changes what the eval measures (a cheaper, possibly weaker judge)
and was deliberately left as an operator choice rather than a default, since the point of a
fresh-judge eval is to reflect a realistic judge, not the cheapest one that passes.

`--report` (below) is the free, offline way to re-read a prior batch's numbers without spending
anything.

## Running it

```
flow.sh eval                          # full manifest, N=3 per fixture
flow.sh eval --stage card              # only the card-gate fixtures
flow.sh eval --fixture fcdb --n 1       # one fixture, one run (cheap smoke check)
flow.sh eval --timeout 180              # override the per-call timeout (default 120s)
flow.sh eval --report                   # OFFLINE: last complete batch's scorecard + drift
```

Exit code: `0` = every evaluated fixture majority-matched its expected verdict (or a clean
skip); `1` = any mismatch, any `UNRELIABLE` fixture, or nothing matched the given filters. This
exit code is **informative only** — it is never wired into `next`/`check` gating. A red `eval`
run does not block a build; it tells the operator the semantic layer needs attention.

## Results, scorecard, and drift

Every batch appends to `$FLOW_PROJECT_ROOT/.flow/eval-results.jsonl` (per-fixture rows plus a
`batch:"start"`/`batch:"done"` header/trailer pair). A batch with no trailer — Ctrl-C mid-run,
the only signal handled is best-effort (see Limitations) — is simply excluded from `--report`
and drift comparisons; that absence of a trailer IS the completeness signal, not a positive
"torn" flag. Reruns append a new `run_id`; there is no in-place dedup or pruning (personal
volume, same stance as the existing global usage-log rotation backlog — documented, not built).

Each result row carries `cli_version` (from `claude --version` — the CLI's own version string,
**not** a model id) and `model` (the served model id, parsed from the JSON response's own
`model` field — falls back to `"unknown"` if that source is ever unavailable; the two are kept
strictly separate so a CLI update is never mistaken for a model swap or vice versa), plus
`flow_version` and a CRLF-normalized `gate_rules_sha` (so a checkout's line-ending convention
never produces a false "the rules changed" alarm).

`--report` prints the last complete batch's scorecard (per-fixture MATCH/MISMATCH/UNRELIABLE,
per-stage hollow-flag-rate/sound-pass-rate) and an advisory drift line against the prior
complete batch: changes in `cli_version`/`model`/`gate_rules_sha`, plus the per-stage flag-rate
delta. Drift is advisory text only, never an exit-code signal. If the two compared batches
evaluated different fixture sets for a stage (e.g. a quick `--fixture`-filtered check against an
earlier full baseline), the delta is flagged as "not directly comparable" rather than presented
as a clean number — a shrinking/growing denominator is not the same signal as a judge's answer
changing. With `model:"unknown"` on either side, drift is explicitly narrowed to the
`cli_version`/prose axes.

## Why `eval` is not `read_only` in telemetry

`eval` is the only verb that makes billable network calls AND writes a results file
(`eval-results.jsonl`); every other read-only verb (`status`, `usage`, `doctor`, ...) only reads
existing state. Marking it `read_only:true` in the standard usage-log would be a telemetry lie,
so it is deliberately excluded from `_log_is_readonly`'s whitelist. `--report` alone genuinely
is read-only (zero calls, offline) but is not special-cased in telemetry, since the standard
event still correctly reflects "a build-affecting command ran" at the `eval`-verb level.

## v2 engine seam (documented, not built)

`_eval_engine_run()` is the single call site that invokes the judge CLI. A second/third engine
(Codex, Antigravity) would implement the same nonce-in/verdict-out contract behind that one
function, without touching the fixture loop, majority-vote, or scorecard logic. Not built in v1
— Claude-only was the approved scope, and no other engine's headless contract has been spiked
yet (the same "measure, don't assume" discipline that gated this build in the first place).

## Limitations (recorded, not hidden)

- **Fixture authorship bias**: the same people who wrote `gate-rules.md`'s challenges also wrote
  the fixtures meant to test it. Mitigated by sourcing every hollow fixture's failure mode
  verbatim from the rule text it's tested against (never an invented taxonomy); residual risk is
  accepted for v1 and disclosed here.
- **Interrupt cleanup is best-effort, not guaranteed**, on at least this build's development
  platform: a signal arriving while the runner is blocked on a foreground judge call was not
  observed to preempt that call promptly. Cleanup between fixtures/calls fires reliably; a
  normal (uninterrupted) run always cleans up its temp files immediately.
- **Small fixture corpus (six)**: enough to prove the mechanism and give a real number, not
  enough for statistical confidence across every stage/failure-mode combination. Widening the
  corpus is a natural v1.x follow-up, not a v1 blocker.

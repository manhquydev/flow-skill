# Done-path matrix (phase 1)

| Path | Invoker | Mech today (pre-ship) | Target |
|------|---------|----------------------|--------|
| `flow.sh check` status=done | operator/agent | empty FAIL; non-empty PASS | + multi-signal ≥2; process-only FAIL |
| `flow.sh card done` | CLI | set done → check → revert on fail | + INT trap restore; same evidence rules |
| hand-edit status:done + check | agent | same as check | same |
| hand-edit status:done **no** re-check | agent | ready trusts status only | ready + graph deps re-validate evidence |
| auto-run step 4→6 | agent | check often on todo; then paste done | auto-run docs: re-check/`card done` required for trust |
| durable story complete | check done path | card_markdown_gate | unchanged (markdown floor honesty limit) |

## Residual

Decoy multi-signal (URL + fake PASS fence) can still mechanical PASS → offline LLM eval (fcdc).

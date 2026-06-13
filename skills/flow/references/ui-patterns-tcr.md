# 7 UI patterns + T-C-R framework

For AI-product UIs. Pick a pattern, then layer T-C-R (Transparency / Control / Recovery) —
the load-bearing frame for trustworthy agentic UI. (Source: ai20k workshop-0422.)

## The 7 patterns
| # | Pattern | Use for |
|---|---|---|
| 1 | **Chat + context panel** | AI TA, RAG chatbot, Socratic tutor (conversation left, evidence right) |
| 2 | **Upload -> dashboard** | survey analysis, report summarizer, invoice extractor |
| 3 | **Query -> structured result** | text-to-SQL, digital-twin Q&A (NL -> table/chart) |
| 4 | **Wizard + inline audit** | syllabus/compliance/onboarding (multi-step form, AI checks each step) |
| 5 | **Draft -> approve -> send** | emergency comms, email assistant (AI drafts, human approves, system sends) |
| 6 | **Queue + approval** | moderation, grading at scale, contract review (batch AI labels, human clears) |
| 7 | **Real-time streaming** | voice Q&A, live transcription (live pipeline) |

**Meta-pattern:** Pattern 1 with a swappable panel covers most cases (panel = sources->RAG,
progress->long agent, reasoning->research, chart->data Q&A, queue->inbox).

## Priority rules to choose a pattern (top wins)
irreversible action -> **5** · batch -> **6** · streaming -> **7** · multi-step form -> **4**
· file upload -> **2** · text->chart/table -> **3** · text->text+sources -> **1** ·
ambiguous -> **1 + pick the panel payload**.

## T-C-R (add to whatever pattern you chose; compounds when added in order)
- **T = Transparency.** Show what the AI is doing: status line ("Đang tra cứu 3 nguồn..."),
  sources panel, confidence traffic-light (green >0.8, amber 0.5-0.8, red <0.5), visible
  SQL/reasoning/plan, which model.
- **C = Control.** Let the user stop/edit/override BEFORE an irreversible act: abort button,
  edit-before-execute, dry-run preview, bulk + keyboard shortcuts, pin/clear.
- **R = Recovery.** Pre-flight validation + post-hoc repair: validate input before the call,
  retry, undo, "flag as bad" (becomes a training signal), regenerate, preview+cancel.

> If a UI element doesn't map cleanly to T, C, or R, rewrite it until it does. This frame is
> load-bearing — it's what makes an agentic UI trustworthy for non-technical users.

## T-C-R per pattern (quick matrix)
| Pattern | T | C | R |
|---|---|---|---|
| 1 Chat+panel | sources panel, streaming status, confidence dot | stop streaming, edit last msg, clear | error-bubble retry, thumbs-down |
| 2 Upload->dash | parse/extract progress, per-insight source | cancel, preview modal for big files | file pre-flight, "try another", keep-previous undo |
| 3 Query->result | "view SQL", confidence badge, rows/ms/model | edit query before run, confirm destructive | retry, "rephrase" feeds error back, history |
| 4 Wizard+audit | per-field ok/warn/fail + reason | back/forward no data loss, save draft, override warning | validate per step, preview+edit before submit |
| 5 Draft->send | confidence/section, recipient preview | mandatory preview (no generate-and-send), edit any field | "sent - undo" 10s, retry, keep draft on fail |
| 6 Queue | confidence dot/item, 1-line reason, counts | bulk + shift-click, J/K/A/R keys, filter by confidence | undo stack, "flag for review" not reject, re-surface |
| 7 Streaming | live status, token-by-token, latency | stop aborts, pause/resume | auto-reconnect (max 3), preserve buffer, manual restart |

Combine with `law/DESIGN.md` (tokens, affordance ladder, object-first) — T-C-R is the
behavior frame, DESIGN.md is the visual law. Both bind every UI card.

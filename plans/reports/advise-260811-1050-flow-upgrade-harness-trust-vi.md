# Advise Report: Nâng cấp flow-skill — harness tin cậy (standalone)

**Date:** 2026-08-11  
**Input:** Research AI coding landscape + product flow v0.25 + interview  
**Research:** `plans/reports/research-260811-1050-ai-coding-landscape-flow-upgrade-vi.md`  
**Mode:** advisory only — không implement

---

## Reframed (đã confirm operator)

### Problem
flow-skill đã là gated build harness (mechanical + semantic + durable) đúng category thắng 2026 ("Agent = Model + Harness"). Vấn đề còn lại không phải "thêm agent mới" hay "bám AgentKit/claudekit", mà là **user tin khi agent chạy skill ở chế độ auto/parallel**: agent có thể launder done (hollow evidence, self-assessment), trong khi proof hiệu quả hiện tại dựa chủ yếu eval gate hollow — **chưa siết đường auto/done**.

### Exact requirements
1. flow **standalone**: chỉ skill flow đủ chạy; không phụ thuộc AgentKit, claudekit, hay agent đặc biệt.
2. Nâng **harness** để giải quyết failure mode **#1: hollow done / semantic laundering under auto**.
3. Chứng minh hiệu quả bằng **eval catch-rate + fixtures** (CI-regressable), không bằng stars/FOMO.
4. Optional host hooks (Claude/Codex hooks) **được phép** nếu detect + silent degrade.
5. Nghiên cứu công nghệ/công cụ **đã giải quyết bài toán cụ thể** → port *cơ chế*, không clone sản phẩm.
6. **Kongming / ak:advise**: không hard-wire AgentKit; nếu có giá trị thì port **protocol** thành native ritual (như native-rituals đã thay ck-predict).

### Goals
- Operator tin giao auto/parallel vì hollow-done bị **bắt bởi mechanical + eval**, không chỉ "skill nói không".
- Scorecard eval mở rộng (card done + ideally auto-path fixtures) có baseline + regression gate trong CI.
- Narrative rõ: flow = honest ship harness, không phải Spec Kit clone hay AgentKit plugin.

### Non-goals
- Phụ thuộc AgentKit / kongming / fable / ck agents.
- Full vector memory (Mem0/Zep/…), CrewAI fan-out, Temporal SaaS, Tessl registry.
- Rewrite thành coding agent cạnh tranh Cursor/Claude Code.
- Graph executor default-on ngay trong đợt này (secondary).

### Constraints
- Pure bash + optional python/sqlite; graceful degrade.
- Standalone + optional host hooks.
- YAGNI/KISS/DRY; skill INFORMS / gate JUDGES.

---

## 1. Verdict

**Đúng bài, sai nếu mở rộng thành "integrate AgentKit".**  
flow đã đứng ở chỗ thị trường trả tiền: harness engineering, ground-truth gates, SDD-ish planning, multi-home portable. 2026 không thiếu coding agent — thiếu **harness khiến auto-run không tự lừa mình**.

Đợt này nên là **trust vertical slice**: harden done-evidence + auto-path eval + (optional) native strategist counsel + optional host hooks for law. **Không** pull kongming binary; **có** học protocol của kongming/advise và ritual hóa native. Graph/cost/parallel là wave-2 trừ khi eval hollow-done đã xanh.

---

## 2. What you should do (ordered)

### P0 — Hollow-done trust (must ship)

1. **Inventory done-path attack surface**  
   Map mọi đường gắn `status: done` / `card done` / auto step 6:  
   `flow.sh check`, `card done`, hand-edit, graph `card-verify-live`, harness `story complete`.  
   Mỗi đường: signal hiện tại + cách agent bypass.

2. **Mechanical done-evidence hard rules (expand)**  
   Đã có check evidence non-empty — siết class hollow phổ biến:  
   - Evidence chỉ là prose "looks good" / không paste exit code / URL.  
   - Screenshot path không tồn tại.  
   - Verify steps marked checked nhưng không có command output pair.  
   - Bug-fix cards: require red→green pair wording (đã có law — enforce mechanically where feasible).  
   Prefer **regex/structure heuristics + exit codes** over LLM-as-judge cho P0.

3. **Eval fixtures: card-done FLAG suite expansion**  
   Hiện: `fcda` PASS / `fcdb` FLAG.  
   Thêm fixtures: fake live URL, empty evidence with checked boxes, "tests pass = done", grade-laundered verify.  
   Target: **semantic gate-rules + mechanical** both covered where each belongs.

4. **Auto-path eval (new class)**  
   Fixtures không cần full LLM auto — **scripted scenario**:  
   "agent claims tier A + pastes hollow evidence → `card done` / check MUST fail".  
   Document expected exit codes. This is the trust proof for auto without billable storm.

5. **CI scorecard**  
   `flow eval` batch + offline `--report` drift; fail CI on regression below baseline.  
   Publish baseline numbers in `docs/quality-metrics.md` or eval README.

### P1 — Standalone "kongming-class" counsel (protocol port, not AgentKit)

6. **Native ritual: Strategist counsel** (new section in `native-rituals.md`)  
   Port from kongming **behavior contract**, not the agent:  
   - Advisory only, one-shot, **no user interview** (khác forge-idea / ak:advise).  
   - Reframe → scout-in-repo → advise with TL;DR / do / avoid / checklist / assumptions.  
   - Trigger: two-strikes deadlock **before** optional cross-vendor; hard ADR fork; auto HALT escalate.  
   - Detection: if host has `kongming`/`advisor` **and** operator opt-in → richer path; else native.  
   - Gate still judges. Zero import of AgentKit.

7. **Do NOT port ak:advise interview loop into hot path auto**  
   Interview is human-facing (Scope/Idea/mode work already covers). Auto needs **autonomous counsel**, not Q&A stall.

### P1 — Optional host hooks (operator allowed)

8. **Hooks playbook + thin adapters**  
   Where Claude Code / Codex hooks exist: block edit of `_templates/`, `runner/flow.sh` mid-run; optional warn on `status: done` without going through `card done`.  
   Absent hooks → no-op + doctor message. Never require hooks for gates.

### P2 — Proven external mechanisms worth porting later (not this slice)

| Source | Proven problem | Port as | When |
|--------|----------------|---------|------|
| SWE-bench / OpenHands eval method | measure agent quality | fixture all-or-nothing grading | already partial → expand P0 |
| Spec Kit constitution | project invariants | already shipped | maintenance only |
| AHE (harness observability) | which harness edit helped | decision prediction + post-outcome log | after P0 baseline |
| Anthropic tool design | tool misuse | absolute paths, verify feedback parse | continuous |
| Ralph-style budgeted loop | infinite agent loop | hard stops already in auto-run — **enforce mechanically** | P0.5 |
| Aider repo-map | brownfield context | assess ranker already v0.7 path | polish if assess weak |
| Spec Kit / OpenSpec layouts | brownfield SDD import | `/flow assess` foreign tree | wave-2 distribution |
| Cost dashboards 2026 | token burn | extend `/flow usage` with optional cost fields | wave-2 |

### P2 — Parallel secondary (not equal P0)

9. Keep workspace overlap + merge-order law; add **eval fixture** for allowed-files overlap false-green if missing.  
10. Graph executor: dogfood + more tests; **default-off** until P0 eval green.

---

## 3. What you shouldn't do

- **Wire AgentKit/kongming as dependency** — phá standalone; user base có mỗi skill flow.
- **Clone Spec Kit / OpenSpec** — overlap lớn; thua mindshare; dilute "kill valid + world-state done".
- **Full multi-agent frameworks** (CrewAI, etc.) — token tax, wrong problem.
- **Vector memory stack** — reaffirm SKIP 2026-06 decision.
- **LLM-as-judge replaces mechanical done** — expensive + grade-launders itself.
- **Default-on graph + cost platform in same release as hollow-done** — thrash.
- **Promise "proves coding quality" without fixture definition** — vague success.

---

## 4. What could be better / more efficient

| Path | Effort | Impact on trust |
|------|--------|-----------------|
| **A. Mechanical done + auto eval only** | Low–Med | Highest trust ROI |
| B. A + native strategist ritual | Med | Escalation quality without AgentKit |
| C. A + hooks only | Low | Law breaks mid-run |
| D. Distribution/interop Spec Kit first | Med | Adoption, not auto trust |
| E. Cost observability first | Med | Enterprise bill pain, secondary to hollow-done |

**Recommended:** A then B then C. D/E after scorecard exists.

---

## 5. My take — route from v0.25 → "trusted auto"

```
Wave 0 (1-3 days): attack-surface map + fixture design table
Wave 1 (vertical): mechanical hollow-done + eval fixtures + CI baseline  → version bump trust
Wave 2: native strategist counsel + optional hooks
Wave 3: usage cost hooks OR Spec Kit assess-import OR graph recommend-path
```

Philosophy stay: **skill informs, gate judges, standalone first, FOMO last.**

Kongming answer in one line: **Học protocol, không import agent. Optional detect = enrichment tier như Codex.**

---

## 6. Benefits

- Trust claim verifiable: catch-rate on hollow-done fixtures.
- Auto/parallel becomes sellable without "just trust the skill".
- Standalone story strengthens vs "requires AgentKit".
- Aligns 2026 market (harness > model) without competing as IDE agent.
- Kongming-class counsel available everywhere; richer when AgentKit present.

## 7. Trade-offs

- Mechanical heuristics miss clever hollow text → still need semantic eval fixtures (billable).
- Stricter done = more false FAIL until templates teach good evidence → docs/teach mode update.
- Native strategist without fable = weaker counsel than real kongming — honest degrade.
- Hooks only on some hosts → uneven law enforcement (document).
- Delay distribution narrative vs Spec Kit — intentional for trust-first.

---

## 8. Work checklist

- [ ] Map all done/auto paths and bypass cases (table in plan)
- [ ] Spec mechanical hollow-evidence rules + tests in `tests/test_flow_*.sh`
- [ ] Add ≥3 FLAG + ≥1 PASS card-done fixtures beyond fcdb/fcda
- [ ] Add auto-path scripted scenarios (exit-code contract, no full agent required)
- [ ] Wire CI baseline + fail-on-regression for eval scorecard
- [ ] Update gate-rules.md / ground-truth-gates.md for new classes
- [ ] Write `native-rituals.md` § Strategist counsel + agent-detection optional kongming
- [ ] Optional: hooks reference + doctor detect
- [ ] Dogfood: run eval batch; record baseline in docs
- [ ] CHANGELOG + version coherence bump when ship

## 9. Success metrics (verifiable)

| Metric | Target |
|--------|--------|
| Hollow-done FLAG fixtures | Catch-rate ≥ existing gate-eval stage bar (document number from current scorecard; no regression) |
| New mechanical tests | All green in `run_all.sh` on 3 OS CI |
| Auto-path scenarios | 100% expected fail/pass on scripted hollow claims |
| Standalone | Install skill-only → full planning + card done gate + eval dry-run without AgentKit |
| Kongming | Zero required; if present, opt-in path announced; if absent, native ritual available |
| False FAIL sample | Manual review ≤ N known good cards still pass (define N=3 golden cards) |

---

## Appendix: Research snapshot (why this advice)

- Market: Cursor/Claude Code/Codex/Copilot front-runners; multi-agent side-by-side normal.
- Tech: harness engineering, SDD mainstream, verification-as-signal, skills/hooks/MCP cost ladder.
- Prior flow decisions: constitution/eval/access_count PORT; Mem0/CrewAI/Temporal SKIP — still valid.
- Dogfood: Codex cross-model caught bugs green tests missed — multi-lens valuable; **proof still needs mechanical**.
- User interview: standalone, eval catch-rate, hollow-done #1, optional hooks, no AgentKit hard dep.

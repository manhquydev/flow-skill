# Phase 05 — DESIGN law + playbooks + T-C-R / 7 UI patterns

**Priority:** P2 · **Status:** ✅ done (2026-06-13) · **Depends:** Phase 01 (song song được với 03–04)
**Mục tiêu:** enforce DESIGN.md cho mọi UI card; playbook read-before/harvest-after loop; mang T-C-R framework + 7 UI pattern từ ai20k vào làm asset tham chiếu.

## Context links
- `ai20k-build-phase/buildflow/DESIGN.md` + `playbooks/*`
- `ai20k-build-phase/resources/.claude/skills/{ui-pattern,tcr-apply}/SKILL.md`
- `ai20k-build-phase/resources/workshop-0422/refs/*` (7 case + T-C-R matrix)

## Key insights
- DESIGN.md: Structure là luật (không cãi), Tokens là khẩu vị (đổi có chủ đích). Mock card LÀ design review.
- Playbook: đọc trước build, harvest sau build; smoke-test full loop trước khi tin một stack/model (bài học Qwen tool_calls).
- 7 UI pattern + framework T-C-R (Transparency/Control/Recovery) là khung chịu lực cho UI agentic; mặc định pattern 1 (Chat+panel) khi phân vân.

## Requirements
**Functional**
- UI/mock/frontend card: gate bắt buộc review theo `law/DESIGN.md` (như review shapes vs contract).
- Playbook subsystem: `playbooks/` trong skill + luật "read-before/harvest-after"; `/flow` nhắc đọc playbook khi card chạm stack có playbook; sau card → nhắc harvest bài học.
- T-C-R + 7 pattern: reference asset để chọn UI pattern + retrofit T-C-R cho card frontend.

**Non-functional**
- DESIGN tokens là default, project override có chủ đích (ghi trong file, đổi cả cụm).
- No emoji, no engine words, no gradient sai chỗ — checklist cơ học được (grep) ở mức khả thi.

## Architecture
```
skill/flow/
├── law/DESIGN.md                       # copy verbatim
├── playbooks/                          # README (read/harvest law) + 3 playbook gốc (CF-Qwen, docker-stale, rag-lite)
└── references/
    ├── ui-patterns-tcr.md              # 7 pattern + T-C-R matrix + priority rules chọn pattern
    └── design-review-checklist.md      # checklist enforce DESIGN.md cho UI card (grep-able + Claude review)
```

## Implementation steps
1. Copy `DESIGN.md` + 3 playbook + `playbooks/README.md` vào skill.
2. Viết `design-review-checklist.md`: phần cơ học (grep emoji, `{{`, gradient trên input/table) + phần Claude review (object-first, affordance ladder, Luma pattern).
3. Viết `ui-patterns-tcr.md`: 7 pattern + T-C-R matrix + priority rules (irreversible→5, batch→6, streaming→7, …, ambiguous→1+panel).
4. Wire gate: UI/mock/frontend card → chạy design-review trước done; playbook hook ở card touch stack.
5. Test: card frontend cố tình có emoji/engine word → checklist bắt; card chạm "cloudflare" → nhắc đọc playbook.

## Todo list
- [ ] Copy DESIGN.md + 3 playbook + README
- [ ] design-review-checklist.md (grep + Claude review)
- [ ] ui-patterns-tcr.md (7 pattern + T-C-R + priority)
- [ ] Wire UI-card gate + playbook hook
- [ ] Test design-violation catch + playbook prompt

## Success criteria
- UI card vi phạm DESIGN (emoji/engine word/gradient sai) bị gate chặn.
- Card chạm stack có playbook → skill nhắc đọc trước, harvest sau.
- Chọn UI pattern theo priority rules cho ra pattern đúng cho ca test.

## Risk & mitigation
- **Over-strict design gate cản tốc độ:** Structure là luật cứng; Tokens cho override có chủ đích.

## Security considerations
- Playbook không chứa secret; ví dụ dùng env var/placeholder.

## Next steps
→ Phase 06: đóng gói + install + test 6-round + docs.

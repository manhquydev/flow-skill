# Brainstorm: mở rộng flow-skill installer sang các coding agent (Cursor + universal Agent-Skills)

Date: 2026-07-17 · Session: /brainstorm · Nền: research report
`research-260717-0915-npx-agent-installer-expansion-report.md` · Status: design APPROVED (operator)

## 1. Problem statement

Hai vấn đề operator nêu: (1) cài qua `npx @manhquy/flow-skill` không hoạt động đúng cho
Antigravity; (2) muốn mở rộng hỗ trợ các coding agent phổ biến (Cursor, v.v.) — **không đoán
mò**, phải dựa trên cấu trúc skill thật của từng agent.

## 2. Phát hiện then chốt (đảo ngược giả định ban đầu)

**Agent Skills đã là CHUẨN MỞ.** Anthropic công bố spec tại agentskills.io ngày 18/12/2025,
do Agentic AI Foundation quản trị. 32–40 tool đọc **CÙNG format SKILL.md từ CÙNG cấu trúc thư
mục** — "một skill viết cho Codex chạy y hệt trên Claude Code, Cursor, Gemini CLI, Roo Code,
không sửa gì". flow SKILL.md **đã conform** (đó là lý do Codex/Antigravity đã chạy được).

Hệ quả: bài toán "mở rộng agent" **sụp từ "adapt nội dung per-agent" xuống chỉ còn "thêm điểm
cài (marker + destTemplate)"**. Nội dung SKILL.md + 21 reference + runner + harness **không
đổi một chữ** cho bất kỳ agent spec-compliant nào. Nhiều installer đa-agent đã tồn tại làm
mẫu (skills.sh của Vercel/MIT, agent-skill-creator "17 platforms", Agent Skills CLI).

**Điểm gating thật KHÔNG phải file format** (đã giải quyết) mà là: **sandbox của agent có cho
`flow.sh` chạy + trả exit code không**. Đây là ẩn số per-agent → phải verify sống, không
tuyên bố suông.

## 3. Cấu trúc skill thật của từng agent (deliverable chính, có nguồn)

| Agent | Đọc SKILL.md | Vị trí cài | Chạy script | Ghi chú |
|---|---|---|---|---|
| **Universal** `~/.agents/skills/` | ✅ | `~/.agents/skills/flow` (flow ĐÃ có) | ✅ | Cursor + Devin + nhiều tool đọc chung; symlink-standard nổi lên 2026 |
| Claude Code | ✅ | `~/.claude/skills/flow` | ✅ | đã hỗ trợ |
| Codex CLI | ✅ | `~/.codex/skills/flow` | ✅ | đã hỗ trợ, live-verified trước đây |
| Antigravity/Gemini-3 | ✅ | `~/.gemini/antigravity-cli/skills/flow` + `~/.gemini/config/skills/flow` | ✅ | đã hỗ trợ, live-verified (`agy -p` đọc đúng SKILL.md) |
| **Cursor** | ✅ | `~/.cursor/skills/flow` + `.cursor/skills/` (project); cũng đọc `~/.agents/skills/` | ✅ bash/py/js | 3-tier progressive loading = đúng kiến trúc flow |
| **Windsurf** (Cascade) | ✅ | `.windsurf/skills/flow` (project-scope) | ✅ | mới thêm skill-loader; không còn "rules-only" |
| **Cline** | ✅ | vị trí cần verify | ✅ | đọc SKILL.md; độ tin thấp hơn, verify trước khi claim |
| Copilot/VS Code, Gemini CLI, Kiro, Junie, Goose, Amp, Roo Code, TRAE... | ✅ (32–40 tool) | theo chuẩn / universal | ✅ | phủ qua universal thay vì integration riêng |

## 4. Quyết định operator (captured)

1. **Phạm vi: A trước → B.** A = fix staleness (blocker). B = thêm Cursor + universal
   (phủ Copilot/VS Code/Gemini CLI qua `~/.agents/skills/`).
2. **Mức verify: live-test runner THẬT.** Mỗi agent claim support phải: cài thật → chạy
   `flow.sh status`/`next` trong sandbox agent đó → xác nhận exit code + agent đọc được
   SKILL.md (như đã làm với Antigravity). Không tuyên support khi chưa chạy thật.
3. **Agent ưu tiên: Cursor + (Copilot/VS Code + Gemini CLI qua universal).**
4. **Bước kế: report → /ck:plan → red-team → validate** cho tới khi sạch.

## 5. Giải pháp chốt

### WS-A — Fix staleness (blocker, làm trước)
- `npm run sync` (copy `skills/flow` → `npm-wrapper/skills/flow`) + bump
  `npm-wrapper/package.json` version + publish `--tag rc`.
- **CI guard mới**: fail publish workflow nếu `version:` của `npm-wrapper/skills/flow/SKILL.md`
  ≠ root `skills/flow/SKILL.md` (mirror kỷ luật `flow.sh coherence`). Đây là fix gốc rễ để
  staleness không tái diễn — quan trọng hơn cả bản fix một lần.

### WS-B — Thêm điểm cài (chỉ config, zero content change)
- Thêm entry `TARGETS` (constants.mjs): **cursor** (`~/.cursor/skills/flow`, marker `.cursor`).
- Định vị lại **agents** target = "universal Agent-Skills home" (`~/.agents/skills/flow` đã có)
  — tài liệu hoá là điểm phủ cho mọi tool spec-compliant đọc `~/.agents/skills/`.
- Mỗi target mới: test detect (marker present/absent) + test install (copy đúng vị trí) theo
  đúng pattern 35 test node:test hiện có.
- **Live-runner verification** (điều kiện release theo quyết định #2): với mỗi agent claim, chạy
  thật `flow.sh status` trong agent đó; ghi bằng chứng vào CHANGELOG/journal như đã làm với
  Antigravity. Agent nào chưa verify được runner → chỉ ghi "installs, runner unverified", KHÔNG
  claim full support.

### Không làm đợt này (YAGNI)
- Windsurf/Cline: có skill-loader nhưng để đợt sau (project-scope Windsurf + vị trí Cline chưa
  chắc → cần verify riêng). Không nằm trong agent ưu tiên operator chọn.
- Content adapter per-agent: KHÔNG cần — chuẩn mở nghĩa là 1 SKILL.md chạy mọi nơi.

## 6. Rủi ro + giảm thiểu

- **Runner không chạy trong sandbox agent X** (rủi ro thật duy nhất) → live-test bắt buộc
  trước claim; degrade "installs, runner unverified" thay vì tuyên sai.
- **Universal `~/.agents/skills/` không được tool Y đọc như kỳ vọng** → verify per-tool; đừng
  claim phủ 32-40 tool khi chỉ test được vài cái. Chỉ ghi số tool đã verify thật.
- **Staleness tái diễn** → CI version-guard (WS-A) là fix gốc, không chỉ vá một lần.
- **Cursor project-scope vs global** → destTemplate global `~/.cursor/skills/flow`; project
  scope chỉ thêm nếu operator cần (parity với giới hạn project-scope=claude-only hiện tại).

## 7. Success metrics
- npx cài ra nội dung v0.22 (không còn v0.21) cho mọi target — verify bằng version trong file đã cài.
- CI guard chặn được 1 case cố tình để version lệch (test).
- Cursor: `--target cursor` cài đúng `~/.cursor/skills/flow`; runner chạy thật trong Cursor,
  có bằng chứng ghi lại.
- 35 test node:test cũ vẫn xanh + test mới cho cursor target.

## 8. Next steps
`/ck:plan --tdd` với report này làm input → red-team → validate. TDD vì sửa installer có 35
test sẵn (khoá hành vi cũ, viết test target mới trước).

## Câu hỏi chưa giải quyết
1. Copilot/VS Code + Gemini CLI đọc `~/.agents/skills/` hay có path riêng — phải verify sống
   ở giai đoạn plan/implement, không claim trước.
2. Cursor có cần cả project-scope (`.cursor/skills/`) hay chỉ global — chờ tín hiệu nhu cầu.
3. Thời điểm cắt release npm cho A (fix ngay, hay gộp A+B một lần publish).

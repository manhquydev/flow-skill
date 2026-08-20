---
title: "Cài skill, rồi nói muốn build gì."
description: "Cài flow bằng npx. Sau khi cài thì có cổng chặn việc rỗng. Đi cổng thì có plan trong repo. Done nghĩa là bằng chứng done. Đi một dự án đủ, hoặc tra lệnh."
lang: vi
---

## Cài

Cần [Node.js](https://nodejs.org/) **22.14 trở lên** và một coding agent: Claude Code, Codex, Cursor, hoặc Antigravity.

```bash
npx @manhquy/flow-skill@latest
```

Đừng `npm i` gói này. Lệnh đó không copy skill. Đừng pin version skill trên npm. Luôn ghi `@latest`.

Chuyện xảy ra: installer detect agent, bạn chọn home, skill nằm xuống (ví dụ `~/.claude/skills/flow`).

Rồi restart agent. Chưa restart thì agent không biết skill tồn tại.

| Agent | Sau restart |
|---|---|
| Claude Code | gõ `/flow` |
| Codex CLI | restart một lần, rồi gõ `$flow` |
| Cursor | reload tool, mở skill flow |
| Antigravity | restart IDE hoặc `agy`, rồi `/flow` |

Tuỳ chọn: `bash ~/.claude/skills/flow/runner/flow.sh doctor` in `READY`.

`--help` in cả hai số version (installer và skill). Xem [Hai số version](/vi/docs/how-to/troubleshoot-install/#two-version-numbers).

## Bạn nhận được gì

Ba khả năng. Cái đầu đúng ngay sau `npx`. Hai cái sau đúng sau khi đi cổng hoặc đóng card.

1. **Cổng chặn trung thực.** `/flow next` không mở stage sau nếu file trống, bịa, hoặc hạ scope để lọt. Dừng ý tưởng tại cổng là kết quả hợp lệ. Đây là cổng từ chối, không phải công tắc dừng agent.
2. **Plan viết trong repo, khi bạn đi cổng.** Sáu file dưới `flow/`, rồi card dưới `cards/`. Session khác nhặt được lạnh. Những file đó không có sẵn sau lúc cài.
3. **Done nghĩa là thứ đó tồn tại.** URL sống, CLI chạy được, API import được, hoặc skill đã chạy thật. Không phải “tests pass.” Phải có bằng chứng done.

## Lần chạy đầu: một lệnh, một restart, một kiểm

```bash
npx @manhquy/flow-skill@latest
# restart agent
# trong thư mục project:
Tôi muốn build app quản lý kho cho cửa hàng.
# hoặc gõ /flow  (Codex: $flow)
```

Chat là cửa. Lệnh `/flow` gõ tay luôn thắng. Concierge hỏi một câu đồng ý, rồi một việc kế. Routing tin được trên Claude; trên Codex hoặc Antigravity thì chat là best-effort, hãy gõ verb. Caveat đầy đủ nằm ở [Vòng hằng ngày](/vi/docs/how-to/use-chat-concierge).

Thành công trên trang này: skill trên đĩa, agent đã restart, bạn nói muốn build gì **hoặc** gõ `/flow`, và harness trả **status hoặc việc kế hoặc kết quả cổng**.

Bài dài, gồm “Xem cổng từ chối”: [Cài đặt và lần chạy đầu](/vi/docs/tutorials/install-and-first-run).

## Lệnh hằng ngày

| Bạn muốn | Gõ |
|---|---|
| Đang ở đâu? | `/flow` |
| Tiến hoặc bị chặn trung thực | `/flow next` |
| Cắt một lát build | `/flow card` |
| Chứng nó tồn tại | `/flow check C-001` |
| Codebase có sẵn | `/flow assess` |
| Kiểm máy | `/flow doctor` |

Codex dùng `$flow`. Bảng đủ: [Lệnh](/vi/docs/reference/commands). `/flow auto` là nâng cao; xem [Khi việc phải dừng](/vi/docs/explanation/auto-tiers-and-security-halts).

## Các luồng là việc

Idea → Research → Scope → PRD → ADR → Contract, rồi card, rồi Retro. Tên file đứng cạnh việc dưới dạng `flow/00-idea.md` … `flow/05-contract.md`, không phải heading.

Contract là stage duy nhất không được skip. Xem [Vì sao contract không bao giờ được skip](/vi/docs/explanation/stage-pipeline/#contract-never-skipped) và [Khi việc phải dừng](/vi/docs/explanation/auto-tiers-and-security-halts).

Repo có sẵn bắt đầu bằng `/flow assess` ([Assess brownfield](/vi/docs/how-to/resume-mid-project/#assess-a-brownfield)). Teach và work khác nhau ở một câu đồng ý; cổng vẫn giống nhau ([Teach và work](/vi/docs/how-to/use-chat-concierge/#teach-and-work)).

Không nhét walkthrough đầy đủ vào đây. [Đi một dự án đủ](/vi/docs/tutorials/first-greenfield-project).

## Khi bị kẹt

- Nhặt dự án lạnh → [Tiếp tục giữa dự án](/vi/docs/how-to/resume-mid-project)
- Mở session chết → [Mở session cũ](/vi/docs/how-to/resume-mid-project/#unlock-stale-session)
- Cài hỏng → [Cài hỏng thì sao](/vi/docs/how-to/troubleshoot-install)

## Đọc thêm

- Hai lớp chạy thế nào → [Harness hai lớp](/vi/docs/explanation/what-is-flow/#two-layer-harness)
- Vì sao “tests pass” không phải done → [Done nghĩa là bằng chứng thế giới thật](/vi/docs/explanation/what-is-flow/#done-means-world-state)
- Khi việc phải dừng → [Khi việc phải dừng](/vi/docs/explanation/auto-tiers-and-security-halts)
- Vì sao hai số version → [Hai số version](/vi/docs/how-to/troubleshoot-install/#two-version-numbers)
- Kiến trúc → [Ba lớp](/vi/docs/explanation/what-is-flow/#system-architecture)
- [Lệnh](/vi/docs/reference/commands), [Thuật ngữ](/vi/docs/reference/glossary), [Nhật ký thay đổi](/vi/docs/reference/changelog)
- Power (auto, attest, engine phụ) → [Điều phối agent](/vi/docs/explanation/agent-orchestration)

Nếu chỉ cần cài và chạy, dừng ở trên.

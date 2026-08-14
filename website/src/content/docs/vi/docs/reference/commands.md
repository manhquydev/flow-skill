---
title: "Tham chiếu lệnh"
description: "Mọi verb flow, nó làm gì, và có mutate state không. Codex dùng $flow thay /flow."
lang: vi
---

Mọi verb dispatch xuống engine cơ học, `bash <skill-dir>/runner/flow.sh <command>`.
Trong Claude Code, Cursor, và Antigravity bạn gõ `/flow …`; trong Codex CLI bạn gõ `$flow …`.
Trên Windows PowerShell, gọi `<skill-dir>\runner\flow.cmd <command>` chứ không gọi `bash`.

## Lệnh hằng ngày

```
/flow              status — đang ở đâu, cái gì chặn
/flow next         kiểm cổng + mở stage kế
/flow assess       đánh giá brownfield
/flow card         tạo build card
/flow check C-001  validate card (done = bằng chứng thế giới thật)
/flow auto         build tự động (HALT nhóm bảo mật)
/flow doctor       kiểm môi trường
```

## State và vào lại

| Lệnh | Làm gì |
|---|---|
| `/flow resume` | Bản tóm tắt câu chuyện phiên, chỉ đọc, để vào lại dự án giữa chừng: phiên trước (chỉ tên lệnh, không bao giờ raw args), card in flight cộng dwell, trạng thái cổng, một dòng `NEXT ->`. Không lấy lock. Chạy lệnh này ĐẦU TIÊN khi nhặt lại dự án đã có lúc lạnh. |
| `/flow` *(status)* | Đang ở đâu, cái gì chặn, một dòng `NEXT ->` từ cùng helper với `resume`, dwell stage hiện tại, danh sách card (tóm gọn khi quá mười card), và một dòng tóm tắt bộ nhớ. |
| `/flow recall` | Đọc lại bộ nhớ bền vững — debt mở, retro gần đây, scope card trước, friction/backlog harness, sức khỏe audit, playbook — lúc bắt đầu stage hoặc card. |
| `/flow unlock` | Xóa khóa concurrency của dự án này sau session crash hoặc bỏ dở. |
| `/flow doctor` | Tự kiểm môi trường trên macOS, Linux, Windows: bash, python, grep, git, path cài. |

## Stage và planning

| Lệnh | Làm gì |
|---|---|
| `/flow next` | Kiểm cổng stage hiện tại; nếu pass, mở stage kế (hoặc bắt đầu ở stage 00). Thử thách ngữ nghĩa của stage vừa pass được áp sau pass cơ học. |
| `/flow assess` | Brownfield: scaffold và gác cổng bản đánh giá hiện trạng trong `flow/00-inspect.md` trước khi plan. Có người duyệt. |
| `/flow skip <stage> --reason` | Vượt cổng có dòng debt mở khớp. Chỉ phi nhóm bảo mật; stage 05 không bao giờ skip được. |
| `/flow clarify` | Liệt kê bullet `- [ ]` sót dưới `## Open decisions` trên Scope, PRD, và Contract. Cố vấn, không phải cổng của `next`. |
| `/flow constitution` | Kiểm bất biến per-dự-án operator tự viết trong `flow/constitution.md`. Cố vấn, không phải cổng của `next`. |
| `/flow converge` | Card phần còn lại, chỉ-append, đối soát code hiện tại với plan. Transactional — tất cả card hoặc không cái nào; không bao giờ sửa card đã có; in `CONVERGED` và không ghi gì khi không có gap. |

## Card và building

| Lệnh | Làm gì |
|---|---|
| `/flow card` | Tạo build card kế, chỉ sau khi mọi cổng planning đã pass. |
| `/flow card start\|done C-NNN` | Đánh dấu card in flight, hoặc flip `done` do CLI sở hữu với cùng luật `check` — revert nếu fail. Song song với sửa tay. |
| `/flow check C-NNN` | Validate một card: `[FILL]`, status, section bắt buộc, bằng chứng done. |
| `/flow ready` | Liệt kê card todo build được cộng gợi ý an-toàn-song-song. |
| `/flow auto` | Preflight lần chạy tự động; `auto stop` tắt. Tier-A auto-merge, Tier-B được một lần sửa bởi subagent mới, Tier-C nhóm bảo mật HALT. |
| `/flow attest semantic\|live-verify\|status\|recover` | Mint hoặc xem biên nhận gắn fingerprint dùng bởi control plane attested-execution. |
| `/flow workspace add\|list\|enter\|remove\|check\|doctor` | Cô lập đa-agent bằng worktree: mỗi agent một `git worktree` để nhiều agent chạy song song mà không một lần đổi nhánh lật mọi terminal. |
| `/flow loop-prep <card>` | Plumbing để iterate theo một mục tiêu số: worktree cô lập cộng lệnh verify dạng số suy từ allowed files của card. |
| `/flow loop-log <card> --iterations N --start M --end K --outcome …` | Ghi một lần loop đã xong vào usage telemetry. |

## Mode và cấu hình

| Lệnh | Làm gì |
|---|---|
| `/flow mode [teach\|work]` | Xem hoặc đặt ai viết artifact ở cổng. Mặc định `teach`. |
| `/flow project-type [web\|cli\|library\|skill]` | Xem hoặc đặt loại dự án, chọn luật bằng chứng done và seam contract. Mặc định `web`. |
| `/flow debt add\|list` | Ghi hoặc liệt kê skip cổng có chủ đích trong `DEBT.md`. Mục nhóm bảo mật chỉ operator. |

## Drift và audit

Cả bốn chỉ cảnh báo: gắn cờ, không tự sửa.

| Lệnh | Kiểm gì |
|---|---|
| `/flow contract` | Lệch base-URL client versus prefix path server (web). |
| `/flow tokens` | Token khai báo trong `DESIGN.md` versus CSS thực dùng: chưa dùng, lệch giá trị, orphan. |
| `/flow coherence` | Lệch version giữa các trường version khai báo. |
| `/flow consistency` | Phủ liên-artifact: mỗi `FRn` trong PRD được một card claim và một interface contract phục vụ, success metric có số, không còn placeholder. |
| `/flow design <file>` | Kiểm `DESIGN.md` cơ học trên file UI. |

## Lớp bền vững và tri thức

| Lệnh | Làm gì |
|---|---|
| `/flow harness <args>` | Passthrough xuống CLI lớp bền vững: intake, story, trace, decision, backlog, query, audit, propose. |
| `/flow promote <file>` | Copy playbook vào KB liên-dự-án tại `~/.claude/flow/playbooks`. |
| `/flow usage [--global\|--prune]` | Tổng hợp usage-log JSONL cục bộ thành analytics build: cycle time, tỷ lệ fail cổng, dwell theo stage và theo card, phân bố lệnh. Chỉ lưu cục bộ. |
| `/flow retro` | In ba câu hỏi retro. Operator viết dòng, không bao giờ agent. |

## Evaluation

| Lệnh | Làm gì |
|---|---|
| `/flow eval` | Bằng chứng hành vi cho cổng ngữ nghĩa: model có thật sự gắn cờ fixture rỗng-nhưng-sạch-cơ-học không? Opt-in và **tính phí**; skip sạch không gọi nếu thiếu CLI `claude`. |
| `/flow eval --report` | Offline, không gọi: scorecard batch hoàn chỉnh gần nhất cộng drift so với batch trước. |

## Xem thêm

- [CLI cài đặt](/vi/docs/reference/install-cli)
- [Lệnh drift](/vi/docs/reference/drift-commands)
- [Lệnh phụ harness](/vi/docs/reference/harness-subcommands)
- Nguồn đầy đủ: [`skills/flow/SKILL.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/SKILL.md)

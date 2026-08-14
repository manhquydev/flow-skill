---
title: "Cài đặt và lần chạy đầu"
description: "Cài skill flow bằng npx, xác nhận cả hai số version, và xem cổng từ chối trung thực lần đầu."
lang: vi
---

Cuối tutorial này, skill `flow` đã nằm trong skill home của agent, bạn đã xác nhận version mình nhận được, và đã thấy một cổng từ chối tiến — đúng hành vi mà cả harness tồn tại vì nó.

Thời gian: khoảng mười phút.

## Trước khi bắt đầu

Cần [Node.js](https://nodejs.org/) **22.14 trở lên** và một coding agent được hỗ trợ (Claude Code, Codex CLI, Cursor, Antigravity, hoặc Agents home). Skill lúc chạy còn cần `bash` — trên Windows nghĩa là Git Bash. `python3` khuyến nghị nhưng không bắt buộc: thiếu nó thì cổng vẫn chạy, chỉ lớp SQLite bền vững tắt.

## Bước 1 — chạy installer

```bash
npx @manhquy/flow-skill@latest
```

Luôn ghi `@latest`. Lệnh trần `npx @manhquy/flow-skill` có thể lấy từ cache npx và âm thầm chạy bản cũ.

Ba việc xảy ra:

1. npm tải installer GA hiện tại.
2. Installer hiện multi-select tương tác các agent nó detect được trên máy.
3. Nó copy cây skill vào mỗi home bạn chọn, ví dụ `~/.claude/skills/flow`.

Chọn agent bạn thực sự dùng. Chạy lại lệnh sau để thêm agent khác.

## Bước 2 — restart agent

Skill là file trên đĩa; agent đọc thư mục đó lúc khởi động. Chưa restart thì agent không biết skill tồn tại.

| Agent | Sau restart |
|---|---|
| Claude Code | gõ `/flow` |
| Codex CLI | restart một lần, rồi gõ `$flow` |
| Cursor / Agents home | reload tool, mở skill flow |
| Antigravity | restart IDE hoặc `agy`, rồi `/flow` |

## Bước 3 — xác nhận những gì vừa cài

Có hai số version **cố ý**. Xác nhận cả hai ngay sẽ tránh nhầm sau này.

```bash
npx @manhquy/flow-skill@latest --help
```

Installer in version của chính nó và skill version nó ship:

```
flow-skill v0.6.0 (ships skill v0.29.0)
```

Rồi đọc skill version từ đĩa:

```bash
grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
# version: "0.29.0"
```

`0.6.0` là npm installer CLI. `0.29.0` là skill product — thứ thực sự gác cổng build của bạn. Chúng đi độc lập. Nếu thấy lạ, đọc [Phiên bản: npm installer vs skill product](/vi/docs/explanation/versions-npm-vs-skill).

## Bước 4 — kiểm môi trường

```bash
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

Bạn muốn `READY`. `doctor` kiểm bash, python, grep, git trên macOS, Linux, Windows. Thiếu `python3` thì báo lớp bền vững disabled — đó là chế độ suy giảm, không phải fail. Còn gì khác, sang [Khắc phục cài đặt](/vi/docs/how-to/troubleshoot-install).

Trên Windows PowerShell, gọi `runner\flow.cmd` thay vì `bash`. `bash` trần trong PowerShell thường ra WSL, không đọc được path `C:/...`, khiến bản cài đúng trông như hỏng.

## Bước 5 — xem cổng fail

Tạo thư mục trống, mở agent ở đó. Rồi xin stage đầu:

```
/flow next
```

Runner scaffold `flow/00-idea.md` rồi gate-check ngay. Vì bạn chưa viết gì, nó từ chối:

```
FAIL: gate for stage 00-idea is not clean.
  [x] unchecked gate boxes:
      L4:- [ ] The pitch below is 3 sentences, no more
  [x] unfilled [FILL] placeholders:
      L10:[FILL: sentence 1 — who has the problem]
Fix the above, then run '/flow next' again. (Kill at a gate is also valid.)
```

Đây là cài đặt đang chạy đúng. Lớp cơ học đọc file, thấy ô chưa tick và `[FILL]` chưa điền, exit khác 0 kèm số dòng. Nó không điền hộ, và sẽ không điền hộ.

## Bước 6 — hỏi bằng tiếng thường

Không bắt buộc học verb. Trong session agent mới, gõ:

> "Tôi muốn build app quản lý kho cho cửa hàng."

Concierge chạy lệnh status trước để lấy ground truth cơ học, hỏi một câu đồng ý về ai soạn artifact, rồi đề xuất đúng một hành động kế. Lệnh `/flow` tường minh luôn thắng routing chat, nên power user không mất gì.

## Bạn đang có

- Skill đã cài trong ít nhất một agent home.
- Cả hai số version xác nhận từ máy, không từ README.
- Một lần cổng fail đọc hết, kèm số dòng.

## Tiếp

Đi một dự án thật qua mọi cổng planning trong [Dự án greenfield đầu tiên](/vi/docs/tutorials/first-greenfield-project), hoặc đọc [Harness hai lớp](/vi/docs/explanation/two-layer-harness) để hiểu thứ vừa phán file của bạn.

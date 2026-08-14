---
title: "Khắc phục cài đặt"
description: "Sửa các fail cài flow thường gặp: không có lệnh /flow, skill cũ, lỗi path PowerShell, và lớp bền vững disabled."
lang: vi
---

Đi bảng này trước — hầu hết báo cáo khớp một trong sáu hàng.

| Hiện tượng | Cách xử lý |
|---|---|
| Không có `/flow` sau `npm i` | Chạy `npx @manhquy/flow-skill@latest`. Phải **execute** CLI; chỉ cài package không copy gì vào skill home. |
| Skill cũ sau “cài lại” | Luôn dùng `@latest`. Tên package trần có thể lấy từ cache npx. |
| Claude hoặc Codex không list skill | Restart agent **một lần** sau cài lần đầu. |
| `flow.sh: No such file` trên PowerShell | Gọi `…/runner/flow.cmd`, không gọi `bash`. |
| `durable layer DISABLED` | Cài `python3`, hoặc bỏ qua — cổng cơ học vẫn chạy. |
| CRLF hoặc “bad interpreter” | Repo ép LF qua `.gitattributes`; clone lại nếu line ending bị méo. |

## Bắt đầu với doctor

```bash
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

`doctor` kiểm bash, python, grep, git và báo các path cài nó thấy. Kết quả `READY` nghĩa là môi trường ổn, vấn đề ở chỗ khác — thường là agent chưa được restart.

## “Cài rồi mà không có /flow”

Hai nguyên nhân tách biệt, theo thứ tự khả năng.

**Bạn cài package thay vì chạy nó.** `npm i @manhquy/flow-skill` thêm package vào `node_modules`. Nó không copy cây skill tới chỗ agent tìm. Installer là CLI bạn execute:

```bash
npx @manhquy/flow-skill@latest
```

**Bạn chưa restart agent.** Agent liệt kê thư mục skill lúc khởi động. Claude Code cần restart; Codex cần restart rồi `$flow` chứ không `/flow`; Cursor và Antigravity cần reload tool hoặc IDE.

Xác nhận file thật sự đã nằm:

```bash
ls ~/.claude/skills/flow/SKILL.md
```

## “Nó cài bản cũ”

Kiểm cái bạn thật sự có, từ máy chứ không từ tài liệu:

```bash
npx @manhquy/flow-skill@latest --help
# flow-skill v0.7.0 (ships skill v0.30.0)

grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
# version: "0.30.0"
```

Nếu skill trên đĩa đứng sau cái `--help` báo, bước copy không tới home đó — chạy lại installer và chọn agent tường minh.

Hai lỗi pin gây hầu hết bản cũ:

- Pin `@0.30.0` trên npm. Đó là version **skill product**, không phải version package npm đã publish. Pin installer, ví dụ `@0.7.0`, hoặc dùng `@latest`.
- Dùng tag `@rc`. Đã retire và cũ.

## Windows: PowerShell resolve nhầm bash

Trong PowerShell hoặc cmd — kể cả trong Codex — `bash` trần thường ra WSL tại `C:\WINDOWS\system32\bash.exe`. WSL không đọc path `C:/...` hoặc `/c/...`, nên fail `No such file or directory` và harness trông như hỏng khi không hỏng.

Dùng launcher, nó tìm Git Bash và truyền path Git Bash chấp nhận:

```powershell
& "$env:USERPROFILE\.codex\skills\flow\runner\flow.cmd" status
```

Chỉ gọi `bash flow.sh` trực tiếp khi đã xác nhận `bash` là Git Bash.

## “durable layer DISABLED”

Đây là chế độ suy giảm, không phải fail. Lớp bền vững là store Python cộng SQLite cho intake, story, trace, decision, backlog. Không có `python3` thì cổng cơ học và mọi check stage/card vẫn chạy — bạn mất bộ nhớ xuyên session, nên `/flow recall` đọc lại ít hơn. Cài `python3` để bật lại.

## Cài không dùng npm

Cho contributor hoặc máy air-gapped, cài từ git checkout:

```bash
bash install.sh global          # hoặc: pwsh install.ps1 global  trên Windows
bash install.sh project [dir]   # skill Claude theo project
```

Đường npm vẫn là đường khuyến nghị cho mọi người khác. Xem [Đường cài đặt khác](/vi/docs/how-to/alternative-install).

## Vẫn kẹt

Thu thập ba thứ trước khi hỏi: output `doctor` đầy đủ, hai số version ở trên, và lệnh đúng kèm chữ lỗi. Mở issue tại [github.com/manhquydev/flow-skill](https://github.com/manhquydev/flow-skill/issues).

## Xem thêm

- [Cài đặt và lần chạy đầu](/vi/docs/tutorials/install-and-first-run)
- [Đường dẫn cài đặt](/vi/docs/reference/install-paths)
- [CLI cài đặt](/vi/docs/reference/install-cli)

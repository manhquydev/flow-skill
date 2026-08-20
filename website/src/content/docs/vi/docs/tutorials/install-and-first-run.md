---
title: "Cài đặt và lần chạy đầu"
description: "Cài, restart, nói muốn build gì (hoặc gõ /flow), rồi nhận status, việc kế, hoặc kết quả cổng."
lang: vi
---

Cuối tutorial này, skill `flow` nằm trên đĩa trong agent home, agent đã restart, và harness
đã trả **status, một việc kế, hoặc kết quả cổng**.

Thời gian: một lệnh, một restart, rồi một kiểm cơ học. Đường sâu tùy chọn (hai số version
và transcript cổng từ chối) khoảng mười phút. Đó không phải dòng thành công.

## Trước khi bắt đầu

Cần [Node.js](https://nodejs.org/) **22.14 trở lên** và một coding agent được hỗ trợ (Claude
Code, Codex CLI, Cursor, Antigravity, hoặc Agents home). Skill lúc chạy còn cần `bash` —
trên Windows nghĩa là Git Bash. `python3` khuyến nghị nhưng không bắt buộc: thiếu nó thì
cổng vẫn chạy, chỉ lớp SQLite bền vững tắt.

## Bước 1 — chạy installer

```bash
npx @manhquy/flow-skill@next
```

Dùng `@next` cho skill **v0.31.0** (installer `0.7.1-next.0`). `@latest` vẫn ship 0.7.0 /
skill 0.30.0 cho đến khi được promote. Lệnh trần `npx @manhquy/flow-skill` có thể lấy từ
cache npx và âm thầm chạy bản cũ.

Ba việc xảy ra:

1. npm tải installer GA hiện tại.
2. Installer hiện multi-select tương tác các agent nó detect được trên máy.
3. Nó copy cây skill vào mỗi home bạn chọn, ví dụ `~/.claude/skills/flow`.

Chọn agent bạn thực sự dùng. Chạy lại lệnh sau để thêm agent khác.

## Bước 2 — restart agent

Skill là file trên đĩa; agent đọc thư mục đó lúc khởi động. Chưa restart thì agent không
biết skill tồn tại.

| Agent | Sau restart |
|---|---|
| Claude Code | gõ `/flow` |
| Codex CLI | restart một lần, rồi gõ `$flow` |
| Cursor / Agents home | reload tool, mở skill flow |
| Antigravity | restart IDE hoặc `agy`, rồi `/flow` |

## Bước 3 — kiểm môi trường

```bash
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

Bạn muốn `READY`. `doctor` kiểm bash, python, grep, git trên macOS, Linux, Windows. Thiếu
`python3` thì báo lớp bền vững disabled. Đó là chế độ suy giảm, không phải fail. Còn gì
khác, sang [Cài hỏng thì sao](/vi/docs/how-to/troubleshoot-install).

Trên Windows PowerShell, gọi `runner\flow.cmd` thay vì `bash`. `bash` trần trong PowerShell
thường ra WSL, không đọc được path `C:/...`, khiến bản cài đúng trông như hỏng.

Xác nhận hai số version (installer và skill) là độ sâu tùy chọn. Xem
[Hai số version](/vi/docs/how-to/troubleshoot-install/#two-version-numbers).

<details>
<summary>In cả hai số version</summary>

```bash
npx @manhquy/flow-skill@next --help
# expect: flow-skill v0.7.1-next.0 (ships skill v0.31.0)
```

Installer in version của chính nó và skill version nó ship. Rồi đọc skill version từ đĩa:

```bash
grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
```

Hai số đó đi độc lập. Đừng chép số từ trang này.

</details>

## Bước 4 — nói muốn build gì

Không bắt buộc học verb. Trong session agent mới, trong thư mục project, gõ:

> "Tôi muốn build app quản lý kho cho cửa hàng."

Hoặc gõ `/flow` (Codex: `$flow`).

Concierge chạy lệnh status trước để lấy ground truth cơ học, hỏi một câu đồng ý về ai soạn
artifact, rồi đề xuất đúng một hành động kế. Lệnh `/flow` tường minh luôn thắng routing chat.

Routing tin được trên Claude. Trên Codex hoặc Antigravity, coi chat routing là best-effort
và hãy gõ verb. Caveat đầy đủ nằm ở
[Vòng hằng ngày](/vi/docs/how-to/use-chat-concierge).

Thành công là một trong: status, việc kế, hoặc kết quả cổng. “Concierge bảo yes” không phải
chiến lợi phẩm duy nhất.

## Bạn đang có

- Skill đã cài trong ít nhất một agent home.
- Agent đã restart nên nhìn thấy skill.
- Một câu trả lời từ harness: status, việc kế, hoặc kết quả cổng.

## Tiếp

Đi một dự án thật qua mọi cổng planning trong
[Đi một dự án đủ](/vi/docs/tutorials/first-greenfield-project), hoặc đọc
[Harness hai lớp](/vi/docs/explanation/what-is-flow/#two-layer-harness) để hiểu thứ vừa
phán file.

## Xem cổng từ chối {#watch-a-gate-refuse}

Đây là độ sâu tùy chọn. Đây là demo xác định rằng lớp cơ học còn sống. Dừng tại cổng cũng
là kết quả hợp lệ.

<details id="watch-a-gate-refuse">
<summary>Transcript file Idea trống</summary>

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

Đây là cài đặt đang chạy đúng. Lớp cơ học đọc file, thấy ô chưa tick và `[FILL]` chưa điền,
exit khác 0 kèm số dòng. Nó không điền hộ, và sẽ không điền hộ.

</details>

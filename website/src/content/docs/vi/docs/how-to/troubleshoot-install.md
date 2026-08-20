---
title: "Khắc phục cài đặt"
description: "Sửa các fail cài flow thường gặp, rồi flag CLI, đường dẫn cài, biến môi trường, và hai số version."
lang: vi
---

Đi bảng này trước. Hầu hết báo cáo khớp một trong sáu hàng.

| Hiện tượng | Cách xử lý |
|---|---|
| Không có `/flow` sau `npm i` | Chạy `npx @manhquy/flow-skill@next`. Phải **execute** CLI; chỉ cài package không copy gì vào skill home. |
| Skill cũ sau “cài lại” | Dùng `@next` cho skill v0.31.0 (`@latest` vẫn ship 0.30.0 cho đến khi được promote). Tên package trần có thể lấy từ cache npx. |
| Claude hoặc Codex không list skill | Restart agent **một lần** sau cài lần đầu. |
| `flow.sh: No such file` trên PowerShell | Gọi `…/runner/flow.cmd`, không gọi `bash`. |
| `durable layer DISABLED` | Cài `python3`, hoặc bỏ qua: cổng cơ học vẫn chạy. |
| CRLF hoặc “bad interpreter” | Repo ép LF qua `.gitattributes`; clone lại nếu line ending bị méo. |

## Bắt đầu với doctor

```bash
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

`doctor` kiểm bash, python, grep, git và báo các path cài nó thấy. Kết quả `READY` nghĩa là môi trường ổn, vấn đề ở chỗ khác. Thường là agent chưa được restart.

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
# --help in cả hai số: installer CLI, rồi skill product nó ship

grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
```

Nếu skill trên đĩa đứng sau cái `--help` báo, bước copy không tới home đó. Chạy lại installer và chọn agent tường minh.

Hai lỗi pin gây hầu hết bản cũ:

- Pin version **skill product** trên npm. Số đó không phải version package npm đã publish. Pin version installer CLI, hoặc dùng `@next` cho skill hiện tại.
- Dùng tag `@rc`. Đã retire và cũ.

Nếu npm báo `No matching version found`, bạn đã pin số skill product. Dùng `@next` hoặc pin installer. Hai số và vì sao chúng khác nhau nằm ở [Hai số version](#two-version-numbers).

## Windows: PowerShell resolve nhầm bash

Trong PowerShell hoặc cmd, kể cả trong Codex, `bash` trần thường ra WSL tại `C:\WINDOWS\system32\bash.exe`. WSL không đọc path `C:/...` hoặc `/c/...`, nên fail `No such file or directory` và harness trông như hỏng khi không hỏng.

Dùng launcher, nó tìm Git Bash và truyền path Git Bash chấp nhận:

```powershell
& "$env:USERPROFILE\.codex\skills\flow\runner\flow.cmd" status
```

Chỉ gọi `bash flow.sh` trực tiếp khi đã xác nhận `bash` là Git Bash.

## “durable layer DISABLED”

Đây là chế độ suy giảm, không phải fail. Lớp bền vững là store Python cộng SQLite cho intake, story, trace, decision, backlog. Không có `python3` thì cổng cơ học và mọi check stage/card vẫn chạy. Bạn mất bộ nhớ xuyên session, nên `/flow recall` đọc lại ít hơn. Cài `python3` để bật lại.

## Vẫn kẹt

Thu thập ba thứ trước khi hỏi: output `doctor` đầy đủ, hai số version `--help` in ra, và lệnh đúng kèm chữ lỗi. Mở issue tại [github.com/manhquydev/flow-skill](https://github.com/manhquydev/flow-skill/issues).

## Đường cài đặt khác {#alternative-install}

Installer npm, `npx @manhquy/flow-skill@next`, là đường khuyến nghị cho skill v0.31.0. Các đường khác tồn tại cho contributor và máy air-gapped.

Từ git checkout:

```bash
bash install.sh global          # hoặc: pwsh install.ps1 global  trên Windows
bash install.sh project [dir]   # skill Claude theo project
```

`bash install.sh global` đồng bộ mọi agent home detect được và chạy bước doctor. `bash install.sh project [dir]` cài skill Claude theo project. Trên Windows dùng `pwsh install.ps1 global`, vì `bash` trần trong PowerShell thường là WSL và không đọc path Windows.

Claude Code cũng thêm kho làm plugin marketplace rồi cài `flow@flow-marketplace`.

Đường thủ công hoàn toàn là copy `skills/flow/` tới `~/.claude/skills/flow/` và `chmod +x runner/flow.sh`. Mọi kênh ghi cùng một cây, nên dự án đổi kênh mà không phải phát hành lại cổng hay card nào.

Lệnh và ghi chú nền tảng:
[`README_VN.md`](https://github.com/manhquydev/flow-skill/blob/master/README_VN.md)

## Flag CLI cài đặt {#install-cli-flags}

```bash
npx @manhquy/flow-skill@next
```

Cần [Node.js](https://nodejs.org/) **22.14 trở lên**. Dùng `@next` cho skill hiện tại;
`@latest` vẫn ship 0.30.0 cho đến khi được promote. Lệnh trần `npx @manhquy/flow-skill` có
thể lấy từ cache npx và chạy bản cũ.

Sao nguyên; đừng paraphrase nghĩa flag. `--project` chỉ áp cho `claude`.

```bash
npx @manhquy/flow-skill@next --yes
npx @manhquy/flow-skill@next --yes --target claude
npx @manhquy/flow-skill@next --yes -t claude -t codex
npx @manhquy/flow-skill@next --yes --all
npx @manhquy/flow-skill@next --yes --project --dir .
npx @manhquy/flow-skill@next --yes --all --dry-run --json
```

| Flag | Ý nghĩa |
|---|---|
| `-y`, `--yes` | Bỏ prompt; cài selection mặc định (detected + Claude) |
| `-t`, `--target <name>` | Target (lặp được hoặc comma-separated) |
| `--all` | Mọi target, kể cả chưa detect |
| `--project` | Scope project. Chỉ Claude → `<dir>/.claude/skills/flow` |
| `--dir <path>` | Thư mục project (kéo theo `--project`; mặc định: cwd) |
| `--json` | JSONL events (`plan`, `install:*`, `summary`) |
| `--dry-run` | In plan; không ghi đĩa |
| `-h`, `--help` | Help. `--help` in cả hai số version. |

`--project` **chỉ** hỗ trợ `claude`. Kết hợp target khác thì exit `2`.

| Nên | Không |
|---|---|
| `npx @manhquy/flow-skill@next` | Bare `npx @manhquy/flow-skill` (cache npx có thể cũ) |
| **Chạy** CLI để copy skill | Chỉ `npm i` (chỉ thêm package; không cài skill vào agent home) |
| Pin version installer nếu cần bản cố định | Pin version skill product trên npm |
| Ưu tiên `@next` cho skill hiện tại | `@rc` (đã retire / tụt hậu) |

Package: [`@manhquy/flow-skill` trên npm](https://www.npmjs.com/package/@manhquy/flow-skill).
Nghĩa flag được giữ cùng installer:
[`npm-wrapper/README_VN.md`](https://github.com/manhquydev/flow-skill/blob/master/npm-wrapper/README_VN.md).

## Đường dẫn cài đặt {#install-paths}

Installer copy cùng một cây skill vào mọi agent home bạn chọn. Không gì chia sẻ giữa các home. Mỗi cái là bản copy đầy đủ.

### Theo agent

| Agent | Path | Gọi |
|---|---|---|
| Claude Code | `~/.claude/skills/flow` (hoặc project-local `.claude/skills/flow`) | `/flow` |
| Codex CLI | `~/.codex/skills/flow` | `$flow`. Restart Codex sau cài |
| Agents home | `~/.agents/skills/flow` | theo host |
| Antigravity | `~/.gemini/antigravity-cli/skills/flow` (CLI) và `~/.gemini/config/skills/flow` (IDE) | `/flow` sau reload |
| Cursor | `~/.cursor/skills/flow` | panel agent skills sau reload |

Antigravity có hai home vì CLI và IDE đọc thư mục khác nhau. Cùng một bundle `SKILL.md` ở cả hai; chạy `agy inspect` để xác nhận đã được phát hiện.

### Bên trong một skill home

| Path | Nội dung |
|---|---|
| `SKILL.md` | Cửa lớp ngữ nghĩa: dispatch, gác cổng, orchestration. Mang `metadata.version`. |
| `runner/flow.sh` | Engine cơ học. `runner/flow.cmd` là launcher Windows. |
| `harness/` | Lớp bền vững (Python cộng SQLite). |
| `law/` | Luật phiên build `CLAUDE.md`, luật UI `DESIGN.md`, `RETRO.md`. |
| `references/` | Playbook ngữ nghĩa: luật cổng, Concierge, loại dự án, mapping agent, và nữa. |
| `_templates/` | Artifact có cổng mà runner copy vào dự án. Không sửa trong lúc chạy. |
| `playbooks/` | Tri thức stack. Đọc trước khi build trên stack đó, thu hoạch sau. |

### File dự án nằm đâu

Skill home giữ harness. **Dự án** của bạn giữ work, dưới thư mục bạn chạy từ:

```
flow/00-idea.md .. 05-contract.md   artifact planning, có cổng
cards/C-NNN.md                      đơn vị shipping
MODE, PROJECT_TYPE                  mode soạn và loại dự án
RETRO.md, DEBT.md, AUTO-LOG.md      sổ cái
DESIGN.md                           luật UI của dự án
.flow/harness.db                    bản ghi bền vững
```

Ghi đè root dự án bằng `FLOW_PROJECT_ROOT`. Chạy từ thư mục con không có `flow/` riêng thì nhận dự án flow tổ tiên gần nhất và in một dòng ra stderr, thay vì tạo root thứ hai bị mảnh.

### KB liên-dự-án

`/flow promote <playbook.md>` copy playbook tới `~/.claude/flow/playbooks`, nơi `/flow recall` hiện nó ở mọi dự án chứ không chỉ dự án nó tới từ.

### Phụ thuộc runtime

| Phụ thuộc | Cần cho |
|---|---|
| `bash` | Engine cơ học. Trên Windows nghĩa là Git Bash. Dùng `runner/flow.cmd`. |
| `python3` | Khuyến nghị. Nuôi harness bền vững. Thiếu nó, cổng vẫn chạy và lớp SQLite tắt. |
| `git` | Tùy chọn. Cần cho worktree và `/flow auto`. |
| Node.js ≥ 22.14 | Chỉ npm installer, không phải skill lúc chạy. |

### Xác nhận một home

```bash
grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

## Biến môi trường {#environment-variables}

Runner đọc một số biến `FLOW_*`. Đây là những cái được ghi cho dùng hằng ngày; tập đầy đủ định nghĩa trong nguồn runner.

| Biến | Hiệu lực |
|---|---|
| `FLOW_PROJECT_ROOT` | Ghi đè root dự án thay vì dựa vào walk thư mục. |
| `FLOW_SESSION_ID` | Id session ổn định. Export một lần mỗi session và truyền vào mọi lời gọi để được bảo vệ concurrency cứng thay vì cảnh báo. |
| `FLOW_LOCK_TTL` | Số giây trước khi `flow/.lock` tự reclaim. Mặc định 900. |
| `FLOW_FORCE` | Đặt `1` để chiếm lock bạn chắc chắn đã chết. |
| `FLOW_LOG_DISABLE` / `DO_NOT_TRACK` | Tắt usage-log JSONL cục bộ mà `/flow usage` tổng hợp. Log chỉ cục bộ dù sao. |
| `FLOW_EVAL_RETRY_BACKOFF` | Backoff retry tính bằng giây cho batch eval tính phí. Mặc định 5; đặt 0 trong test. |

Không có `FLOW_SESSION_ID` thì runner không chứng minh được session cạnh tranh là khác, nên nó cảnh báo chứ không chặn. Đó là lý do export nó quan trọng trên máy dùng chung.

Định nghĩa có thẩm quyền:
[`skills/flow/runner/flow.sh`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/runner/flow.sh)

## Hai số version {#two-version-numbers}

`flow` publish hai số version, và chúng không khớp. Đó là chủ đích, không phải drift. `--help` in cả hai số. Kiểm chúng từ máy của bạn chứ không từ tài liệu nào.

| Cái gì | Nó version cái gì |
|---|---|
| **Skill product** | Các cổng, `SKILL.md`, runner, references, templates: thứ phán build của bạn. Nằm trong metadata `SKILL.md`. |
| **npm installer** | CLI `@manhquy/flow-skill` copy skill vào agent home. Nằm trên package npm. |

```bash
npx @manhquy/flow-skill@next --help
# flow-skill v0.7.1-next.0 (ships skill v0.31.0)

grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
```

### Vì sao hai số

Chúng version artifact khác nhau với nhịp đổi khác nhau.

```
  monorepo skills/flow/  --npm run sync-->  npm-wrapper/skills/flow  --npm pack-->  registry
         |                                         |
         | install.sh / agent skill homes          | npx @manhquy/flow-skill@latest
         v                                         v
  ~/.claude/skills/flow                     same tree via installer CLI
```

Skill product là harness. Version của nó dẫn check coherence và trường telemetry ghi trong lớp bền vững, nên dự án luôn nói được ngữ nghĩa cổng nào nó được build dưới. Nó đổi mỗi khi cổng, stage, hoặc playbook tham chiếu đổi, nghĩa là thường xuyên.

Package npm chỉ version **installer CLI**: detect agent, multi-select tương tác, file copy đi đâu, các flag. Bề mặt đó nhỏ và ổn định. Publish installer version mới vì luật cổng đổi sẽ nói dối về cái gì đã đổi, và buộc user lý luận về một số không nói gì với họ.

Gộp hai số nghĩa là hoặc bump installer mỗi lần đổi cổng, hoặc đóng băng version cổng theo nhịp phát hành installer. Cả hai tệ hơn giải thích một bảng.

### Sai lầm chuyện này gây ra, và cách tránh

Mode fail là pin nhầm số. Version skill product không phải version package npm đã publish. Pin installer CLI nếu cần bản cố định. Hiện tại skill mới nhất nằm trên `@next`.

```bash
# Sai: pin version skill product (không phải version package npm)
# Đúng: pin version installer CLI, hoặc dùng @next cho skill hiện tại
npx @manhquy/flow-skill@next
```

Hiện skill mới nhất nằm trên `@next` (`0.7.1-next.0` ship skill `0.31.0`). `@latest` vẫn ship installer `0.7.0` / skill `0.30.0` cho đến khi được promote. Lệnh trần `npx @manhquy/flow-skill` có thể lấy từ cache npx và âm thầm chạy bản cũ. Tag `@rc` đã retire; đừng dùng.

Nếu npm báo `No matching version found`, gần như chắc bạn đã pin số skill product. `--help` in cả hai số; pin số installer.

### Số nào quan trọng với bạn

Nếu bạn **dùng** flow, skill product là số mô tả trải nghiệm: nó nói bạn có cổng nào và lệnh nào. Version installer chỉ quan trọng khi debug lần cài hoặc pin một bản.

Nếu bạn **báo vấn đề**, đưa cả hai. `--help` in chúng cùng một dòng, đó là lý do dòng đó tồn tại.

### Kiểm drift trong một dự án

```
/flow coherence
```

Gắn cờ lệch version giữa các trường version khai báo: lát cắt doc-versus-code rẻ của lattice drift. Chỉ cảnh báo: gắn cờ, không tự sửa.

---

[Cài đặt và lần chạy đầu](/vi/docs/tutorials/install-and-first-run) ·
[Nhật ký thay đổi](/vi/docs/reference/changelog)

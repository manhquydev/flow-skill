---
title: "Đường dẫn cài đặt"
description: "Skill flow rơi vào đâu theo từng agent, cách gọi, và phụ thuộc runtime mỗi path cần."
lang: vi
---

Installer copy cùng một cây skill vào mọi agent home bạn chọn. Không gì chia sẻ giữa các home — mỗi cái là bản copy đầy đủ.

## Theo agent

| Agent | Path | Gọi |
|---|---|---|
| Claude Code | `~/.claude/skills/flow` (hoặc project-local `.claude/skills/flow`) | `/flow` |
| Codex CLI | `~/.codex/skills/flow` | `$flow` — restart Codex sau cài |
| Agents home | `~/.agents/skills/flow` | theo host |
| Antigravity | `~/.gemini/antigravity-cli/skills/flow` (CLI) và `~/.gemini/config/skills/flow` (IDE) | `/flow` sau reload |
| Cursor | `~/.cursor/skills/flow` | panel agent skills sau reload |

Antigravity có hai home vì CLI và IDE đọc thư mục khác nhau. Cùng một bundle `SKILL.md` ở cả hai; chạy `agy inspect` để xác nhận đã được phát hiện.

## Bên trong một skill home

| Path | Nội dung |
|---|---|
| `SKILL.md` | Cửa lớp ngữ nghĩa: dispatch, gác cổng, orchestration. Mang `metadata.version`. |
| `runner/flow.sh` | Engine cơ học. `runner/flow.cmd` là launcher Windows. |
| `harness/` | Lớp bền vững (Python cộng SQLite). |
| `law/` | Luật phiên build `CLAUDE.md`, luật UI `DESIGN.md`, `RETRO.md`. |
| `references/` | Playbook ngữ nghĩa: luật cổng, Concierge, loại dự án, mapping agent, và nữa. |
| `_templates/` | Artifact có cổng mà runner copy vào dự án. Không sửa trong lúc chạy. |
| `playbooks/` | Tri thức stack — đọc trước khi build trên stack đó, thu hoạch sau. |

## File dự án nằm đâu

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

## KB liên-dự-án

`/flow promote <playbook.md>` copy playbook tới `~/.claude/flow/playbooks`, nơi `/flow recall` hiện nó ở mọi dự án chứ không chỉ dự án nó tới từ.

## Phụ thuộc runtime

| Phụ thuộc | Cần cho |
|---|---|
| `bash` | Engine cơ học. Trên Windows nghĩa là Git Bash — dùng `runner/flow.cmd`. |
| `python3` | Khuyến nghị. Nuôi harness bền vững. Thiếu nó, cổng vẫn chạy và lớp SQLite tắt. |
| `git` | Tùy chọn. Cần cho worktree và `/flow auto`. |
| Node.js ≥ 22.14 | Chỉ npm installer, không phải skill lúc chạy. |

## Xác nhận một home

```bash
grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

## Xem thêm

- [CLI cài đặt](/vi/docs/reference/install-cli)
- [Đường cài đặt khác](/vi/docs/how-to/alternative-install)
- [Khắc phục cài đặt](/vi/docs/how-to/troubleshoot-install)

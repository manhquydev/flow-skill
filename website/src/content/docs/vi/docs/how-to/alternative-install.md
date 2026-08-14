---
title: "Đường cài đặt khác"
description: "Cài flow từ git checkout, như plugin Claude, hoặc bằng tay khi npm không phải kênh đúng."
lang: vi
---

Installer npm, `npx @manhquy/flow-skill@latest`, là đường khuyến nghị cho mọi người. Các đường khác tồn tại cho contributor và máy air-gapped. Từ git checkout, `bash install.sh global` đồng bộ mọi agent home detect được và chạy bước doctor, còn `bash install.sh project [dir]` cài skill Claude theo project; trên Windows dùng `pwsh install.ps1 global`, vì `bash` trần trong PowerShell thường là WSL và không đọc path Windows. Claude Code cũng thêm kho làm plugin marketplace rồi cài `flow@flow-marketplace`. Đường thủ công hoàn toàn là copy `skills/flow/` tới `~/.claude/skills/flow/` và `chmod +x runner/flow.sh`. Mọi kênh ghi cùng một cây, nên dự án đổi kênh mà không phải phát hành lại cổng hay card nào.

Lệnh và ghi chú nền tảng:
[`README_VN.md`](https://github.com/manhquydev/flow-skill/blob/master/README_VN.md)

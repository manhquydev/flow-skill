---
title: "Chạy auto-build"
description: "Lái pha build tự động với xử lý theo tier, và biết chỗ nào nó dừng chờ bạn."
lang: vi
---

`/flow auto` preflight một lần chạy tự động và, nếu preflight pass, bật chính sách auto dùng chung; `/flow auto stop` trả bạn về thủ công. Preflight fail-closed: mọi card phải có rủi ro đã phân loại — nhóm bảo mật cần xác nhận tác giả khác trong `DEBT.md` — và stage 05 phải mang semantic receipt hiện hành. Mỗi card vòng là phân tier, build trong worktree cô lập với subagent có phạm vi, review đối kháng, biên nhận, `check`, merge, deploy, verify live, bằng chứng thế giới thật, rồi done cộng trace bền vững. Card xanh Tier-A auto-merge; Tier-B được một lần sửa bởi subagent mới; work nhóm bảo mật Tier-C HALT để bạn chấp nhận phơi nhiễm bằng văn bản. Trần cứng về iteration, token, và thời gian là bắt buộc, và mọi cổng quyết trên tín hiệu cơ học chứ không phải tự đánh giá của agent.

Tier, vòng worktree, `AUTO-LOG.md`, và điều kiện HALT:
[`skills/flow/references/auto-run.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/auto-run.md)

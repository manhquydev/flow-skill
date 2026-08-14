---
title: "Tầng auto và halt bảo mật"
description: "Vì sao lần chạy tự động xếp work thành ba tier, và vì sao tier thứ ba dừng chờ người."
lang: vi
---

Tự chủ trong `flow` không phải tất-cả-hoặc-không; nó được xếp tier theo giá một câu trả lời sai. Tier-A là card xanh không phơi nhiễm bảo mật, và nó auto-merge không hỏi, vì đòi người duyệt work mà mọi cổng đã pass chỉ huấn luyện người bấm approve. Tier-B là rắc rối sửa được, và nó nhận đúng một lần sửa bởi subagent *mới* — luật two-strikes — trước khi escalate; mới quan trọng vì agent viết bug là agent kém nhất thấy bug. Khi lần sửa cần thử nghiệm lặp lại theo một mục tiêu số chứ không phải bất đồng review, protocol loop mới là tool đúng.

Tier-C là work nhóm bảo mật — authentication, authorization, phơi nhiễm admin, tenancy, payments, data migration, gỡ validation — và nó **HALT**. Operator chấp nhận phơi nhiễm bằng văn bản trong `DEBT.md`; không bao giờ là quyết định của planner. Lý do là bất đối xứng: merge Tier-A sai tốn một revert, merge Tier-C sai có thể tốn dữ liệu hoặc một tài khoản. Cạnh các tier là hard stop về iteration, token, và thời gian, và mọi cổng quyết trên tín hiệu cơ học — exit code thật, lần verify thật, check live — không bao giờ tự đánh giá của agent.

Định nghĩa tier, vòng worktree, và điều kiện HALT:
[`skills/flow/references/auto-run.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/auto-run.md)

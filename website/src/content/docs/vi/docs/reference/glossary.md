---
title: "Thuật ngữ"
description: "Các thuật ngữ flow dùng, định nghĩa một lần."
lang: vi
---

| Thuật ngữ | Nghĩa |
|---|---|
| **Cổng** | Checklist phải thỏa trung thực trước khi stage hoặc card tiến. Chỉ pass khi lớp cơ học và lớp ngữ nghĩa đồng ý. |
| **Lớp cơ học** | `runner/flow.sh`, engine bash xác định exit 0 hoặc 1. Ground truth. |
| **Lớp ngữ nghĩa** | Model đọc `SKILL.md`, phán cái script không phán được: research bịa, scope dìm hạng, bằng chứng rỗng. |
| **Lớp bền vững** | Store Python và SQLite giữ bản ghi intake, story, trace, decision, backlog xuyên session. |
| **Stage** | Một bước planning có cổng, `00-idea` tới `05-contract`, mỗi cái đẻ file dưới `flow/`. |
| **Card** | Một phiên build có phạm vi, `cards/C-NNN.md`, với allowed files, verify, independent test, và evidence. |
| **Contract** | Stage 05, seam giữa bên sản xuất và bên tiêu thụ. Viết trước code, không bao giờ skip được. |
| **Bằng chứng done** | Bằng chứng thế giới thật rằng card đã xong: URL live, lần gọi thật, API đã import, lần chạy skill thật. Không bao giờ “tests pass”. |
| **Debt** | Skip cổng có chủ đích đã ghi trong `DEBT.md`, kèm phơi nhiễm và điều kiện đóng. |
| **Security-class** | Auth, authorization, phơi nhiễm admin, tenancy, payments, data migration, gỡ validation. HALT lần chạy tự chủ; chỉ operator. |
| **Mode teach / work** | Ai viết artifact planning — bạn, hoặc agent. Cổng ràng buộc giống nhau. |
| **Loại dự án** | `web`, `cli`, `library`, hoặc `skill`. Chọn seam contract và luật bằng chứng done. |
| **Concierge** | Cửa chat định tuyến tiếng thường qua state cơ học tới đúng một hành động đề xuất. |
| **Drift check** | Check cố vấn gắn cờ bất đồng giữa artifact: coherence, contract, tokens, consistency. |
| **Attestation** | Biên nhận gắn fingerprint chứng minh một subject đã review hoặc đã verify cụ thể, bị lần chạy tự chủ tiêu thụ. |
| **Kill** | Bỏ cuộc tại một cổng. Kết quả hợp lệ, được tôn trọng. |
| **Two-strikes** | Card bị chặn nhận một lần sửa bởi subagent mới trước khi escalate. |
| **Playbook** | Tri thức stack đã trả giá, đọc trước khi build trên stack đó và thu hoạch sau. `/flow promote` chia sẻ xuyên dự án. |

Định nghĩa chuẩn sống cùng skill:
[`skills/flow/SKILL.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/SKILL.md)

---
title: "Điều phối agent"
description: "Stage ủy thác cho agent chuyên khi chúng tồn tại và rơi về hành vi built-in khi không — cổng không bao giờ dịch."
lang: vi
---

Mỗi stage có thể ủy thác phần soạn cho agent chuyên, và rơi về hành vi built-in khi không cái nào được cài, đó là thứ giữ `flow` portable chứ không phụ thuộc registry agent của ai khác. Thang ưu tiên là agent chuyên trước, rồi skill tương đương, rồi fallback built-in. Bản đồ stage gần đúng như bạn kỳ vọng: research tới researcher, scope và PRD tới planner, ADR tới architect, contract tới kernel hướng spec, build tới fullstack developer, review tới code reviewer hoặc review đối kháng ba lớp, verify live tới tester.

Luật làm chuyện này an toàn là một câu: **agent gắn vào được, cổng cố định.** Cổng giống nhau trên mọi path, nên agent thiếu không bao giờ hạ thanh và agent fancy không bao giờ nâng pass nó không đáng. Ủy thác cũng cô lập ngữ cảnh by design — subagent chỉ nhận task, file, tiêu chí chấp nhận, và trích law hoặc contract liên quan, không bao giờ lịch sử session — và trả một trong một tập nhỏ phán. Sau mọi ủy thác cổng chạy, thử thách ngữ nghĩa được áp, hook bền vững được ghi, và path nào thực sự chạy được thông báo.

Bản đồ stage-tới-agent, template prompt, và hook bền vững:
[`skills/flow/references/agent-stage-mapping.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/agent-stage-mapping.md)

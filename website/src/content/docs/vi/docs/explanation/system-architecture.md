---
title: "Kiến trúc hệ thống"
description: "Ba lớp cùng làm việc, artifact trên đĩa, và hai kênh phân phối."
lang: vi
---

`flow` được xây thành ba lớp cùng làm việc cộng artifact trên đĩa, để engine xác định nhanh xử lý phần cơ học gian được trong khi model xử lý phán đoán và bản ghi bền vững sống sót qua session. Lớp ngữ nghĩa là `SKILL.md` và playbook tham chiếu. Nó gọi lớp cơ học, `runner/flow.sh`, exit code là ground truth, và sở hữu vòng đời stage cùng card, kiểm cổng, sổ cái debt, kiểm design, và passthrough harness. Bên dưới, lớp bền vững là CLI Python và SQLite do flow sở hữu, giữ intake và risk lane, story và proof, trace và tier, decision, backlog; nó suy giảm lịch sự khi thiếu Python. Bản thân artifact sống trong dự án đang được build: `flow/00-idea.md` tới `05-contract.md`, `cards/C-NNN.md`, file mode và sổ cái, và `.flow/harness.db`.

Phân phối là hai kênh song song nuôi cùng một cây chuẩn. Installer npm là đường chính, thuần Node không đòi shell, và script cài trong kho là implementation tham chiếu dùng lúc phát triển và CI. Cả hai ghi cùng skill home, nên dự án đổi kênh mà không phải phát hành lại cổng.

Sơ đồ đầy đủ và bảng thành phần:
[`docs/system-architecture.md`](https://github.com/manhquydev/flow-skill/blob/master/docs/system-architecture.md)

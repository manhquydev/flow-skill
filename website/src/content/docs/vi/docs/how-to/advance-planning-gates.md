---
title: "Vượt cổng planning"
description: "Dùng /flow next để đi stage 00 tới 05, và đọc lần cổng fail mà không đoán."
lang: vi
---

`/flow next` kiểm cổng stage bạn đang đứng và, chỉ khi pass, mở stage kế. Khi lớp cơ học fail nó in đúng cái sai kèm số dòng — ô cổng chưa tick, `[FILL]` còn sót — rồi dừng. Sửa trong file rồi chạy lại. Khi script pass, thử thách ngữ nghĩa của stage vừa xong được áp trước khi bạn được phép đi tiếp, nên artifact sạch cơ học nhưng rỗng vẫn bị gọi là yếu. Ở mode `teach` agent không bao giờ tick ô hoặc viết artifact hộ bạn; nó chỉ nói cái gì đang fail.

Thứ tự stage, điều kiện mở, và mỗi artifact phải chứa gì:
[`skills/flow/references/stage-state-machine.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/stage-state-machine.md)

---
title: "Build dự án CLI hoặc skill"
description: "Đặt loại dự án để seam contract, trình tự card, và bằng chứng done khớp CLI hoặc agent skill thay vì web app."
lang: vi
---

`flow` sinh ra theo hình web, nên việc đầu tiên trên lần build CLI hoặc skill là `/flow project-type cli` hoặc `/flow project-type skill`. Loại đổi ba thứ: stage 05 contract mô tả gì, trình tự card chuẩn, và cái gì được tính là done. Với CLI, contract là lệnh, flag, shape output và exit code, và done nghĩa là tool cài được và một lần gọi thật trả output và exit code đúng. Với skill, contract là bề mặt lệnh và file mà agent đọc, và done nghĩa là đã cài vào skill home và một lần chạy thật đạt done-definition của chính nó. Bản thân các cổng không đổi — chỉ hình của bằng chứng dịch chuyển.

Thích nghi theo loại, trình tự card, và ghi chú wording cổng:
[`skills/flow/references/project-types.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/project-types.md)

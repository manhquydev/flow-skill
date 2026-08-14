---
title: "Đổi chế độ teach và work"
description: "Chọn ai viết artifact planning. Cổng ràng buộc giống nhau cả hai cách."
lang: vi
---

`/flow mode teach` và `/flow mode work` đặt mode soạn, lưu trong file `MODE`, mặc định `teach`. Ở `teach` bạn viết mọi artifact planning và agent chỉ gác cổng, bắt nội dung rỗng hoặc bịa; bị cấm tick ô hoặc soạn hộ. Ở `work` agent phỏng vấn bạn một lần, tự soạn stage 00 tới 05, chỉ dừng để duyệt scope, rồi giao bộ card thành một tóm tắt. Cổng và luật done giống nhau cả hai — mode `work` đổi người soạn, không bao giờ đổi thanh.

Kịch bản phỏng vấn work-mode và hình bàn giao:
[`skills/flow/references/mode-work.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/mode-work.md)

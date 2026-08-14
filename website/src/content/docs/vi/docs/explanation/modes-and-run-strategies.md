---
title: "Chế độ và chiến lược chạy"
description: "Bốn trục mode độc lập — soạn thảo, loại dự án, chế độ chạy, và greenfield versus brownfield — phối hợp tự do."
lang: vi
---

`flow` có bốn trục mode và chúng thật sự độc lập, nên bạn đặt từng cái theo dự án rồi kết hợp theo nhu cầu work. **Mode soạn** quyết ai viết artifact ở cổng: `teach`, mặc định, nghĩa là bạn viết và agent chỉ gác cổng; `work` nghĩa là agent phỏng vấn một lần, soạn stage 00 tới 05, chỉ dừng để duyệt scope. **Loại dự án** quyết done nghĩa là gì — URL live cho web, lần gọi thật và exit code cho CLI, API import được cho library, lần chạy đã cài cho skill. **Chế độ chạy** quyết card được build thế nào: thủ công, bạn lái card, build, check; hoặc auto, lần chạy tự động xử lý theo tier và HALT với work nhóm bảo mật. **Greenfield versus brownfield** quyết bạn bắt đầu đâu: stage 00-idea cho thứ mới, hoặc bản đánh giá hiện trạng có cổng cho codebase có sẵn.

Không trục nào đổi thanh. Cổng và luật done giống nhau mọi tổ hợp; mode dịch người soạn, hình bằng chứng, và cách lái, không bao giờ chiều cao cổng.

Kịch bản work-mode và biên mode:
[`skills/flow/references/mode-work.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/mode-work.md)

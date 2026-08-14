---
title: "Đặt loại dự án"
description: "Chọn web, cli, library, hoặc skill để seam contract và bằng chứng done khớp thứ bạn đang build."
lang: vi
---

`/flow project-type web|cli|library|skill` đặt loại, lưu trong file `PROJECT_TYPE`, mặc định `web`; chạy không đối số in giá trị hiện tại và luật bằng chứng done nó kéo theo. Đặt trước stage 05, vì loại quyết định contract mô tả gì — HTTP endpoint cho web, lệnh và exit code cho CLI, bề mặt API export cho library, bề mặt lệnh agent đọc cho skill — và quyết định bằng chứng cổng card sẽ đòi lúc cuối. Đổi sau nghĩa là phải xem lại contract, nên rẻ bây giờ và đắt sau.

Seam theo loại, trình tự card, và bằng chứng done:
[`skills/flow/references/project-types.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/project-types.md)

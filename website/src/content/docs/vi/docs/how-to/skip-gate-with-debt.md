---
title: "Bỏ cổng bằng nợ"
description: "Vượt một cổng thật sự không khớp, bằng cách ghi phơi nhiễm thành debt trước."
lang: vi
---

Skip là hợp lệ; skip lặng lẽ thì không. Ghi phơi nhiễm bằng `/flow debt add "skip 01-research" "<exposure>" "<close-before condition>"`, rồi `/flow skip 01-research --reason "…"`. Skip chỉ tiến khi dòng debt mở nêu đúng stage đó và lý do không thuộc nhóm bảo mật, và `planning_complete` khi đó chịu stage đó nên card không bị chặn mãi. Ba hàng rào theo thứ tự: stage 05, contract, không bao giờ skip được — thích nghi theo loại dự án thay vì skip; lý do nhóm bảo mật như auth, tenancy, payments, permissions, hoặc data migration HALT để operator chấp nhận bằng văn bản; và dòng debt mở không liên quan không mở gì cả.

Sổ cái debt, luật HALT nhóm bảo mật, và khi nào một lần chạy dừng:
[`skills/flow/references/debt-and-halts.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/debt-and-halts.md)

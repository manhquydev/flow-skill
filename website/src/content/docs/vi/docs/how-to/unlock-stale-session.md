---
title: "Mở khóa phiên cũ"
description: "Xóa flow/.lock do session crash để lại, mà không giẫm lên session còn sống."
lang: vi
---

`flow` cho một session mỗi dự án, vì hai session chia một plan sẽ ghi đè state của nhau. Runner giữ `flow/.lock`: lệnh mutate như `next`, `card`, `skip`, và `auto` từ chối lock ngoại lai mới, `status` cảnh báo, và lock tự reclaim sau TTL — mặc định 900 giây. Nếu terminal crash hoặc session bị bỏ, `/flow unlock` xóa nó. Nếu session kia có thể còn sống, dừng và phối hợp; đừng force qua session đang chạy. Để bảo vệ cứng thay vì cảnh báo, export `FLOW_SESSION_ID` ổn định một lần mỗi session và truyền vào mọi lời gọi — không có nó runner không chứng minh được session khác đang chạy, nên chỉ cảnh báo và không bao giờ tự chặn.

Ngữ nghĩa lock và override môi trường:
[`skills/flow/SKILL.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/SKILL.md)

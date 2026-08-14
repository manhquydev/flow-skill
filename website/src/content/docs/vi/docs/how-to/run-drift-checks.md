---
title: "Chạy kiểm drift"
description: "Bốn check cố vấn gắn cờ cách tài liệu và code lặng lẽ ngừng khớp."
lang: vi
---

`/flow contract`, `/flow tokens`, `/flow coherence`, và `/flow consistency` mỗi cái gắn cờ một trục drift và không bao giờ tự sửa. `contract` bắt lệch base-URL client versus prefix path server — lớp double-`/api`, mixed-prefix mà tool diff schema bỏ sót. `tokens` so token khai báo trong `DESIGN.md` với CSS thực dùng, báo token chưa dùng, lệch giá trị, và biến orphan. `coherence` gắn cờ lệch version giữa các trường version khai báo, lát cắt doc-versus-code rẻ. `consistency` audit artifact còn truy vết tới nhau không: mọi requirement PRD được một card claim và một interface contract phục vụ, success metric có số, không còn placeholder. Chạy hai cái cuối sau cổng contract và trước khi cắt card.

Mô tả và khi nào chạy từng cái:
[`README_VN.md`](https://github.com/manhquydev/flow-skill/blob/master/README_VN.md)

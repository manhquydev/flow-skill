---
title: "Lệnh drift"
description: "Bốn check drift cố vấn và trục mỗi cái phủ."
lang: vi
---

Cả bốn gắn cờ và không bao giờ tự sửa. Cùng nhau chúng tạo lattice: version, URL, design token, và artifact còn truy vết tới nhau không.

| Lệnh | Trục | Nó báo gì |
|---|---|---|
| `/flow coherence` | version | Lệch version giữa các trường version khai báo — lát cắt doc-versus-code rẻ |
| `/flow contract` | URL | Lệch base-URL client versus prefix path server, lớp double-`/api` và mixed-prefix (web) |
| `/flow tokens` | design | Token khai báo trong `DESIGN.md` đối với CSS thực dùng: token chưa dùng, lệch giá trị, biến orphan |
| `/flow consistency` | truy vết | Mỗi `FRn` trong PRD được một card claim và một interface contract phục vụ, success metric có số, không còn placeholder |

`/flow design <file>` là kiểm cơ học liên quan trên một file UI chứ không phải quét cả dự án. Chạy `consistency` và `coherence` sau cổng contract và trước khi cắt card; chạy `contract` và `tokens` lúc build các bề mặt chúng mô tả.

Mô tả và thời điểm:
[`README_VN.md`](https://github.com/manhquydev/flow-skill/blob/master/README_VN.md)

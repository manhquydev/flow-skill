---
title: "Lệnh phụ harness"
description: "CLI lớp bền vững tới qua /flow harness: intake, story, trace, decision, backlog, query, audit, propose."
lang: vi
---

`/flow harness <args>` là passthrough xuống lớp bền vững, CLI Python và SQLite do flow sở hữu, lưu thứ sống sót giữa các session.

| Subcommand | Mục đích |
|---|---|
| `intake` | Ghi yêu cầu vào với type, tóm tắt, và cờ; cờ rủi ro như auth tự nâng lane |
| `story` | Theo dõi một đơn vị work và bằng chứng của nó. Hoàn tất bằng `story complete --proof-source …` |
| `trace` | Bản ghi được chấm tier viết khi check card pass |
| `decision` | Ghi một quyết định rồi đóng vòng sau với kết quả thực tế |
| `backlog` | Backlog cải tiến mà `propose` ghi vào |
| `query` | Đọc bản ghi lại |
| `audit` | Chấm entropy và drift trong bản ghi tích lũy |
| `propose` | Đào friction và can thiệp lặp thành mục backlog; xác định, bắn khi từ hai lần trở lên |

Hầu hết những cái này engine viết hộ bạn — tiến một stage seed một intake, lần check pass ghi một trace — nên bề mặt thủ công chủ yếu là đọc. Lớp này tùy chọn: thiếu `python3` thì cổng vẫn chạy và chỉ store này tắt.

Schema, flag, và bảng quyền hạn live:
[`skills/flow/harness/README.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/harness/README.md)

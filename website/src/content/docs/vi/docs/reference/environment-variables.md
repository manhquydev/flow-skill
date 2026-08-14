---
title: "Biến môi trường"
description: "Override môi trường bạn hay cần nhất: root dự án, danh tính session, khóa, và telemetry."
lang: vi
---

Runner đọc một số biến `FLOW_*`. Đây là những cái được ghi cho dùng hằng ngày; tập đầy đủ định nghĩa trong nguồn runner.

| Biến | Hiệu lực |
|---|---|
| `FLOW_PROJECT_ROOT` | Ghi đè root dự án thay vì dựa vào walk thư mục. |
| `FLOW_SESSION_ID` | Id session ổn định. Export một lần mỗi session và truyền vào mọi lời gọi để được bảo vệ concurrency cứng thay vì cảnh báo. |
| `FLOW_LOCK_TTL` | Số giây trước khi `flow/.lock` tự reclaim. Mặc định 900. |
| `FLOW_FORCE` | Đặt `1` để chiếm lock bạn chắc chắn đã chết. |
| `FLOW_LOG_DISABLE` / `DO_NOT_TRACK` | Tắt usage-log JSONL cục bộ mà `/flow usage` tổng hợp. Log chỉ cục bộ dù sao. |
| `FLOW_EVAL_RETRY_BACKOFF` | Backoff retry tính bằng giây cho batch eval tính phí. Mặc định 5; đặt 0 trong test. |

Không có `FLOW_SESSION_ID` thì runner không chứng minh được session cạnh tranh là khác, nên nó cảnh báo chứ không chặn — đó là lý do export nó quan trọng trên máy dùng chung.

Định nghĩa có thẩm quyền:
[`skills/flow/runner/flow.sh`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/runner/flow.sh)

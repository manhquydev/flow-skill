---
title: "Bật review Codex"
description: "Thêm OpenAI Codex làm engine thứ hai tùy chọn cho review, và hiểu đánh đổi chi phí cùng dữ liệu trước."
lang: vi
---

Khi plugin `openai-codex` đã cài và authenticated, `flow` có thể định tuyến vài thời điểm giá trị cao tới vendor thật sự khác. Nó phân biệt *installed* với *usable*: installed nghĩa là thư mục agent hoặc plugin có mặt, usable thêm đòi probe rẻ không tính phí báo ready và đã login. Chỉ engine usable mới được route tới; nếu không `flow` degrade lặng-mà-có-báo về thang bình thường, nên vắng mặt không bao giờ làm hỏng lần chạy. Vì lời gọi Codex tính phí, đúng ba trigger mở cổng: deadlock two-strikes khi agent cùng-model bị chặn hai lần, review card nhóm bảo mật, và operator opt-in tường minh. Gate parity tuyệt đối — Codex soạn hoặc phê, và cùng cổng stage vẫn phán; review cross-model hỗ trợ triage và không bao giờ tự pass hoặc tự fail một card. Đọc ranh giới tin cậy trước khi bật trên code nhạy cảm: authentication giao hoàn toàn cho plugin, và chọn Codex gửi diff cùng trích contract hoặc PRD tới OpenAI theo điều khoản retention của gói bạn.

Detect, cost gate, hình kết quả, và ranh giới tin cậy:
[`skills/flow/references/codex-integration.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/codex-integration.md)

---
title: "Bật review Antigravity"
description: "Thêm Google Antigravity làm engine thứ ba tùy chọn, và vì sao review của nó chạy interactive mặc định."
lang: vi
---

Antigravity, qua CLI `agy` hoặc IDE Antigravity, là engine thứ ba khác hãng, dùng cùng thời điểm giá trị cao như Codex để một lần review được phán bởi ba model ít khi chung điểm mù. Nó nhận check usable nghiêm nhất trong mọi tầng vì lý do đo được: `agy -p` trả exit code 0 với stdout rỗng ngay cả khi chưa authenticated, lỗi chỉ nằm trong file log. Nên `flow` chỉ route sang Antigravity khi output mong đợi không rỗng, không bao giờ dựa exit code — exit code nói dối. Vì capture headless không đáng tin, mặc định được hỗ trợ là interactive — chạy review trong IDE Agent Manager hoặc terminal thật rồi dán kết quả lại. Kết quả Gemini rỗng nghĩa là “review không sẵn” và không bao giờ là duyệt. Cùng cost gate tính phí và dữ liệu rời máy, cùng gate parity tuyệt đối, áp như với Codex.

Home cài, check usable, và hình review:
[`skills/flow/references/antigravity-integration.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/antigravity-integration.md)

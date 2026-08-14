---
type: brainstorm
date: 2026-08-14
topic: vi-voice-semantics
status: accepted
---

# Brainstorm — tiếng Việt trên site: ngữ nghĩa, cách dùng, mạch nói

Tiếp `advise-260814-0910-vi-voice.md`. Phần (b): khóa contract nghiên cứu trước khi ai viết lại `/vi/`.

## Outcome

Có một bộ luật tiếng Việt (cách dùng, ngữ nghĩa, mạch lạc, thuật ngữ) đủ để **sau này** viết lại landing + 15 trang full mà không dịch câu Anh, không telegram, không bịa metaphor. Operator vẫn là người viết vàng first viewport. Agent chỉ được bung từ vàng + luật này.

## Constraints

- Operator đọc được tiếng Việt có dấu; không đọc được English. Báo cáo và luật viết bằng tiếng Việt.
- `/vi/` giữ lên. Không rewrite copy trong phiên nghiên cứu này.
- Hai pass agent trước đã fail: calque (dịch slot) rồi telegram (rút ngắn cho punch). Cấm lặp.
- EN = danh sách claim, không phải khuôn câu.
- Khóa từ: **cổng**, **card**, **bằng chứng done**. Lệnh và tên file giữ tiếng Anh.
- Cấm khung đã bị reject: chạy / lớp / cơ học (như metaphor trưng bày), “thẻ”, bỏ dấu.
- 31 stub để nguyên.
- Root `DESIGN.md` không đụng. Layout Galley giữ.

## Non-goals

- Không viết vàng hộ operator.
- Không khóa voice bible / glossary mới trước trang vàng.
- Không dịch lại EN landing.
- Không “dịch hay hơn” từng câu hiện tại.
- Không đụng DNS / domain (phần a).
- Không commit.

## Acceptance

- Báo cáo research có: chẩn đoán copy hiện tại, ngữ nghĩa từng thuật ngữ khóa, luật mạch nói, bảng DNT vs dịch, luật theo loại trang (landing / giải thích / how-to / reference).
- Có hướng làm việc sau vàng, không có câu trưng bày để ship.
- Test 60 giây vẫn của operator: đọc to first viewport, không vấp, dám gửi link.

## Approaches

| # | Hướng | Trade-off |
|---|--------|-----------|
| A | Operator viết vàng first viewport (nhắn đồng nghiệp). Agent bung landing → 3 trang trụ → 12 trang full, bị luật research này giữ. | Chậm lúc đầu. Đúng tai. Đã khóa ở advise. |
| B | Viết voice bible / glossary trước, rồi generate cả site. | Trông chuyên nghiệp. Advise đã cấm: khóa giấy trước vàng = lặp pass 1–2. |
| C | Sửa particle / nối câu trên copy hiện tại, giữ khung Anh. | Nhanh. Không đủ: lỗi nằm ở **cấu trúc thông tin** (câu đấm Anh), không chỉ thiếu “thì/mà”. |

**Chọn A.** Research dưới đây là ràng buộc cho bước bung, không phải bản thảo thay vàng.

## Handoff

- Research: [research-260814-0920-vi-voice-semantics.md](./research-260814-0920-vi-voice-semantics.md)
- Advise cũ: [advise-260814-0910-vi-voice.md](./advise-260814-0910-vi-voice.md)
- Việc tiếp: operator gửi vàng. Không cook copy VI trước đó.

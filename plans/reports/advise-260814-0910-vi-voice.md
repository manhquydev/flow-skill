# Advise — tiếng Việt trên site (voice, không dịch)

**Date:** 2026-08-14  
**Trigger:** operator (native VI, cannot read EN) rejects live `/vi/` as disconnected translated prose. `--advise` / kongming.

## Verdict

**No-go:** không viết lại tiếng Việt bằng agent trong phiên này. Hai pass trước (calque → telegram) đã fail cùng một tai. Pass thứ ba sẽ lặp.

`/vi/` **giữ lên** (operator không đọc được EN). Đóng băng copy. Ship domain / CSS / EN.

## Hướng xử lý

1. **Ai viết vàng:** operator nói/gõ first viewport như nhắn đồng nghiệp. Agent không được bịa câu trưng bày.
2. **Khóa trước:** một trang vàng (hero + hai cột + lockup), không khóa glossary / voice bible trước.
3. **EN = danh sách claim**, không phải khuôn câu. Bỏ map H1/lede/verdict/proofs.
4. **Thứ tự sau vàng:** landing còn lại → `what-is-flow` → `two-layer-harness` → `install-and-first-run` → 12 trang full còn lại. 31 stub để nguyên.
5. **Cấm:** dịch slot, rút ngắn “cho punch”, khung chạy / lớp / cơ học, metaphor operator không nói.

## Intent cards (claim only — chưa phải copy)

- Agent vẫn viết code; flow quyết được đi tiếp hay phải dừng.
- Phải cả máy chạy (`flow.sh` 0/1) lẫn skill mới mở cổng.
- Bị chặn ở cổng là kết quả đúng, không phải fail xấu.
- Cài bằng `npx @manhquy/flow-skill@latest`.
- Giữ từ: cổng, card, bằng chứng done. Lệnh tiếng Anh.

## Test 60 giây (operator)

Mở `/vi/` trên điện thoại, đọc to first viewport. Pass = không vấp, không sửa câu trong đầu, dám gửi link group chat. Fail = ông nói câu thay; mình gõ đúng lời ông.

H1 hiện tại (“Cổng chỉ mở khi cả hai cùng đồng ý.”) giữ trừ khi ông tự đổi.

---
title: "Thực thi có attest"
description: "Biên nhận gắn fingerprint ngăn lần chạy tự động tiêu thụ một lần duyệt đã cũ."
lang: vi
---

Khi lần chạy đã tự chủ, “cái này đã được review” phải nghĩa là thứ script kiểm được. Control plane attested-execution phát biên nhận — biên nhận `semantic_gate` cho stage hoặc card đã review, biên nhận `live_verify` cho lần deploy đã check — gắn fingerprint của thứ chúng duyệt. Khi auto đang bật, `check`, lần flip card do CLI sở hữu, sẵn sàng dependency, và gỡ worktree đã merge đều đòi biên nhận hiện hành, và `auto stop` trả bạn về mode thủ công chỉ-cảnh-báo. Mint chạy trên blob đã commit ở một revision cụ thể chứ không phải thứ bẩn trong working tree, và biên nhận live đòi đúng HEAD tip cộng fingerprint tính lại, nên sửa file sau khi duyệt làm mất hiệu lực lần duyệt thay vì thừa kế lặng lẽ.

Hạn chế trung thực được nêu trong thiết kế chứ không ngụ ý: biên nhận phát hiện **subject staleness**. Chúng không xác thực actor và không chống host thù địch. Chúng là hàng rào chống vòng tự chủ tiêu thụ lần duyệt lỗi thời của chính nó, không phải biên bảo mật chống người kiểm soát máy.

Contract biên nhận và bề mặt lệnh:
[`skills/flow/references/attestations.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/attestations.md)

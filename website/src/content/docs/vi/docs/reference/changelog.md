---
title: "Nhật ký thay đổi"
description: "Ghi chú phát hành hướng operator đã chọn lọc cho skill flow, kèm pointer tới changelog đầy đủ."
lang: vi
---

Cặp hiện tại: skill product **v0.31.0**, npm installer **0.7.1-next.0** trên `@next`
(`@latest` vẫn ship 0.7.0 / skill 0.30.0 cho đến khi được promote). Hai số version thứ khác
nhau — `--help` in cả hai. Xem [Hai số phiên bản](/vi/docs/how-to/troubleshoot-install/#two-version-numbers).
GitHub Release: [`v0.31.0`](https://github.com/manhquydev/flow-skill/releases/tag/v0.31.0).

Đây là thay đổi có khả năng ảnh hưởng cách bạn dùng `flow` nhất. Lịch sử đầy đủ, không rút gọn, sống trong kho.

## 0.31.0 — harden eval + parallel bất-kể-host + docs value-first

- **Harden eval.** Biên nhận judge-input, linter fixture-impossibility chỉ-CI, dòng timeout `doctor`, recipe live-eval isolated rẻ hơn.
- **Luật parallel bất-kể-host.** Flow vẫn là lớp kỷ luật; own-runtime đỗ sau tripwire có tên (ADR-0001).
- **Docs value-first.** Landing + docs hub outcome-first, heading anchor thật, i18n parity.
- **Cross-OS.** Hotfix BSD grep trên macOS trong bash suite.

## 0.30.0 — identity lớp kỷ luật + harden CI/eval

- **Identity ADR.** Flow sở hữu cổng và biên nhận, không bao giờ sở hữu runtime.
- **`/flow eval --record` / `--replay`.** Replay artifact-eval không cần key. Không phải fresh-judge; không tính vào eval floor.
- **Evidence nêu artifact.** Mỗi mục done-evidence phải nêu artifact hoặc lệnh tạo ra nó.
- **CI.** Suite theo manifest, job `all-checks-passed` bắt buộc, pack-rehearsal không credential.

## 0.29.0 — import spec-kit và converge

- **Open decisions.** Quyết định sản phẩm chưa xong là bullet `- [ ]` dưới heading `## Open decisions` trên Scope, PRD, và Contract, được scanner cổng sẵn có đếm. `/flow clarify` in chúng thành list cố vấn, scoped theo section.
- **Card `## Independent test`.** Card giờ nêu bằng chứng lát cắt người dùng thấy, hoặc `infra` / `none`. Placeholder sót ở đó làm `check` fail.
- **`/flow converge`.** Remainder card chỉ-append đối soát code hiện tại với plan. Transactional, không bao giờ sửa card đã có, và không ghi gì khi không có gap.

## 0.28.x — attested execution

- Biên nhận `semantic_gate` và `live_verify` gắn fingerprint, cộng `/flow attest semantic|live-verify|status|recover` và `/flow auto stop`.
- Trường risk trên card, với preflight tự chủ fail-closed cho đến khi mọi card có rủi ro đã phân loại.
- Biên nhận phát hiện subject staleness; chúng không xác thực actor hay chống host thù địch.

## 0.27.0 — liên tục quyền hạn harness

- Lớp bền vững do flow sở hữu, với bảng quyền hạn live trong harness README.
- Đánh giá brownfield nhận tag claim trên sổ bằng chứng.

## 0.26.0 — sàn tin cậy done rỗng

- Sàn cơ học trên bằng chứng card: prose chỉ-quy-trình như duyệt PR, CI xanh, hoặc release notes không còn đánh dấu card done được.

## Lịch sử đầy đủ

Mọi phát hành, kể cả thay đổi nội bộ và chỉ-test:
[`CHANGELOG.md`](https://github.com/manhquydev/flow-skill/blob/master/CHANGELOG.md)

Quy trình phát hành:
[`docs/release-process.md`](https://github.com/manhquydev/flow-skill/blob/master/docs/release-process.md)

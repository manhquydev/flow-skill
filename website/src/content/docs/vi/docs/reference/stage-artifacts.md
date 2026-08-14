---
title: "Artifact từng stage"
description: "File mỗi stage flow đẻ ra, và chúng sống ở đâu trong dự án của bạn."
lang: vi
---

Runner copy template vào dự án khi mỗi stage mở. Artifact planning sống dưới `flow/`, đơn vị shipping dưới `cards/`, và sổ cái ở root dự án.

| Path | Stage | Nội dung |
|---|---|---|
| `flow/00-idea.md` | 00 | Pitch ba câu: ai có vấn đề, họ đang làm gì, bạn sẽ làm gì khác |
| `flow/00-inspect.md` | brownfield | Đánh giá hiện trạng: stack, chức năng đối với mục tiêu sản phẩm, rủi ro, baseline test |
| `flow/01-research.md` | 01 | Thứ đã tồn tại — đối thủ, hệ thống live, bằng chứng thật |
| `flow/02-scope.md` | 02 | Feature đã chấm hạng, phần cắt, và duyệt scope |
| `flow/03-prd.md` | 03 | Functional requirement có số (`FRn`) |
| `flow/04-adr.md` | 04 | Quyết định kiến trúc, kể cả option đã loại |
| `flow/05-contract.md` | 05 | Interface, viết trước code. Seam. Không bao giờ skip được |
| `flow/constitution.md` | tùy chọn | Bất biến per-dự-án operator tự viết, cố vấn |
| `cards/C-NNN.md` | build | Một phiên build có phạm vi: allowed files, implements, verify, independent test, evidence, risk |
| `MODE`, `PROJECT_TYPE` | — | Mode soạn và loại dự án |
| `DEBT.md`, `RETRO.md`, `AUTO-LOG.md` | — | Skip có chủ đích, dòng retro, log lần chạy tự chủ |
| `.flow/harness.db` | — | Bản ghi bền vững |

Mọi artifact planning đi kèm placeholder `[FILL]` và ô cổng; cả hai được scan cơ học, và cái nào chưa xong đều fail stage. Quyết định chưa xong thuộc dưới heading `## Open decisions`, nơi cùng scanner đếm chúng.

Thứ tự stage, điều kiện mở, và nội dung bắt buộc:
[`skills/flow/references/stage-state-machine.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/stage-state-machine.md)

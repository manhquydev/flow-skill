---
title: "flow là gì"
description: "flow là harness build có cổng cho coding agent: cổng trung thực giữa ý tưởng và bằng chứng done thật, không phải lớp quản lý dự án."
lang: vi
---

`flow` là **harness build có cổng**. Nó đưa sản phẩm từ ý tưởng tới bằng chứng done thật — URL đã deploy, CLI cài rồi chạy, library API import được, hoặc skill đạt done-definition của chính nó — qua các cổng phải thỏa trung thực trước khi tiến.

Nó là skill bạn cài vào coding agent, không phải dịch vụ đăng ký và không phải framework code phụ thuộc. **Độc lập**: không bắt buộc AgentKit hay claudekit, dù review đa model tùy chọn mở khi các engine đó có mặt.

## Vấn đề nó tồn tại vì

Coding agent vui vẻ đẻ plan hợp lý, tài liệu research hợp lý, và tuyên bố work đã xong hợp lý. Mỗi artifact đọc ổn khi đứng một mình. Failure mang tính hệ thống chứ không cục bộ: không gì trong vòng được đặt để nói *không*.

Hai mode fail chiếm hầu hết thiệt hại.

**Giấy tờ trông như tiến độ.** Tài liệu research với quote đối thủ bịa pass mọi check cấu trúc. Tài liệu scope nơi feature hạng C được viết thành B cũng pass. Cả hai đọc ổn; không cái nào sống sót khi chạm thực tế.

**“Done” mà chưa done.** Agent báo card xong vì test xanh và nhánh đã merge. Không ai load trang. Không ai chạy lệnh. “Tests pass” là trạng thái giữa pipeline bị thăng chức lặng lẽ thành trạng thái cuối.

## flow làm gì với chuyện đó

Ba cam kết, mọi thứ khác đi theo.

**Done nghĩa là bằng chứng thế giới thật.** Mỗi card nêu bằng chứng done từ đầu, và cổng đòi bằng chứng đó được dán vào trước khi card được đánh dấu done. Với dự án web đó là URL live và output `curl` thật; với CLI, một lần gọi thật kèm exit code. Code đã merge và CI xanh bị từ chối tường minh. Xem [Done nghĩa là bằng chứng thế giới thật](/vi/docs/explanation/done-evidence).

**Hai lớp phải đồng ý.** Script xác định bắt phần cơ học gian được — ô chưa tick, `[FILL]` còn sót, evidence rỗng — và exit 0 hoặc 1. Model đọc skill bắt cái script không bắt được: research bịa, scope dìm hạng, endpoint không có auth. Cổng chỉ pass khi cả hai đồng ý. Xem [Harness hai lớp](/vi/docs/explanation/two-layer-harness).

**Kill tại gate là hợp lệ.** Harness chỉ biết nói “tiến” thì là băng chuyền. Kill ý tưởng yếu ở Scope thì rẻ và khôn, và flow coi đó là kết quả hạng nhất chứ không phải failure cần vòng vo.

## Nó không phải

Không phải tool quản lý dự án: không board, không burndown, không estimate. Không phải code generator — nó gác cổng bất kể agent hay người viết code. Không phải hệ CI, dù luật bằng chứng khắt hơn hầu hết cổng CI. Và không phải wrapper làm agent thông minh hơn; nó làm agent *chịu trách nhiệm*, thứ khác và hữu ích hơn.

## Hình một lần chạy

```
Idea -> Research -> Scope -> PRD -> ADR -> Contract -> Cards -> Build -> Review -> Deploy -> Verify-live -> Retro
|------------------ planning (files in flow/) ------------------|  |------- shipping (inside cards/) -------|
```

Planning là sáu stage có cổng, sống thành file dưới `flow/`. Shipping là dãy card dưới `cards/`, mỗi cái một phiên build có phạm vi đối với contract viết ở stage 05. Giữa các session, store bền vững giữ debt, retro, trace, playbook, để session sau bắt đầu với nỗi đau cũ trong tầm mắt.

Chat là cửa mặc định — mô tả bạn muốn gì, Concierge đề xuất một hành động kế. Lệnh gõ như `/flow next` luôn thắng routing chat.

## Đi tiếp

- [Pipeline các stage](/vi/docs/explanation/stage-pipeline) — mỗi cổng đang chống tự lừa gì.
- [Harness hai lớp](/vi/docs/explanation/two-layer-harness) — cơ chế chi tiết.
- [Cài đặt và lần chạy đầu](/vi/docs/tutorials/install-and-first-run) — xem cổng từ chối trong mười phút.

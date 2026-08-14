---
title: "Converge kế hoạch với code"
description: "Append card phần còn lại để đối soát code đang làm gì với plan đã nói."
lang: vi
---

Build thật lệch: code được viết mà plan không hỏi, và work đã plan lặng lẽ không hạ cánh. `/flow converge` là closer flow-back cho gap đó. Bạn đánh giá code hiện tại đối với plan, viết payload `flow-converge/v1` mô tả gap, rồi chạy verb. Nó transactional và chỉ-append — hoặc mọi remainder card được viết hoặc không cái nào, không bao giờ sửa card đã có, và khi không có gap nó in `CONVERGED` rồi không ghi gì. Work tồn tại trong code nhưng chưa từng được yêu cầu thành card review, không bao giờ thành xóa, vì quyết định gỡ thứ gì thuộc operator. Nửa ngữ nghĩa có bằng chứng hành vi riêng: `flow.sh eval --stage converge` đưa trạng thái kho cho một judge và hỏi phán đúng là gap hay hội tụ.

Phân loại gap và schema payload:
[`skills/flow/references/converge.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/converge.md)

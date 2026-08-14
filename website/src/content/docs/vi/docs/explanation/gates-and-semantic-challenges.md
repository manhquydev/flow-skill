---
title: "Cổng và thử thách ngữ nghĩa"
description: "Nửa ngữ nghĩa của mỗi cổng thực sự hỏi gì, và vì sao theo từng stage chứ không generic."
lang: vi
---

Pass cơ học nghĩa là file đầy đủ về cấu trúc. Nó không nói gì về nội dung có đúng không. Thử thách ngữ nghĩa là bộ câu hỏi theo từng stage mà model áp sau khi script pass, và cố ý cụ thể theo từng stage vì mỗi stage mời một lời nói dối khác. Research mời đối thủ bịa và số không nguồn. Scope mời dìm hạng, nơi feature bạn muốn build được viết cao hơn hạng nó đáng. PRD mời requirement không chủ và nỗi đau không feature. Contract mời endpoint không cột auth. Card mời bằng chứng mô tả quy trình chứ không phải thế giới. Prompt generic “cái này có tốt không?” không bắt được những thứ này đáng tin; thử thách có tên theo từng stage thì có.

Chỉ dẫn chạy cả hai chiều: đừng lặng lẽ tiến qua artifact rỗng, và đừng lặng lẽ chặn artifact vững. Khi thứ gì pass cơ học nhưng đọc yếu, operator được nói đúng vậy rồi quyết. Cũng có bằng chứng hành vi rằng lớp này hoạt động — `/flow eval` đưa fixture rỗng-nhưng-sạch-cơ-học cho judge mới và chấm chúng có bị gắn cờ không, đó là ngưỡng dưới chứ không phải bảo đảm.

Thử thách theo từng stage:
[`skills/flow/references/gate-rules.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/gate-rules.md)

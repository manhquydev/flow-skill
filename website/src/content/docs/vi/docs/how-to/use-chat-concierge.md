---
title: "Dùng chat Concierge"
description: "Lái flow bằng tiếng thường: Concierge chạy gì không hỏi, cái gì phải xác nhận, và cách bỏ qua nó."
lang: vi
---

Không bắt buộc học verb. Chat là cửa mặc định: nói bạn muốn gì, Concierge tìm ra đang ở đâu và đề xuất một bước kế.

## Cứ nói bạn muốn gì

Mở agent trong thư mục project và gõ câu bình thường:

> "Tôi muốn build app quản lý kho cho cửa hàng."

> "Đang ở đâu?"

> "Card này done chưa?"

Concierge trả lời bằng ngôn ngữ bạn dùng. Trả lời tiếng Việt thì nhận tiếng Việt; law và file tham chiếu của flow vẫn lấy bản English làm chuẩn.

## Nó làm gì trước khi trả lời

Mọi câu tiếng thường đi cùng một vòng ngắn, và bước một không thương lượng:

1. Chạy lệnh status — hoặc `resume` nếu bạn vào dự án lúc lạnh — để lấy **ground truth cơ học**. Không bao giờ đoán state từ conversation.
2. Khớp intent với bảng routing intent-class × state.
3. Đề xuất đúng **một** hành động kế, bằng tiếng thường, giải thích khái niệm cổng trong một câu lần đầu nó xuất hiện.
4. Mời chạy hành động đó, theo luật quyền hạn bên dưới.

Một đề xuất mỗi lần là chủ đích. Bạn sẽ không bị dump cả bảng verb vì hỏi một câu đơn.

## May-run — được chạy không hỏi

Lệnh chỉ-đọc, không mutate state, chạy thẳng, vì xin phép để nhìn là ma sát thuần:

`status`, `resume`, `recall`, `usage`, `coherence`, `consistency`, `contract`, `tokens`,
`constitution`, `clarify`, `design`, `doctor`, `ready`, `gate`.

## Must-ask — phải hỏi trước

Mọi thứ mutate state, tốn tiền, hoặc thuộc quyền operator được xác nhận trước khi chạy:

`next`, `assess`, `card`, `check`, `project-type`, `skip`, `debt`, `harness`, `promote`,
`mode`, `auto`, `attest`, `workspace`, `unlock`, `retro`, `eval`, `converge`.

Luật là **default-deny**: verb nào không nằm list chỉ-đọc ở trên đều must-ask, kể cả verb thêm vào flow sau khi file routing được viết.

`next` nằm list must-ask dù trông như chỉ tiến một cổng đã pass. Điều kiện pass — lớp cơ học *và* thử thách ngữ nghĩa cùng đồng ý — không biết được trước khi chạy. Auto-chạy sẽ để Concierge lặng lẽ đẩy một stage rỗng-nhưng-sạch-cơ-học qua bạn, đúng failure mà các cổng tồn tại để chặn.

## Một câu đồng ý

Nếu bạn mới và câu hỏi đòi agent soạn artifact hộ — “build giúp X” — Concierge hỏi một câu thường trước khi đụng mode:

> "Muốn tôi soạn nháp từng bước và anh duyệt không?"

Trả lời có thì chuyển sang mode `work`: agent phỏng vấn một lần, soạn stage 00 tới 05, dừng để duyệt scope. Trả lời không thì ở mode `teach`: bạn soạn, agent chỉ gác cổng. Cổng ràng buộc giống nhau. Đổi ý sau bằng `/flow mode teach` hoặc `/flow mode work`.

## Bỏ qua Concierge

Gõ verb. `/flow next`, `/flow card`, `/flow check C-001` tường minh được dispatch đúng như viết, không Concierge diễn giải. Lệnh `/flow …` tường minh luôn thắng routing chat — power user không mất gì vì chat là cửa mặc định.

## Một lần chạy đầu đã làm thật

1. Bạn mở agent mới trong thư mục trống và nói *"Tôi muốn build app quản lý kho cho cửa hàng."*
2. Concierge chạy status, thấy chưa có `flow/`, rồi trả lời: chưa có dự án flow ở đây — mình hỏi một câu ngắn rồi soạn từng bước để anh duyệt nhé?
3. Bạn nói có. Nó chuyển `work` và bắt đầu phỏng vấn hướng tới cổng Scope.

Không gõ verb flow nào. Câu đồng ý là nghi thức duy nhất.

## Một hạn chế đáng biết

Routing parse prose status cho người đọc, không phải contract token máy. Tin cậy trên Claude; trên engine khác như Codex hoặc Antigravity, coi routing chat là best-effort. Routing sai thì gõ verb — lớp cơ học hành xử giống nhau trên mọi engine.

## Xem thêm

- [Concierge và chat-first](/vi/docs/explanation/concierge-and-chat-first)
- [Đổi chế độ teach và work](/vi/docs/how-to/switch-teach-work-mode)
- [Tham chiếu lệnh](/vi/docs/reference/commands)

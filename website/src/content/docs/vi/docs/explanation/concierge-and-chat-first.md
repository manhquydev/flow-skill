---
title: "Concierge và chat-first"
description: "Vì sao chat là cửa mặc định vào flow, routing bám state cơ học thế nào, và vì sao quyền hạn là default-deny."
lang: vi
---

Hầu hết operator không cần học verb. Chat là cửa mặc định: bạn nói muốn gì, Concierge định tuyến. Lệnh gõ vẫn tồn tại và luôn thắng.

## Vì sao cần cửa chat

Harness với hơn hai mươi verb có vách đứng lúc đầu. Người cần kỷ luật cổng nhất — đang build sản phẩm thật đầu tiên — đúng là người ít khả năng đọc bảng lệnh trước. Mỗi verb phải học trước khi nhận giá trị là một chỗ bỏ cuộc.

Nhưng cửa chat chỉ đáng có nếu nó không thành nguồn sự thật thứ hai, mềm hơn. Đó là bài toán thiết kế Concierge thực sự giải.

## Routing bám đất, không đoán

Vòng bắt đầu bằng lệnh, không bằng diễn giải. Với mọi câu tiếng thường, Concierge chạy lệnh status — hoặc `resume` khi vào dự án lúc lạnh — rồi đọc kết quả. Không suy state từ conversation, và không suy từ file nào tình cờ tồn tại.

Điều này quan trọng vì phương án kia, dò artifact mờ, sai đúng lúc sai đắt nhất: stage làm dở, session bỏ, card ai đó sửa tay. `flow` đã có state machine cơ học biết câu trả lời. Concierge hỏi nó.

Từ state đó nó tra hàng intent-class gần nhất trong bảng routing và đề xuất đúng **một** hành động kế, bằng tiếng thường, giải thích khái niệm cổng trong một câu lần đầu xuất hiện. Một đề xuất mỗi lần là ràng buộc chủ đích: dump bảng verb lên người hỏi câu đơn là cách mất họ.

## Quyền hạn là default-deny

Concierge phân loại mọi verb trước khi chạy gì. Lệnh strictly chỉ-đọc — status, resume, recall, usage, drift check, doctor, ready — chạy không hỏi, vì đòi đồng ý để nhìn là ma sát thuần. Mọi thứ mutate state, tốn tiền, hoặc thuộc quyền operator phải được xác nhận trước.

Luật là default-deny: verb nào không nằm list chỉ-đọc đều must-ask, **kể cả verb thêm vào flow sau khi file routing được viết**. Mệnh đề đó mới thú vị. Nghĩa là hành vi an toàn là hành vi bạn nhận mặc định khi hệ thống lớn, chứ không phải hành vi bạn nhận khi nhớ cập nhật list.

`next` nằm phía must-ask dù trông như đọc một cổng đã pass. Điều kiện pass — lớp cơ học và thử thách ngữ nghĩa cùng đồng ý — không biết được trước khi chạy, vì thử thách ngữ nghĩa chỉ áp sau pass cơ học. Auto-chạy sẽ để Concierge lặng lẽ đẩy stage rỗng-nhưng-sạch-cơ-học qua operator. Đúng failure các cổng tồn tại để chặn, nên cửa trước không được phép đưa nó trở lại.

## Một câu đồng ý, không trang settings

User hoàn toàn mới mà câu hỏi đòi soạn nháp nhận một câu: muốn tôi soạn từng bước và anh duyệt từng cái? Có thì chuyển mode `work`; không thì ở `teach`. Không gì khác về cổng thay đổi — cả hai mode pass cổng giống nhau, khác duy nhất là ai soạn.

Một câu là toàn bộ nghi thức onboarding. Phương án kia, bắt user hiểu teach versus work trước khi thấy một cổng, giải thích phân biệt chưa có nghĩa với họ.

## Lệnh gõ không bị đụng

`/flow next` tường minh dispatch đúng như bảng lệnh mô tả, Concierge không diễn giải. Không có mode để tắt, không gì để cấu hình, và không lệch giữa chat làm gì và verb làm gì — chat *là* verb, được chọn hộ bạn.

Lệnh `/flow …` tường minh luôn thắng chat.

## Hạn chế trung thực

Routing parse prose status cho người đọc chứ không phải contract token máy. Tin cậy trên Claude và best-effort trên engine khác. Lớp cơ học hành xử giống nhau mọi nơi, nên fallback khi routing cảm giác sai luôn có và luôn đúng: gõ verb.

## Xem thêm

- [Dùng chat Concierge](/vi/docs/how-to/use-chat-concierge)
- [Chế độ và chiến lược chạy](/vi/docs/explanation/modes-and-run-strategies)
- [Tham chiếu lệnh](/vi/docs/reference/commands)

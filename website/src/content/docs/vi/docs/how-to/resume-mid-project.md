---
title: "Tiếp tục giữa dự án"
description: "Nhặt lại dự án flow lúc lạnh mà không đoán lại state: chạy resume trước, đọc dòng NEXT, xử lý lock cũ."
lang: vi
---

Bạn bỏ dự án hai tuần, hoặc là session agent mới không nhớ gì. **Đừng** bắt đầu bằng đọc file rồi đoán đang ở đâu.

## Chạy resume trước

```
/flow resume
```

Đây là verb đầu tiên khi vào một dự án giữa chừng. Chỉ đọc, không lấy lock, và ghép bản tóm tắt câu chuyện phiên từ state đã có trên đĩa:

- phiên trước, chỉ tên lệnh — không bao giờ raw args
- card in flight và dwell (ngồi đó bao lâu)
- trạng thái cổng hiện tại
- đúng một dòng `NEXT ->`

Đọc dòng `NEXT ->` rồi làm đúng cái đó. Cùng helper quyết định với `/flow status`, nên hai lệnh không bao giờ bất đồng.

## Khi nào bỏ qua

Bỏ `resume` khi bạn đã có ngữ cảnh sống trong conversation này — nếu chính bạn vừa chạy `next` hoặc `card` một phút trước thì chạy lại chẳng thêm gì. Dành cho lần vào lạnh, không phải mọi lệnh.

## Rồi lấy view đang làm việc

```
/flow
```

`/flow` trần là `status`: đang ở đâu, cái gì chặn, dwell của stage hiện tại, danh sách card (tóm gọn khi quá mười card), và một dòng tóm tắt bộ nhớ. Dùng `resume` để vào lại, `status` để tiếp tục làm.

## Nạp bộ nhớ trước khi đụng gì

```
/flow recall
```

`recall` đọc lại lớp bền vững: debt mở, retro gần nhất, scope card trước, friction và backlog của harness, sức khỏe audit, playbook đã promote. Chạy trước khi soạn stage hoặc card để bắt đầu với nỗi đau cũ trong tầm mắt, không phải phát hiện lại.

## Nếu lock chặn bạn

`flow` cho một session mỗi dự án. File `flow/.lock` từ chối session thứ hai chạy song song, vì hai session chia một plan sẽ giẫm lên nhau.

```
/flow unlock
```

Chỉ dùng khi session kia thật sự chết — terminal crash, cửa sổ bỏ dở. Nếu session kia còn sống, dừng và phối hợp với người đang chạy. Đừng force qua lock sống; chạy song song làm hỏng plan. Lock cũng tự reclaim sau TTL, mặc định 900 giây.

Để bảo vệ cứng thay vì cảnh báo, export một `FLOW_SESSION_ID` ổn định một lần mỗi session và truyền vào mọi lời gọi:

```bash
export FLOW_SESSION_ID=$(uuidgen)
FLOW_SESSION_ID=$FLOW_SESSION_ID bash ~/.claude/skills/flow/runner/flow.sh next
```

Không có nó thì runner chỉ cảnh báo — không chứng minh được session khác, nên không bao giờ tự chặn.

## Nếu bạn nhặt code người khác, không phải plan của mình

Dự án có code nhưng không có thư mục `flow/` là brownfield. Chạy [đánh giá brownfield](/vi/docs/tutorials/brownfield-assess) thay vì `resume`; chưa có câu chuyện phiên để khôi phục.

## Chạy từ thư mục con

Nếu chạy `flow` từ thư mục con như `frontend/` không có `flow/` riêng, nó nhận dự án flow tổ tiên gần nhất và in một dòng ghi chú ra stderr, thay vì đẻ root thứ hai bị mảnh. Thư mục con có `flow/` hoặc `cards/` riêng luôn được tôn trọng, cũng như `FLOW_PROJECT_ROOT` tường minh.

## Xem thêm

- [Tạo và kiểm card](/vi/docs/how-to/create-and-check-cards)
- [Mở khóa phiên cũ](/vi/docs/how-to/unlock-stale-session)
- [Tham chiếu lệnh](/vi/docs/reference/commands)

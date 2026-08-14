---
title: "Pipeline các stage"
description: "Mỗi stage có cổng từ Idea tới Retro đang chống tự lừa gì, và vì sao contract là stage duy nhất không skip được."
lang: vi
---

```
Idea -> Research -> Scope -> PRD -> ADR -> Contract -> Cards -> Build -> Review -> Deploy -> Verify-live -> Retro
|------------------ planning (files in flow/) ------------------|  |------- shipping (inside cards/) -------|
```

Pipeline không phải checklist tài liệu phải đẻ. Mỗi stage tồn tại vì một kiểu tự lừa hay xảy ra đúng điểm đó trong build, và cổng nhắm vào kiểu tự lừa đó.

## Planning: sáu file có cổng

Artifact planning sống dưới `flow/` và được đánh số để thứ tự không thương lượng.

**00 — Idea.** Pitch ba câu: ai có vấn đề, họ đang làm gì, bạn sẽ làm gì khác. Cổng đang tìm vấn đề chứ không phải giải pháp đội lốt vấn đề. Đây là chỗ rẻ nhất cả dự án để kill thứ gì.

**01 — Research.** Thứ đã tồn tại: đối thủ, hệ thống live, giá thật. Luật là *inspect first, bằng chứng không phải vibe*. Đây là stage bịa hấp dẫn nhất và đắt nhất, vì plan dựng trên đối thủ bịa thì sai tự tin suốt tuần. Script không phát hiện quote bịa; cổng ngữ nghĩa là phòng thủ duy nhất.

**02 — Scope.** Chấm hạng feature và cắt. Fail đặc trưng ở đây là dìm hạng — feature hạng C được viết thành B vì bạn muốn build. Scope là chỗ hầu hết dự án được cứu hoặc mất, nên mode `work` dừng để operator duyệt tường minh đúng điểm này, không chỗ nào khác.

**03 — PRD.** Scope sống sót thành functional requirement có số. Mỗi `FRn` viết ở đây sau này phải được một card claim và một interface contract phục vụ. Truy vết đó kiểm được bằng máy, nên requirement không thể bốc hơi lặng lẽ giữa planning và building.

**04 — ADR.** Quyết định kiến trúc, kể cả cái bạn loại và vì sao. Option bị loại mới là phần đáng giá: sáu tháng sau chúng là lý do không ai mở lại câu hỏi đã chốt.

**05 — Contract.** Interface, viết trước khi có code. Method, path, auth, shape request và response cho web; lệnh, flag, shape output và exit code cho CLI; bề mặt API export cho library; bề mặt lệnh cho skill.

## Vì sao contract không bao giờ skip được

Mọi stage planning khác skip được với debt ghi trung thực. Stage 05 thì không, không bao giờ.

Contract là **seam**. Bên sản xuất build tới nó, bên tiêu thụ build từ nó, và hai bên đi độc lập đúng vì shape giữa chúng đã cố định. Skip không tiết kiệm thời gian; nó dời chi phí sang lúc tích hợp, khi hai nửa đã build nửa chừng phát hiện bất đồng và ai đó viết lại một bên.

Kỷ luật theo sau khắt: đừng improvise shape. Shape sai thì sửa contract trước rồi mới đổi code. Tôn trọng một shape ngay bằng null hoặc stub dù giá trị thật ship ở card sau.

Nếu contract không khớp loại dự án, thích nghi — đọc “endpoint” thành “interface” hoặc “command” — chứ đừng skip.

## Shipping: card

Sau khi stage 05 pass, `/flow card` cắt build card. Mỗi card là một phiên build có phạm vi với danh sách allowed-files, requirement nó implements, khối verify, independent test, và section evidence bắt đầu trống.

Build, review đối kháng, deploy, rồi verify **live** như người dùng. Card done khi bằng chứng thế giới thật được dán vào và cổng check pass — không phải khi test xanh.

## Brownfield: stage 00-inspect

Codebase có sẵn không bắt đầu ở Idea. `/flow assess` scaffold và gác cổng `flow/00-inspect.md`, bản đồ hiện trạng gồm stack, sản phẩm đang làm gì so với đáng lẽ phải làm, rủi ro, và baseline test. Có người duyệt, và nó tồn tại để planning cho hệ thống có sẵn bám vào cái đang có chứ không phải cái README kho tuyên bố.

## Retro

Một dòng trung thực mỗi lần chạy, do operator viết, không bao giờ do agent. Nó nuôi lớp bền vững, nên `recall` của dự án sau hiện nỗi đau dự án này.

## Kill là lối ra hợp lệ

Mỗi cổng có ba kết quả, không phải hai: pass, chặn, và kill. Harness chỉ biết nói “tiến” thì là băng chuyền gắn nghi thức tuân thủ. Kill ý tưởng yếu ở Scope là quyết định tốt rẻ nhất có trong một lần build.

## Xem thêm

- [Artifact từng stage](/vi/docs/reference/stage-artifacts)
- [Cổng và thử thách ngữ nghĩa](/vi/docs/explanation/gates-and-semantic-challenges)
- [Dự án greenfield đầu tiên](/vi/docs/tutorials/first-greenfield-project)

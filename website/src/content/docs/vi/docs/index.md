---
title: "Tài liệu flow"
description: "Cách đọc tài liệu này: hướng dẫn để học, cách làm cho một việc, giải thích cho cái why, tham chiếu cho đúng hình."
lang: vi
---

`flow` là harness build có cổng cho coding agent. Nó đưa sản phẩm từ ý tưởng tới **bằng chứng done thật** — URL đã deploy, CLI cài rồi chạy, library API import được, hoặc skill đạt done-definition của chính nó — qua các cổng phải thỏa trung thực trước khi tiến.

Tài liệu chia bốn loại viết riêng. Mỗi loại trả một câu hỏi khác; trộn chúng là lý do hầu hết docs khó đọc. Chọn bucket khớp việc bạn đang làm.

## Hướng dẫn — học bằng cách làm

Bắt đầu đây nếu chưa từng chạy `flow`. Tutorial là bài có kết quả bảo đảm: làm đúng bước, cuối cùng có thứ thật trên máy. Tutorial không dừng để giải thích mọi quyết định thiết kế, và không liệt kê mọi option — làm vậy sẽ phá bài học.

- [Cài đặt và lần chạy đầu](/vi/docs/tutorials/install-and-first-run) — cài skill và nhận kết quả cổng trung thực đầu tiên.
- [Dự án greenfield đầu tiên](/vi/docs/tutorials/first-greenfield-project) — từ ý tưởng tới build card, đi hết cổng planning.

## Cách làm — xong một việc cụ thể

Dùng khi đã biết `flow` là gì và đang có việc trước mặt: nhặt lại dự án bỏ hai tuần, cắt card, skip cổng đã ghi debt trung thực, gắn engine review thứ hai. How-to giả định bạn đủ năng lực và đi thẳng vào điểm.

- [Tiếp tục giữa dự án](/vi/docs/how-to/resume-mid-project)
- [Tạo và kiểm card](/vi/docs/how-to/create-and-check-cards)
- [Dùng chat Concierge](/vi/docs/how-to/use-chat-concierge)
- [Khắc phục cài đặt](/vi/docs/how-to/troubleshoot-install)

## Giải thích — hiểu vì sao được xây như vậy

Đọc lúc rời bàn phím. Chúng nói về cơ chế: vì sao hai lớp cổng thay vì một, vì sao “tests pass” không bao giờ được nhận là done, vì sao harness giữ bộ nhớ trong lớp bền vững, và vì sao có hai số version. Không có bước làm ở đây.

- [flow là gì](/vi/docs/explanation/what-is-flow)
- [Harness hai lớp](/vi/docs/explanation/two-layer-harness)
- [Done nghĩa là bằng chứng thế giới thật](/vi/docs/explanation/done-evidence)
- [Phiên bản: npm installer vs skill product](/vi/docs/explanation/versions-npm-vs-skill)

## Tham chiếu — tra đúng hình

Khô, đúng sự kiện, xếp để quét: bảng lệnh, file rơi vào đâu theo agent, artifact mỗi stage tạo ra, biến môi trường. Trang tham chiếu mô tả máy móc; không dạy và không tranh luận.

- [Tham chiếu lệnh](/vi/docs/reference/commands)
- [CLI cài đặt](/vi/docs/reference/install-cli)
- [Đường dẫn cài đặt](/vi/docs/reference/install-paths)
- [Nhật ký thay đổi](/vi/docs/reference/changelog)
- [Thuật ngữ](/vi/docs/reference/glossary)

## Bắt đầu ngắn nhất có thể

Cặp hiện tại: skill product **v0.30.0**, npm installer **0.7.0** trên `@latest`. Xem
[Phiên bản: npm installer vs skill product](/vi/docs/explanation/versions-npm-vs-skill).

```bash
npx @manhquy/flow-skill@latest
# expect: flow-skill v0.7.0 (ships skill v0.30.0)
```

Restart agent, mở project, rồi nói bạn muốn build gì bằng tiếng thường. Chat là cửa mặc định — lệnh gõ như `/flow next` luôn chạy, nhưng không bắt buộc học verb để bắt đầu.

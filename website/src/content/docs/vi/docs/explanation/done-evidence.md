---
title: "Done nghĩa là bằng chứng thế giới thật"
description: "Vì sao flow từ chối nhận test xanh, PR đã duyệt, hoặc nhánh đã merge là done, và cái gì được tính thay thế."
lang: vi
---

Mỗi card nêu bằng chứng done từ đầu, và cổng đòi bằng chứng đó được dán vào trước khi card được đánh dấu done. “Tests pass” và “code merged” là trạng thái giữa pipeline. Chúng không bao giờ là done.

## Failure mà điều này chặn

Cách build có agent hỗ trợ sai phổ biến nhất không phải bug. Là status. Card được báo xong vì test xanh, review đã duyệt, nhánh đã merge. Mỗi câu đó đúng. Không ai load trang.

Mỗi tín hiệu đó đo **proxy** của thứ bạn quan tâm. Test đo mô hình hệ thống của bạn đối với chính nó. Merge đo sự đồng ý về một diff. Không cái nào đụng thế giới đang chạy. Proxy lệch thực tế lặng lẽ, và lệch vô hình đúng lúc quan trọng nhất, vì mọi dashboard đều xanh.

Sửa không phải thêm proxy. Là đòi một lần quan sát thứ thật.

## Cái gì được tính, theo loại dự án

Loại dự án quyết định hình của bằng chứng, và tinh thần giống nhau mọi trường hợp: có người tương tác với thực tế đã deploy rồi dán cái quay về.

| Loại dự án | Bằng chứng done |
|---|---|
| `web` | URL đã deploy live cộng output `curl` thật |
| `cli` | Tool cài được, và một lần gọi thật trả output và exit code đúng |
| `library` | Public API import được, ví dụ dùng chạy được, đạt ngưỡng coverage |
| `skill` | Cài vào skill home, và một lần chạy thật đạt done-definition của chính nó |

Đặt loại bằng `/flow project-type <type>`; mặc định là `web`.

## Cái gì không được tính

Artifact quy trình, dù ấn tượng:

- pull request đã duyệt
- badge CI xanh hoặc workflow run
- release notes mô tả cái đã ship
- code review không tìm thấy gì
- tóm tắt của chính agent nói work đã xong

Lớp cơ học ép một sàn ở đây: card có section evidence chỉ chứa prose quy trình bị từ chối, nên kỷ luật không tranh cãi được ngay lúc đó. Ngoài sàn đó, cổng ngữ nghĩa hỏi câu khó hơn — đây là bằng chứng *thế giới*, hay mô tả thế giới?

Tự đánh giá của agent bị loại tường minh. Tín hiệu ground-truth cho mọi cổng là thứ agent không tự đẻ: exit code của script, output lệnh verify thật, check live.

## Vì sao cổng từ chối evidence rỗng mạnh đến vậy

```
  [x] status is 'done' but ## Evidence is empty (paste world-state proof: URL/curl/DB row)
FAIL: C-001 has gate violations (above).
```

Cái này bắn dù code đã xong và đúng. Lý do: lúc rẻ nhất để bắt bằng chứng là lúc bạn đang nhìn thứ đang chạy anyway. Hoãn lại thì tái dựng từ trí nhớ, và bằng chứng tái dựng không phân biệt được với bằng chứng bịa.

Cùng lý do dẫn lần flip do CLI sở hữu, `/flow card done C-NNN`: áp cùng luật với `check` và revert nếu cổng fail, nên không có path code nào đẻ ra done rỗng.

## Lối ra trung thực

Nếu card thật sự chưa chứng minh được ngay — chưa có đích deploy, dịch vụ ngoài không sẵn — câu trả lời không phải nới bằng chứng. Là ghi phơi nhiễm thành debt, bằng văn bản, với điều kiện đóng. Debt nhìn thấy được và hiện trong `recall`; done rỗng vô hình và hiện trong production.

## Xem thêm

- [Tạo và kiểm card](/vi/docs/how-to/create-and-check-cards)
- [Loại dự án](/vi/docs/explanation/project-types)
- [Bỏ cổng bằng nợ](/vi/docs/how-to/skip-gate-with-debt)

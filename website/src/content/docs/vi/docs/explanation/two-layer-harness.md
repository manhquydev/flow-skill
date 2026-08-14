---
title: "Harness hai lớp"
description: "Vì sao flow tách gating thành script xác định và model gác cổng, và vì sao cổng chỉ pass khi cả hai đồng ý."
lang: vi
---

Đây là ý tưởng cốt của `flow`. Mọi thứ khác là hệ quả.

Một cổng phải bắt hai loại fail rất khác, và không thành phần nào giỏi cả hai. Nên `flow` chạy hai lớp, và cổng chỉ pass khi **cả hai** đồng ý.

## Lớp một — cổng cơ học

`runner/flow.sh` là engine bash xác định, exit 0 hoặc 1. Nó sở hữu vòng đời stage/card, và kiểm những thứ gian được dễ và phát hiện dễ:

- ô cổng chưa tick, kể cả bullet `- [ ]` sót dưới `## Open decisions` — cùng một scanner xử lý cả hai
- `[FILL]` còn sót
- status card hợp lệ
- section `## Evidence` rỗng trên card tuyên bố done

Exit code là ground truth. Luật cho model thẳng: luôn chạy script trước, đọc exit code, relay trung thực. Đừng thay bằng phán của mình.

Lớp này không đọc nghĩa. Không phân biệt quote đối thủ thật với quote bịa, hay feature hạng B trung thực với hạng C được viết thành B.

## Lớp hai — cổng ngữ nghĩa

Đó là việc của model. Sau khi script pass, skill áp một bộ thử thách theo từng stage trước khi operator được phép tiến. Đây là chỗ research bịa bị hỏi, scope dìm hạng bị gọi tên, endpoint không cột auth bị gắn cờ, và “tests pass” dán vào evidence bị từ chối vì giữa pipeline.

Chỉ dẫn đối xứng và quan trọng cả hai chiều: đừng lặng lẽ tiến qua artifact rỗng, và đừng lặng lẽ chặn artifact vững. Khi script pass nhưng nội dung yếu, operator được nói đúng vậy — pass cơ học và yếu về chất — rồi operator quyết.

## Vì sao tách, chứ không một checker thông minh hơn

Script không phán nghĩa; model không đáng tin để xác định về cơ học. Tách chúng đặt mỗi lớp fail đúng chỗ bắt được, và làm nửa gian được thành bắt buộc chứ không thuyết phục được. Bạn không nói `exit 1` đổi ý. Bạn cũng không viết regex phát hiện quote thị trường bịa.

Có lợi thứ hai, tinh hơn. Vì lớp cơ học là process riêng với exit code thật, tuyên bố của model về một cổng kiểm được. Agent nói “cổng đã pass” đối chiếu được với tín hiệu nó không tự sản xuất.

## Lớp thứ ba: bộ nhớ bền vững

Dưới cả hai là lớp bền vững — store Python và SQLite giữ intake và risk lane, story và proof, trace và tier, decision, backlog. Nó suy giảm lịch sự: thiếu `python3` thì cổng vẫn chạy, chỉ lớp này tắt.

```
+---------------------------------------------------------------+
|  Semantic layer  -  SKILL.md + references/  (the model)       |
|  judgment: hollow content, grade-laundering, adversarial      |
|  review, agent orchestration, work mode, auto tiers           |
+---------------------------------------------------------------+
              | calls (exit code = ground truth)
              v
+---------------------------------------------------------------+
|  Mechanical layer  -  runner/flow.sh  (bash, exit 0/1)        |
|  stage/card lifecycle, gate checks, debt ledger,              |
|  design check, harness passthrough                            |
+---------------------------------------------------------------+
              | reads/writes (best-effort, graceful degrade)
              v
+---------------------------------------------------------------+
|  Durable layer  -  Python + sqlite3 (flow-owned)              |
|  intake/risk-lane, story+proof, trace+tier, decision, backlog |
+---------------------------------------------------------------+
```

Đây là bộ nhớ ngoài. Tiến độ và ma sát sống sót qua session và cửa sổ ngữ cảnh, thuốc giải cho suy giảm chậm khi dự án dài chỉ sống trong conversation.

## Hệ quả cho agent

Agent gắn vào được; cổng cố định. Stage có thể ủy thác soạn cho agent chuyên khi có, và rơi về hành vi built-in khi không có. Cổng giống nhau trên mọi path, nên agent thiếu không bao giờ hạ thanh. Agent soạn; cổng vẫn phán.

Cùng luật chi phối engine khác hãng tùy chọn. Model thứ hai hoặc thứ ba có thể review một card, nhưng phán của nó hỗ trợ triage — không bao giờ tự pass và không bao giờ tự fail.

## Xem thêm

- [Cổng và thử thách ngữ nghĩa](/vi/docs/explanation/gates-and-semantic-challenges)
- [Kiến trúc hệ thống](/vi/docs/explanation/system-architecture)
- [Done nghĩa là bằng chứng thế giới thật](/vi/docs/explanation/done-evidence)

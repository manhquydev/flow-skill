---
title: "Loại dự án"
description: "Vì sao một harness gác cổng được web app, CLI, library, và skill mà không làm yếu cổng nào."
lang: vi
---

`flow` sinh ra theo hình web, và cách trung thực để hỗ trợ loại phần mềm khác không phải khái quát hóa cổng thành mơ hồ mà là nêu đúng ba thứ đổi. Loại dự án thích nghi seam contract stage 05, trình tự card chuẩn, và bằng chứng done nghĩa là gì. Mọi thứ khác — tinh thần mỗi cổng, “contract trước code”, “done là bằng chứng thế giới thật” — không đụng. Đó là vì lần build CLI không phải lần build web pha loãng: bằng chứng nó phải đẻ ra cụ thể như nhau, chỉ mang hình tool đã cài và exit code thật chứ không phải URL đã deploy.

Có một nếp đáng biết. Một số wording cổng stage-05 vẫn nói “endpoint” và hỏi cột auth, hương vị web. Với loại khác bạn đọc “endpoint” thành “interface” hoặc “command” và thay writes cùng side-effect cho auth — phần mở đầu stage cấp phép thích nghi đó tường minh, và check no-drift tương đương là bằng chứng done theo loại thật sự pass.

Bảng theo loại, trình tự card, và ghi chú wording cổng:
[`skills/flow/references/project-types.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/project-types.md)

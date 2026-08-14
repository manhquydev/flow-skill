---
title: "Dự án greenfield đầu tiên"
description: "Đưa dự án mới từ ý tưởng qua sáu cổng planning tới build card, và xem mỗi cổng từ chối gì."
lang: vi
---

Tutorial này đưa một thư mục trống tới một build card thật. Bạn sẽ viết sáu artifact planning, mỗi cái bị phán hai lần — một lần bởi script không tranh cãi được, một lần bởi model đọc với tư cách phê bình.

Cần cài skill trước: [Cài đặt và lần chạy đầu](/vi/docs/tutorials/install-and-first-run).

Thời gian: một đến hai giờ, tùy bạn trung thực thế nào ở cổng Scope.

## Pipeline sắp đi

```
Idea -> Research -> Scope -> PRD -> ADR -> Contract -> Cards -> Build -> Review -> Deploy -> Verify-live -> Retro
|------------------ planning (files in flow/) ------------------|  |------- shipping (inside cards/) -------|
```

Planning là stage `00` tới `05`, sống thành file dưới `flow/`. Shipping xảy ra trong `cards/`. Không cắt được card cho đến khi cả sáu cổng planning đã pass hoặc mang debt ghi trung thực.

## Bước 1 — chọn “done” nghĩa là gì

```
/flow project-type web
```

Loại dự án quyết định bằng chứng harness sẽ đòi lúc cuối: URL deploy live cho `web`, một lần gọi thật với output và exit code đúng cho `cli`, public API import được cộng ví dụ chạy được cho `library`, skill đã cài và đạt done-definition của chính nó cho `skill`. Mặc định là `web`. Đặt ngay để khỏi viết contract sai hình.

## Bước 2 — quyết ai viết artifact

```
/flow mode teach
```

Mode `teach` — mặc định — **bạn** viết mọi artifact planning, agent chỉ gác cổng. Mode `work` thì agent phỏng vấn một lần, tự soạn stage `00` tới `05`, chỉ dừng để duyệt scope. Cổng ràng buộc giống nhau; khác duy nhất là tay ai gõ.

Nếu đang học harness, ở `teach` cho dự án đầu. Bạn sẽ thấy mỗi cổng thực sự kiểm gì.

## Bước 3 — stage 00, ý tưởng

```
/flow next
```

Runner tạo `flow/00-idea.md` rồi fail cổng, vì template đầy `[FILL]` và ô chưa tick. Mở file, viết pitch ba câu: ai có vấn đề, họ đang làm gì, bạn sẽ làm gì khác. Tick ô bạn thật sự đã thỏa. Chạy `/flow next` lại.

Khi script pass, agent áp dụng thử thách ngữ nghĩa cho stage vừa xong. Đây là nửa script không làm được: nó đẩy lại nếu “vấn đề” của bạn là giải pháp đội lốt, hoặc pitch mô tả feature thay vì người đang đau.

**Kill dự án ở đây là kết quả hợp lệ.** Ý tưởng yếu chết ở stage 00 tốn một giờ. Cùng ý tưởng đó chết sau contract tốn một tuần.

## Bước 4 — stage 01, research

Điền `flow/01-research.md` bằng thứ đã tồn tại: đối thủ, hệ thống live bạn đã mở, giá bạn thật sự kiểm. Luật của stage này là *inspect first — bằng chứng, không phải vibe*.

Cổng ngữ nghĩa ở đây sắc hơn thường, vì research bịa là thứ dễ viết nhất và khó bắt nhất bằng script. Quote không nguồn, đối thủ chưa mở, số thị trường không link — hãy chờ bị hỏi lấy từ đâu.

Nếu stage thật sự không khớp — tool nội bộ không có thị trường công, ví dụ — đừng bịa. Ghi debt rồi skip trung thực:

```
/flow debt add "skip 01-research" "internal tool, no public market" "before public release"
/flow skip 01-research --reason "internal tool, no public market"
```

`skip` chỉ tiến khi có dòng debt mở đúng stage đó, và lý do không thuộc nhóm bảo mật.

## Bước 5 — stage 02 tới 04: scope, PRD, ADR

- **Scope** (`flow/02-scope.md`) là chỗ dự án thường được cứu hoặc mất. Chấm hạng feature trung thực; cổng ngữ nghĩa đang nhìn dìm hạng — feature hạng C được viết thành B vì bạn muốn build.
- **PRD** (`flow/03-prd.md`) biến scope sống sót thành functional requirement có số. Mỗi `FRn` viết ở đây sau này phải được một card claim và một interface contract phục vụ — truy vết đó kiểm được bằng máy.
- **ADR** (`flow/04-adr.md`) ghi quyết định kiến trúc, và quan trọng hơn: cái bạn đã loại và vì sao.

Chạy `/flow next` sau mỗi stage. Thứ chưa xong nằm dưới heading `## Open decisions` dạng `- [ ]`; cùng scanner cổng đếm các bullet đó, nên quyết định treo chặn stage cho đến khi bạn chốt hoặc chủ động chuyển đi.

## Bước 6 — stage 05, contract

`flow/05-contract.md` là seam, và là stage duy nhất không bao giờ skip được. Viết interface trước khi có code: method, path, auth, request/response cho web — lệnh, flag, hình output, exit code cho CLI.

Từ đây luật tuyệt đối: backend build **tới** contract, UI consume **từ** nó. Shape sai thì sửa contract trước rồi mới sửa code. Tôn trọng một shape ngay bằng null hoặc stub dù giá trị thật ship ở card sau.

Khi cổng này pass bạn sẽ thấy:

```
PASS: stage 05-contract gate clean. Planning is COMPLETE.
All planning stages passed (or were debt-skipped). Run '/flow card' to create build cards.
```

## Bước 7 — cắt card đầu

```
/flow card
```

Lệnh này viết `cards/C-001.md`. Một card là một phiên build có phạm vi: danh sách allowed-files, requirement nó implements, khối `## Verify` bạn sẽ thật sự chạy, `## Independent test` mô tả bằng chứng người dùng thấy, và `## Evidence` bắt đầu trống.

Trước khi build, chạy `/flow recall` — nó đọc lại debt mở, retro gần nhất, scope card trước, playbook đã promote, để bạn bắt đầu với nỗi đau cũ trong tầm mắt.

## Bước 8 — build, rồi chứng minh

Chỉ build những path mà danh sách allowed-files của card nêu. Rồi:

```
/flow check C-001
```

Card fail khi `## Evidence` còn trống, dù code hoàn hảo và mọi test xanh:

```
  [x] status is 'done' but ## Evidence is empty (paste world-state proof: URL/curl/DB row)
FAIL: C-001 has gate violations (above).
```

Dán bằng chứng thật — URL live kèm output curl thật cho web, lần gọi thật và exit code cho CLI — rồi check lại:

```
PASS: C-001 is valid (status: done).
```

## Bạn đã học

- Sáu cổng planning, mỗi cái bị phán cơ học rồi ngữ nghĩa.
- Kill và skip có debt trung thực đều là kết quả hạng nhất.
- Contract viết trước code và là stage duy nhất không skip được.
- “Tests pass” là giữa pipeline; done là bằng chứng thế giới thật.

## Tiếp

- [Tạo và kiểm card](/vi/docs/how-to/create-and-check-cards) cho vòng hằng ngày.
- [Pipeline các stage](/vi/docs/explanation/stage-pipeline) cho mỗi stage đang chống tự lừa gì.
- [Done nghĩa là bằng chứng thế giới thật](/vi/docs/explanation/done-evidence) cho vì sao bước 8 khắt khe.

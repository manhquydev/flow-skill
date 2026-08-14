---
type: researcher
date: 2026-08-14
topic: vi-voice-semantics
conducted: 2026-08-14 09:20 +07
searches: 5
---

# Research Report: tiếng Việt trên flow — cách dùng, ngữ nghĩa, mạch nói

## Mục lục

- [Tóm tắt](#tóm-tắt)
- [Phương pháp](#phương-pháp)
- [1. Tiếng Việt không phải English ngắn hơn](#1-tiếng-việt-không-phải-english-ngắn-hơn)
- [2. Ngữ nghĩa thuật ngữ flow](#2-ngữ-nghĩa-thuật-ngữ-flow)
- [3. Cách dùng theo loại trang](#3-cách-dùng-theo-loại-trang)
- [4. Chẩn đoán copy hiện tại](#4-chẩn đoán-copy-hiện-tại)
- [5. Luật viết (sau vàng)](#5-luật-viết-sau-vàng)
- [So sánh hướng](#so-sánh-hướng)
- [Khuyến nghị triển khai](#khuyến-nghị-triển-khai)
- [Nguồn](#nguồn)
- [Phụ lục](#phụ-lục)
- [Câu hỏi còn mở](#câu-hỏi-còn-mở)

## Tóm tắt

Copy `/vi/` hiện đúng **thuật ngữ** (cổng, card, bằng chứng done) nhưng sai **cách nói**. Câu được dựng theo cú pháp đấm của English: mảnh rời, gạch ngang, “Không phải X. Là Y.”, chấm phẩy. Tiếng Việt nối ý bằng **chủ đề lặp + tiểu từ** (`thì`, `mà`, `chứ`, `mới`, `cả… lẫn…`), không bằng dấu câu Anh.

Hai pass trước fail đúng hai cực của cùng một lỗi: dịch slot (calque) và cắt cụt cho “punch” (telegram). Cả hai vẫn lấy câu Anh làm khuôn. Landing/hero phải **transcreation** (giữ ý, viết lại câu). How-to/reference được phép sát nghĩa hơn, miễn glossary ổn.

Không viết câu vàng trong báo cáo này. Luật dưới đây chỉ constrains bước bung sau khi operator gửi first viewport.

## Phương pháp

- Nguồn ngoài: 5 web search (trần skill), cộng fetch Microsoft Style Guides index, cộng ngữ liệu trong repo (`/vi/` landing, `what-is-flow`, `two-layer-harness`, glossary, `install-and-first-run`, `README_VN.md`, advise 0910).
- Khoảng tài liệu: giáo trình mạch lạc/liên kết (ổn định); UX writing VN 2024–2026; localization/transcreation 2023–2026; blog harness VI 2026.
- Tiêu chí nguồn: ưu tiên hướng dẫn địa phương hóa có ngữ cảnh UI, tài liệu kỹ thuật tiếng Việt, glossary Microsoft, bài viết developer VN cùng miền (harness/gate/skill). Bỏ blog dịch máy không có tác giả.
- Ranh giới: không nghiên cứu typography/Galley; không DNS; không viết lại page.

**Search terms:** Vietnamese localization transcreation UX; mạch lạc liên kết thì mà chứ; Microsoft Vietnamese style guide; Vietnamese UX writing microcopy 2024; calque harness gate skill tiếng Việt.

## Key Findings

### 1. Tiếng Việt không phải English ngắn hơn

#### 1.1 Chủ đề trước, đấm sau

Tiếng Việt là ngôn ngữ **đưa chủ đề lên trước** (topic-prominent). Câu tự nhiên hay là: *cái đang nói* → `thì` → *nhận định*. English landing đảo ngược: luật mới lên đầu, chủ đề cắt thành headline.

Hệ quả: dịch H1 “The gate opens only when both agree.” thành “Cổng chỉ mở khi cả hai cùng đồng ý.” thì **đúng nghĩa, hơi cứng**. Người nói chuyện việc thường đặt điều kiện làm chủ đề: muốn mở cổng → phải đủ hai bên. Không khóa câu thay. Chỉ khóa hướng thông tin: **cảnh rồi mới luật**, trừ khi operator tự viết luật-trước.

#### 1.2 Mạch lạc ≠ liên kết

Giáo trình ngữ văn tách hai thứ:

| | Là gì | Fail trên `/vi/` |
|---|--------|------------------|
| **Mạch lạc** | Cùng một đề tài, câu sau nối logic với câu trước | Landing nhảy: agent viết → bị chặn → máy chạy → skill soi → gạch. Đúng hết nhưng không có một sợi. |
| **Liên kết** | Phép lặp, đại từ, từ nối | Thay bằng `;` `—` và câu cụt. Mất `thì / mà / nên / chứ / mới`. |

Một đoạn VI đứng được khi **lặp từ chủ đề** (cổng, máy, skill) chứ không tránh lặp như prose Anh.

#### 1.3 Tiểu từ mang lập trường

Dấu câu Anh không thay được tiểu từ:

| Việc cần nói | Device Anh (cấm làm khuôn) | Device Việt |
|---|---|---|
| Điều kiện → kết quả | When X, Y. | X thì Y. / Phải X mới Y. |
| Không phải A mà B | Not A. It’s B. | Không phải A, mà là B. (một câu) |
| Cả hai bắt buộc | Both must. A — both. | Phải cả A lẫn B. Thiếu một bên thì… |
| Chốt / phản bác nhẹ | em-dash punch | chứ không phải… / mới đúng |
| Việc đã xong / bước sau | then / already | rồi / đã / mới tới |

Câu trên landing đã có một chỗ native: “Ý tưởng yếu **thì** gạch ngay tại cổng.” Đó là tín hiệu đúng. Xung quanh toàn fragment Anh.

#### 1.4 Transcreation vs dịch

Đồng thuận nguồn localization (Gojek UX, SimpleLocalize, 1StopAsia):

- **Transcreation** (landing, H1, lede, CTA cảm xúc): giữ ý + cảm, câu có thể khác hẳn.
- **Dịch có glossary** (how-to bước, reference, lệnh, số version): sát nghĩa, thuật ngữ khóa.
- Không transcreate lệnh, tên file, exit code, slug.

Gojek: viết như người địa phương nói chuyện hàng ngày; dịch **cảm**, không dịch **trò chơi chữ**. User gọi tính năng bằng tên họ dùng, không bằng tên product. Với flow: developer VN đã nói `skill`, `card`, `harness`, `npx` — giữ loanword. Đừng bịa “kỹ năng / thẻ / bộ khai thác”.

#### 1.5 Độ dài

VI thường dài hơn EN 20–30%. Pass telegram cắt cho vừa khung Galley chính là cách làm hỏng mạch. Cho phép câu dài hơn EN nếu có tiểu từ. Không được xóa `thì/mà` để “gọn”.

#### 1.6 Xưng hô và thể

UX VN 2024–2026:

- `Bạn` = mặc định sản phẩm, trung tính.
- `Quý khách` = ngân hàng / formal — cấm.
- `Vui lòng…` = calque “Please” — cứng. How-to dùng động từ trần: “Chạy…”, “Restart…”.
- Pro-drop (bỏ đại từ) nghe như nhắn đồng nghiệp. Landing vàng của operator có thể không có “bạn”. Đừng nhét “bạn” vào cho “đủ UX”.
- `Chúng tôi` gần như không cần: flow là tool, không phải công ty nói.

#### 1.7 Dấu thanh

Bắt buộc đủ dấu. Bỏ dấu đổi nghĩa (`ma / má / mà / mả / mã`). Unicode NFC. Không “viet tat” trên site.

---

### 2. Ngữ nghĩa thuật ngữ flow

Không dịch từng morpheme. Mỗi từ có **trường nghĩa** và **cái không được kéo theo**.

| Term | Giữ | Nghĩa đang dùng | Không kéo theo | Ghi chú |
|---|---|---|---|---|
| **cổng** | VI | Điểm không qua thì không tiến. Cụ thể như cổng nhà/sân. | `cửa` (đã = chat mặc định), `gate` English trên UI, `checkpoint` dịch “điểm kiểm” | Khóa. Metaphor vật lý ổn trong VI. |
| **card** | EN | Một phiên build có phạm vi, file `cards/C-NNN.md`. | `thẻ` (bài / ATM / nhân dân) | Khóa. Microsoft cũng hay DNT danh từ sản phẩm. |
| **bằng chứng done** | lai | Bằng chứng thế giới thật card đã xong. | `hoàn thành`, `xong` trần, `tests pass` | `done` giữ EN vì `xong` yếu, `hoàn thành` công sở. |
| **skill** | EN | Gói hướng dẫn agent đọc. | `kỹ năng` (HR / CV) | Developer VN giữ `skill`. |
| **harness** | EN | Vòng kiểm quanh agent: ràng buộc, tool, cổng. | `bộ khai thác` (đào), `dây cương` (thơ), `khung` | Blog VN 2026 giữ `harness`. Giải thích một lần, đừng calque. |
| **flow.sh / runner** | EN / ? | Script exit 0/1. | `máy chạy` nếu operator không nói vậy | `máy chạy` là từ bịa cho “runner”. Ambiguous. Chờ vàng. |
| **kill** | EN trong glossary | Bỏ cuộc tại cổng = kết quả đúng. | `failure`, `gạch` (một register khác) | Landing đang dùng `gạch`. Glossary dùng `Kill` / bỏ cuộc. Phải một miệng. |
| **layer / lớp** | tránh trưng bày | Trong docs = cơ học vs ngữ nghĩa. | “hai lớp” làm slogan landing | Advise cấm “lớp/cơ học” làm metaphor hero. Docs giải thích được phép dùng nếu cần, nhưng đừng nhái EN “mechanical layer”. |
| **done** | EN | Trạng thái có bằng chứng. | `xong` khi nói cổng | Giữ trong “bằng chứng done”. |
| **agent** | EN | Model đang viết code. | `trợ lý`, `tác nhân` | Loanword đã ổn. |

**Do-not-translate (DNT):** `flow`, `flow.sh`, `/flow next`, `/flow card`, `npx @manhquy/flow-skill@latest`, tên stage (`Idea`…`Contract`), path (`flow/00-idea.md`), `exit 0/1`, `[FILL]`, `SKILL.md`, `card`, `skill`, `harness` (khi là tên kỹ thuật).

**Dịch được, một lần rồi khóa:** cổng, bằng chứng done, nợ (`debt` có thể giữ EN trong reference), chế độ teach/work.

Microsoft terminology (nguyên tắc, không copy glossary Windows): UI thường (`Sao chép`, `Đã sao chép`) thì dịch; tên sản phẩm / API / file thì DNT. Lockup hiện tại đúng hướng.

ShipWithAI và blog harness VN: `Agent = Model + Harness`. Họ **không** dịch harness. Flow càng không nên dịch — dễ đụng nghĩa “test harness” cũ hoặc “khai thác”.

---

### 3. Cách dùng theo loại trang

| Loại | Giọng | Dịch hay viết lại | Mẫu câu |
|---|---|---|---|
| Landing / hero | Khẩu ngữ việc, như nhắn Zalo đồng nghiệp | Transcreation | Chủ đề → thì → chốt. Một sợi suốt viewport. |
| Explanation (`what-is-flow`, `two-layer-harness`) | Văn viết kỹ thuật nhẹ, vẫn nói được | Viết lại từ claim, không map câu EN | Đoạn 3–6 câu, phép lặp chủ đề, định nghĩa tại chỗ |
| Tutorial / how-to | Mệnh lệnh, từng bước | Sát nghĩa + glossary | Động từ đầu câu. Không “Vui lòng”. |
| Reference / glossary | Khô, ổn định | Sát nghĩa | Bảng term. Một nghĩa / term. |
| Stub (31) | Để nguyên | Không đụng | — |

`README_VN.md` gần miệng người viết hơn docs site: “Chat là cửa mặc định”, “đẻ” không xuất hiện, câu có nhịp nói. Docs explanation đang đặc Hán-Việt + metaphor Anh (“băng chuyền”, “thăng chức lặng lẽ”, “Failure mang tính hệ thống”). Đó là calque học thuật, không phải “đúng hơn landing”.

---

### 4. Chẩn đoán copy hiện tại

Đây là **cơ chế lỗi**, không phải bản thảo thay thế để ship.

#### Landing (`website/src/pages/vi/index.astro`)

| Chỗ | Hiện tại | Lỗi |
|---|---|---|
| Lede | `Agent vẫn viết code; flow quyết đi tiếp hay phải dừng.` | Chấm phẩy Anh. “quyết đi tiếp” = calque *decides to advance*. |
| Lede | `Bị chặn ở cổng không sao — đó là kết quả đúng.` | Gạch ngang + `kết quả đúng` = *valid outcome*. Nghe biên bản. |
| Verdict | `Máy chạy và skill — phải cả hai.` | Câu không động từ. Telegram. |
| Máy chạy | `Không cảm tính. Không “chắc là được”.` | Hai fragment. Mất chủ đề. |
| Skill | `Skill soi việc vừa làm có rỗng không.` | Calque *looks whether the work is hollow*. “rỗng” đúng nghĩa sản phẩm nhưng câu Anh. |
| Stand H2 | `Không phải agent viết code. Là cổng đứng quanh agent.` | Khuôn *Not X. It’s Y.* “đứng quanh” = *gates around*. |
| Band | `Sáu cổng rồi mới tới card build đầu` | Gần native (`rồi mới tới`). Giữ hướng này. |

H1 “Cổng chỉ mở khi cả hai cùng đồng ý.” — advise giữ trừ khi operator đổi. `cùng đồng ý` hơi lễ. Không sửa trước vàng.

#### Explanation

`what-is-flow.md`: “Failure mang tính hệ thống chứ không cục bộ”, “thăng chức lặng lẽ thành trạng thái cuối”, “Kill tại gate là hợp lệ”, “harness chỉ biết nói tiến thì là băng chuyền”.

- Trộn EN (`Failure`, `Kill`, `gate`) giữa câu Việt.
- Metaphor nhà máy Anh (*quietly promoted*, *conveyor belt*).
- “Ba cam kết, mọi thứ khác đi theo” = slogan dịch.

`two-layer-harness.md`: “Lớp một — cổng cơ học”, “relay trung thực”, “nửa gian được thành bắt buộc chứ không thuyết phục được”. Đúng ý sản phẩm, sai miệng. Title “Harness hai lớp” ổn cho URL; body đừng nhại sơ đồ EN.

#### How-to

`install-and-first-run.md` khá hơn: bước rõ, lệnh DNT, “Luôn ghi `@latest`”. Vẫn còn câu dịch: “đúng hành vi mà cả harness tồn tại vì nó”, “âm thầm chạy bản cũ” (ổn), “lớp SQLite bền vững tắt” (nặng). Tutorial chịu được độ khô hơn landing.

#### Glossary

Khóa đúng cổng / card / bằng chứng done. Đang khóa thêm “Lớp cơ học / Lớp ngữ nghĩa” — hữu ích cho docs, **không** copy ra hero.

---

### 5. Luật viết (sau vàng)

Dùng khi bung từ trang vàng. Không dùng để bịa hero.

1. **Viết từ claim, không từ câu EN.** Claim đã có trong advise 0910.
2. **Một sợi chủ đề / viewport.** Landing: sợi = cổng mở khi đủ hai bên. Mọi câu móc lại sợi đó (phép lặp).
3. **Cấm khuôn Anh:** Not X. It’s Y. / A — B. / A; B. / ba fragment xếp chồng.
4. **Bắt buộc có tiểu từ khi có quan hệ:** điều kiện=`thì`/`mới`; đối lập=`mà`/`chứ`; xong bước=`rồi`.
5. **Cho phép câu dài hơn EN.** Cấm cắt tiểu từ cho vừa cột.
6. **Loanword khi dân code đã nói.** skill, card, harness, agent, npm, exit. Cấm “kỹ năng / thẻ / bộ khai thác / tác nhân”.
7. **Một miệng / một nghĩa.** `gạch` vs `bỏ` vs `dừng` vs `chặn` vs `kill` — operator chọn một, cả site theo.
8. **`máy chạy` chưa khóa.** Nếu vàng không dùng, đổi sang `flow.sh` hoặc lời operator.
9. **Không metaphor mới.** Không băng chuyền, dây cương, nhà máy, “đứng quanh”.
10. **How-to:** động từ trần, `Bạn` tùy chọn, không `Vui lòng`.
11. **Reference:** khô, bảng, DNT nguyên.
12. **31 stub:** không đụng.
13. **Test:** operator đọc to. Pass = không sửa câu trong đầu, dám gửi group. Agent không tự chấm pass.
14. **Thứ tự bung:** landing còn lại → `what-is-flow` → `two-layer-harness` → `install-and-first-run` → 12 trang full.

## So sánh hướng

Đã chọn ở brainstorm: **A — vàng rồi mới bung**. B (bible trước) và C (vá particle) bị loại.

Tách nội dung (SimpleLocalize): hero = transcreation; docs thao tác = dịch có glossary. Đừng áp một giọng cho cả site.

## Khuyến nghị triển khai

### Việc tiếp (không làm trong report này)

1. Operator gửi vàng: hero + hai cột + lockup, như nhắn đồng nghiệp. Có dấu.
2. Agent dán nguyên văn, không “chỉnh punch”.
3. Bung phần landing dưới-the-fold theo luật §5, rồi 3 trang trụ, rồi 12 full.
4. Mỗi trang: đọc to (operator) trước khi qua trang sau.

### Bẫy thường gặp

| Bẫy | Vì sao hỏng | Xử |
|---|---|---|
| Dịch từng slot H1/lede/verdict | Pass 1 | Claim list, không map câu |
| Cắt ngắn cho Galley | Pass 2 | Giữ tiểu từ, chấp nhận dài |
| Bịa `máy chạy` / `gạch` cho “có vị” | Từ không ai nói | Chờ vàng |
| Dịch harness/skill/card | Calque HR / bài / đào | DNT |
| Voice bible trước vàng | Giấy thắng miệng | Cấm |
| Agent tự chấm “nghe tự nhiên” | Tai không phải native cho bản này | Chỉ operator |

### “Security” nghĩa là toàn vẹn claim

Không được làm mềm cổng để nghe dễ chịu. “Dừng ở cổng là đúng” ≠ “không sao, bỏ qua”. Kill/dừng là **kết quả hạng một**, không phải xin lỗi. Copy không được biến flow thành agent viết code (stand hiện tại suýt vậy rồi phải phủ định).

### “Performance” nghĩa là đọc được

- First viewport: ≤ 60 giây đọc to, không vấp.
- VI dài hơn EN: đừng nhồi ba claim vào một fragment.
- How-to: một hành động / bước, lệnh tách khối `translate="no"`.

## Nguồn

### Official / style

- [Microsoft Localization Style Guides](https://learn.microsoft.com/en-us/globalization/reference/microsoft-style-guides) — có [Vietnamese](https://aka.ms/vietnamese-styleguide) (PDF; fetch aka.ms lúc nghiên cứu trả 500, index 2025-05-02 xác nhận guide tồn tại).
- [Microsoft language resources / terminology](https://learn.microsoft.com/en-us/globalization/reference/microsoft-language-resources)
- [Managing terminology](https://github.com/MicrosoftDocs/globalization/blob/main/globalization/localization/managing-terminology.md) — DNT cho brand và term thị trường đã nói English.

### Localization / transcreation

- [Gojek — How we localise UX copies](https://www.gojek.io/blog/language-no-bar-how-we-localise-ux-copies-at-gojek) — nói như người địa phương; dịch cảm; tên do user gọi.
- [SimpleLocalize — Translation vs transcreation](https://simplelocalize.io/blog/posts/translation-vs-transcreation/) — hero = transcreation; UI/docs/legal = dịch.
- [1StopAsia Vietnamese marketing/copy quality guide (PDF)](https://www.1stopasia.com/blog/wp-content/uploads/articles-download/Vietnamese-Language-Quality-Guide-Marketing-and-Copywriting-%20Final.pdf) — authentic local, không literal; khiêm + thực dụng.
- [Translated — software localization](https://translated.com/resources/software-localization-best-practices-technical-excellence) — context UI, không dịch string trần.
- [XTM — Software localization 2026](https://xtm.ai/blog/software-localization) — visual context.

### Tiếng Việt / UX VN

- [Mạch lạc và liên kết trong văn bản](https://mcbooks.vn/mach-lac-va-lien-ket-trong-van-ban/)
- [Thùy Dương — quy trình UX writing](https://thuyduong.co/quy-trinh-viet-noi-dung-ux-writing/)
- [vietnamcos — Voice/Tone UX Writing](https://www.vietnamcos.com/courses/lesson/ux-metrics-and-analytics/bai-59-voice-va-tone-trong-ux-writing) — `Bạn`; đừng over-translate `login`; đọc to.
- [Claude.vn — UX copy tiếng Việt](https://claude.vn/articles/claude-cho-design-ux-copywriting-hi%E1%BB%87u-qu%E1%BA%A3) — cấm “Vui lòng” calque; CTA động từ.
- [ClickUp VI — viết tài liệu kỹ thuật](https://clickup.com/vi/blog/111583/how-to-write-technical-documentation) — một chủ đề / đoạn, active, Diátaxis.

### Cùng miền thuật ngữ

- [ShipWithAI — Harness engineering](https://shipwithai.io/vi/blog/harness-engineering-claude-code/) — giữ `harness`, không calque.
- [VDict — calque](https://vdict.com/calque,1,0,0.html) — dịch từng phần ≠ loanword.

### Nội bộ

- [advise-260814-0910-vi-voice.md](./advise-260814-0910-vi-voice.md)
- [brainstorm-260814-0920-vi-voice-semantics.md](./brainstorm-260814-0920-vi-voice-semantics.md)
- `website/src/pages/vi/index.astro`
- `website/src/content/docs/vi/docs/explanation/what-is-flow.md`
- `website/src/content/docs/vi/docs/explanation/two-layer-harness.md`
- `website/src/content/docs/vi/docs/reference/glossary.md`
- `README_VN.md`

## Phụ lục

### A. Glossary nghiên cứu (không thay glossary site)

- **Calque:** dịch từng mảnh (*hollow* → rỗng trong câu Anh). Khác loanword (`skill` giữ nguyên).
- **Transcreation:** viết lại để cùng ý/cảm, khác câu.
- **DNT:** do not translate.
- **Topic-comment:** chủ đề rồi bình. `thì` là dấu chủ đề thường gặp.
- **Telegram:** cụt dấu, mất tiểu từ, nghe lệnh không nghe người.
- **Mạch lạc / liên kết:** thống nhất đề tài vs keo hình thức.

### B. Compatibility

Không áp dụng. Site: Astro/Starlight, locale `/` EN + `/vi/`.

### C. Raw notes

- 5 search. Gojek full-page 429; vẫn dùng snippet search (đủ luật “nói như local”).
- Microsoft Vietnamese style guide PDF: aka.ms 500 lúc fetch. Nguyên tắc lấy từ index + terminology docs.
- Blog harness VI xác nhận thị trường giữ `harness`/`skill`/`gate` trong prose kỹ thuật; landing vẫn nên nói `cổng` vì đã khóa và cụ thể hơn `gate`.

## Câu hỏi còn mở

1. Operator đã có vàng first viewport chưa? (blocker bước bung)
2. `máy chạy` giữ hay bỏ?
3. Một miệng cho dừng cổng: `gạch` / `bỏ` / `dừng` / `chặn` / `kill`?
4. Hero có `bạn` hay pro-drop?
5. H1 hiện tại giữ hay operator đổi?
6. Docs explanation: giữ title “Harness hai lớp” (slug) hay đổi title hiển thị cho gần miệng hơn?

## Next steps

1. Operator gửi vàng (hero + 2 cột + lockup).
2. Không cook VI trước vàng.
3. Sau vàng: bung theo luật §5 + thứ tự advise 0910.

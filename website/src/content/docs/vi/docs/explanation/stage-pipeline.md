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

## Vì sao contract không bao giờ skip được {#contract-never-skipped}

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

## Vượt cổng bằng `/flow next` {#advance-with-next}

`/flow next` kiểm cổng stage bạn đang đứng và, chỉ khi pass, mở stage kế. Runner lấy file số cao nhất đã có trong `flow/` làm stage hiện tại. Planning xong chỉ khi cả sáu cổng stage sạch; lúc đó `/flow card` mới mở.

Khi lớp cơ học fail nó in đúng cái sai kèm số dòng: ô cổng chưa tick, `[FILL]` còn sót, rồi dừng. FAIL không bao giờ tiến. Listing đó là cả chẩn đoán: mở file được nêu, sửa đúng những dòng đó, chạy `/flow next` lại. Đừng đoán ô nào trống.

Khi script pass, thử thách ngữ nghĩa của stage vừa xong được áp trước khi bạn được phép đi tiếp, nên artifact sạch cơ học nhưng rỗng vẫn bị gọi là yếu. Ở mode `teach` agent không bao giờ tick ô hoặc viết artifact hộ bạn; nó chỉ nói cái gì đang fail.

Kill là trạng thái kết thúc hợp lệ. Dừng ở bất kỳ cổng nào, nhất là Scope, là kết quả được tôn trọng, không phải flow thất bại. Pass, chặn, và kill là ba câu trả lời; harness chỉ biết nói “tiến” thì là băng chuyền.

## Loại dự án {#project-types}

`flow` sinh ra theo hình web. Cách trung thực để hỗ trợ loại phần mềm khác không phải khái quát hóa cổng thành mơ hồ mà là nêu đúng ba thứ đổi. Đặt loại bằng `/flow project-type web|cli|library|skill` trước stage 05. Giá trị lưu trong file `PROJECT_TYPE`, mặc định `web`. Chạy không đối số in giá trị hiện tại và luật bằng chứng done nó kéo theo.

Loại thích nghi seam contract stage 05, trình tự card chuẩn, và bằng chứng done nghĩa là gì. Mọi thứ khác (tinh thần mỗi cổng, “contract trước code”, “done là bằng chứng thế giới thật”) không đụng. Đổi sau nghĩa là phải xem lại contract, nên rẻ bây giờ và đắt sau.

- **web.** Contract: HTTP endpoint (method, path, auth, request, response); OpenAPI được phục vụ. Done: URL đã deploy live cộng output `curl` thật.
- **cli.** Contract: lệnh, flag, shape output, exit code. Done: tool cài được và một lần gọi thật trả output và exit code đúng. Việc đầu trên lần build CLI: `/flow project-type cli`.
- **library.** Contract: bề mặt public API, hàm và type export kèm shape. Done: public API import được, ví dụ dùng chạy được, đạt ngưỡng coverage.
- **skill.** Contract: lệnh và file mà agent đọc. Done: đã cài vào skill home và một lần chạy thật đạt done-definition của chính nó. Việc đầu trên lần build skill: `/flow project-type skill`.

Lần build CLI không phải lần build web pha loãng: bằng chứng nó phải đẻ ra cụ thể như nhau, chỉ mang hình tool đã cài và exit code thật chứ không phải URL đã deploy. Bản thân các cổng không đổi; chỉ hình của bằng chứng dịch chuyển.

Một số wording cổng stage-05 vẫn nói “endpoint” và hỏi cột auth, hương vị web. Với loại khác bạn đọc “endpoint” thành “interface” hoặc “command” và thay writes cùng side-effect cho auth. Phần mở đầu stage cấp phép thích nghi đó tường minh, và check no-drift tương đương là bằng chứng done theo loại thật sự pass.

## Ma trận loại dự án {#project-types-matrix}

Đặt bằng `/flow project-type <web|cli|library|skill>`, lưu trong `PROJECT_TYPE`, mặc định `web`.

| Loại | Seam contract (stage 05) | Bằng chứng done | Trình tự card |
|---|---|---|---|
| `web` | HTTP endpoint: method, path, auth, request, response; OpenAPI được phục vụ | URL đã deploy live cộng output `curl` thật | scaffold và `/healthz`, lát cắt dọc, backend, contract test, UI mock, frontend, e2e |
| `cli` | Lệnh, flag, shape output, exit code | Tool cài được và một lần gọi thật trả output và exit code đúng | scaffold cộng một lệnh thật, nhóm subcommand, test, smoke cài trên thư mục sạch |
| `library` | Bề mặt public API: hàm và type export kèm shape | Public API import được, ví dụ dùng chạy được, đạt ngưỡng coverage | scaffold cộng core API, các vòng API, test, ví dụ dùng chạy được, dry-run publish |
| `skill` | Lệnh và file mà agent đọc | Cài vào skill home và một lần chạy thật đạt done-definition của chính nó | scaffold cộng một lệnh chạy được, references và law, cài, một lần chạy dogfood |

Hằng số trên cả bốn loại: mọi requirement map tới một interface, mọi interface có shape viết trước code, contract là seam, và “tests pass” hoặc “merged” không bao giờ là done.

## Chế độ và chiến lược chạy {#modes}

`flow` có bốn trục mode và chúng thật sự độc lập, nên bạn đặt từng cái theo dự án rồi kết hợp theo nhu cầu work.

**Mode soạn** quyết ai viết artifact ở cổng: `teach`, mặc định, nghĩa là bạn viết và agent chỉ gác cổng; `work` nghĩa là agent phỏng vấn một lần, soạn stage 00 tới 05, chỉ dừng để duyệt scope.

**Loại dự án** quyết done nghĩa là gì: URL live cho web, lần gọi thật và exit code cho CLI, API import được cho library, lần chạy đã cài cho skill.

**Chế độ chạy** quyết card được build thế nào: thủ công, bạn lái card, build, check; hoặc auto, lần chạy tự động xử lý theo tier và HALT với work nhóm bảo mật.

**Greenfield versus brownfield** quyết bạn bắt đầu đâu: stage 00-idea cho thứ mới, hoặc bản đánh giá hiện trạng có cổng cho codebase có sẵn.

Không trục nào đổi thanh. Cổng và luật done giống nhau mọi tổ hợp; mode dịch người soạn, hình bằng chứng, và cách lái, không bao giờ chiều cao cổng.

## Làm rõ quyết định còn mở {#clarify-open-decisions}

Quyết định sản phẩm chưa xong sống thành bullet `- [ ]` dưới heading `## Open decisions` trên artifact Scope, PRD, và Contract. Chúng được đếm bởi *cùng* scanner ô mà các cổng đã dùng, nghĩa là quyết định chưa chốt thật sự chặn stage chứ không ngồi trong comment không ai đọc.

`/flow clarify` in các bullet sót đó, scoped đúng section, và luôn exit 0. Nó là máy in cố vấn, không phải cổng thứ hai. Chốt chúng là nghi thức write-back có biên, opt-in: đi từng bullet, ghi quyết định vào artifact, rồi tick ô. Không gì về `clarify` là điều kiện tiên quyết của `/flow next`; scanner cổng đang ép các ô vốn đã là điều kiện đó.

## Artifact từng stage {#stage-artifacts}

Runner copy template vào dự án khi mỗi stage mở. Artifact planning sống dưới `flow/`, đơn vị shipping dưới `cards/`, và sổ cái ở root dự án. Path dưới đây là file, không phải heading.

| Path | Stage | Nội dung |
|---|---|---|
| `flow/00-idea.md` | 00 | Pitch ba câu: ai có vấn đề, họ đang làm gì, bạn sẽ làm gì khác |
| `flow/00-inspect.md` | brownfield | Đánh giá hiện trạng: stack, chức năng đối với mục tiêu sản phẩm, rủi ro, baseline test |
| `flow/01-research.md` | 01 | Thứ đã tồn tại: đối thủ, hệ thống live, bằng chứng thật |
| `flow/02-scope.md` | 02 | Feature đã chấm hạng, phần cắt, và duyệt scope |
| `flow/03-prd.md` | 03 | Functional requirement có số (`FRn`) |
| `flow/04-adr.md` | 04 | Quyết định kiến trúc, kể cả option đã loại |
| `flow/05-contract.md` | 05 | Interface, viết trước code. Seam. Không bao giờ skip được |
| `flow/constitution.md` | tùy chọn | Bất biến per-dự-án operator tự viết, cố vấn |
| `cards/C-NNN.md` | build | Một phiên build có phạm vi: allowed files, implements, verify, independent test, evidence, risk |
| `MODE`, `PROJECT_TYPE` | - | Mode soạn và loại dự án |
| `DEBT.md`, `RETRO.md`, `AUTO-LOG.md` | - | Skip có chủ đích, dòng retro, log lần chạy tự chủ |
| `.flow/harness.db` | - | Bản ghi bền vững |

Mọi artifact planning đi kèm placeholder `[FILL]` và ô cổng; cả hai được scan cơ học, và cái nào chưa xong đều fail stage. Quyết định chưa xong thuộc dưới heading `## Open decisions`, nơi cùng scanner đếm chúng.

## Xem thêm

- [Cổng và thử thách ngữ nghĩa](/vi/docs/explanation/what-is-flow#semantic-challenges)
- [Done nghĩa là gì](/vi/docs/explanation/what-is-flow#done-means-world-state)
- [Dự án greenfield đầu tiên](/vi/docs/tutorials/first-greenfield-project)
- [Khi việc phải dừng](/vi/docs/explanation/auto-tiers-and-security-halts)

---

Nơi maintainer (không phải trang công khai): [`skills/flow/references/stage-state-machine.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/stage-state-machine.md), [`skills/flow/references/project-types.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/project-types.md), [`skills/flow/references/mode-work.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/mode-work.md), [`skills/flow/references/clarify.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/clarify.md).

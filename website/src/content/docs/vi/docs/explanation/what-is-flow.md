---
title: "flow là gì"
description: "flow là harness build có cổng cho coding agent: cổng trung thực giữa ý tưởng và bằng chứng done thật, không phải lớp quản lý dự án."
lang: vi
---

`flow` là harness build có cổng. Sản phẩm đi từ ý tưởng tới bằng chứng done thật: URL đã deploy, CLI cài rồi chạy, library API import được, hoặc skill đạt done-definition của chính nó. Cổng nào cũng phải thỏa trung thực trước khi được phép tiến.

Bạn cài nó vào coding agent. Không phải dịch vụ đăng ký, không phải framework để code bám vào. **Flow sở hữu cổng và biên nhận, không bao giờ sở hữu runtime.** **Độc lập**: AgentKit hay claudekit không bắt buộc; review đa model chỉ mở khi engine đó đang có mặt.

## Vấn đề nó tồn tại vì

Coding agent vui vẻ đẻ plan hợp lý, tài liệu research hợp lý, rồi tuyên bố work đã xong cũng hợp lý. Từng artifact đọc ổn khi đứng một mình. Lỗ hổng nằm ở vòng, không nằm ở một file: không gì được đặt để nói *không*.

Hai mode fail chiếm hầu hết thiệt hại.

**Giấy tờ trông như tiến độ.** Research với quote đối thủ bịa vẫn pass check cấu trúc. Scope nơi feature hạng C được viết thành B cũng pass. Cả hai đọc ổn; không cái nào sống sót khi chạm thực tế.

**“Done” mà chưa done.** Agent báo card xong vì test xanh và nhánh đã merge. Không ai load trang. Không ai chạy lệnh. “Tests pass” là trạng thái giữa pipeline bị thăng chức lặng lẽ thành trạng thái cuối.

## flow làm gì với chuyện đó

Ba cam kết, phần còn lại đi theo.

**Done nghĩa là bằng chứng thế giới thật.** Mỗi card nêu bằng chứng done từ đầu, và cổng đòi bằng chứng đó được dán vào trước khi card được đánh dấu done. Web: URL live và output `curl` thật. CLI: một lần gọi thật kèm exit code. Code đã merge và CI xanh bị từ chối tường minh. Xem [Done nghĩa là bằng chứng thế giới thật](#done-means-world-state).

**Hai lớp phải đồng ý.** Script xác định bắt phần cơ học gian được (ô chưa tick, `[FILL]` còn sót, evidence rỗng) rồi exit 0 hoặc 1. Model đọc skill bắt cái script không bắt được: research bịa, scope dìm hạng, endpoint không auth. Cổng chỉ pass khi cả hai đồng ý. Xem [Harness hai lớp](#two-layer-harness).

**Kill tại cổng là hợp lệ.** Harness chỉ biết nói “tiến” thì thành băng chuyền. Kill ý tưởng yếu ở Scope thì rẻ và khôn. flow coi đó là kết quả hạng nhất, không phải failure cần vòng vo.

## Những gì nó từ chối mang danh

Không board, không burndown, không estimate: không phải tool quản lý dự án. Không phải code generator; nó gác cổng bất kể agent hay người viết code. Không phải hệ CI, dù luật bằng chứng done khắt hơn hầu hết cổng CI. Cũng không phải wrapper làm agent thông minh hơn. Việc nó làm là buộc agent *chịu trách nhiệm*.

## Hình một lần chạy

```
Idea -> Research -> Scope -> PRD -> ADR -> Contract -> Cards -> Build -> Review -> Deploy -> Verify-live -> Retro
|------------------ planning (files in flow/) ------------------|  |------- shipping (inside cards/) -------|
```

Planning là sáu stage có cổng, sống thành file dưới `flow/`. Shipping là dãy card dưới `cards/`, mỗi cái một phiên build có phạm vi, bám contract viết ở stage 05. Giữa các session, store bền vững giữ debt, retro, trace, playbook, để session sau bắt đầu với nỗi đau cũ trong tầm mắt.

Chat là cửa mặc định: mô tả bạn muốn gì, Concierge đề xuất một hành động kế. Lệnh gõ như `/flow next` luôn thắng routing chat.

## Harness hai lớp {#two-layer-harness}

Đây là ý tưởng cốt. Phần còn lại là hệ quả.

Một cổng phải bắt hai loại fail rất khác nhau, và không thành phần nào giỏi cả hai. `flow` chạy hai lớp. Cổng chỉ pass khi **cả hai** đồng ý. Thiếu một lớp thì chưa pass.

### Lớp một: cổng cơ học

`runner/flow.sh` là engine bash xác định, exit 0 hoặc 1. Nó sở hữu vòng đời stage và card, và kiểm những thứ gian được dễ, phát hiện cũng dễ:

- ô cổng chưa tick, kể cả bullet `- [ ]` sót dưới `## Open decisions` (cùng một scanner xử lý cả hai)
- `[FILL]` còn sót
- status card hợp lệ
- section `## Evidence` rỗng trên card tuyên bố done

Exit code là ground truth. Luật cho model thẳng: luôn chạy script trước, đọc exit code, relay trung thực. Đừng thay bằng phán của mình.

Lớp này không đọc nghĩa. Nó không phân biệt quote đối thủ thật với quote bịa, hay feature hạng B trung thực với hạng C được viết thành B.

### Lớp hai: cổng ngữ nghĩa

Đó là việc của model. Sau khi script pass, skill áp một bộ thử thách theo từng stage trước khi operator được phép tiến. Đây là chỗ research bịa bị hỏi, scope dìm hạng bị gọi tên, endpoint không cột auth bị gắn cờ, và “tests pass” dán vào evidence bị từ chối vì vẫn giữa pipeline.

Chỉ dẫn đối xứng, quan trọng cả hai chiều: đừng lặng lẽ tiến qua artifact rỗng, và đừng lặng lẽ chặn artifact vững. Khi script pass nhưng nội dung yếu, operator được nói đúng vậy (pass cơ học, yếu về chất) rồi operator quyết.

### Vì sao tách, chứ không một checker thông minh hơn

Script không phán nghĩa. Model không đáng tin để xác định về cơ học. Tách chúng đặt mỗi lớp fail đúng chỗ bắt được, và biến nửa gian được thành bắt buộc chứ không thuyết phục được. Bạn không nói `exit 1` đổi ý. Bạn cũng không viết regex phát hiện quote thị trường bịa.

Lợi thứ hai tinh hơn. Lớp cơ học là process riêng với exit code thật, nên tuyên bố của model về một cổng kiểm được. Agent nói “cổng đã pass” đối chiếu được với tín hiệu nó không tự sản xuất.

### Lớp thứ ba: bộ nhớ bền vững

Dưới cả hai là lớp bền vững: store Python và SQLite giữ intake và risk lane, story và proof, trace và tier, decision, backlog. Nó suy giảm lịch sự: thiếu `python3` thì cổng vẫn chạy, chỉ lớp này tắt.

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

Đây là bộ nhớ ngoài. Tiến độ và ma sát sống sót qua session và cửa sổ ngữ cảnh. Đó là thuốc giải cho suy giảm chậm khi dự án dài chỉ sống trong conversation.

### Hệ quả cho agent

Agent gắn vào được; cổng cố định. Stage có thể ủy thác soạn cho agent chuyên khi có, và rơi về hành vi built-in khi không có. Cổng giống nhau trên mọi path, nên agent thiếu không bao giờ hạ thanh. Agent soạn; cổng vẫn phán.

Cùng luật chi phối engine khác hãng tùy chọn. Model thứ hai hoặc thứ ba có thể review một card, nhưng phán của nó hỗ trợ triage: không bao giờ tự pass và không bao giờ tự fail.

## Done nghĩa là bằng chứng thế giới thật {#done-means-world-state}

Mỗi card nêu bằng chứng done từ đầu, và cổng đòi bằng chứng đó được dán vào trước khi card được đánh dấu done. “Tests pass” và “code merged” là trạng thái giữa pipeline. Chúng không bao giờ là done.

### Failure mà điều này chặn

Cách build có agent hỗ trợ sai phổ biến nhất nằm ở status, không nằm ở bug. Card được báo xong vì test xanh, review đã duyệt, nhánh đã merge. Mỗi câu đó đúng. Không ai load trang.

Mỗi tín hiệu đó đo **proxy** của thứ bạn quan tâm. Test đo mô hình hệ thống của bạn đối với chính nó. Merge đo sự đồng ý về một diff. Không cái nào đụng thế giới đang chạy. Proxy lệch thực tế lặng lẽ, và lệch vô hình đúng lúc quan trọng nhất, vì mọi dashboard đều xanh.

Sửa không phải thêm proxy: đòi một lần quan sát thứ thật.

### Cái gì được tính, theo loại dự án

Loại dự án quyết định hình của bằng chứng. Tinh thần thì giống nhau mọi trường hợp: có người tương tác với thực tế đã deploy rồi dán cái quay về.

| Loại dự án | Bằng chứng done |
|---|---|
| `web` | URL đã deploy live cộng output `curl` thật |
| `cli` | Tool cài được, và một lần gọi thật trả output và exit code đúng |
| `library` | Public API import được, ví dụ dùng chạy được, đạt ngưỡng coverage |
| `skill` | Cài vào skill home, và một lần chạy thật đạt done-definition của chính nó |

Đặt loại bằng `/flow project-type <type>`; mặc định là `web`. Seam của contract và phần còn lại của matrix nằm ở [Loại dự án](/vi/docs/explanation/stage-pipeline/#project-types).

### Cái gì không được tính

Artifact quy trình, dù ấn tượng:

- pull request đã duyệt
- badge CI xanh hoặc workflow run
- release notes mô tả cái đã ship
- code review không tìm thấy gì
- tóm tắt của chính agent nói work đã xong

Lớp cơ học ép một sàn ở đây: card có section evidence chỉ chứa prose quy trình bị từ chối, nên kỷ luật không tranh cãi được ngay lúc đó. Ngoài sàn đó, cổng ngữ nghĩa hỏi câu khó hơn: đây là bằng chứng *thế giới*, hay mô tả thế giới?

Tự đánh giá của agent bị loại tường minh. Tín hiệu ground-truth cho mọi cổng là thứ agent không tự đẻ: exit code của script, output lệnh verify thật, check live.

### Vì sao cổng từ chối evidence rỗng mạnh đến vậy

```
  [x] status is 'done' but ## Evidence is empty (paste world-state proof: URL/curl/DB row)
FAIL: C-001 has gate violations (above).
```

Cái này bắn dù code đã xong và đúng. Lý do: lúc rẻ nhất để bắt bằng chứng là lúc bạn đang nhìn thứ đang chạy anyway. Hoãn lại thì tái dựng từ trí nhớ, và bằng chứng tái dựng không phân biệt được với bằng chứng bịa.

Cùng lý do dẫn lần flip do CLI sở hữu, `/flow card done C-NNN`: áp cùng luật với `check` và revert nếu cổng fail, nên không có path code nào đẻ ra done rỗng.

### Lối ra trung thực

Nếu card thật sự chưa chứng minh được ngay (chưa có đích deploy, dịch vụ ngoài không sẵn) đừng nới bằng chứng. Ghi phơi nhiễm thành debt, bằng văn bản, với điều kiện đóng. Debt nhìn thấy được và hiện trong `recall`; done rỗng vô hình và hiện trong production.

Cách mở dòng đó, và khi nào skip bị từ chối, nằm ở [Skip a gate with debt](/vi/docs/explanation/auto-tiers-and-security-halts/#skip-a-gate-with-debt). Cách dán bằng chứng lên card nằm ở [Tạo và kiểm card](/vi/docs/how-to/create-and-check-cards).

## Thử thách ngữ nghĩa {#semantic-challenges}

Pass cơ học nghĩa là file đầy đủ về cấu trúc. Nó không nói nội dung có đúng không. Thử thách ngữ nghĩa là bộ câu hỏi theo từng stage mà model áp sau khi script pass. Cố ý cụ thể theo từng stage vì mỗi stage mời một lời nói dối khác.

Research mời đối thủ bịa và số không nguồn. Scope mời dìm hạng: feature bạn muốn build được viết cao hơn hạng nó đáng. PRD mời requirement không chủ và nỗi đau không feature. Contract mời endpoint không cột auth. Card mời bằng chứng mô tả quy trình chứ không phải thế giới. Prompt generic “cái này có tốt không?” không bắt được những thứ này đáng tin. Thử thách có tên theo từng stage thì có.

Chỉ dẫn chạy cả hai chiều: đừng lặng lẽ tiến qua artifact rỗng, và đừng lặng lẽ chặn artifact vững. Khi thứ gì pass cơ học nhưng đọc yếu, operator được nói đúng vậy rồi quyết. Cũng có bằng chứng hành vi rằng lớp này hoạt động: `/flow eval` đưa fixture rỗng-nhưng-sạch-cơ-học cho judge mới và chấm chúng có bị gắn cờ không. Đó là ngưỡng dưới, không phải bảo đảm.

### Theo từng stage, không generic

**Idea (00).** Pitch có thật ba câu (ai / nỗi đau / cái gì) không? Người được nêu có phải người hoặc nhóm cụ thể, không phải “users”? Nỗi đau có cụ thể, không phải một category? Ritual forge-idea là opt-in; không bao giờ thành điều kiện cổng này kiểm.

**Research (01).** Rủi ro bịa cao nhất. Ba đối thủ có *thật sự được mở* không? Với sản phẩm web / market: complaint có phải quote thật kèm link nguồn chạy được, và kênh mười user đầu có phải một chỗ cụ thể? Với cli / library / skill / tool nội bộ: ma sát first-party có cụ thể và quan sát được, kèm người hưởng lợi có tên; “không kênh thị trường” ở đây là bình thường, không phải tín hiệu kill. Chi phí phải thật, không đoán.

**Scope (02).** Canh dìm hạng. Gọi C là C (realtime, payments viết từ đầu, auth tự làm, pipeline agent tự trị, concurrency nặng). Nếu lựa chọn sản phẩm vật chất còn mở (quota, identity key, tenancy, response contract, chủ enforcement) thì dừng và liệt kê; default cấu hình được không phải thẩm quyền. Bullet dưới `## Assumptions` mã hóa luật sản phẩm mà không có thẩm quyền operator hoặc ADR là open decision hoặc dừng, không phải default thầm.

**PRD (03).** Metric thành công có phải một con số thật, không phải “UX tốt hơn”? Mỗi nỗi đau có dẫn evidence và nêu feature v1 giết nó, và mỗi feature v1 có giết ít nhất một nỗi đau? Mồ côi một bên là scope drift. Người lạ có build được v1 từ file này mà không hỏi operator không?

**ADR (04).** Mỗi quyết định có nêu phương án bị từ chối thật, không phải bù nhìn? Storage, auth, deploy đã quyết thật, không phải “TBD”? List NOT-doing có trung thực về thứ bị hoãn?

**Contract (05).** Interface là seam theo loại dự án: web = endpoint, cli = command + flags + output/exit, library = hàm public + args + return, skill = command/file. Mỗi feature PRD map ít nhất một interface và ngược lại. Mỗi interface có cả hình input lẫn output, tên field/flag không trôi. Cột access/effects là thật với mọi interface; đừng để sản phẩm web để trống. Đọc contract đối chiếu mọi doc nó tự gọi là nguồn sự thật trước khi pass: mâu thuẫn ở đây ship như “đã pass” và mọi card thừa kế.

**Card (`/flow check C-NNN`).** Phạm vi có đúng một việc? `## Independent test` có phải bằng chứng user nhìn thấy, không phải “unit tests pass”? Diff có nằm trong `## Allowed files`? Shape có khớp `flow/05-contract.md` đúng từng tên? `## Evidence` có phải thế giới thật (URL bấm được, curl thật, hàng DB) và mỗi mục có nêu artifact hoặc lệnh đã sinh ra nó?

**Consistency (`/flow consistency`).** Advisory; không chặn đường build. Sau các pass theo ID của runner, model vẫn phải bắt coverage rỗng (`FRn` dán lên card không giao feature đó), requirement mâu thuẫn giữa các artifact, feature trong cut list xuất hiện lại như v1, và thuật ngữ trôi (`ticket` / `issue` / `request`).

Toàn bộ chữ thử thách cho model nằm ở file maintainer trong chân trang. Skip security-class và HALT của auto không thuộc trang này; chúng nằm ở [Khi việc phải dừng](/vi/docs/explanation/auto-tiers-and-security-halts).

## Kiến trúc hệ thống {#system-architecture}

`flow` là ba lớp cùng làm việc cộng artifact trên đĩa: engine xác định nhanh cho phần cơ học gian được, skill cho phán đoán, store bền vững để bản ghi sống sót qua session. Hình operator công khai gồm bốn mảnh: skill, runner, artifact, và hai kênh phiên bản.

### Skill

Lớp ngữ nghĩa là `SKILL.md` cộng playbook dưới `skills/flow/references/`. Đó là thứ hosting agent đọc: dispatch, gác cổng, orchestration. Sau khi `runner/flow.sh` trả 0, lớp này chạy thử thách theo từng stage ở trên. Nó không được thay exit code của script bằng một lần pass theo vibe.

### Runner

Lớp cơ học là `runner/flow.sh`. Bash, xác định, exit 0 hoặc 1. Nó sở hữu vòng đời stage và card, kiểm cổng (`[FILL]`, ô, evidence rỗng), sổ cái debt, kiểm design, và passthrough harness. Exit code là ground truth. Luôn chạy trước; luôn relay trung thực.

Bên dưới, CLI Python và SQLite do flow sở hữu giữ intake và risk lane, story và proof, trace và tier, decision, backlog. Thiếu `python3` thì cổng vẫn chạy; chỉ lớp bền vững này tắt.

### Artifact

Artifact sống trong dự án đang được build, không nằm trong skill home:

```
flow/00-idea.md .. 05-contract.md   planning, gated
cards/C-NNN.md                      shipping units
MODE, RETRO.md, DEBT.md, AUTO-LOG.md, DESIGN.md
.flow/harness.db                    durable records
```

File planning dưới `flow/` là các stage có cổng. Mỗi card dưới `cards/` là một phiên build có phạm vi, bám contract stage 05. File sổ cái và `.flow/harness.db` là cách debt, retro, trace sống sót cửa sổ ngữ cảnh kế.

### Hai kênh phiên bản

Phân phối là hai kênh song song nuôi cùng một cây chuẩn. Installer npm (`npx @manhquy/flow-skill@latest`) là đường chính: thuần Node, không đòi shell. Script cài trong kho là implementation tham chiếu dùng lúc phát triển và CI. Cả hai ghi cùng skill home, nên dự án đổi kênh mà không phải phát hành lại cổng.

```
  monorepo skills/flow/  --npm run sync-->  npm-wrapper/skills/flow  --npm pack-->  registry
         |                                         |
         | install.sh / agent skill homes          | npx @manhquy/flow-skill@latest
         v                                         v
  ~/.claude/skills/flow                     same tree via installer CLI
```

Hai kênh đánh số artifact khác nhau. **Skill product** đánh số cổng, `SKILL.md`, runner, references, template: thứ phán build của bạn. **Gói npm** chỉ đánh số installer CLI: phát hiện agent, đường copy, flag. Chúng không cần trùng. `--help` in cả hai số. Kiểm trên máy bạn, đừng lấy từ tài liệu. Câu chuyện cặp số, kể cả số nào nên pin, nằm ở [Hai số phiên bản](/vi/docs/how-to/troubleshoot-install/#two-version-numbers).

## Đi tiếp

- [Pipeline các stage](/vi/docs/explanation/stage-pipeline): mỗi cổng đang chống tự lừa gì.
- [Cài đặt và lần chạy đầu](/vi/docs/tutorials/install-and-first-run): xem cổng từ chối.
- [Tạo và kiểm card](/vi/docs/how-to/create-and-check-cards): dán bằng chứng done, đánh dấu done.

---

Nhà maintainer (không phải trang công khai): [`docs/adr/0001-discipline-layer-identity.md`](https://github.com/manhquydev/flow-skill/blob/master/docs/adr/0001-discipline-layer-identity.md), [`skills/flow/references/gate-rules.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/gate-rules.md), [`docs/system-architecture.md`](https://github.com/manhquydev/flow-skill/blob/master/docs/system-architecture.md).

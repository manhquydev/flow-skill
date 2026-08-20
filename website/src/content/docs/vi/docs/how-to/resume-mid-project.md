---
title: "Tiếp tục giữa dự án"
description: "Nhặt lại dự án flow lúc lạnh mà không đoán lại state: chạy resume trước, đọc dòng NEXT, xử lý lock cũ, hoặc đánh giá brownfield."
lang: vi
---

Bạn bỏ dự án hai tuần, hoặc là session agent mới không nhớ gì. **Đừng** bắt đầu bằng đọc file rồi đoán đang ở đâu.

## Chạy resume trước {#resume}

```
/flow resume
```

Đây là verb đầu tiên khi vào một dự án giữa chừng. Chỉ đọc, không lấy lock, và ghép bản tóm tắt câu chuyện phiên từ state đã có trên đĩa:

- phiên trước, chỉ tên lệnh, không bao giờ raw args
- card in flight và dwell (ngồi đó bao lâu)
- trạng thái cổng hiện tại
- đúng một dòng `NEXT ->`

Đọc dòng `NEXT ->` rồi làm đúng cái đó. Cùng helper quyết định với `/flow status`, nên hai lệnh không bao giờ bất đồng.

## Khi nào bỏ qua

Bỏ `resume` khi bạn đã có ngữ cảnh sống trong conversation này. Nếu chính bạn vừa chạy `next` hoặc `card` một phút trước thì chạy lại chẳng thêm gì. Dành cho lần vào lạnh, không phải mọi lệnh.

## Rồi lấy view đang làm việc

```
/flow
```

`/flow` trần là `status`: đang ở đâu, cái gì chặn, dwell của stage hiện tại, danh sách card (tóm gọn khi quá mười card), và một dòng tóm tắt bộ nhớ. Dùng `resume` để vào lại, `status` để tiếp tục làm.

## Recall và promote {#recall-and-promote}

```
/flow recall
```

Chạy `recall` lúc bắt đầu stage hoặc card, trước khi soạn gì. Nó đọc lại lớp bền vững: debt mở, retro gần nhất, scope card trước, friction và backlog của harness, sức khỏe audit, playbook đã promote. Coi output là ngữ cảnh để áp dụng, không phải nhiễu, để work bắt đầu với nỗi đau cũ trong tầm mắt thay vì phát hiện lại.

Capture do engine bắn chứ không tự nguyện: tiến qua stage 01 seed một intake, lần check card pass ghi trace được chấm tier, skip có chủ đích ghi debt. `status` hiện một dòng tóm tắt bộ nhớ; `card` tự nhét scope card trước. Improve cũng cơ học: `harness audit` chấm entropy và drift, `harness propose` đào friction lặp thành backlog cải tiến khi pattern bắn ít nhất hai lần, `harness decision outcome` đóng vòng dự-đoán so với thực tế.

Cửa sổ conversation quên. Bản ghi bền vững thì không.

### Promote một playbook

Khi bài học lớn hơn một dự án, nâng nó:

```
/flow promote <playbook.md>
```

Lệnh copy playbook vào KB liên-dự-án tại `~/.claude/flow/playbooks`. Từ đó `recall` hiện nó mọi nơi, không chỉ nơi nó được học.

Vòng là capture, reuse, improve: `next` và `check` ghi bản ghi tự động, `recall` đọc lại, `promote` chia sẻ những bài đã trả giá.

Engine thêm (Codex và Antigravity) và phần còn lại của vòng bền vững nằm ở
[Điều phối agent](/vi/docs/explanation/agent-orchestration/#second-engine).

## Mở khóa phiên cũ {#unlock-stale-session}

`flow` cho một session mỗi dự án. Hai session chia một plan sẽ ghi đè state của nhau. Runner giữ `flow/.lock`: lệnh mutate như `next`, `card`, `skip`, và `auto` từ chối lock ngoại lai mới, `status` cảnh báo, và lock tự reclaim sau TTL `FLOW_LOCK_TTL`, mặc định 900 giây.

```
/flow unlock
```

Chỉ dùng khi session kia thật sự chết: terminal crash, cửa sổ bỏ dở. Nếu session kia còn sống, dừng và phối hợp với người đang chạy. Đừng force qua lock sống; chạy song song làm hỏng plan.

`FLOW_FORCE=1` chiếm lock bạn chắc đã chết. `/flow unlock` xóa nó. Nếu runner báo **BLOCKED by another session's lock**, dừng và phối hợp. Đừng `FLOW_FORCE` qua session đang chạy.

Để bảo vệ cứng thay vì cảnh báo, export một `FLOW_SESSION_ID` ổn định một lần mỗi session và truyền vào mọi lời gọi:

```bash
export FLOW_SESSION_ID=$(uuidgen)
FLOW_SESSION_ID=$FLOW_SESSION_ID bash ~/.claude/skills/flow/runner/flow.sh next
```

Không có nó thì runner chỉ cảnh báo. Không chứng minh được session khác, nên không bao giờ tự chặn.

## Đánh giá brownfield {#assess-a-brownfield}

Dự án có code nhưng không có thư mục `flow/` là brownfield. Chưa có câu chuyện phiên để khôi phục, nên đừng bắt đầu bằng `resume`. Codebase có sẵn không bắt đầu ở stage Idea. `/flow assess` scaffold và gác cổng `flow/00-inspect.md` (bản đồ hiện trạng) trước khi stage planning nào mở. Planning cho hệ thống có sẵn phải bám vào cái đang có, không phải cái README kho tuyên bố đang có.

Dự án greenfield bỏ bước này và bắt đầu bằng `/flow next` (Idea).

### Bước operator

1. Từ root dự án, chạy:

   ```
   /flow assess
   ```

   Lần đầu copy template inspect sang `flow/00-inspect.md`, seed auto-scan (stack, CI, file ngữ cảnh, ranked surfaces), và seed file law. Cổng chưa pass.

2. Điền mọi section từ **bằng chứng** (đọc code):
   - lệnh stack / build / test / run từ file thật
   - component, module, entry point chính
   - chức năng hiện tại (works / partial / stub / missing) kèm bằng chứng file
   - trạng thái UI/UX so với mục tiêu sản phẩm, hoặc ghi "no UI"
   - rủi ro, tech-debt, issue đã biết
   - baseline test và chất lượng (cái gì được cover, cách chạy suite)
   - **Verdict**: codebase có đủ khỏe để build tiếp không, và cái gì phải sửa trước?

3. Bắt đầu lượt chức năng và rủi ro từ auto-scan **Ranked surfaces**. Đó là code leverage cao nhất, bề mặt mà phần lớn codebase phụ thuộc, nơi rủi ro xuyên cắt dễ ẩn nhất.

4. Gắn tag mọi claim trọng yếu từ Functionality / Risks / Verdict trong **Evidence ledger**. Đừng viết policy sản phẩm như sự thật trừ khi tag là **Authoritative**.

   | Tag | Nghĩa |
   |-----|---------|
   | **Authoritative** | Instruction, quyết định đã chấp nhận, contract sản phẩm, thủ tục đã ghi |
   | **Observed** | Code/config/test cho thấy hành vi hiện tại |
   | **Derived** | Hệ quả vận hành trực tiếp của implementation đã quan sát |
   | **Decision required** | Lựa chọn chuẩn/sản phẩm chưa có authority |
   | **Unknown** | Repo không xác lập câu trả lời |

5. Một người duyệt bản đánh giá. Brownfield do operator gác cổng. Ở `teach` mode agent chỉ báo; không tick box hay soạn artifact hộ.

6. Chạy lại `/flow assess`. PASS cơ học nghĩa là không còn `[FILL]` và mọi box cổng đã check. FAIL liệt kê lỗ còn lại; điền từ bằng chứng rồi chạy lại.

7. Sau PASS cơ học, áp semantic challenge trước khi planning:
   - Claim trọng yếu đã gắn Authoritative / Observed / Derived / Decision required / Unknown chưa?
   - Có claim **Observed** hoặc **Derived** nào bị nâng thầm thành luật sản phẩm must-build mà không có authority của operator không?
   - Mục **Decision required** / **Unknown** đã liệt kê cho operator, không bị bịa vào Scope/PRD?
   - Ledger trống, hoặc chỉ còn hàng `[FILL]` trong khi box đã check, là rỗng: báo mechanically-passed-but-qualitatively-weak.

8. Khi cả hai lớp đồng ý, sang planning bằng `/flow next`.

Có thể tái dùng `scout` / `researcher` (hoặc `bmad-document-project`) để gom bằng chứng. Cổng vẫn phán. Operator vẫn duyệt.

## Chạy từ thư mục con

Nếu chạy `flow` từ thư mục con như `frontend/` không có `flow/` riêng, nó nhận dự án flow tổ tiên gần nhất và in một dòng ghi chú ra stderr, thay vì đẻ root thứ hai bị mảnh. Thư mục con có `flow/` hoặc `cards/` riêng luôn được tôn trọng, cũng như `FLOW_PROJECT_ROOT` tường minh.

## Xem thêm

- [Tạo và kiểm card](/vi/docs/how-to/create-and-check-cards)
- [Điều phối agent](/vi/docs/explanation/agent-orchestration)
- [Tham chiếu lệnh](/vi/docs/reference/commands)

---

Nhà maintainer (không phải trang công khai): [`skills/flow/SKILL.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/SKILL.md), [`skills/flow/references/command-dispatch.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/command-dispatch.md), [`skills/flow/_templates/00-inspect.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/_templates/00-inspect.md), [`skills/flow/references/gate-rules.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/gate-rules.md).

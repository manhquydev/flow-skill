---
title: "Tạo và kiểm card"
description: "Cắt một build card, chỉ build những gì nó cho phép, và pass cổng check bằng bằng chứng thế giới thật."
lang: vi
---

Một card là một phiên build có phạm vi. Đây là vòng bạn sẽ sống phần lớn thời gian sau khi planning xong.

## Điều kiện trước

`/flow card` từ chối cho đến khi cả sáu cổng planning đã pass hoặc mang dòng debt mở khớp. Nếu từ chối, chạy `/flow` rồi sửa stage nó nêu.

## Cắt card

```
/flow card
```

Lệnh này tạo `cards/C-NNN.md` kế tiếp. Trước khi viết một dòng code, đọc và điền những gì template hỏi:

| Section | Để làm gì |
|---|---|
| `## Allowed files` | Path duy nhất phiên này được đụng. Đây là bán kính nổ. |
| `implements:` | Id requirement PRD (`FRn`) card này claim. |
| `## Verify` | Lệnh bạn sẽ thật sự chạy, không phải nguyện vọng. |
| `## Independent test` | Bằng chứng lát cắt người dùng thấy — hoặc `infra` / `none` nếu thật sự không phải. |
| `## Evidence` | Để trống đến khi done. Bằng chứng thế giới thật dán vào đây. |
| `risk` / `risk-reason` | Hạng rủi ro, cần trước mọi lần chạy auto. |

`[FILL]` còn sót trong `## Independent test` làm `check` fail, đừng bỏ qua.

## Nạp tri thức cũ trước

```
/flow recall
```

Debt mở, retro gần nhất, scope card trước, friction harness, playbook đã promote. Coi output là ngữ cảnh để áp dụng, không phải nhiễu.

## Tùy chọn: đánh dấu in flight

```
/flow card start C-001
```

Ghi card đang làm vào registry portable `cards/.inflight` để hiện trên `/flow status`. Không bao giờ đụng trường `status:` có cổng, và hoàn toàn tùy chọn — sửa tay vẫn được.

## Build trong vạch

Ba luật ràng mọi phiên build:

1. **Một card mỗi session.** Không hai, và không hai song song cho đến khi `/flow ready` nói chúng an toàn.
2. **Chỉ đụng `## Allowed files`.** Drift ngoài list đúng là thứ reviewer tìm.
3. **Contract là seam.** Build theo shape stage 05 đã khai. Shape sai thì sửa contract trước, rồi mới sửa code.

Với card UI, mock card phải được duyệt trước mọi frontend code, và `/flow design <file>` chạy kiểm `DESIGN.md` cơ học trên file đó.

## Kiểm card nào chạy song song được

```
/flow ready
```

Liệt kê card todo build được kèm gợi ý an-toàn-song-song dựa trên overlap allowed files.

## Kiểm card

```
/flow check C-001
```

Lớp cơ học validate card trước: status hợp lệ, `[FILL]` còn sót, section bắt buộc, và `## Evidence` có thật sự được điền. Chỉ sau khi pass mới tới review ngữ nghĩa — diff so với scope, drift allowed-files, khớp shape contract, `DESIGN.md` cho UI, và bằng chứng có đúng là thế giới thật.

Fail bạn sẽ gặp nhiều nhất:

```
  [x] status is 'done' but ## Evidence is empty (paste world-state proof: URL/curl/DB row)
FAIL: C-001 has gate violations (above).
```

Cái này bắn dù build xong và mọi test xanh. “Tests pass” và “merged” là trạng thái giữa pipeline.

## Dán bằng chứng được tính

Cái gì được tính phụ thuộc loại dự án:

| Loại dự án | Bằng chứng pass |
|---|---|
| `web` | URL đã deploy live cộng output `curl` thật |
| `cli` | Một lần gọi thật với output và exit code thật |
| `library` | Public API import được, ví dụ dùng chạy được, đạt ngưỡng coverage |
| `skill` | Cài vào skill home, cộng một lần chạy thật đạt done-definition |

Artifact quy trình — PR đã duyệt, badge CI xanh, release notes — không phải bằng chứng. Sàn cơ học từ chối prose chỉ-quy-trình, nên card không thể done bằng giấy tờ.

Luật đầy đủ nằm ở [Done nghĩa là bằng chứng thế giới thật](/vi/docs/explanation/what-is-flow/#done-means-world-state).

## Flip sang done

```
/flow check C-001
PASS: C-001 is valid (status: done).
```

Hoặc để CLI sở hữu lần flip:

```
/flow card done C-001
```

`card done` áp cùng luật done với `check` và **revert** nếu cổng fail, nên không bao giờ đẻ ra done rỗng. Sửa tay `status: done` rồi chạy `check` vẫn hợp lệ như nhau.

## Converge kế hoạch với code {#converge}

Build thật lệch: code được viết mà plan không hỏi, và work đã plan không hạ cánh. `/flow converge` đóng gap đó. Verb này opt-in, nằm ngoài chuỗi cổng `next`.

Đánh giá code đang có đối với plan (PRD `FRn`, interface trong contract, `INV-n` constitution). Viết payload `flow-converge/v1` mô tả gap, rồi chạy:

```
/flow converge
```

Hoặc `flow.sh converge --file <path>`.

Ba luật ràng verb:

1. **Chỉ append.** Không sửa, không đánh số lại, không xóa `cards/C-*.md` đã có. Không đụng application code. Remainder card được emit; session sau mới build.
2. **Tất cả hoặc không.** Runner transactional: mọi remainder card được viết, hoặc không cái nào. Không append dở.
3. **`CONVERGED` nghĩa là không ghi gì.** Zero findings (hoặc không payload) thì in `CONVERGED` và để `cards/` nguyên.

Work tồn tại trong code nhưng chưa từng được yêu cầu thành **card review** (`implements: none`), không thành lệnh xóa. Quyết định gỡ cái gì thuộc operator.

Gap type payload nhận: `missing`, `partial`, `contradicts`, `unrequested`. Cái khác thì bị từ chối và không ghi gì.

Viết findings vào `.flow/converge-pending.md` trước (run-state, gitignored, nên lần `CONVERGED` không làm bẩn `cards/`). Đưa bảng findings ra trước khi ghi card. Format:

```
schema: flow-converge/v1
findings: 2

---
gap-type: missing
severity: HIGH
implements: FR2
source-ref: 03-prd.md:FR2
title: implement the mark-task-done endpoint
deps: C-002
allowed: src/app.py
---
gap-type: unrequested
severity: LOW
implements: none
source-ref: src/app.py:debug_dump
title: the debug_dump surface no feature asked for
deps:
allowed: src/app.py
```

Card được append mang `[FILL]` Verify và Evidence vì chưa build. Cắt, điền, rồi `check` như card khác.

Phân loại gap và schema payload đầy đủ nằm ở [`skills/flow/references/converge.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/converge.md).

## Xem thêm

- [Done nghĩa là bằng chứng thế giới thật](/vi/docs/explanation/what-is-flow/#done-means-world-state)
- [Bỏ cổng bằng nợ](/vi/docs/explanation/auto-tiers-and-security-halts/#skip-a-gate-with-debt)
- [Chạy auto-build](/vi/docs/explanation/auto-tiers-and-security-halts/#run-an-auto-build)

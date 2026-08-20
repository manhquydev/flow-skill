---
title: "Khi việc phải dừng"
description: "Skip là khoản vay. Việc security-class không bao giờ skip thầm. Auto chia tầng, và Tier-C thì HALT. Trang này là nhà công khai của các luật đó."
lang: vi
---

Skip là khoản vay, và vay thì phải ghi sổ. Lý do security-class không bao giờ skip thầm, và không bao giờ do planner quyết. `/flow auto` chia tầng: việc xanh có thể merge không hỏi, việc security-class thì **HALT**.

Trang này là nhà operator cho các luật đó. File maintainer vẫn canonical trong repo; chỉ link ở chân trang.

## Security-class halt rules {#security-class-halts}

Các lớp này không được viết kiểu “ví dụ …” rồi im phần còn lại. Mỗi lớp dưới đây đều **dừng**.

- authentication / auth
- authorization
- admin-surface exposure
- tenancy
- payments
- data loss / data migration
- removing or weakening validation

Với bất kỳ lớp nào:

- **Operator** chấp nhận phơi bày **bằng chữ** trong `DEBT.md`. Bạn không quyết hộ.
- Trong `/flow auto` đây là **Tier-C HALT**. Dừng và hỏi. Không đi tiếp.
- Đóng một run khi còn **security debt đang mở** cần operator xác nhận tường minh. “Temporary” không phải xác nhận.

## Skip a gate with debt {#skip-a-gate-with-debt}

Skip là hợp lệ. Skip thầm thì không.

Ghi phơi bày trước, rồi mới skip:

```
/flow debt add "skip 01-research" "<the exposure, concretely>" "<close before: named condition>"
/flow skip 01-research --reason "…"
```

Các chốt, theo đúng thứ tự này (chúng trỏ list lớp ở trên; không viết lại bản ngắn hơn):

1. Stage **05 (contract) không bao giờ được skip**. Hãy adapt contract theo loại project. Xem [Vì sao contract không bao giờ được skip](/vi/docs/explanation/stage-pipeline/#contract-never-skipped).
2. Lý do security-class thì **dừng**. Operator chấp nhận phơi bày **bằng chữ** trong `DEBT.md`. **Không bao giờ do planner quyết**.
3. Một dòng debt **không liên quan** sẽ không mở stage.
4. `/flow skip` chỉ tiến khi có dòng debt **đang mở** **ghi đúng stage đó** **và** lý do **không** phải security-class.
5. Sau skip hợp lệ, `planning_complete` có thể chịu stage đó để card không bị kẹt mãi. Dòng debt vẫn mở.

### DEBT.md

- Lần skip đầu tạo `DEBT.md`.
- Hình dòng: thứ bị skip, phơi bày cụ thể, điều kiện đóng có tên, ngày, card.

```
- [ ] DEBT: <what was skipped> -- <exposure> -- close before: <named condition> -- opened <date> (cards: C-NNN...)
```

- Đóng run khi còn **security debt đang mở** cần operator xác nhận tường minh. “Temporary” không phải xác nhận.
- Card bị debt chặn ở `todo` với evidence PARTIAL ghi tên debt. Không làm dở, không làm tròn thành done.

## Run an auto build {#run-an-auto-build}

`/flow auto` preflight; đạt thì ghi auto state dùng chung. `/flow auto stop` trở về tay. Không có đường tắt ẩn.

Preflight **fail-closed**:

- mọi card có risk đã phân loại (**không `unknown`**)
- card security-class cần **xác nhận của author khác** trong `DEBT.md`
- stage 05 mang receipt `semantic_gate` **còn hiện hành**

Rồi, từng card, vòng theo ngôn ngữ operator: phân tầng, build trong worktree riêng với subagent scoped, review, biên nhận, `check`, merge, deploy, verify live, dán bằng chứng done, rồi done. Dùng verb `/flow workspace` để journal không thủng. `git worktree add` trần không ghi gì.

### Tầng

| Tầng | Việc | Hành động |
|---|---|---|
| **Tier-A** | Xanh, không security-class | Auto-merge không hỏi. |
| **Tier-B** | Sửa được | **Một** lần sửa bởi subagent **mới** (two-strikes). Lần đỏ đầu của card thường không gọi engine cross-vendor tính tiền. |
| **Tier-C** | Chạm security-class **hoặc** skip kèm debt | **HALT**. Operator chấp nhận bằng chữ trong `DEBT.md`. Không bao giờ do planner quyết. |

Trần cứng (số vòng / token / wall-clock) là bắt buộc. Vượt cái nào → HALT + báo cáo. Vòng không trần là anti-pattern.

Mọi cổng quyết trên tín hiệu **cơ học** (exit code thật, `## Verify` chạy thật, check live). Không bao giờ tự đánh giá của agent.

Merge song song bị conflict → dừng và lập plan lại. Check overlap đã bị lách.

## When the run stops itself {#halts-when-the-run-stops}

Run thì HALT và báo. Không bao giờ đi tiếp thầm. Dừng khi bất kỳ cái nào:

- Trần cứng bị vượt (số vòng / token / wall-clock).
- Tín hiệu ground-truth đỏ không sửa được trong two-strikes.
- Chạm security-class Tier-C.
- Conflict lúc merge song song (check overlap bị lách: dừng và lập plan lại).
- `BLOCKED` / `NEEDS_CONTEXT` từ subagent mà thêm context cũng không gỡ.

Khi dừng: nói cái gì chặn, cái gì đã xong, debt/blocker đang mở, và **2–4 lựa chọn cụ thể**. Đừng vá quanh regression. Để operator quyết.

---

Nhà maintainer (không phải trang công khai): [`skills/flow/references/debt-and-halts.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/debt-and-halts.md), [`skills/flow/references/auto-run.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/auto-run.md), [`skills/flow/references/attestations.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/attestations.md).

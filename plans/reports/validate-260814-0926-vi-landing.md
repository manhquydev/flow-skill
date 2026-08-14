---
type: validate
date: 2026-08-14
topic: vi-landing
conducted: 2026-08-14 09:26 +07
scope: website/src/pages/vi/index.astro
operator: substituted (thay tôi)
---

# Validation log — `/vi/` landing

Agent substituted for the operator (native VI, cannot read EN). He said "thay tôi". No interview. Decisions below treated as locked. Two prior rewrites (calque, then telegram) were rejected. This pass writes from claims, not from `website/src/pages/index.astro` sentence slots.

## 14 decisions — confirmed

| # | Decision | Status |
|---|----------|--------|
| 1 | Improve landing NOW (operator overrode wait-for-gold) | Confirmed. Applied. |
| 2 | Scope: first viewport + below-fold bands on `/vi/` only. Not 15 docs. Not 31 stubs. | Confirmed. Only `website/src/pages/vi/index.astro` edited. |
| 3 | Write from claims, not from English sentence templates | Confirmed. EN landing not used as slot map. |
| 4 | Keep H1 "Cổng chỉ mở khi cả hai cùng đồng ý." unless a single-sợi rewrite cannot keep it | Confirmed. Kept. |
| 5 | Locked: cổng, card, bằng chứng done. Commands / paths / stage names stay English | Confirmed. |
| 6 | Drop invented label "Máy chạy". Column title = `flow.sh` (`translate="no"`) | Confirmed. No replacement calque. |
| 7 | One mouth for stop-at-gate: dừng / chặn / bỏ. No gạch, kill, Kill, "kết quả đúng" | Confirmed. Mouth used: **chặn** (bị chặn) + **dừng** (dừng luôn / dừng ngay / phải dừng). **bỏ** not needed. |
| 8 | Pro-drop OK. No "Vui lòng". No "Quý khách". "Bạn" only if spoken | Confirmed. Dropped "hộ bạn". No Bạn / Vui lòng / Quý khách. |
| 9 | Ban EN devices: em-dash punch, semicolon-as-glue, "Không phải X. Là Y.", telegram fragments | Confirmed. See self-check. |
| 10 | Require topic-comment glue: thì / mà / chứ / mới / rồi / cả…lẫn… and phép lặp of cổng | Confirmed. See glue map. |
| 11 | Diacritics required. No em-dash (—) in visible copy | Confirmed. Title and selectLabel had —. Replaced. |
| 12 | Do not change class names, structure, InstallLockup props except stiff VI labels | Confirmed. Labels: Sao chép / Đã sao chép / Cách cài kept. selectLabel only lost the —. |
| 13 | Keep install command `npx @manhquy/flow-skill@latest` | Confirmed. Unchanged. |
| 14 | Claims stay true (intent, not wording): agent still writes; both sides open the cổng; stop-at-gate is first-class, not a bad fail; install via npx @latest | Confirmed. See claim check. |

## Visible strings — old → new

Unchanged strings omitted.

| Slot | Old | New |
|------|-----|-----|
| `<title>` | `flow — cổng chỉ mở khi cả hai cùng đồng ý` | `flow: cổng chỉ mở khi cả hai cùng đồng ý` |
| meta description | `Agent vẫn viết code; flow quyết đi tiếp hay phải dừng. Máy chạy và skill phải cùng đồng ý. Dừng ở cổng là kết quả đúng.` | `Agent vẫn viết code, còn cổng mở hay đóng thì flow quyết. Phải cả flow.sh lẫn skill thì cổng mới mở. Bị chặn ở cổng thì dừng luôn, chứ không phải fail.` |
| section `aria-label` | `Máy chạy và skill` | `flow.sh và skill` |
| H1 | `Cổng chỉ mở khi cả hai cùng đồng ý.` | *(kept)* |
| lede | `Agent vẫn viết code; flow quyết đi tiếp hay phải dừng. Bị chặn ở cổng không sao — đó là kết quả đúng.` | `Agent vẫn viết code, còn cổng mở hay đóng thì flow quyết. Bị chặn ở cổng thì dừng luôn, chứ không phải fail.` |
| verdict | `Máy chạy và skill — phải cả hai.` | `Phải cả flow.sh lẫn skill thì cổng mới mở.` |
| col 1 H2 | `Máy chạy` | `flow.sh` (`translate="no"`) |
| col 1 body | `flow.sh thoát 0 hoặc 1. Không cảm tính. Không “chắc là được”.` | `flow.sh chỉ trả 0 hoặc 1. Cảm tính hay “chắc là được” thì cổng này không mở.` |
| proofs mechanical | *(kept)* | `Còn ô cổng chưa tick.` / `[FILL] còn trong file.` / `Khối evidence để trống.` |
| col 2 H2 | `Skill` | *(kept)* |
| col 2 body | `Skill soi việc vừa làm có rỗng không.` | `Skill bắt việc rỗng, cái flow.sh không bắt được.` |
| kill-line | `Ý tưởng yếu thì gạch ngay tại cổng.` | `Ý tưởng yếu thì dừng ngay tại cổng.` |
| proofs semantic | *(kept)* | `Research chưa làm thật.` / `Hạ scope để lọt cổng.` / `“tests pass” thế cho bằng chứng done.` |
| copyLabel | `Sao chép` | *(kept)* |
| copiedLabel | `Đã sao chép` | *(kept)* |
| selectLabel | `Đã chọn — nhấn Ctrl+C` | `Đã chọn, nhấn Ctrl+C` |
| secondaryLabel | `Cách cài` | *(kept)* |
| pipeline aria | `Sáu cổng trước khi build` | *(kept)* |
| band H2 | `Sáu cổng rồi mới tới card build đầu` | *(kept)* |
| band lede | `Mỗi cổng để lại một file thật trong repo. /flow next không mở cổng sau nếu file hiện tại chưa qua cả hai bên.` | `Mỗi cổng để lại một file thật trong repo. File hiện tại chưa qua cả hai bên thì /flow next không mở cổng sau.` |
| band foot | `Rồi tới /flow card. Done nghĩa là bằng chứng done: …` | `Rồi mới tới /flow card. Done thì phải có bằng chứng done: …` (list after colon kept) |
| stand H2 | `Không phải agent viết code. Là cổng đứng quanh agent.` | `flow gác cổng, chứ không viết code.` |
| stand body | `flow không viết code hộ bạn. Agent vẫn viết; flow quyết đoạn vừa viết được đi tiếp hay phải dừng.` | `Agent vẫn viết. Được đi tiếp hay phải dừng thì cổng quyết.` |
| CTA primary | `Cài và chạy lần đầu` | *(kept)* |
| CTA secondary | `Đọc tài liệu` | *(kept)* |

Class `kill-line` kept (structure / CSS). Not visible copy.

## Glue map (sợi = cổng chỉ mở khi đủ hai bên)

| Place | Glue | Cổng loop |
|-------|------|-----------|
| H1 | khi | cổng chỉ mở |
| lede | còn, thì, chứ | cổng mở hay đóng / bị chặn ở cổng |
| verdict | cả…lẫn…, thì, mới | cổng mới mở |
| flow.sh col | thì | cổng này không mở |
| skill col | cái … không, thì | dừng ngay tại cổng |
| band H2 | rồi mới | sáu cổng |
| band lede | thì | mỗi cổng / không mở cổng sau |
| band foot | rồi mới, thì | *(card / bằng chứng done — next beat)* |
| stand | chứ, thì | gác cổng / cổng quyết |

## Claim check

| Claim | Where it still holds |
|-------|----------------------|
| Agent vẫn viết code; flow quyết được đi tiếp hay phải dừng | lede + stand |
| Phải cả flow.sh (0/1) lẫn skill mới mở cổng | verdict + two columns |
| Bị chặn/dừng ở cổng là kết quả hạng một, không phải fail xấu | lede: "dừng luôn, chứ không phải fail" — miệng người, không "kết quả đúng" |
| Cài bằng `npx @manhquy/flow-skill@latest` | InstallLockup `command` unchanged |

## Self-check (đọc to trong đầu)

First viewport, one breath:

> Cổng chỉ mở khi cả hai cùng đồng ý. Agent vẫn viết code, còn cổng mở hay đóng thì flow quyết. Bị chặn ở cổng thì dừng luôn, chứ không phải fail. Phải cả flow.sh lẫn skill thì cổng mới mở.

Không vấp. Không sửa câu trong đầu khi gửi group. Tai agent không thay tai operator — ông đọc to trên điện thoại mới là pass thật.

### EN devices còn lại?

- Không em-dash trong copy hiện.
- Không chấm phẩy trong copy hiện (`;` chỉ còn trong frontmatter JS).
- Không khuôn "Không phải X. Là Y." Stand dùng một câu `A, chứ không B`.
- Không telegram "Không cảm tính. Không …".
- `fail` là loanword dân code nói, đối lập với "kết quả đúng" (biên bản). Giữ.
- `flow.sh`, `skill`, `card`, `agent`, `[FILL]`, `tests pass`, stage names, paths, `/flow next`, `/flow card` — DNT, đúng.
- Class `kill-line` còn tên EN. Không hiện. Không đụng CSS.

### Chỗ còn rủi ro (operator đọc to)

1. H1 "cùng đồng ý" hơi lễ. Khóa rồi. Không đổi.
2. "gác cổng" lấy từ miệng `README_VN.md` (teach mode). Không phải metaphor mới, nhưng operator chưa nói đúng hai chữ này trên landing. Nếu ông không nói vậy, đổi stand H2 theo lời ông.
3. "bắt việc rỗng" đặc hơn "xem có rỗng không". Gần miệng README ("bắt những thứ gian lận"). Nếu đọc vấp, nới: "Skill xem việc vừa làm có rỗng không."
4. "trả 0 hoặc 1" = miệng coder VN cho exit code. Không viết "thoát" (calque exits).
5. Proofs giữ nguyên: vẫn là mảnh liệt kê. Chấp nhận vì là ví dụ, không phải lede.
6. CTA "Cài và chạy lần đầu" hơi nút-docs. Giữ vì không cứng kiểu "Vui lòng".
7. Pass thật = operator đọc to, không sửa câu trong đầu. Agent không tự chấm pass.

## Files

- Edited: `website/src/pages/vi/index.astro`
- Report: `plans/reports/validate-260814-0926-vi-landing.md`
- Not touched: CSS, EN landing, docs, `Landing.astro`, 31 stubs

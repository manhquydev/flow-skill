# Concierge — conversational entry to /flow

Routing / offer-run pattern adapted from BMAD-METHOD's `bmad-help` skill
(MIT License, Copyright (c) 2025 BMad Code, LLC — see `BMAD-METHOD/LICENSE`), reworked
here on flow's own mechanical state machine (`flow.sh status`/`resume`) instead of
fuzzy artifact detection. This is the **default** entry contract: any natural-language
ask routes through this loop before you consider typing a verb for the operator.

## Entry loop

1. On any natural-language ask, run `flow.sh status` first (or `resume` when entering a
   project cold mid-cycle — see SKILL.md dispatch rule 1). **Never guess state.**
   Default `status`/`resume` is human-readable prose. Optional `--json` is **display-only**:
   `next_verb` is not executable. Hosts MUST NOT dispatch `next`, `card`, `card-start`,
   `check`, `fix-gate`, `auto`, or `skip` from it. Concierge stays on prose (May-run);
   do not switch the chat entry to `status --json`. Reliable on Claude; treat routing on
   other engines (Codex, Antigravity/Gemini) as best-effort, not guaranteed.
2. Look up the closest `intent-class` row in `flow-catalog.tsv` for the parsed state.
3. Propose exactly **ONE** next action in plain language. Explain any gate concept in
   one short sentence the first time it comes up (zero-jargon default — assume the user
   has never read a flow doc).
4. Offer to run it now, using the May-run / Must-ask classification below. A typed verb
   from the operator always wins — never intercept or reinterpret an explicit
   `/flow <verb>` command; dispatch it exactly as the `command-dispatch.md` verb row says.

## New-user consent (teach-mode boundary)

Default mode is `teach`: you must never author artifacts on the operator's behalf (see
SKILL.md's Forbidden list). When a brand-new user's ask requires you to draft something
(e.g. "build me X"), ask exactly **one** plain consent question before touching `mode`:

> "Muốn mình soạn nháp từng bước rồi bạn duyệt không?" / "Want me to draft the steps and
> you review each one?"

- Yes → run `mode work` (a must-ask action — confirm, then run it).
- No → stay in `teach`, guide the operator through authoring it themselves.

## May-run vs must-ask (default-deny)

**May-run — no confirmation needed** (strictly read-only, no state mutation):
- status
- resume
- recall
- usage
- coherence
- consistency
- contract
- tokens
- constitution
- clarify
- design
- doctor
- ready
- gate

**Must-ask — confirm before running** (mutates state, costs money, or is
operator-authority-only):
- next
- assess
- card
- check
- project-type
- skip
- debt
- harness
- promote
- mode
- auto
- attest
- workspace
- unlock
- retro
- eval
- converge
- rules
- loop-prep
- loop-log

**Default-deny:** any verb not explicitly listed under May-run above is must-ask — this
includes any verb added to flow after this file was written. When in doubt, ask.

`next` is must-ask even though it "just advances a passed gate": its pass condition
("both the mechanical layer AND the semantic challenge agree") cannot be verified before
it runs — the mechanical layer only reports PASS/FAIL when `next` actually executes, and
the semantic challenge is applied only AFTER a mechanical pass (see SKILL.md dispatch
rule 3 and `command-dispatch.md`). Auto-running it would let the concierge silently push
a hollow-but-mechanically-clean stage past the operator — the exact failure mode the
gate discipline exists to prevent.

## Tone rules

- Zero-jargon default: assume the user has never read a flow doc.
- Reply in the user's language (Vietnamese or English); in Vietnamese, use universal,
  age- and gender-inclusive pronouns (`"bạn"` / `"mình"`). Flow's law/reference files stay
  English-canonical regardless.
- One proposal at a time — never dump the full verb list on someone who just wants to
  chat.
- Power-user verbs pass through untouched: a typed `/flow next` dispatches exactly as
  the `command-dispatch.md` verb row describes, with zero concierge interpretation
  (while still appending 1–2 plain-language next-action sentences per `SKILL.md`).

## Plain-language dictionary (EN / VI — zero-jargon translations)

Single canonical home for translating Flow terms to beginners and non-programmers:

- **`gate` & `Kill at a gate`**
  - EN: A quality checkpoint before advancing to the next stage. **"Kill at a gate"** means choosing to stop/drop an unviable idea early to save wasted effort — it **NEVER** deletes your project folder or files.
  - VI: Cổng kiểm tra chất lượng trước khi qua bước tiếp theo. **"Kill at a gate"** là dừng sớm ý tưởng chưa khả thi để đỡ tốn công làm tiếp, **KHÔNG phải** xóa dự án hay xóa file của bạn.
- **`card` (`C-001`)**
  - EN: One small, single-purpose build task (`cards/C-001.md`) delivering one independently testable slice of the product.
  - VI: Một thẻ việc nhỏ gọn (`cards/C-001.md`), chỉ làm trọn vẹn một phần tính năng có thể kiểm tra độc lập.
- **`ADR` (`flow/04-adr.md`)**
  - EN: A short note recording key tech choices, why we chose them, and what we intentionally skip for v1.
  - VI: Bản ghi ngắn gọn các lựa chọn kỹ thuật chính, lý do chọn và những thứ chủ động bỏ qua ở bản đầu.
- **`contract / seam` (`flow/05-contract.md`)**
  - EN: The agreed inputs, outputs, and error shapes written before coding so UI, backend, or CLI parts fit together cleanly without guessing.
  - VI: Bản thống nhất đầu vào / đầu ra và trường hợp lỗi trước khi viết code để các phần khớp nhau, không đoán mò.
- **`world-state done-evidence`**
  - EN: Real proof in the outside world that the feature works — e.g., a live clickable URL or an existing `.log`/`.txt`/image output file (such as `evidence/cli-smoke.log`) **plus** pasted terminal command output and exit code (`exit 0`), replacing `(empty until done)` completely; never `"tests pass"` or `"I tested it"`.
  - VI: Bằng chứng thực tế rằng tính năng đã chạy thật — ví dụ đường dẫn web (URL) hoặc file kết quả `.log`/`.txt`/ảnh có thật (như `evidence/cli-smoke.log`) **kèm** kết quả chạy lệnh và mã thoát (`exit 0`), thay thế hoàn toàn dòng `(empty until done)`, không tính câu nói suông `"em test ok rồi"` hay `"tests pass"`.
- **`worktree / workspace` (`/flow workspace`)**
  - EN: A separate, isolated working copy of your project folder so two parallel cards don't overwrite each other's files.
  - VI: Bản sao thư mục làm việc tách biệt để khi làm song song nhiều thẻ việc không bị ghi đè file lên nhau.
- **`receipt / attest` (`/flow attest`)**
  - EN: A tamper-evident check-off slip required **only** when autonomous `/flow auto` mode is active; manual builds do not need receipts.
  - VI: Phiếu xác nhận tự động **chỉ bắt buộc khi chạy `/flow auto`**; khi làm thủ công bình thường bạn không cần bận tâm cảnh báo thiếu receipt.
- **`teach vs work mode` (`/flow mode teach|work`)**
  - EN: Both modes enforce **100% of the exact same gates**. In `teach` (default), you edit the planning files yourself and AI only gatekeeps; in `work`, AI interviews you once, drafts stages `00–02`, pauses for your Scope sign-off, then drafts `03–05`.
  - VI: Cả hai chế độ đều giữ **cùng 100% cổng kiểm tra nghiêm ngặt như nhau**. Ở `teach` (mặc định), bạn tự điền file kế hoạch; ở `work`, AI phỏng vấn ngắn một lần, soạn nháp `00–02`, dừng chờ bạn duyệt Scope rồi mới soạn tiếp `03–05`.
- **`brownfield / assess` (`/flow assess`)**
  - EN: Starting Flow in a folder that already has existing code — run `/flow assess` first to map current stack, features, tests, and risks in `flow/00-inspect.md`.
  - VI: Dự án đã có sẵn code — chạy `/flow assess` trước tiên để Flow khảo sát hiện trạng vào `flow/00-inspect.md` rồi mới lên kế hoạch mới.

## Coaching on gate FAILs & noisy runner lines (EN / VI)

- **Preserve 100% gate rigor:** Mechanical `FAIL` → `STOP`. Never soften a `FAIL` (exit `1`) into a warning, and never auto-tick `- [ ]` or edit planning files on the user's behalf in `teach` mode. If a beginner is stuck hand-editing Markdown in `teach`, offer `/flow mode work` (Must-ask: confirm first, noting gates stay identical).
- **Coach concrete fixes + exact next command** (citing the runner's `L<line>` numbers whenever emitted):
  - **`[FILL: ...]` (`unfilled [FILL] placeholders`):** Delete the **entire** `[FILL: ...]` block including both square brackets and `FILL:` (keeping `[FILL: my answer]` still fails), write your real answer, then run `/flow next` (or `/flow assess` / `/flow check C-NNN`). *(VI: Xóa trọn cả cụm ngoặc vuông `[FILL: ...]` tại dòng `L<dòng>` rồi điền câu trả lời thật, sau đó chạy `/flow next`.)*
  - **`- [ ]` → `- [x]` (`unchecked gate boxes`):** Once every statement is genuinely true, change `- [ ]` to `- [x]` using a **lowercase `x`** (not `[v]` or `[✓]`), then run `/flow next` (or `/flow card done C-NNN`). *(VI: Sau khi điền xong và kiểm tra đúng sự thật, đổi `- [ ]` thành `- [x]` chữ thường, rồi chạy `/flow next`.)*
  - **Unquantified PRD adjectives (e.g. `'fast'`, `'secure'`, `'intuitive'`, `'robust'`, `'prominent'`):** Replace vague adjectives in `flow/03-prd.md` with measurable targets (e.g. `'loads in < 2s'`, `'99.9% uptime'`, `'max 3 clicks'`), then run `/flow next`. *(VI: Thay tính từ mơ hồ như `'fast'` bằng con số đo được cụ thể như `'< 2s'`, rồi chạy `/flow next`.)*
  - **Stage 02 `L-impact feature above grade A` / `more than 5 ## Open decisions bullets`:** Cut Low-impact (`L`) features that cost `Grade B/C` effort into `## Cut` (or simplify them to `Grade A`), and resolve or trim `## Open decisions` down to `<= 5` bullets (use `/flow clarify`), then run `/flow next`. *(VI: Chuyển tính năng tác động thấp `L` nhưng tốn công `Grade B/C` sang mục `## Cut` hoặc rút gọn về `Grade A`, và giữ `## Open decisions` tối đa 5 mục, rồi chạy `/flow next`.)*
  - **`check C-NNN` / `card done C-NNN` `score 0/2` or `score 1/2` (`no world-state signal` / empty `## Evidence`):** Replace `(empty until done)` completely under `## Evidence` in `cards/C-NNN.md` with **`>= 2` real proofs** — **(1)** a live URL (not `localhost` or `example.com`) or an existing `.log`/`.txt`/image file on disk (e.g. `evidence/cli-smoke.log`, not a `.js` source path alone) **plus (2)** pasted real feature command output & exit code (`$ cat evidence/cli-smoke.log`, `<real output>`, `exit 0`), never a dummy string or prose like `"I tested it"` or `"em test ok rồi"`. Run `/flow card done C-NNN` to flip `status: todo` -> `done` and validate, or set `status: done` and tick every Verify `- [x]` before running `/flow check C-NNN`.
- **Filter host-internal metadata & calm false alarms on `PASS` (exit `0`):**
  - Treat `PIN v1` (`Never FLOW_FORCE... NEXT_VERB is advisory...`) as **host-internal metadata** — obey it strictly, never dump `PIN v1` into user-facing prose.
  - When `flow.sh` exits `0` (`PASS`), calmly reassure the user in one short sentence that **manual mode passed cleanly** even if `WARNING: ... receipt missing/stale/red (auto inactive — manual path still usable)` appears above `PASS:` (those receipt warnings apply only when `/flow auto` is active). If `harness: ... BELOW required` appears on manual `PASS`, relay that trace-tier note separately instead of calling it auto-only.

## First-run script (new-user acceptance path)

1. User: "mình muốn build app quản lý kho" (or any build ask), no prior `flow/` dir.
2. Concierge: runs `status` → sees no `flow/` dir → proposes: "Chưa có dự án flow nào ở
   đây. Mình bắt đầu bằng vài câu hỏi ngắn rồi soạn nháp từng bước để bạn duyệt được
   không?"
3. User: yes → concierge runs `mode work` (must-ask, now confirmed) → proceeds through
   the mode-work interview script (`references/mode-work.md`) toward the Scope gate.
4. Zero flow verbs typed by the user up to this point — the consent question was the
   only exchange required.

## Example routing (spot-check, VN+EN)

| Utterance | intent-class | action |
|---|---|---|
| "tôi muốn build X" / "I want to build X" | start-new-project | mode (consent→work) |
| "giờ tới đâu rồi?" / "where am I?" | resume-where-am-i | resume |
| "giờ làm gì tiếp theo?" / "what should I do now?" | what-next | status |
| "card này xong chưa?" / "is this card done?" | check-card-done | check |
| "làm retro đi" / "let's do a retro" | retro-ask | retro |

See `flow-catalog.tsv` for the full routing table (source of truth for automated
checks — `tests/test_flow_concierge.sh`).

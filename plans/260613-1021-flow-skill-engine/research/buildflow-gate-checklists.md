# Buildflow gate checklists — VERBATIM spec (nguồn cho flow.sh)

> Trích nguyên văn từ `D:\project\flow\ai20k-build-phase\buildflow\_templates\*`.
> flow.sh phải enforce: (a) mọi `- [ ]` đã tick, (b) zero `[FILL]`, (c) report vi phạm + line + file.
> Lớp Claude enforce phần ngữ nghĩa (cột "Claude challenge").

## Stage 00 — `_templates/00-idea.md`
```
- [ ] The pitch below is 3 sentences, no more
- [ ] I can name at least ONE real person/group who has this pain (named below)
- [ ] No FILL placeholders remain in this file
```
**Claude challenge:** pitch >3 câu; "person/group" mơ hồ ("mọi người"); pain không cụ thể.

## Stage 01 — `_templates/01-research.md`
```
- [ ] I actually OPENED 3 existing tools/competitors (links below, with one honest note each)
- [ ] I found 3 REAL user complaints online and quoted them (with source links)
- [ ] I wrote what competitors CHARGE (real prices) and who is paying them
- [ ] I named the ONE channel my first 10 users come from (a place, not "social media")
- [ ] I wrote why those users would pick this over the status quo (one honest paragraph)
- [ ] I wrote what is technically free vs hard for this idea
- [ ] No FILL placeholders remain in this file
```
**Claude challenge:** quote rỗng/không link; "social media" chung chung; giá bịa; competitor không mở thật.

## Stage 02 — `_templates/02-scope.md`
```
- [ ] Every feature below has an IMPACT (H/M/L with the business reason) AND a grade (A/B/C)
- [ ] No L-impact feature above grade A survives in v1
- [ ] The suggested-features section was actually considered (each suggestion has an in/out decision)
- [ ] fit(grades, budget) holds — every C in scope is justified as path 1, 2, or 3 above (written next to the feature)
- [ ] If the product IS a C feature: it is FIRST in build order, and its sibling C features are on the cut list
- [ ] The cut list is written (what I am NOT building in v1)
- [ ] GO / KILL decision is written below
- [ ] No FILL placeholders remain in this file
```
**Impact:** H=moves money/core promise · M=retention/ops · L=nice-to-have.
**Grade:** A=rẻ (CRUD/form/dashboard/API wrapper) · B=vừa (file proc/3rd-party/auth-lib/single LLM call/HITL draft) · C=đắt (realtime/payment-from-scratch/custom auth/agentic pipeline/heavy concurrency).
**3 path cho C:** (1) C LÀ product→C đi FIRST; (2) re-architect C→B; (3) irreducible→KILL/re-budget.
**Claude challenge:** grade-laundering (gọi C là B không justify); v1 toàn A-grade L-impact.

## Stage 03 — `_templates/03-prd.md`
```
- [ ] Every section below is filled from MY scope decision (stage 02), not re-expanded
- [ ] Success metric is a NUMBER, not vibes ("save time" fails; "first response < 2h" passes)
- [ ] Each feature names the user action and the observable result
- [ ] Pain & gain is a MAPPING TABLE: every pain cites evidence (a stage-01 quote or a named observation), and names the v1 feature that kills it; every v1 feature kills at least one pain
- [ ] A stranger could build v1 from this without asking me anything
- [ ] No FILL placeholders remain in this file
```
**Claude challenge:** metric không phải số; feature không map pain (hoặc pain không có feature); thiếu evidence.

## Stage 04 — `_templates/04-adr.md`
```
- [ ] Each decision has a one-line "why" and a one-line "what I rejected"
- [ ] The NOT-doing list is written
- [ ] Decisions cover: data storage, auth approach, deploy target
- [ ] No FILL placeholders remain in this file
```
**Claude challenge:** decision thiếu "rejected"; chưa phủ data/auth/deploy.

## Stage 05 — `_templates/05-contract.md`
```
- [ ] Every PRD feature maps to at least one endpoint below
- [ ] Every endpoint has request AND response shapes written
- [ ] Auth column filled for every endpoint (public / token / admin)
- [ ] No FILL placeholders remain in this file
```
**OpenAPI rule:** bảng này = PLANNING source of truth; served spec = RUNTIME artifact cùng contract; đổi 1 chiều: amend file→code→spec theo sau. Contract-test card assert live spec khớp.
**Claude challenge:** feature không có endpoint; endpoint thiếu auth/shape; drift field (vd `player_email`).

## Card — `_templates/card.md`
**Sections bắt buộc:** `# C-NNN`, `status:`, `deps:`, `## Scope`, `## Allowed files`, `## Verify`, `## Done-evidence`, `## Evidence`.
**Check (`/flow check C-NNN`):**
- `status: todo|done` (không giá trị khác); `deps: [card ids|"none"]` hợp lệ.
- Zero `[FILL]`.
- Nếu `status: done`: mọi `## Verify` box ✓ AND `## Evidence` non-empty (không phải placeholder).
**Claude challenge:** evidence = "tests pass"/"merged" (KHÔNG phải world-state); allowed-files drift vs scope; scope >1 thứ.

## Luật xuyên suốt (CLAUDE.md) — flow.sh + Claude phải tôn trọng
- 1 card/session; chỉ động `## Allowed files`; cần file khác → STOP, amend card.
- Contract & DESIGN là 2 law file; contract sai → amend file trước rồi code; honor SHAPE ngay (null/stub), giao VALUE ở card sau, KHÔNG bỏ field.
- Done = world-state (URL/curl/DB row). Merge ≠ shipped → verify live sau merge.
- KHÔNG tự tick gate box / viết artifact thay operator. Đọc file flow.sh vừa tạo trước khi edit.
- Debt: skip cố ý → 1 dòng `DEBT.md`; security-class skip = operator văn bản, auto = Tier-C halt.
- Forbidden: 2 card/1 worktree; parallel khi chưa `ready`; edit `_templates/`/`flow.sh` trong project run; frontend trước khi mock approve.

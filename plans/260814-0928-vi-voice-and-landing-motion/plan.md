---
title: "VI voice and landing motion"
description: "Rewrite /vi/ landing from spoken Vietnamese laws; add Galley-Proof motion so the homepage is not a static sheet."
status: in_progress
priority: P1
effort: "4h"
tags: [website, vi, motion]
created: 2026-08-14
---

# VI voice and landing motion

## Overview

Hai việc song song. (1) Red-team + validate copy `/vi/` rồi viết lại landing theo luật research — operator bảo "thay tôi", không interview. (2) Motion trên trang chủ trong thế giới Galley Proof: hai cột đồng ý thì cổng mở, không fade-up SaaS.

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | Landing VI nói được: một sợi, tiểu từ, không calque/telegram | P1 |
| 2 | Trang chủ có focal motion (hai galley + tick) + lockup press | P1 |
| 3 | `prefers-reduced-motion` tắt motion; copy vẫn đọc được | P1 |

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | [VI voice red-team / validate / rewrite](./phase-01-start.md) | in-progress |
| 2 | [Landing motion](./phase-02-landing-motion.md) | in-progress |

## Constraints

- Khóa từ: cổng, card, bằng chứng done. Lệnh EN.
- Không đụng root `DESIGN.md`. `website/DESIGN.md` là luật Galley.
- Không đổi class name (motion CSS // copy VI).
- 31 stub và 15 docs full: không đụng pass này.
- Không deps npm mới.

## Success Criteria

- [ ] Operator đọc to first viewport `/vi/` không vấp
- [ ] Không em-dash, không "Không phải X. Là Y.", không `máy chạy` bịa
- [ ] Crayon kill-line vẫn là một authored vermillion
- [ ] Reduced-motion: không animation, content visible

## Agent ownership (this session)

| Agent | Owns |
|---|---|
| Red-team Assumption Destroyer | findings only |
| Red-team Failure Mode Analyst | findings only |
| Validate + rewrite | `website/src/pages/vi/index.astro` |
| Motion CSS | `website/src/styles/landing.css` |
| Lockup | `website/src/components/InstallLockup.astro` |

## Red Team Review

### Session — 2026-08-14
**Findings:** 12 unique after dedupe (8 + 9 raw, overlap on rewrite-now / kill mouths / máy chạy / docs count / title-meta)
**Severity:** 3 Critical, 6 High, 3 Medium
**Accepted:** 8 · **Rejected:** 2 · **Accept (applied):** 2

| # | Finding | Severity | Disposition | Applied To |
|---|---------|----------|-------------|------------|
| 1 | Rewrite-now = pass 3, no gold | Critical | Reject (stop-ship) | Operator said "thay tôi cải thiện"; risk kept |
| 2 | Claims = EN slot map | Critical | Accept | Residual: lede still claim-shaped; no more slot rewrite |
| 3 | Flatten stop-words erases kill | Critical | Accept (applied) | kill-line → `bỏ` (crayon = bỏ cuộc, not dừng) |
| 4 | `máy chạy` vs `flow.sh` filename | High | Accept | Left column is `flow.sh`; chờ vàng nếu ông đặt tên khác |
| 5 | Landing-only mouth dies on docs | High | Accept | Docs freeze this pass; known |
| 6 | 15+31 inventory sai | High | Accept | Cây VI = 47 file, ~23 đọc được; không bung pass này |
| 7 | Title/meta/H1 lệch | High | Accept (applied by validate) | Title/meta/lede cùng một miệng |
| 8 | Stand H2 phủ nhận agent viết | High | Accept (applied by validate) | `flow gác cổng, chứ không viết code` + `Agent vẫn viết` |
| 9 | Lockup formal vs body Zalo | Medium | Reject | Microsoft UI labels giữ; không bịa lockup |
| 10 | Motion + measure EN clip dấu | Medium | Accept (applied) | `html[lang=vi] .headline { line-height: 1.15 }` |
| 11 | `đồng ý` ≠ exit 0/1 | Medium | Accept | H1 giữ; body đã nói 0 hoặc 1 |
| 12 | Pipeline stage names EN | High | Accept | DNT; chờ vàng cách gọi sáu cổng |

### Whole-Plan Consistency Sweep

- Constraint "31 stub" in this plan is stale (finding 6). Docs freeze still stands; count is wrong, scope is not.
- Advise no-go overwritten by this session's operator order; do not re-open a fourth agent rewrite.
- Kill mouths: landing crayon = **bỏ**; block = **chặn/dừng**; docs still say `Kill` until a later pass.
- Motion files shipped: `landing.css`, `InstallLockup.astro`. Copy file: `vi/index.astro`.

<!-- slug: vi-voice-and-landing-motion -->

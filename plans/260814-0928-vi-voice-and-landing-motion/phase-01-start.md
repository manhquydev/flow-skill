---
phase: 1
title: "VI voice red-team / validate / rewrite"
status: in-progress
priority: P1
effort: "2h"
dependencies: []
---

# Phase 1: VI voice red-team / validate / rewrite

## Overview

Red-team copy + luật research. Validate "thay tôi" (14 quyết định đã khóa). Rewrite landing `/vi/` only.

## Requirements

- Functional: first viewport + bands trên `website/src/pages/vi/index.astro` nói như nhắn đồng nghiệp
- Non-functional: đủ dấu; giữ class; H1 giữ nếu được

## Related Code Files

- Modify: `website/src/pages/vi/index.astro`
- Create: `plans/reports/validate-260814-0926-vi-landing.md`
- Read: `plans/reports/research-260814-0920-vi-voice-semantics.md`

## Implementation Steps

1. Red-team 2 lens (Assumption Destroyer, Failure Mode Analyst)
2. Validate agent rewrite theo 14 quyết định
3. Adjudicate findings; vá Accept vào copy
4. Không bung 15 docs

## Success Criteria

- [ ] Copy không còn device Anh (— ; Not X. It's Y. telegram)
- [ ] Một miệng dừng/chặn/bỏ
- [ ] Claim sản phẩm còn đủ

## Risk Assessment

Pass 3 agent rewrite có thể lại calque. Mitigation: luật research + red-team evidence filter.

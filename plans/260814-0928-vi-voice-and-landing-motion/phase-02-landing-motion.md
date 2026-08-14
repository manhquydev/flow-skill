---
phase: 2
title: "Landing motion"
status: in-progress
priority: P1
effort: "2h"
dependencies: []
---

# Phase 2: Landing motion

## Overview

Thêm motion đúng thế giới giấy in. Focal: hai `.galley` ổn rồi `.pass-mark` vẽ. Lockup: nhấn như máy in.

## Requirements

- Functional: entrance + tick + pipeline stamp + copy press
- Non-functional: content visible default; reduced-motion off; no layout shift

## Related Code Files

- Modify: `website/src/styles/landing.css`
- Modify: `website/src/components/InstallLockup.astro`
- Do not modify: `website/DESIGN.md`, root `DESIGN.md`, `*.astro` copy

## Implementation Steps

1. CSS agent: hero/galley/tick/pipeline
2. Lockup agent: scoped styles + press/copied
3. Giữ crayon `.kill-line` 760ms / 420ms
4. Detector sau khi xong

## Success Criteria

- [ ] Không generic fade-up mọi section
- [ ] Không shadow/glass/blur/radius
- [ ] Reduced-motion block phủ animation mới

## Risk Assessment

Hai agent đụng `landing.css` — đã tách: CSS agent vs scoped `<style>` trong lockup.

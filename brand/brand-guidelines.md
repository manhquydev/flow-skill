# flow — brand guidelines

Companion to [brand-brief.md](brand-brief.md). Machine-readable tokens:
[tokens.json](tokens.json) / [tokens.css](tokens.css). This document is the
source of truth; tokens must match it exactly.

## 1. Color palette

Identity anchor: README badge accent `#1AA3C4`, already in use on
flowskill.io.vn (in `flowskill-website` repo: `#1aa3c4`, dark variant
`#0a4e5e`). Legacy site colors `#D63A2F` and the warm greys (`#C9C6BB`,
`#C4C0B4`, `#B7B3A6`) are **not** part of this palette; do not extend them.

### 1.1 Brand — Signal Teal

| Token | Hex | RGB | Role |
|---|---|---|---|
| Teal Signal | `#1AA3C4` | rgb(26, 163, 196) | Primary accent: badges, links-as-graphics, gate glyph, banner brand line, focus rings |
| Teal Deep | `#0A4E5E` | rgb(10, 78, 94) | Teal *text* on light backgrounds (Signal Teal fails contrast for body text), hover/pressed states |
| Teal Bright | `#5BC8DE` | rgb(91, 200, 222) | Teal text/graphics on dark backgrounds (`#0F172A`) where Signal Teal is the minimum, not the target |

Contrast rules: `#1AA3C4` on `#F8FAFC` ≈ 2.9:1 — decorative/large-graphics
only. For readable teal text on light: `#0A4E5E` (≈ 7.4:1). On dark `#0F172A`:
`#1AA3C4` ≈ 5.6:1 (ok for ≥ 18px), `#5BC8DE` ≈ 8.9:1 (use for small teal text).

### 1.2 Neutrals

| Token | Hex | RGB | Role |
|---|---|---|---|
| Ink | `#0F172A` | rgb(15, 23, 42) | Primary text on light; **doubles as the dark-mode background** (the identity inverts: ink becomes paper) |
| Ink Soft | `#334155` | rgb(51, 65, 85) | Secondary text, captions, table borders on light |
| Mist | `#E2E8F0` | rgb(226, 232, 240) | Primary text on dark backgrounds |
| Paper | `#F8FAFC` | rgb(248, 250, 252) | Light-mode background, cards, docs surfaces |

### 1.3 Functional gate colors

Status-only. Never decorative, never brand-narrative.

| Token | Hex | RGB | Meaning |
|---|---|---|---|
| Pass | `#22C55E` | rgb(34, 197, 94) | Gate agreed; stage advanced |
| Warn | `#F59E0B` | rgb(245, 158, 11) | Degraded/skipped: debt opened, best-effort degrade |
| Fail | `#EF4444` | rgb(239, 68, 68) | Gate blocked; kill is a valid outcome |

Usage rules: gate colors appear only as status dots, badge fills, and
`--json` renderings of real gate state — at ≤ 5% of any surface, combined.
Badge text on a gate-colored fill is Ink `#0F172A`, never white, never the
gate color itself on itself. A Fail dot must always sit next to the blocking
condition and the exact next verb ("run `/flow check C-001`").

### 1.4 Usage ratios (per surface)

- ~60% background: Paper `#F8FAFC` (light) / Ink `#0F172A` (dark)
- ~30% structure & text: Ink `#0F172A` / Ink Soft `#334155` (light) or
  Mist `#E2E8F0` (dark)
- ≤ 10% brand accent: Teal Signal family
- ≤ 5% functional: pass/warn/fail, status semantics only

## 2. Typography

Both families are open source (OFL) and ship full Vietnamese diacritics —
required for the bilingual promise. Never substitute a non-Vietnamese face.

| Token | Family | Fallback stack | Weights |
|---|---|---|---|
| `font.ui` | Inter | `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif` | 400, 600, 700 |
| `font.mono` | JetBrains Mono | `"SF Mono", "Cascadia Code", Menlo, Consolas, "Liberation Mono", monospace` | 400, 700 |

Rules:
- **JetBrains Mono is the identity face.** flow is terminal-first: the
  wordmark, `/flow` verbs, verdicts (`GAP`, `CONVERGED`, `NEXT ->`), file
  paths, and badges render in mono. UI prose (docs, site paragraphs) uses Inter.
- Body ≥ 16px, line-height ≥ 1.5; VI text needs the extra leading for diacritics.
- Headlines sentence-case; verdicts and commands uppercase-as-typed (`/flow next`
  is literal — never restyle verb casing).
- Code samples always mono, always in Teal Deep (light) / Teal Bright (dark)
  or Ink — never in gate colors (color is reserved for status).

## 3. Logo

The official logo system pairs the **Direction A gate mark** (bilateral
mechanical and semantic gate stanchions framing an advancing pass chevron)
with the shape-built lowercase wordmark **`flow-04-gate-o-v2`** (dual-gate
stanchions for the letter 'o', 32u open corridor, 20u stanchions). Pure vector
paths with zero live `<text>` tags, zero gradients, and zero raster dependencies.

- **Primary Lockup:** `brand/brand-lockup-light.svg` (light surfaces, letters
  Ink `#0F172A`) and `brand/brand-lockup-dark.svg` (dark surfaces, letters
  Mist `#E2E8F0`). Stanchions Signal Teal `#1AA3C4`, chevron Gate Green `#22C55E`.
- **Glyph Tier:** `brand/brand-mark-glyph.svg` (standalone 512×512 gate mark).
- **Icon Suite:** `brand/icons/` (vector `favicon.svg`, raster `favicon-16/32.png`,
  `apple-touch-icon-180.png`, `icon-512.png`, `icon-1024-squircle.png`,
  `og-image-1200x630.png`, and die-cut `sticker.svg`).
- **Tier usage & minimum size:** Lockup $\ge 24\text{px}$ container height.
  Below 24px (favicons, IDE status bars, breadcrumbs), collapse to the glyph.
- **Clearspace:** Minimum $1 \times H_{\text{mark}}$ on all four sides — no text,
  badges, dividers, or container edges inside this exclusion perimeter.
- **Do:**
  - Use `brand-lockup-light.svg` on Paper and `brand-lockup-dark.svg` on Ink.
  - Collapse lockup to `brand-mark-glyph.svg` in viewports $< 24\text{px}$ tall.
  - Use GitHub `#gh-light-mode-only` / `#gh-dark-mode-only` fragments to swap.
- **Don't:**
  - Don't recolor wordmark with gate status colors — status is data, not brand.
  - Don't render the lockup below 24px height or truncate clearspace.
  - Don't box the logo in a filled teal pill; the mark is stroke-first.
  - Don't typeset the wordmark in stock proportional fonts.
## 4. Application notes

### GitHub README header
- Two-variant header image via `<picture>` + `prefers-color-scheme`: light =
  Paper bg, Ink wordmark, Teal Signal chevron; dark = Ink bg, Mist wordmark,
  Teal Signal chevron. Alt text states the identity line, not the tagline.
- Tagline under the header in mono: "Proof over vibes." / "Bằng chứng hơn
  cảm hứng." — one language per README (EN README / README_VN.md).

### npm badges (shields.io)
- Brand badge (website): `color=1aa3c4` — already the live convention.
- `npm` version badge keeps registry red `cb3837`; `license` keeps its
  conventional green; **never** recolor third-party convention badges into
  brand teal — teal badges are reserved for flow-owned facts (website, docs).
- Gate-color badges (`brightgreen` tests, etc.) only ever reflect real
  status; a red badge stays red until the gate says otherwise.

### Terminal ASCII banner (`/flow` greeting)
- Mono-only, ≤ 5 lines, ≤ 60 columns, renderable without 24-bit color.
- One Teal Signal `256/truecolor` line (brand), status line uses gate colors
  only when reporting actual gate state; default is no color (respects `NO_COLOR`).
- Footer line = tagline #3: `done means proven` / `xong nghĩa là đã chứng minh`
  — locale-follows-session, never mixed on one banner.

## 5. Light / dark background rules

- Light mode: bg Paper `#F8FAFC`, text Ink `#0F172A`, secondary Ink Soft
  `#334155`, teal text = Teal Deep `#0A4E5E`.
- Dark mode: bg Ink `#0F172A`, text Mist `#E2E8F0`, teal text = Teal Signal
  `#1AA3C4` (large) or Teal Bright `#5BC8DE` (small). Never pure `#FFFFFF`
  text and never pure `#000000` backgrounds — the slate pair is the brand.
- Gate colors keep the same hex on both modes; on dark, pair them with Mist
  text labels since their contrast against dark is dot-sized, not
  paragraph-sized.
- Never place Signal Teal text directly on Paper at body size; never place
  Mist text on Paper or Ink text on Ink. When in doubt, check the ratios in
  §1.4 and the pairs listed in this section.

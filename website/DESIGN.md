---
name: flow website
description: A letterpress galley proof that will not go to press until both columns agree.
colors:
  ink: '#111111'
  newsprint: '#c9c6bb'
  newsprint-dark: '#b7b3a6'
  process-cyan: '#1aa3c4'
  cyan-deep: '#0a4e5e'
  kill-vermillion: '#d63a2f'
  ink-soft: 'color-mix(in srgb, #111111 78%, #c9c6bb)'
typography:
  display:
    fontFamily: "'Big Shoulders Display', sans-serif"
    fontSize: 'clamp(4.5rem, 12vw, 6rem)'
    fontWeight: 800
    lineHeight: 0.85
    letterSpacing: '-0.035em'
  headline:
    fontFamily: "'Big Shoulders Display', sans-serif"
    fontSize: 'clamp(1.7rem, 3.4vw, 2.6rem)'
    fontWeight: 700
    lineHeight: 1.05
    letterSpacing: '-0.03em'
  title:
    fontFamily: "'Big Shoulders Display', sans-serif"
    fontSize: '1.85rem'
    fontWeight: 800
    lineHeight: 1.1
    letterSpacing: '-0.03em'
  body:
    fontFamily: "Archivo, ui-sans-serif, sans-serif"
    fontSize: '1.05rem'
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: 'normal'
  label:
    fontFamily: "Archivo, ui-sans-serif, sans-serif"
    fontSize: '0.82rem'
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: 'normal'
  command:
    fontFamily: "'Azeret Mono', ui-monospace, monospace"
    fontSize: 'clamp(0.82rem, 1.6vw, 1rem)'
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: '0.01em'
rounded:
  none: '0'
spacing:
  tight: '0.55rem'
  row: '0.85rem'
  gutter: '1.75rem'
  band: '2.75rem'
components:
  press-bar:
    backgroundColor: '{colors.ink}'
    textColor: '{colors.newsprint}'
    typography: '{typography.command}'
    rounded: '{rounded.none}'
    height: '3.4rem'
  copy-command:
    backgroundColor: 'transparent'
    textColor: '{colors.newsprint}'
    rounded: '{rounded.none}'
    padding: '0.35rem 0.85rem'
  copy-command-hover:
    backgroundColor: '{colors.cyan-deep}'
    textColor: '{colors.newsprint}'
  action-primary:
    backgroundColor: '{colors.ink}'
    textColor: '{colors.newsprint}'
    rounded: '{rounded.none}'
    padding: '0.9rem 1.5rem'
  action-primary-hover:
    backgroundColor: '{colors.cyan-deep}'
    textColor: '{colors.newsprint}'
  action-quiet:
    backgroundColor: 'transparent'
    textColor: '{colors.ink}'
    rounded: '{rounded.none}'
  pipeline-slug:
    backgroundColor: 'transparent'
    textColor: '{colors.ink}'
    typography: '{typography.label}'
    rounded: '{rounded.none}'
    padding: '0.7rem 0.85rem 0.8rem'
---

# Design System: flow website

## Overview

**Creative North Star: "The Galley Proof"**

This is a letterpress galley proof pinned to the stone: cool newsprint under dense black
ink, a publisher's blue pencil marking the guides, and a vermillion crayon reserved for the
one line that gets killed. The page is a printed sheet, not an application surface. It has
gutters and rules instead of containers and cards, registration crosses where the grid
intersects, and a full-bleed black press bar carrying the line that goes to press. Density
is editorial: text sits in ruled columns, the paper carries visible grain, and nothing
floats above the sheet.

The system is flat by physical necessity. There is no elevation vocabulary at all, because
ink cannot hover over paper. Separation is done with a 1px black rule where the structure is
real and a cyan hairline where the mark is only a guide. Corners are square everywhere; a
rounded corner would betray the material. The type does the shouting: a monumental condensed
gothic for the display voice, a plain grotesque for reading, and a mono face used only where
the reader is looking at an actual command.

The confirmed anti-look is the neighboring category: the dark AI-coding-agent landing with a
neon terminal hero and a star-count row. The other confirmed rejection is its opposite — the
cream-parchment, timid-serif documentation splash. Cool gray paper and a hard black gothic
keep the page out of both ruts.

**Key Characteristics:**

- Cool newsprint (`#c9c6bb`) with a tiled paper grain, never cream or white
- Zero radius on every element, including the primary action
- 1px black rules for structure; cyan hairlines for guides only
- Vermillion appears once per page, as a drawn crayon strike
- Condensed gothic display at up to 6rem against 1.05rem grotesque body
- No shadows, no glass, no cards

## Colors

A four-ink press: one paper, one black, one process blue for registration, one vermillion for
the kill.

### Primary

- **Press Black** (`#111111`): every glyph of body and display type, all structural rules, the
  full-bleed press bar behind the install command, and the primary action block. This is the
  ink; it is used without apology and without tints in text.

### Secondary

- **Process Cyan** (`#1aa3c4`): registration crosshairs, hairline column guides, and the focus
  ring where it sits on black. It is a plate-alignment mark, not a link color.
- **Deep Process Cyan** (`#0a4e5e`): the same blue pushed to reading strength. Used for the
  active-page underline, the primary action's hover fill, and anything tinted that a reader
  must actually resolve against paper.

### Tertiary

- **Kill Vermillion** (`#d63a2f`): the editor's crayon. It exists to strike through the single
  sentence that reports a killed idea, and for nothing else.

### Neutral

- **Cool Newsprint** (`#c9c6bb`): the page itself and the text color on black surfaces. Carries
  a tiled 256px grain image so the paper reads as stock rather than as a flat fill.
- **Newsprint Shadow** (`#b7b3a6`): the slightly darker stock used for inline-code fills and the
  quieter sidebar surface in the documentation chrome.
- **Soft Ink** (`color-mix(in srgb, #111111 78%, #c9c6bb)`): secondary text — file names under a
  stage, the edition line in the colophon. It is ink thinned with the paper it sits on, never a
  neutral gray.

### Named Rules

**The Reading Cyan Rule.** `#1aa3c4` may only carry marks, hairlines, and focus rings on black.
Anything the reader has to read on paper uses `#0a4e5e`. Bright process cyan measures about
1.7:1 against newsprint and fails on sight.

**The One Crayon Rule.** Vermillion strikes exactly one line per page. A second vermillion mark
turns an editorial verdict into decoration and cancels the first one.

## Typography

**Display Font:** Big Shoulders Display (with `sans-serif`)
**Body Font:** Archivo (with `ui-sans-serif, sans-serif`)
**Label/Mono Font:** Azeret Mono (with `ui-monospace, monospace`)

**Character:** A tall condensed gothic set tight against a plain, wide-aperture grotesque — the
voice of a headline block next to the body galley it belongs to. The mono face is a third
voice used strictly for machine text: the install command, stage artifact paths, and the
version edition line.

### Hierarchy

- **Display** (800, `clamp(4.5rem, 12vw, 6rem)`, 0.85): the wordmark `flow` at the top of the
  sheet. One per page.
- **Headline** (700, `clamp(1.7rem, 3.4vw, 2.6rem)`, 1.05): the page `h1`, balanced, capped at
  18ch so it breaks where a compositor would break it.
- **Verdict** (700, `clamp(1.5rem, 2.9vw, 2.3rem)`, 1.02): the display-weight sentence pinned to
  the foot of a column above a 1px rule. Reserved for a statement the page is willing to be
  judged on.
- **Title** (800, `1.85rem`–`clamp(1.55rem, 3vw, 2.15rem)`, 1.05): column heads and band heads.
- **Body** (400, `1.05rem`, 1.5): reading text, held to a 38–46ch measure inside ruled columns
  and up to 68ch in full-width bands.
- **Label** (600, `0.82rem`): pipeline slugs and navigation.
- **Command** (500, `clamp(0.82rem, 1.6vw, 1rem)`): the install line and stage artifact paths.

### Named Rules

**The Six-Rem Ceiling Rule.** Display type stops at 6rem and tracking never goes tighter than
-0.04em. The wordmark is monumental because the column is narrow, not because the number is big.

**The Machine-Text-Only Rule.** Azeret Mono appears only where the reader is looking at
something a machine will read back: a command, a file path, a version. Mono as a costume for
"technical" is a different world's habit.

## Layout

The page is one continuous sheet, not a stack of sections. The first viewport is a CSS grid of
named areas — a 1.35fr copy column beside a 0.9fr galley column, then a full-width press bar,
then the stage slugs — held to `calc(100dvh - 4rem)` so the docket, both columns, the install
command, and the pipeline all land above the fold on a 900px-tall window.

Below the fold the sheet continues as full-bleed bands separated by 1px rules. Each band takes
`2.75rem` of padding above its heading and `2.5rem` below its last line: more space above a
heading than below it, so headings bind to the text they introduce. Horizontal gutters are
`1.75rem` on desktop and `1.1rem` under 720px.

Responsive behavior is a recomposition, not a shrink. Under 720px the grid areas reorder to
`hero → press bar → galleys → pipeline`, which puts the install command inside the first screen
on a 390×844 device instead of below two columns of explanation. The six-slug pipeline goes from
six columns to three, the stage list from three columns to two. Under 560px the press bar wraps:
the command and its copy control hold the first row, the status line reserves a line so nothing
jumps, and the secondary link takes a full row above the fold of the bar.

## Elevation & Depth

There is no elevation. Not "subtle" elevation — none. Nothing casts a shadow, nothing blurs
anything behind it, and no surface is layered over another. Depth is entirely material: the
paper grain sits under everything, black ink sits on the paper, and the press bar is a solid
black field that reads as a different plate rather than a raised object.

Separation is done with line weight instead. A 1px solid `#111111` rule marks a real structural
boundary — between the docket and the sheet, between columns, between bands. A 1px cyan
hairline at 55% marks a guide: the rows inside a ruled list, the divisions between stage slugs.

### Named Rules

**The Ink-On-Paper Rule.** If an element needs to feel separate, give it a rule or a gutter. A
box-shadow anywhere on this site is a defect, including the zero-blur block shadow.

## Shapes

Zero radius, without exception: the press bar, the copy control, the primary action, the focus
ring. The form language is rectangular fields and long horizontal rules, echoing a galley tray
and the slug tabs at the foot of a proof.

The only drawn geometry is printer's marks. Registration crosshairs — a circle crossed by a
full-width and full-height line, 12–16px — sit where the grid intersects and hang across the
rules they register against. The pass mark is a hand-weight tick with a 4-unit stroke. The kill
crayon is an authored SVG mask: a tapered stroke with a lift in the middle, tilted -2deg,
filled with vermillion. None of these are font glyphs or emoji.

## Components

### Press bar (signature)

The install command is a full-bleed black bar, and the bar *is* the primary call to action —
never a pill, never a centered button.

- **Shape:** square, full width, `3.4rem` minimum height
- **Contents:** a cyan registration mark, the command in Azeret Mono with `user-select: all`, a
  named `Copy` control, a status line, and the secondary link pushed to the right behind a 1px
  divider
- **States:** the copy control and the secondary link fill with deep process cyan on hover
  (newsprint type on `#0a4e5e`, never a newsprint wash on ink); focus inside the bar draws a
  2px `#1aa3c4` ring, which is the one place bright cyan is legible
- **Feedback:** the status line reports `Copied`, and when the clipboard API refuses it selects
  the command and says so instead of failing silently. The command stays selectable either way.

### Buttons

- **Shape:** square (`0`)
- **Primary:** press black on newsprint text, `0.9rem 1.5rem` padding, weight 700
- **Hover / Focus:** background shifts to deep process cyan over 140ms `ease-out`; focus draws a
  2px black ring at 3px offset
- **Quiet:** an underlined ink link; hover thickens the underline from 1px to 3px rather than
  changing color

### Galley block

A ruled editorial column: a display-weight head, one sentence of body, then a list of proof
lines separated by cyan hairlines. No border-radius, no background fill, no card. Two of them
stack against a 1px rule to form the right column of the sheet.

### Pipeline slugs

Six equal cells under a black rule, labelled in 0.82rem semibold, divided by cyan hairline
guides with a registration cross floating at each division. The cross is suppressed at the last
cell, where there is no rule to register against and it would widen the sheet.

### Navigation

The docket is a fixed `4rem` bar: wordmark left, locale pair and docs link right, over a 1px
rule. Links are undecorated ink; hover draws a 1px inset underline; the current locale carries a
2px deep-cyan underline plus `aria-current`, so the state is never carried by color alone.

### Colophon

The footer is a printer's imprint: one sentence naming the product, a mono edition line reading
the live skill and installer versions at build time, then project links and the locale pair.
Links carry a 40% ink underline at rest and full ink on hover.

## Do's and Don'ts

### Do:

- **Do** set the page on cool newsprint `#c9c6bb` with the tiled grain, and keep text ink black.
- **Do** separate with a 1px `#111111` rule for structure and a 55% cyan hairline for guides.
- **Do** keep every corner square, including calls to action.
- **Do** use `#0a4e5e` when a blue must be read on paper, and reserve `#1aa3c4` for marks,
  hairlines, and focus rings on black.
- **Do** let one authored moment carry the motion: the crayon draws left to right on load,
  `760ms cubic-bezier(0.16, 1, 0.3, 1)` after a `420ms` delay, from an already-visible default,
  and it does not run under `prefers-reduced-motion`.
- **Do** name controls by their action (`Copy`, `Install and first run`) and report both the
  success and the recovery path.

### Don't:

- **Don't** add a shadow, glass, blur, or gradient anywhere. There is no elevation in this world.
- **Don't** round a corner, and don't reach for the zero-blur block shadow as a substitute for
  depth.
- **Don't** use vermillion for emphasis, borders, or a second strike. One killed line per page.
- **Don't** set body or navigation text in bright `#1aa3c4`; it fails contrast on newsprint.
- **Don't** build page structure out of same-size cards, or put a kicker or eyebrow above a
  heading.
- **Don't** set mono type as a "technical" flourish; it is for commands, paths, and versions.
- **Don't** dress the page as the neighboring category — dark terminal hero, neon edge, star
  counts — or as a cream-parchment documentation splash.

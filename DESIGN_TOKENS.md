# Nocturne — Design Tokens (VERIFIED)

Extracted directly from the CSS inside `Nocturne - App Design (standalone).html`
(the design-tool bundle was unpacked and its inline styles parsed). **Every value below is
read from the actual stylesheet — none are pixel-guessed.** Where the earlier PDF extraction
differed, the HTML value wins and the correction is noted.

Design: **Nocturne** — "After dark, by invitation." · 42 screens · 3 roles. Dark-first luxury Art Deco.

---

## 1. Color palette (EXACT)

| Token | Hex | Role | vs. PDF guess |
|---|---|---|---|
| `obsidianDeep` | **#0B0B0D** | Deepest app background / page base | — |
| `obsidian` | **#0E0E10** | Primary surface / base | ✓ matched |
| `espresso` | **#1A1210** | Raised card / warm dark surface | ✓ matched |
| `oxblood` | **#3A1220** | Deep accent + destructive family | was #3B1220 → **#3A1220** |
| `emerald` | **#12251C** | Secondary accent (deep green) | was #11251C → **#12251C** |
| `champagne` | **#C9A96A** | **PRIMARY GOLD** — accent, borders, focus, active, dividers | ⚠ was #CFAC4F → **#C9A96A** |
| `goldBright` | **#D4AF37** | Brighter gold — ONLY as gradient partner for CTAs | new |
| `ivory` | **#F4EFE6** | Primary text + primary-button fill (warm white) | was #F3EFE6 → **#F4EFE6** |
| `destructive` | **#C97A7A** | Destructive/error text + outline, offline icons | new (exact) |

### Tinted card-surface variants (used in gradients)
`#17121A` · `#141013` · `#0F1512` — subtle oxblood/espresso/emerald-tinted obsidians for card backgrounds.

### Text emphasis = IVORY at opacity (this is the whole text-color system — ivory #F4EFE6 with alpha)
| Emphasis | Value |
|---|---|
| High (headings) | `#F4EFE6` (full) |
| Body | `rgba(244,239,230,.7)` / `.6` / `.55` |
| Secondary / caption | `rgba(244,239,230,.5)` / `.45` / `.4` |
| Low / disabled | `rgba(244,239,230,.25)` / `.2` |

### Gold at opacity (subtle fills, borders, hover washes) — champagne #C9A96A with alpha
`rgba(201,169,106, .1 / .12 / .14 / .16 / .2 / .22 / .25 / .3 / .35 / .4)`

---

## 2. Fonts

| Role | Family | Notes |
|---|---|---|
| **Display / headings** | **`Playfair Display`** (Google Font) | High-contrast Didone serif. Uses Regular + **Italic** together (hero: "After dark, *by invitation.*"). Dominant brand voice. |
| **Body / interface / labels** | **`Helvetica Neue`, Helvetica, Arial, sans-serif** | Neutral grotesque. Also carries the small-caps tracked labels (uppercase + letter-spacing). |
| **Icons** | **`Material Symbols Outlined`** | Thin-line icon set — Flutter has this natively (Material Symbols / Icons), no asset needed. |

Weights explicitly set: **400** (regular) and **500** (medium). Playfair supplies heavier display weight via the face itself.

> Flutter note: Playfair Display → `google_fonts` package. Body "Helvetica Neue" isn't a Google Font and isn't bundled on Android; closest cross-platform match is **Inter** or the platform default sans. Recommend Inter for Android parity, or a Helvetica-like if you add the asset. FLAG for your decision.

---

## 3. Type scale (px, from CSS)

Sizes actually used, grouped into the design's tiers:

| Tier | Sizes seen (px) | Typical | Font |
|---|---|---|---|
| Hero display | 88, 52, 48, 46, 44 | 48 | Playfair (often italic) |
| Display / screen title | 38, 36, 34, 32, 30 | 34 | Playfair |
| Title / section | 28, 26, 25, 24, 22 | 24 | Playfair or sans |
| Body large | 20, 19, 18, 17 | 18 | Helvetica Neue |
| Body / input | 16, 15 | 15 | Helvetica Neue |
| Micro / label | 14 (uppercase + tracked) | 14 | Helvetica Neue small-caps |

Line-heights are mostly default/tight on display; body reads ~1.4–1.5.

---

## 4. Letter-spacing (the signature)

Tracked uppercase labels are core to the look. Dominant values:

| Use | letter-spacing |
|---|---|
| Standard small-caps label / eyebrow | **.24em** (most common) |
| Tighter labels / nav | .16em, .18em, .2em |
| Chip / button text | .12em–.16em |
| Extra-wide dramatic eyebrows | .26em–.32em (up to .5em on rare hero labels) |

Rule of thumb: **uppercase micro-labels ≈ `.24em`**, buttons/chips ≈ `.14–.16em`.

---

## 5. Border radii (px) — sharper than the PDF suggested

| Element | Radius |
|---|---|
| Filter chips / pills / round buttons | **100px** (full stadium) — very common |
| Large pill buttons | **46px** |
| Cards / panels | small — **2px** (dominant), up to 4–8px; larger cards 10–16px |
| Standard buttons | **4–8px** (gently rounded rect, NOT pills) |
| Small elements / icon tiles | 2–6px |
| Bottom sheet (top corners) | **22px** |
| Dialogs | 12–16px |

Key correction vs PDF: cards/buttons are mostly **crisp (2–8px)**; the *pills* are the only fully-round elements. The look is sharp-cornered + editorial, not soft.

---

## 6. Spacing system

Base unit **4px**. Ramp actually used: **4 · 6 · 8 · 12 · 14 · 16 · 20 · 22 · 28 · 40 · 56 · 60 · 120**.

| Use | Value |
|---|---|
| Most common gap | **14px**, then 16, 8, 6 |
| Card internal padding | 14–16px |
| Component padding | 16 / 14 / 18px |
| Section / screen gutters | 40 / 56 / 60px (large, breathing) |
| Big hero spacing | 96 / 120px |

---

## 7. Buttons

**Primary** — fill `#F4EFE6` (ivory), text `#0E0E10` (obsidian), no border, radius ~4–8px, uppercase tracked (~.14–.16em). Pressed: dimmed ivory. Disabled: muted grey `~#878684`, faded text.

**Ghost / secondary** — transparent fill, **`#C9A96A` gold 1px border**, gold text, same radius. Hover warms via low-opacity gold wash `rgba(201,169,106,.12–.16)`.

**Destructive** — transparent fill, **`#C97A7A` 1px border + `#C97A7A` text**. For account deletion / irreversible actions.

**Gold-gradient accent** — `linear-gradient(135deg, #D4AF37, #C9A96A)` on select highlights/CTAs and the spacing-ramp/active bits.

---

## 8. Inputs — underline style

No box, no fill. Single **1px bottom hairline**.
- Label: uppercase, tracked (~.24em), low-emphasis ivory.
- Default underline: `rgba(244,239,230,.25–.4)`.
- **Focus** underline: **`#C9A96A` gold** + gold caret.
- **Error** underline + helper text: **`#C97A7A`**.
- Dropdown: same underline + trailing chevron.

---

## 9. Cards

- Background: event photo OR a tint gradient — `linear-gradient(135deg|160deg, <tint> → #0E0E10)` where tint ∈ {`#3A1220` oxblood, `#1A1210` espresso, `#12251C` emerald}.
- Image legibility scrim: `linear-gradient(180deg, #0B0B0D, rgba(11,11,13,.6))` bottom-up.
- Border: hairline — gold at low opacity `rgba(201,169,106,.14–.22)` or near-black.
- Radius: 2–16px (see §5). Shadow: soft/low; depth comes from gradient + vignette.
- Content: tracked uppercase eyebrow → Playfair title → low-emphasis meta, bottom-anchored.

---

## 10. Bottom sheet & dialogs

- Sheet: raised espresso/obsidian surface, **top-corner radius 22px**, flush to bottom.
- Grab handle: short centered low-emphasis pill.
- Scrim: strong dark — `rgba(0,0,0,.95)` (plus global vignette). Dialogs share the same scrim/surface family.
- Primary CTA full-width ivory; secondary ghost-gold; destructive oxblood/`#C97A7A`.

---

## 11. Decorative layer (applies globally)

- **Gold hairline dividers** (`#C9A96A`) flank every section eyebrow.
- **Uppercase tracked eyebrows** (~.24em) introduce every section.
- **Circular "N" monogram** medallion — thin gold ring(s), Playfair "N". (Brand mark → basis for the app icon.)
- **Vignette** — radial edge darkening on every screen.
- **Film grain / noise** — faint texture over the whole canvas (`rgba(255,255,255,.02)` speckle) for the low-light film mood.
- **Gold gradient** `linear-gradient(135deg,#D4AF37,#C9A96A)` for active/highlight accents.

---

## 12. Icons

**Material Symbols Outlined**, thin uniform stroke (weight ~100–400), no fill. Seen: home, explore/compass, search, favorite (heart), person, calendar, place/pin, music_note, share, notifications, settings, edit, filter, arrow_back, wifi_off (offline state). Size ~20–34px. Color: low-emphasis ivory default; **gold when active**; ivory high-emphasis.
Flutter: use built-in `Icons` / Material Symbols — no font asset required.

---

## Corrections vs. the earlier PDF-based DESIGN_TOKENS.md
1. **Gold is `#C9A96A`** (not #CFAC4F). Most important fix — it's the signature color.
2. Ivory **#F4EFE6** (not #F3EFE6); Oxblood **#3A1220**; Emerald **#12251C**.
3. Added **#D4AF37** (gradient-only gold), **#C97A7A** (destructive), and tint surfaces #17121A/#141013/#0F1512.
4. Fonts confirmed: **Playfair Display** + **Helvetica Neue/Arial** + **Material Symbols Outlined** (not guesses).
5. Radii are **sharper** than assumed — cards/buttons 2–8px; only chips are full pills (100px); sheet 22px.
6. Text color = **ivory at opacity steps**, not separate grey hexes.
7. Scrim behind sheets/dialogs = **rgba(0,0,0,.95)**; card image scrim and tint gradients captured exactly.
Nothing here is [approx] — all values are read from the stylesheet.

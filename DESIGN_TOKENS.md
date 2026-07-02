# Nocturne — Design Tokens

Extracted from `design-reference.pdf/NL-design.pdf` — the "Nocturne" product design system & screen library ("After dark, by invitation." / **42 screens · 03 roles · 01 language**). Dark-first, luxury Art Deco aesthetic for the nightlife app.

> **How these were extracted.** The PDF is a **flattened, image-only** export (no selectable text; `pdftotext` returns nothing). It is **2 letter-size pages**, each a single tall column: page 1 = the design-language spec (this doc's source), page 2 = the 42 screens grouped as Auth & Onboarding · Member · Promoter · Club/Venue Admin · System & Edge States. All values below were read from high-DPI renders (900–1800 dpi) of page 1, and **the six palette colors were sampled pixel-by-pixel from the swatch rectangles** (authoritative).
>
> **Confidence markers.** `[sampled]` = read directly from swatch pixels (exact). `[read]` = legible in a high-DPI crop. `[approx — VERIFY]` = the underlying label is below the source's legibility floor (the smallest captions are ~2–4 px tall even at 1800 dpi); the **structure** is certain but the **exact number** must be confirmed against the original design source before it's treated as final. Nothing here is invented — where a precise number couldn't be resolved, it is marked, not guessed.

---

## 1. Color palette

Header on the palette panel: **"COLOUR · DARK-FIRST"**. Six named swatches, left→right, each with a name + role caption.

| Token | Name | Hex `[sampled]` | RGB | Role (caption, `[approx — VERIFY]`) |
|---|---|---|---|---|
| `obsidian` | Obsidian | **#0E0E10** | 14,14,16 | Base / app background (darkest) |
| `espresso` | Espresso | **#1A1210** | 26,18,16 | Surface / raised card (dark brown) |
| `oxblood` | Oxblood | **#3B1220** | 59,18,32 | Deep accent / destructive (maroon) |
| `emerald` | Emerald | **#11251C** | 17,37,28 | Secondary accent (deep green) |
| `champagne` | Champagne | **#CFAC4F** | 207,172,79 | Primary accent / gold (the signature color) |
| `ivory` | Ivory | **#F3EFE6** | 243,239,230 | Primary text / primary-button fill (warm white) |

### Derived / supporting values `[read/sampled]`
| Purpose | Value | Notes |
|---|---|---|
| App background (deepest) | `#0B0B0D` – `#0E0E10` | Obsidian; panels sit ~1–3 pts lighter than the page. |
| Card / panel surface | ~`#0E0E10` – `#141216` | Espresso-tinted obsidian; hairline gold/near-black border. |
| Primary button fill (default) | **#F3EFE6 (Ivory)** | Ivory fill, obsidian text. |
| Primary button fill (pressed) | **#F0ECE5** `[sampled]` | Slightly dimmed ivory. |
| Disabled fill | **#878684** `[sampled]` | Muted warm grey, faded text. |
| Gold accent (borders, focus, active) | **#CFAC4F (Champagne)** | Also used for gradients, dividers, active nav. |
| Destructive | **Oxblood #3B1220** family | Outline + red text on "Delete account", error underline. |
| Text — high emphasis | **Ivory #F3EFE6** | Headings, body on dark. |
| Text — low emphasis / captions | ~`#8A8580` – `#B1ADA9` | Warm grey small-caps labels. |
| Overlay / scrim (behind sheets/dialogs) | translucent obsidian, ~`rgba(11,11,13,0.6–0.8)` `[approx — VERIFY]` | Dark scrim + vignette. |

### Gradients `[read]`
- **Gold gradient** — champagne → lighter champagne, used on primary CTAs / accents (the spacing-ramp squares and icon accents render in this gold).
- **Card image gradients** — event cards use a **bottom-up dark gradient** (obsidian → transparent) over the photo so the small-caps title/label sits legibly at the bottom. Card variants seen: warm/oxblood-tinted, emerald-tinted, and neutral obsidian.
- **Vignette + film grain** — the entire canvas carries a subtle radial vignette (darker edges) and a fine film-grain/noise texture. This is an intentional decorative layer, present on every surface (see §11).

---

## 2. Fonts & weights

Panel: **"TYPOGRAPHY"** with a large **"Display Aa"** specimen; right panel **"SCALE · SPACING · RADIO"**.

| Role | Family character `[read]` | Weight | Notes |
|---|---|---|---|
| **Display / headings** | High-contrast **serif** (Didone/"Platform Display"–style; thin hairlines, strong stress). Caption reads ~"PLATFORM DISPLAY · HIGH-CONTRAST SERIF". | Regular + *Italic* | Hero uses roman + italic together ("After dark, *by invitation.*"). This is the editorial luxury serif. |
| **Body / interface** | Refined **grotesque sans** ("a refined grotesque, tuned for calm reading in low light"). | Regular / Medium | Body copy, inputs, list content. |
| **Labels / micro** | The grotesque set in **small-caps with wide letter-spacing** ("SMALL-CAPS MICRO-LABELS · SIGNATURE"; e.g. "MEMBERS ONLY · TONIGHT"). | Medium/Bold, tracked | Section eyebrows, chip text, button text, nav labels — the signature label style. |

> Specific font family names are not printed legibly in the file. Substitute a Didone-class serif for Display (e.g. a Playfair Display / high-contrast serif) and a neutral grotesque for body (e.g. an Inter/Söhne-class sans) unless the original source names them — `[approx — VERIFY]`.

---

## 3. Type scale

Right panel shows a 4-tier "Aa" ramp (serif for Display, grotesque below), each with a px/leading caption. The **tiers are certain; the exact px are `[approx — VERIFY]`** (captions are the smallest text in the file).

| Level | Style | Size `[approx — VERIFY]` | Line height | Letter-spacing | Usage |
|---|---|---|---|---|---|
| **Display** | Serif, high-contrast | ~28–36 px | tight (~1.05–1.1) | ~0 (slightly negative on large) | Hero / screen titles |
| **Title** | Serif or grotesque | ~20–24 px | ~1.2 | ~0 | Section / card titles |
| **Body** | Grotesque | ~14–16 px | ~1.4–1.5 ("calm reading in low light") | ~0 | Paragraphs, inputs, list text |
| **Micro / label** | Grotesque, **small-caps, tracked** | ~10–12 px | ~1.2 | **wide, ~0.12–0.18em** | Eyebrows, chips, buttons, nav labels |

The ramp caption appears to read like "Display / Title / Body / Micro · tracked" with numeric sizes beside each; treat the numbers above as the intended relationship and confirm exact values before finalizing.

---

## 4. Border radii

Radius chips ("RADIO" row) show **three rounded-square samples** (small → slightly larger) plus fully-round pills elsewhere.

| Element | Radius `[approx — VERIFY]` | Evidence |
|---|---|---|
| Cards / panels | ~10–14 px (soft rounded rect) | Event cards, spec panels. |
| Buttons (primary/ghost/destructive) | ~6–10 px (gently rounded rect) | Reserve/Get Directions/Delete are rounded rectangles, **not** pills. |
| Inputs | effectively 0 (underline only — no box) | See §7. |
| **Filter chips** | **full pill** (`radius = height/2`) | Chips are fully rounded stadiums. |
| Bottom sheet | large top-corner radius (~16–20 px), top corners only | See §10. |
| Dialogs | ~12–16 px `[approx — VERIFY]` | Consistent with card family. |
| Icon buttons / small containers | ~6–8 px | Nav/icon tiles. |

The three radius chips imply a small ramp (e.g. ~`sm 6` / `md 10` / `lg 14`) — `[approx — VERIFY]`.

---

## 5. Spacing system

The "SPACING" ramp is a row of **4 gold squares increasing in size** (a modular step scale). Exact px are `[approx — VERIFY]`, but the intent is a consistent multiplier ramp.

- **Base unit:** ~4 px, stepping ~**4 · 8 · 12 · 16 · 24 · 32** (4 visible ramp steps → extend by the same ratio). `[approx — VERIFY]`
- **Screen edge padding:** generous horizontal gutters (~16–20 px) — screens breathe, content is centered in a narrow column.
- **Section spacing:** large vertical rhythm between sections, each introduced by a tracked small-caps eyebrow + gold hairline (see §11).
- **Card internal padding:** ~16 px; label/title stack sits with small (~4–6 px) gaps.
- **Component gaps:** chips/buttons separated by ~8–12 px.

---

## 6. Button anatomy

Panel "BUTTONS" shows three families across states. Text is **small-caps, tracked, `[read]`**.

### Primary (`RESERVE`)
| State | Fill | Text | Border | Shape |
|---|---|---|---|---|
| Default | **Ivory #F3EFE6** | Obsidian #0E0E10 | none | rounded rect (~6–10 px) |
| Pressed | **#F0ECE5** (dimmed ivory) | Obsidian | none | same |
| Disabled | **#878684** (muted grey) | faded ivory/grey | none | same |

Caption: "Primary · ivory · small caps". Padding ~ vertical 12–14 / horizontal 20–24 `[approx — VERIFY]`.

### Ghost / secondary (`GET DIRECTIONS`, `HOVER`)
- **Transparent fill**, **champagne/gold outline** (~1 px), **gold text**. On hover the outline/fill warms slightly toward champagne. Caption: "Ghost · gold outline". Same rounded-rect radius.

### Destructive (`DELETE ACCOUNT`)
- **Transparent fill**, **oxblood/red outline**, **red/oxblood text**. Caption: "Destructive". Same radius. Reserved for account deletion and other irreversible actions.

---

## 7. Input fields

Panel "INPUTS · UNDERLINE STYLE" — inputs are **underline-only** (a single bottom border), never boxed/outlined.

| Part | Treatment `[read]` |
|---|---|
| Container | No box, no fill — just a **1 px bottom hairline**. |
| Label | Small-caps, tracked, low-emphasis (e.g. "EMAIL", "PASSWORD · FOCUSED", "PHONE · ERROR", "GENDER · DROPDOWN") sitting above the value. |
| Value text | Ivory grotesque (e.g. `guest@nocturne.club`, `+1 555…`). |
| Default underline | Faint warm-grey / low-emphasis hairline. |
| **Focus** underline | **Champagne/gold** hairline + visible caret (the "PASSWORD · FOCUSED" row shows a gold underline). |
| **Error** underline | **Oxblood/red** hairline + red helper text ("Enter a complete number"). |
| Dropdown | Same underline style with a trailing chevron (`Female ⌄`). |

---

## 8. Card treatments

Panel "EVENT CARD · STATES" — image-led cards.

- **Background:** full-bleed event photo with a **bottom-up dark gradient** (obsidian → transparent) for text legibility. Variants: warm/oxblood-tinted, emerald-tinted, neutral obsidian, and a text-only/placeholder card (e.g. "Blue Serpent").
- **Border:** subtle hairline (near-black or faint gold) around the rounded rect.
- **Shadow:** soft, low — depth comes from the dark gradient + vignette more than a drop shadow.
- **Corner radius:** ~10–14 px `[approx — VERIFY]`.
- **Internal content:** small-caps tracked eyebrow (e.g. "TONIGHT · TECHNO"), then a serif/grotesque title, then a low-emphasis meta line — anchored bottom-left over the gradient.
- **Internal padding:** ~16 px `[approx — VERIFY]`.

---

## 9. Navigation

Panel "NAV · TAB BAR" — a **bottom navigation bar** with 4 destinations `[read]`: **Home · Explore · Saved (heart) · Profile** (icons + small-caps tracked labels).

| State | Treatment |
|---|---|
| Active | **Champagne/gold** icon + label (and/or a gold indicator); ivory-bright. |
| Inactive | Low-emphasis warm grey. |
| Bar background | Obsidian, with a top gold **hairline** separating it from content. |
| Indicator | Minimal — color shift to gold rather than a filled pill; possibly a small gold underline/dot `[approx — VERIFY]`. |

Tabs/segmented controls elsewhere follow the same active=gold / inactive=grey logic. A drawer is implied by the app's menu structure but its exact styling isn't isolated on page 1 — `[approx — VERIFY]` from page 2 screens.

---

## 10. Bottom sheet & dialogs

Panel "BOTTOM SHEET" — example "Confirm your place" with a **"CONFIRM RSVP"** primary (ivory) button.

- **Container:** raised obsidian/espresso surface with **large top-corner radius** (~16–20 px), top corners only, flush to screen bottom.
- **Grab handle:** short centered pill handle at the top (low-emphasis grey) `[read]`.
- **Overlay/scrim:** dark translucent obsidian behind the sheet (~0.6–0.8 opacity) plus the global vignette `[approx — VERIFY]`.
- **Content:** serif title + body copy + small-caps meta ("Entry is complimentary — settle at the door. Doors close at midnight."), primary CTA full-width ivory button.
- **Dialogs:** same surface/radius/scrim family, centered; primary=ivory, secondary=ghost gold, destructive=oxblood.

---

## 11. Decorative elements

- **Gold hairline dividers:** thin **champagne (#CFAC4F)** rules flank every section eyebrow (e.g. `——— The Design Language ———`) and separate content bands. Signature motif.
- **Small-caps tracked eyebrows:** every section is introduced by a wide-tracked small-caps label (e.g. "01 · FOUNDATIONS", "COLOUR · DARK-FIRST").
- **Art Deco geometry:** the brand mark is a circular **"N" monogram** medallion (top-left), thin-line geometric framing; overall vertical, symmetrical, editorial layout.
- **Vignette:** radial darkening at the edges of every screen.
- **Film grain / noise:** a fine grain texture over the whole canvas (visible as speckle in flat dark areas) — deliberate, gives the "low-light film" mood.
- **Gold gradient accents:** used on the spacing-ramp squares, active states, and CTA highlights.

---

## 12. Icon style

Panel "ICONOGRAPHY · THIN LINE" — a set of **thin, single-weight line icons** `[read]`.

- **Style:** outline / line icons, **thin uniform stroke** (~1.5 px at display size), rounded joins, no fills.
- **Set seen (2 rows):** home, compass/explore, search, heart, person, calendar; pin, music note, "×N"/badge, share, bell, gear; plus edit, filter, back/arrow, etc.
- **Size:** ~20–24 px in nav/actions `[approx — VERIFY]`.
- **Color:** low-emphasis warm grey by default; **champagne/gold** when active/selected; ivory for high emphasis.

---

## Open items to confirm against the original design source `[approx — VERIFY]`
1. Exact **type-scale px sizes / line-heights / tracking** (§3) — captions are sub-legible in the flattened PDF.
2. Exact **radius values** for the 3 radius chips and the sheet/dialog corners (§4).
3. Exact **spacing ramp px** (§5).
4. **Font family names** for the display serif and body grotesque (§2).
5. **Scrim opacity** and any blur behind sheets/dialogs (§10).
6. Precise **role captions** under each color swatch (base/surface/accent/text mapping in §1) and any additional semantic colors not shown on page 1.
7. Nav **active indicator** exact form (color-only vs underline/dot) (§9).

The six core palette hexes (§1) are pixel-exact; everything marked `[read]` is directly legible; only the small-caption numerics are deferred above.

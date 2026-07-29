# Claude Design MCP — Extraction Record

Source of truth for the Siyaq visual adoption. Every value below was read from
the design project through the MCP, not inferred from a screenshot.

## Inspection result

| | |
|---|---|
| Tool | `DesignSync` (reads `claude.ai/design` projects; auth via the claude.ai login / `/design-login`) |
| Project | `a17d4dc4-2b62-41a6-a8c4-bcbc17a8f327` — **"Design system confirmation"**, `type: PROJECT_TYPE_PROJECT`, `canEdit: true` |
| Auth | **Succeeded** — no OAuth prompt required |
| Date | 2026-07-30 |

There is no MCP registered at `https://api.anthropic.com/v1/design/mcp` in this
environment. `DesignSync` is the design-project reader that is installed, and its
documented auth path is the `/design-login` the brief names, so it is the correct
tool. Note the project's own name is *"Design system confirmation"*, not *"Siyaq
Prototype"* — the prototype is a file inside it.

### Files read

- `_ds/organic-…/readme.md` — written design guidance
- `_ds/organic-…/_ds_manifest.json` — **46 machine-readable tokens**
- `Siyaq Prototype.dc.html` — 80,779 chars; the Siyaq screens

### Files present but not yet read

`Siyaq Design System.dc.html`, `Siyaq Explorations.dc.html`, `Siyaq Game
Variants.dc.html`, `Siyaq Prototype (offline).html`, `Siyaq Prototype
standalone-src.dc.html`, `_ds_bundle.js`, `styles.css`, `support.js`,
`_adherence.oxlintrc.json`, `screenshots/game.png`.

`Siyaq Game Variants.dc.html` is likely to matter for Orbit and should be read
before Orbit is implemented.

## Foundations — Organic design system

Warm, rounded, tactile. A cream-and-sand ground, terracotta accent, sage second
accent. Explicitly **not** generic Material.

### Role colors

| Token | Value |
|---|---|
| `--color-bg` | `#f5ead8` |
| `--color-surface` | `#ebddc5` |
| `--color-text` | `#201e1d` |
| `--color-accent` | `#c67139` (terracotta) |
| `--color-accent-2` | `#7a8a5e` (sage) |
| `--color-divider` | `#201e1d` @ 16% |

### Tonal ramps

Generated in OKLCH on a shared perceptual lightness scale, so the same step of
any ramp carries the same visual weight. Light steps (100–300) for tinted fills,
hovers and subtle borders; 500 as base; dark steps (700–900) for text on tinted
fills and pressed states. Ramp steps are preferred over ad-hoc `color-mix()`.

| Step | neutral | accent | accent-2 |
|---|---|---|---|
| 100 | `#f9f4ed` | `#fff2eb` | `#f0fae1` |
| 200 | `#eee7db` | `#ffe1d0` | `#e1eecc` |
| 300 | `#dcd3c4` | `#ffc6a5` | `#ccdbb2` |
| 400 | `#c0b6a5` | `#f6a06b` | `#aebf92` |
| 500 | `#a19786` | `#d67f48` | `#8fa073` |
| 600 | `#82796a` | `#b2622d` | `#728157` |
| 700 | `#645c50` | `#8c491a` | `#56633f` |
| 800 | `#474238` | `#643312` | `#3d472b` |
| 900 | `#2e2b25` | `#402310` | `#272e1b` |

### Type, spacing, radii, elevation

- `--font-heading`: `Caprasimo` @ weight 400 · `--font-body`: `Figtree`
- Spacing (1.10× density): `4.4 / 8.8 / 13.2 / 17.6 / 26.4 / 35.2` px (steps 1,2,3,4,6,8)
- Radii: `sm 8px` · `md 16px` · `lg 28px` · pills `999px`
- Shadows (tuned to the light ground, base `#2e2b25`):
  `sm 0 1px 2px @14%` · `md 0 3px 10px @16%` · `lg 0 12px 32px @22%`
- Icons: **Lucide**, stroke-width **2.75**

### Stated accessibility constraint

> "The accent-to-ground pair is tuned to at least 3:1 — enough for icons, large
> text and interface chrome, not for body copy — so for paragraph-size text in
> the accent use a deep ramp step (`--color-accent-700`) rather than the accent."

This is binding: `--color-accent` may not carry body text. Interaction states are
themed, never browser defaults — focus is `2px solid var(--color-accent)` with
`2px` offset; disabled drops to 45% opacity.

## Siyaq semantic layer (`--sy-*`)

The prototype layers its own semantic tokens on Organic, and defines **two
complete themes**. Both values appear for every token; the Arabic/dark variant
also swaps the type stack.

| Token | Light | Dark |
|---|---|---|
| `--sy-bg` | `--color-bg` `#f5ead8` | `#1c1713` |
| `--sy-surface` | `#fffaf1` | `#2a231c` |
| `--sy-text` | `--color-text` `#201e1d` | `#f2e7d6` |
| `--sy-muted` | `--color-neutral-600` | `#a19786` |
| `--sy-line` | `--color-neutral-300` | `#3d342a` |
| `--sy-gold` | `#d9a441` | `#e8b559` |
| `--sy-hot` | `#3a2b20` | `#f7e3d3` |
| `--sy-indicator` | `#3a342c` | `#5a5046` |
| `--sy-kb` (keyboard) | `#d6cbb8` | `#241e18` |
| `--sy-display` | `Caprasimo` | **`Baloo Bhaijaan 2`** |
| `--sy-body` | `Figtree` | **`Tajawal`** |
| `--sy-e1/e2` | `shadow-sm` / `shadow-md` | `0 1px 3px @.4` / `0 4px 16px @.45` |
| `--sy-e3` (sheet) | `0 -10px 34px rgba(46,43,37,.22)` | `0 -10px 40px rgba(0,0,0,.5)` |

The app frame background is `#e8dcc6` — a shade darker than `--color-bg`.

**Arabic typography is solved by the design itself.** `Baloo Bhaijaan 2` (500,
700) and `Tajawal` (400, 500, 700) are Arabic-supporting faces, loaded alongside
Caprasimo and Figtree. Caprasimo and Figtree are Latin-only, so the display/body
pair must switch by script — which mirrors what the app already does for
IBM Plex Sans Arabic / Inter. No substitution guesswork is required.

## Proximity ramp — the Orbit visual mapping

Five semantic tiers, far → closest. This is the authoritative source for Phase
10/13 colour mapping.

| Tier | Light | Dark | Reads as |
|---|---|---|---|
| `--sy-p1` | `--color-neutral-600` | `--color-neutral-400` | far — neutral, cool |
| `--sy-p2` | `--color-accent-2-400` | `--color-accent-2-300` | sage |
| `--sy-p3` | `--color-accent-2-500` | `--color-accent-2-300` | deeper sage |
| `--sy-p4` | `--color-accent-400` | `--color-accent` | terracotta warming |
| `--sy-p5` | `#e2704a` | `#a33f22` | closest — strongest accent |

Colour alone is never sufficient (brief Phase 13): tier must also drive position,
line weight, scale and the accessible label.

## Motion

Two easings only:

| Name | Curve | Used for |
|---|---|---|
| standard | `cubic-bezier(.22, .9, .24, 1)` | sheets, rise, tie, hearts (8 uses) |
| expressive | `cubic-bezier(.16, 1, .3, 1)` | word travel, pop, splash, ring flash (5 uses) |

| Duration | Keyframe / property | Purpose |
|---|---|---|
| 180ms | `width`, `all` | micro state change |
| 280ms | `sy-rise` (translateY 14px + fade), `sy-sheet` (translateY 100%) | entrance, bottom sheet |
| **420ms** | `sy-tie` | **Orbit: connecting line growth** |
| **820ms** | `transform` | **Orbit: word travel to radial position** |
| 900ms | `sy-pop` (.86 → 1.04 → 1), `sy-splash`, `sy-heart-a/b` | arrival, splash, celebration |
| 2600ms | `sy-ringflash` (r 30 → …, opacity 0 → .5 → 0) | target ring flash |
| 2.4s | `sy-spin` linear infinite | pending spinner |
| 3.0–3.4s | `sy-shimmer` (opacity .2 ↔ .55) | ambient shimmer |
| 5.5s | `sy-breathe` (scale 1 ↔ 1.05) | central target breathing |

Ambient loops (`breathe`, `shimmer`, `spin`) must be suppressed under reduced
motion and on low-end devices — they are continuous repaint sources.

## Screens in the prototype

`splash` · `onb` (onboarding) · `home` · `game` (Orbit) · `victory` · `defeat` ·
`profile`

## Token → Flutter mapping

Implemented in `lib/core/design/organic/` as an **additive** layer. The existing
Siyaq design system is untouched, so nothing regresses while adoption proceeds
screen by screen (brief Phase 22).

| Design | Flutter |
|---|---|
| `--color-*` roles + 3 ramps | `OrganicPalette` (const `Color`s) |
| `--sy-*` semantic, both themes | `OrganicColors.light` / `.dark` `ThemeExtension` |
| `--sy-p1…p5` | `OrganicColors.proximity` (`List<Color>`, far → closest) |
| `--space-*` | `OrganicSpacing` (4.4 … 35.2, rounded to .4 exactly as authored) |
| `--radius-*` + pill | `OrganicRadius` (8/16/28/999) |
| `--shadow-*`, `--sy-e3` | `OrganicElevation` (`List<BoxShadow>`) |
| `--sy-display` / `--sy-body` | `OrganicType.forScript()` — Caprasimo/Figtree vs Baloo Bhaijaan 2/Tajawal |
| easings + durations | `OrganicMotion` (2 curves, 9 durations, ambient set flagged) |
| Lucide @ 2.75 | documented; icon package decision still open |

## Open items

1. **Fonts are not in the repo.** Caprasimo, Figtree, Baloo Bhaijaan 2 and
   Tajawal are all Google Fonts and none are bundled. Adoption needs the four
   families added to `assets/fonts/` and `pubspec.yaml`. Current bundle already
   carries IBM Plex Sans Arabic, Inter, Noto Naskh Arabic and DM Mono, so this is
   a real size decision, not a formality.
2. **Lucide icons** at stroke-width 2.75 have no exact Flutter equivalent in the
   current icon set (Material rounded). Needs either a Lucide package or accepting
   a documented deviation.
3. `Siyaq Game Variants.dc.html` and `styles.css` should be read before Orbit
   layout work — the variants file probably fixes the radial geometry.
4. The prototype's `--color-accent` on `--sy-bg` is 3:1. Any body copy in accent
   must use `--color-accent-700`, per the system's own instruction.

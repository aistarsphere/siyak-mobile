# Siyaq — Figma ↔ Flutter UI Migration Audit

**Audit date:** 2026-07-26
**Figma file:** `Siyak` — `https://www.figma.com/design/WtIvrdnZFHCI8Gy4xaO5re/Siyak`
**Flutter repo:** `ContextGpt` @ `main` (7545201)
**Access method:** Figma Dev Mode MCP server (`127.0.0.1:3845/mcp`), read-only
**Scope:** Audit and planning only. **No application code was modified.**

---

## 1. Executive summary

The Flutter application and the new Figma design system are **both internally coherent, and almost entirely incompatible with each other**. This is not a recolouring job.

Three findings dominate everything else:

**1. The Figma "design system" is a picture of a design system, not a token-driven one.**
The Foundations page documents 25 semantic tokens across Light and Dark, a 4px spacing grid, a 9-step radius scale and a 12-style type ramp. None of it is bound. `get_variable_defs` returns `{}` for the Foundations page, for the Semantic Color Tokens frame, for the Primitive Palette, for Typography, for Spacing and for Corner Radius. Across the eight component sets inspected in depth there are **7 variable bindings against 66 raw hex values**, and only **10 distinct variables resolve anywhere in the file**. The cover page claims *"193 design tokens · 5 variable collections · 350+ variable bindings"*; the component and variant counts on that same page (34 sets / 149 variants) are **exactly correct**, which makes the token claims the outlier rather than a rounding error. Practically: **the approved components cannot auto-switch Light↔Dark**, because their fills are hardcoded dark hexes. Light-theme designs exist only as flat posters on the **Archive** page and as validation mockups — neither of which your brief treats as approved source.

**2. The Flutter theme layer is better than expected, but built on a static global that blocks the required deliverable.**
`AppTokens` is a proper `ThemeExtension` with complete Light and Dark palettes; `ThemeMode.system` works and is persisted; `flutter analyze` reports **no issues**; and the raw-hex discipline is genuinely good (**5 raw colour literals in the whole UI layer**). But 25 of ~30 UI files consume colour through `SC`, a **mutable static** (`static AppTokens _t`) reassigned once per `SiyagApp.build`. Because `SC` is global rather than `BuildContext`-resolved, **two brightnesses cannot exist in one widget tree**. That makes the Component Gallery you require — Light and Dark side by side — impossible to build without refactoring `SC` first. This single constraint should set the order of the whole migration.

**3. The visual identities are unrelated, and the gameplay component you most need does not exist.**
The app is graphite/gold (`#17191E` canvas, `#DDB75F` gold). The Figma system is warm stone with a saffron/amber primary (`#faf8f5` canvas, `#d97706` action). Typography diverges too: Figma specifies **Inter** for both scripts — Inter has no Arabic glyphs — while the app bundles Plus Jakarta Sans, Noto Naskh Arabic and DM Mono. And the approved `Siyaq/Guess Card` is documented as *"Latest, Previous, Best, Improved, Worse, Correct"* but is actually built as six **distance bands**. **There is no Latest variant and no Best variant** — precisely the two states the planned gameplay screen is built around. The validation mockups don't use the approved Guess Card at all.

Alongside these, the audit found a genuine accessibility defect in the Figma system: the Destructive button places `text/primary` `#1c1917` on `#be123c`, a measured **2.78:1** — failing WCAG AA even at large-text thresholds, on a page whose own Foundations text promises AA compliance.

**Recommended posture:** treat the Figma file as an approved *visual direction* that is **not yet an implementable specification**. Close the token and gameplay-component gaps in Figma (Section 22) while building the Flutter token layer and gallery in parallel (Section 23). Do not begin screen migration until the gallery renders both themes.

---

## 2. Figma sources inspected

All 15 pages of the `Siyak` file were enumerated and read. Page IDs are the file's own canvas nodes.

| # | Page | Node | Status per brief | What was extracted |
|---|---|---|---|---|
| 1 | Cover & Documentation | `18:2` | Documentation | System-overview claims, token architecture statement |
| 2 | Foundations | `18:3` | **Approved** | Full token model, type ramp, spacing, radii, elevation, a11y rules |
| 3 | Buttons & Actions | `18:4` | **Approved** | `Siyaq/Button` (12), `Siyaq/Divider` (2) + design context |
| 4 | Inputs & Controls | `18:5` | **Approved** | Text Input (5), Word Guess Input (6), Switch (3), Checkbox (3), Search (3), Category Chip (3) |
| 5 | Navigation | `18:6` | **Approved** | Nav Item (8), Top App Bar (3), Tab Bar (4), Segmented Control (3) |
| 6 | Cards & Content Surfaces | `18:7` | **Approved** | Game Mode Card (5), Mode Badge (5), Notification Card (4) |
| 7 | Guess & Semantic Distance | `18:8` | **Approved** | Guess Card (6), Distance Label (6) + design context |
| 8 | Multiplayer Components | `18:9` | **Approved** | Room Card (3), Player Row (5), Player Avatar (8), Room Code Input (4) |
| 9 | Ranked & Leaderboard | `18:10` | **Approved** | Rank Badge (5), Leaderboard Row (5) |
| 10 | Profile, Progression & Achievements | `18:11` | **Approved** | Stat Card (6), Achievement Badge (3), Progress Bar (4) |
| 11 | Wallet & Rewards | `18:12` | **Approved** | Transaction Row (3), Wallet Balance (2) |
| 12 | Feedback & System States | `18:13` | **Approved** | Toast (4), Dialog (3), Bottom Sheet (3), Empty State (3), Loading Skeleton (3) |
| 13 | Settings Components | `18:14` | **Approved** | Settings Row (4) |
| 14 | Validation & Usage Examples | `18:15` | **Not approved** (reference only) | 8 full-screen mockups, dark+light × gameplay EN/AR, multiplayer, profile |
| 15 | Archive | `18:16` | **Not approved** | 8 legacy reference posters incl. *"Light Theme Components Reference"* |

**Depth of inspection.** `get_metadata` on all 15 pages; `get_variable_defs` on all 15 pages plus 9 individual nodes; `get_design_context` on 10 nodes (Semantic Color Tokens, Primitive Palette, and 8 component sets); `get_screenshot` on the dark-AR and light-EN gameplay validation frames.

**Note on the supplied URL.** The link provided (`?node-id=18-15`) points at **Validation & Usage Examples**, which your brief explicitly excludes from approved source. It was inspected as *reference*, and it proved valuable — but no component specification in this report is derived from it as authority.

---

## 3. Figma sources that could not be inspected

Reported precisely, with the reason. Nothing below was guessed.

| Item | Why it could not be inspected |
|---|---|
| **Variable collections and their modes** | The Dev Mode MCP server exposes only variables **bound to a queried node**. There is no API to enumerate collections, modes, or unbound variables. The cover's *"5 variable collections / 193 tokens"* can therefore be neither confirmed nor refuted — only the **10 distinct bound variables** are evidence. |
| **The 6 effect styles** (`Low/Medium/High`, `Glow/Saffron|Teal|Purple`) | Named on Foundations as labels only. MCP returns computed CSS shadows on instances, not the style definitions. Blur/spread/offset/opacity per elevation level are **unspecified**. |
| **Text-style definitions** (line-height, letter-spacing, weight mapping) | Foundations lists sizes and weight names as *text labels* (e.g. "Body/Large 16px Regular"). MCP returns `leading-[normal]` for every text node, so **no line-height or letter-spacing value exists** anywhere in the file. |
| **The 8 additional text styles** | Cover claims 20; Foundations enumerates 12. The other 8 are not present on any inspected page. |
| **Primitive ramp step values** | Six ramps are named (Neutral, Saffron, Teal, Purple, Crimson, Emerald) and rendered as swatches, but the individual steps carry **no name or numeric label**, so a `saffron/500`-style scale cannot be recovered. |
| **Motion / interaction specification** | No motion page exists and no component carries keyframes. `get_motion_context` was therefore not applicable. **The system specifies no durations, easings or transitions.** |
| **Archive page interiors** | Enumerated at top level only (8 posters, 240 KB of metadata — larger than all 11 approved pages combined). Deliberately not mined for specifications, per your brief. |
| **Component descriptions / published-library status** | Not exposed via MCP. Whether these component sets are published to a team library, and their versioning, is unknown. |

**Access history worth recording:** the MCP server reads whichever tab is focused in Figma desktop. The first probes failed (`No Figma window open`, then node lookups resolving against *"School Hassan — Mobile Design"*). No data from that unrelated file entered this audit; all findings date from after the `Siyak` tab became active and the page list resolved correctly.

---

## 4. Current Flutter theme assessment

**Files:** `lib/core/theme/` — `app_tokens.dart` (150), `app_theme.dart` (159), `siyag_theme.dart` (179), `app_colors.dart` (76, near-dead), `app_typography.dart` (83, **dead**), `app_motion.dart` (50).

### What is genuinely good

- **`AppTokens` is a correct `ThemeExtension<AppTokens>`** with 24 semantic roles and complete `light` and `dark` const instances. Registered via `ThemeData.extensions`. This is the right foundation and should survive the migration.
- **`AppTheme._build(AppTokens)`** derives one `ColorScheme` explicitly (no seed generation), and themes `appBar`, `card`, `dialog`, `bottomSheet`, `navigationBar`, `input`, `chip`, `switch`, `snackBar`, `progressIndicator`, `textSelection`, `pageTransitions`. Material widgets and custom screens share one palette.
- **Light / Dark / System all work.** `ThemeMode` is persisted in `SharedPreferences` (`siyaq.themeMode`), `ThemeMode.system` resolves through `MediaQuery.platformBrightnessOf(context)`, so OS changes rebuild correctly. There is a working three-way selector in the profile screen.
- **`flutter analyze` → "No issues found!"** The baseline is clean.
- **Raw-hex discipline is strong**: only **5** `Color(0x…)` literals in the entire UI layer.

### The structural defect: `SC` is a mutable static

```dart
class SC {
  static AppTokens _t = AppTokens.dark;                       // siyag_theme.dart:15
  static void applyBrightness(Brightness b) => _t = AppTokens.of(b);
  static Color get bg => _t.background;                        // …24 more getters
}
```

`SC.applyBrightness(effective)` is called once in `SiyagApp.build` (`app.dart:28`) before the subtree builds. It works today, and **25 files** depend on it. But it carries consequences that matter for exactly what you plan to do next:

| Consequence | Impact |
|---|---|
| **Two brightnesses cannot coexist in one tree** | **Blocks the required Component Gallery** (Light + Dark side by side) and any dual-theme golden test. |
| Colour is resolved outside the element tree | A widget rebuilt without `SiyagApp` above it (isolated tests, `showDialog` with its own theme, previews) silently renders the **last globally-set** palette. |
| No `dependOnInheritedWidgetOfExactType` | Flutter cannot invalidate colour-dependent widgets on theme change; correctness relies on `SiyagApp` rebuilding the whole subtree. |
| Theme is not injectable | Cannot render a component under a forced theme for testing or for a design-review harness. |

`AppTokens` is already a `ThemeExtension`, so the fix is mechanical rather than architectural: replace the static getters with a `BuildContext` extension resolving `Theme.of(context).extension<AppTokens>()`. **This is the highest-leverage single change in the migration** and is the reason it appears first in the recommended order.

### Secondary theme findings

- **`app_typography.dart` is entirely dead** — zero importers, zero symbol usages. It is the only referent for the `Sora` and `NotoSansArabic` families, which are declared in `pubspec.yaml` and ship **944 KB of unused font assets**.
- **`app_colors.dart` ("Amber Noir", dark-only, from the earlier Stitch design)** is reachable only from the dead typography file and from `lib/features/game/domain/entities/heat.dart`, which uses `AppColors.error/secondary/tertiary/outline/primary/onSurfaceVariant` for heat-tier colours. That path **is live** (`heat.dart` → `guess.dart` → `siyag_room_game_screen.dart`), so a **dark-only legacy palette currently leaks into gameplay colour in both themes**.
- **`AppTokens.lerp` deliberately snaps at `t < 0.5`** rather than interpolating. A defensible choice (avoids muddy greys), but it means **theme transitions are a hard cut** with no cross-fade — worth confirming against the Figma system's intent, which specifies no motion at all.
- **`SiyagHeat` mixes tokens with content**: it owns the cold→warm→hot colour ramp *and* returns hardcoded Arabic strings (`labelAr`, `progressMessage`). Presentation, semantics and copy are fused in the theme layer.

---

## 5. Current shared-component assessment

The shared layer is four files, ~750 lines, under `lib/core/widgets/siyag/`.

| Component | File | Assessment |
|---|---|---|
| `SiyagTap` | `siyag_tap.dart` | Scale-on-press wrapper. Sound reusable primitive. |
| `Kicker` | `siyag_common.dart` | Mono uppercase label. Reusable; hardcodes 10px / 1.8 tracking. |
| `SiyagAvatar` | `siyag_common.dart` | Letter/network avatar with fallback. Good behaviour; **only one size axis** (free `double`), vs Figma's 4 named sizes + status ring. |
| `SiyagPrimaryButton` | `siyag_common.dart` | **One visual style with a colour override.** No type variants, no size variants; disabled is `Opacity(0.5)`; no pressed or focus state. Figma specifies 4 types × 3 states. |
| `SiyagGhostButton` | `siyag_common.dart` | A *second* button class rather than a variant of the first. |
| `SiyagScreenHeader` | `siyag_common.dart` | Hardcodes `fromLTRB(24, 48, 24, 16)` and a 30px title. Not the Figma Top App Bar (3 variants). |
| `showSiyagConfirm` | `siyag_common.dart` | Good: one consistent confirm dialog. Correctly takes explicit `TextDirection`. |
| `SiyagHeatBar` | `siyag_guess.dart` | Continuous animated bar. **Track is `Colors.white @ 0.05`** — a dark-theme assumption (see §6). Figma's bar is **segmented**, not continuous. |
| `SiyagGuessRow` | `siyag_guess.dart` | Closest match to Figma's Guess Card, but **hardcodes `TextDirection.rtl` in 4 places** and hardcodes Arabic heat labels. |
| `SiyagSummaryChip` | `siyag_guess.dart` | Latest/Best summary. **Hardcodes RTL** ×2. Has no Figma counterpart. |
| `SiyagHintPill` | `siyag_guess.dart` | **Hardcodes RTL** ×2 and defaults `revealLabel` to the Arabic literal `'افتح تلميحاً'`. |
| `SiyagBottomNav` | `siyag_bottom_nav.dart` | Functional tab bar. Figma specifies Tab Bar (4) + Nav Item (8) with conflicting tab sets (§11). |

**The decisive point:** *placement in `core/widgets/` does not make these reusable.* Three of the four gameplay components hardcode `TextDirection.rtl` and two embed Arabic copy — they are Arabic-only widgets living in a shared folder. In a bilingual product whose Figma system promises full RTL **and** LTR, that is a correctness bug, not a style issue.

**Coverage gap.** Against Figma's 34 component sets, the Flutter shared layer offers roughly **12 widgets** — and no shared empty state, error state, skeleton, toast, sheet, segmented control, switch, checkbox, chip, search field, progress bar or badge.

---

## 6. Hardcoded and duplicated UI findings

### 6.1 Typography has no scale

**153 `ST.*` call sites use 23 distinct font sizes**, chosen per call site:

```
9, 10, 11, 12, 12.5, 13, 13.5, 14, 15, 16, 17, 18, 19, 20, 22, 24, 26, 28, 30, 34, 52, 54
```

`12.5`, `13.5`, `17` and `19` cannot be reconciled with any ramp. `ST.ar(13)` alone appears **30 times**, `ST.ar(14)` 15, `ST.ar(15)` 13 — three near-identical body sizes competing for the same role. Figma specifies **12 named styles**; the app expresses 23 anonymous ones.

### 6.2 Radii have no scale

**77 `BorderRadius.circular()` sites, 9 distinct values**: `8, 12, 14, 16, 18, 20, 22, 24, 999`. `16` dominates (32 uses) and `999` (16 uses) is the pill. `14`, `18` and `22` are one-offs. Figma's scale is `0/2/4/8/12/16/20/24/999` — overlapping but not identical, and the app has no name for any of them.

### 6.3 Spacing is off-grid

`SizedBox(height:)` uses **18 distinct values** including `2, 3, 6, 10, 14, 22, 28`. Padding literals include **`3, 5, 9, 43, 47, 51, 53, 63, 70, 72, 75`** — unambiguous magic numbers. Figma mandates a **4px base grid**; a meaningful share of current spacing does not sit on it.

### 6.4 Light-theme colour bugs (raw colour, wrong assumption)

Raw hex is rare (5 literals), but the few that exist are load-bearing and **dark-only**:

```dart
// siyag_guess.dart:28  — heat bar track
color: Colors.white.withValues(alpha: 0.05),
// siyag_guess.dart:92  — rank pill fill
color: Colors.white.withValues(alpha: 0.04),
```

White at 4–5% over a **light** surface (`#F7F5F0`) is effectively invisible: in Light theme the heat-bar track and the rank pill lose their shape. These should be `SC.surfaceHi` / `SC.line`. This is a real Light-theme defect in the most-used gameplay row, not a theoretical one.

Separately, `heat.dart` resolves tier colours from the dark-only `AppColors` in both themes (§4).

### 6.5 Component duplication

**41 screen-local widget classes** and **64 inline `BoxDecoration`** constructions across 15 screens. The duplication is semantic, not incidental:

| Concept | Duplicate implementations | Figma equivalent |
|---|---|---|
| Card / tappable surface | `_CategoryCard`, `_OptionCard`, `_ActionCard`, `_InviteCard`, `_RatingCard`, `_SearchingCard`, `_CodeCard`, `_WeeklyHeroCard`, `_Hero`, `_ModeTile` — **10** | `Game Mode Card` (5), `Notification Card` (4) |
| Player / list row | `_Row`, `_PlayerRow`, `_Participant`, `_SharedRow`, `_TierRow` — **5** | `Player Row` (5), `Leaderboard Row` (5) |
| Chip / pill / badge | `_CoinsPill`, `_PresenceChip`, `_Chip`, `_PlayerIdChip`, `_ConnBadge` — **5** | `Category Chip` (3), `Mode Badge` (5) |
| Segmented selector | `_AppearanceSelector`, `_LanguageSelector` — **2**, near-identical | `Segmented Control` (3) |
| Error / empty | `_Error` (weekly only) | `Empty State` (3) |

Highest-density files: `siyag_profile_screen.dart` (10 `BoxDecoration`, 652 lines), `siyag_home_screen.dart` (9), `siyag_room_lobby_screen.dart` (8).

### 6.6 Iconography is emoji

`🔥`, `💡`, `🔒`, `✓`, `🐾`, `⚽`, `💻`, `🍽️`, `🗺️`, `🌍` are used as UI icons in gameplay and room creation. Emoji render per-platform, ignore `IconTheme`, cannot be tinted by state, and are not accessible to screen readers. Figma's validation frames use **drawn icons** and additionally disagree with themselves (gem icons in AR vs star icons in EN for the same hint counter).

---

## 7. RTL, localization and accessibility findings

### RTL / LTR

| Signal | Count | Reading |
|---|---|---|
| Hardcoded `TextDirection.rtl` | **11** (9 in shared widgets) | Forces RTL regardless of locale |
| `Directionality(` | 19 | Direction *is* handled at screen level |
| `EdgeInsetsDirectional` | 3 | Very low |
| `AlignmentDirectional` | 5 | Very low |
| `BorderRadiusDirectional` | **0** | Asymmetric radii will not mirror |
| Non-directional `EdgeInsets.only(left/right)` | 1 | Good — nearly eliminated |
| `Alignment.centerLeft/Right` | **0** | Good |

The screen-level story is decent (19 `Directionality` wrappers, near-zero physical `EdgeInsets`). The **shared gameplay widgets are the problem**: `SiyagGuessRow`, `SiyagSummaryChip` and `SiyagHintPill` pin `TextDirection.rtl` internally, so in English they render right-aligned Arabic-order rows. `siyag_room_game_screen.dart:179` does the same inline.

### Localization

- **Complete and symmetric: 334 keys in `strings_ar.dart`, 334 in `strings_en.dart`.** This is a real asset and must be preserved.
- **But the theme layer holds untranslatable copy.** `SiyagHeat.labelAr()` returns `'ملتهب' / 'حار' / 'دافئ' / 'فاتر' / 'بارد' / 'الإجابة'`, and `SiyagHeat.progressMessage()` returns Arabic sentences — both in `siyag_theme.dart`. The **semantic-distance labels, the single most gameplay-critical text in the product, cannot render in English.** `SiyagHintPill.revealLabel` likewise defaults to an Arabic literal.
- Category display names are hardcoded Arabic in `v2_mappers.dart`; category→emoji matching in `siyag_create_room_screen.dart` string-matches both Arabic and English substrings.
- **Numeral systems are unresolved.** The Figma validation frames use **Eastern Arabic numerals** in AR (`٨٣٠`, `٠١:٤٢`, `٣/٥`) and Western in EN. The app has no numeral formatting layer, so ranks and timers currently render Western in both.

### Accessibility

| Check | Result |
|---|---|
| `Semantics` / `semanticLabel` / `MergeSemantics` | **0 occurrences** |
| `textScaler` / `TextScaler` / `textScaleFactor` | **0 occurrences** |
| Focus handling (`FocusNode`, `Focus(`) | 2 occurrences |
| Icon-only controls with labels | none |
| Emoji used as meaningful icons | yes (§6.6) |

This is the weakest area of the codebase. There is **no screen-reader support at all**, and **no text-scaling strategy** — which is dangerous in combination with the fixed heights catalogued in §12 (`h=44/46/48/56/72/80/100/104/120/160/168/192`) and Figma's own fixed `h-[48px]` buttons and `h-[64px]` guess cards. At 200% text scale these clip.

Figma's Foundations page promises: WCAG AA 4.5:1, ≥44×44 touch targets, non-colour indicators, and **2px focus rings on all interactive components**. The app satisfies the non-colour-indicator rule partially (rank numbers accompany heat colour) and satisfies **none** of the focus-ring rule. Figma itself provides no Focus variant to implement against (§11).

---

## 8. Light, Dark and System theme gaps

| Aspect | Flutter today | Figma today | Gap |
|---|---|---|---|
| Light palette | Complete (`AppTokens.light`) | Documented as swatches; **components are dark-only** | Figma cannot supply light component specs |
| Dark palette | Complete (`AppTokens.dark`) | Component fills are dark hexes | Aligned in mode, not in colour |
| System mode | Works, persisted, OS-reactive | Not modelled | Flutter ahead |
| Mode switching mechanism | `ThemeMode` + `SC.applyBrightness` | Claimed via variable modes — **not implemented** | Figma's core claim unmet |
| Both themes in one tree | **Impossible** (`SC` static) | n/a | **Blocks the gallery** |
| Theme transition | Hard cut (`lerp` snaps) | Unspecified | Decision required |
| Light-theme correctness | **2 known defects** (§6.4) + `heat.dart` (§4) | n/a | Must fix |
| Dual-theme tests | None (`test/theme/theme_test.dart` exists but cannot render both) | n/a | Unlocked by the `SC` refactor |

**The asymmetry is worth stating plainly:** for Light/Dark, **Flutter is ahead of Figma**. The app has a working, persisted, OS-reactive three-way theme with two complete palettes. Figma has two documented palettes and a component library that renders one of them. Migration must not regress this.

---

## 9. Figma foundation tokens identified

### 9.1 Primitive palette
Six ramps, named on-canvas: **Neutral, Saffron, Teal, Purple, Crimson, Emerald**. Rendered as swatch rows. Individual steps are **unlabelled and unbound** — no `saffron/500` scale is recoverable (§3).

### 9.2 Semantic colour tokens — 25 tokens, both modes
Extracted from the paired swatches on `18:131` (left swatch = Dark, right = Light).

| Group | Token | Dark | Light |
|---|---|---|---|
| **Backgrounds** | `bg/primary` | `#1c1917` | `#faf8f5` |
| | `bg/secondary` | `#292524` | `#f0ebe3` |
| | `bg/tertiary` | `#44403c` | `#e7e2da` |
| **Surfaces** | `surface/base` | `#292524` | `#ffffff` |
| | `surface/elevated` | `#44403c` | `#faf8f5` |
| | `surface/interactive` | `#57534e` | `#f0ebe3` |
| | `surface/disabled` | `#292524` | `#e7e5e4` |
| **Text** | `text/primary` | `#fafaf7` | `#1c1917` |
| | `text/secondary` | `#a8a29e` | `#57534e` |
| | `text/tertiary` | `#78716c` | `#78716c` |
| | `text/disabled` | `#57534e` | `#a8a29e` |
| | `text/inverse` | `#1c1917` | `#fafaf7` |
| **Actions** | `action/primary` | `#d97706` | `#d97706` |
| | `action/primary-hover` | `#b45309` | `#b45309` |
| | `action/secondary` | `#44403c` | `#e7e5e4` |
| | `action/destructive` | `#e11d48` | `#e11d48` |
| **Game modes** | `game/solo` | `#d97706` | `#d97706` |
| | `game/weekly` | `#9333ea` | `#7e22ce` |
| | `game/multiplayer` | `#0d9488` | `#0f766e` |
| | `game/ranked` | `#e11d48` | `#be123c` |
| | `game/practice` | `#059669` | `#047857` |
| **Status** | `status/success` | `#059669` | `#047857` |
| | `status/error` | `#e11d48` | `#be123c` |
| | `status/warning` | `#d97706` | `#b45309` |
| | `status/info` | `#0d9488` | `#0f766e` |

### 9.3 The 10 variables actually bound in the file
`text/primary` · `text/secondary` · `text/disabled` · `surface/base` · `surface/disabled` · `bg/primary` · `border/default` · `radius/lg` · `radius/button` · `spacing/16`

Note `border/default` (`#d6d0c8`) **exists as a variable but has no group on Foundations** — there is no `border/*` section in the documented token model at all.

### 9.4 Typography
**Inter**, 12 styles enumerated (cover claims 20):

| Style | Size | Weight | | Style | Size | Weight |
|---|---|---|---|---|---|---|
| Display/Large | 40 | Bold | | Body/Large | 16 | Regular |
| Display/Medium | 32 | Bold | | Body/Medium | 14 | Regular |
| Display/Small | 28 | SemiBold | | Body/Small | 12 | Regular |
| Heading/H1 | 24 | SemiBold | | Label/Large | 14 | Medium |
| Heading/H2 | 20 | SemiBold | | Label/Medium | 12 | Medium |
| Heading/H3 | 18 | Medium | | Label/Small | 10 | Medium |

**No line-height or letter-spacing is defined for any style.** Arabic guidance is a single sentence: *"Arabic text renders with system Arabic fonts at the same size scale"* — no family, no per-script line-height compensation.

### 9.5 Spacing, sizing, radii, elevation
- **Spacing** — 16 values enumerated (cover claims 20): `0, 2, 4, 6, 8, 10, 12, 16, 20, 24, 32, 40, 48, 56, 64, 80`. Stated: 4px base grid, **minimum touch target 44px**.
- **Radii** — 9: `none 0 · xs 2 · sm 4 · md 8 · lg 12 · xl 16 · 2xl 20 · 3xl 24 · full 999`.
- **Elevation** — 6 effect styles named (`Low`, `Medium`, `High`, `Glow/Saffron`, `Glow/Teal`, `Glow/Purple`); **values unspecified** (§3).
- **Motion** — none specified anywhere in the file.

### 9.6 Accessibility & bilingual rules (as stated on Foundations)
WCAG AA 4.5:1 on all text pairs · touch targets ≥44×44 · non-colour indicators for distance (icons, labels, bars) · **2px focus rings via a `border/focus` token** · Arabic mirrors horizontal layout · English LTR · same type scale both scripts, Inter for Latin + system Arabic · components absorb **30–50% text expansion**.

---

## 10. Figma component families identified

**34 component sets · 149 variants** — independently counted and matching the cover's own figures exactly.

| Page | Component set | Variant axis | Count |
|---|---|---|---|
| Buttons | `Siyaq/Button` | Type (Primary/Secondary/Ghost/Destructive) × State (Default/Pressed/Disabled) | 12 |
| Buttons | `Siyaq/Divider` | Type (Default/WithLabel) | 2 |
| Inputs | `Siyaq/Text Input` | State (Empty/Filled/Focused/Error/Disabled) | 5 |
| Inputs | `Siyaq/Word Guess Input` | State × Lang (EN/AR) | 6 |
| Inputs | `Siyaq/Search Input` | State (Empty/Filled/Loading) | 3 |
| Inputs | `Siyaq/Switch` | State (On/Off/Disabled) | 3 |
| Inputs | `Siyaq/Checkbox` | State (Unchecked/Checked/Disabled) | 3 |
| Inputs | `Siyaq/Category Chip` | State (Default/Selected/Disabled) | 3 |
| Navigation | `Siyaq/Top App Bar` | Type (Home/Detail/Game) | 3 |
| Navigation | `Siyaq/Tab Bar` | Active (Home/Ranked/Social/Profile) | 4 |
| Navigation | `Siyaq/Nav Item` | Tab (Home/Leaderboard/Profile/Settings) × State | 8 |
| Navigation | `Siyaq/Segmented Control` | Active (First/Second/Third) | 3 |
| Cards | `Siyaq/Game Mode Card` | Mode ×5 | 5 |
| Cards | `Siyaq/Mode Badge` | Mode ×5 | 5 |
| Cards | `Siyaq/Notification Card` | Type (Challenge/Achievement/System/Weekly) | 4 |
| **Guess** | **`Siyaq/Guess Card`** | **Distance (Very Far→Correct)** | **6** |
| **Guess** | **`Siyaq/Distance Label`** | **Level (Very Far→Correct)** | **6** |
| Multiplayer | `Siyaq/Room Card` | Status (Waiting/Playing/Full) | 3 |
| Multiplayer | `Siyaq/Player Row` | Role (Self/Opponent/Host/Ready/Waiting) | 5 |
| Multiplayer | `Siyaq/Player Avatar` | Size × Status | 8 |
| Multiplayer | `Siyaq/Room Code Input` | State (Empty/Partial/Complete/Error) | 4 |
| Ranked | `Siyaq/Rank Badge` | Tier (Bronze→Master) | 5 |
| Ranked | `Siyaq/Leaderboard Row` | Type (Top1/Top2/Top3/Regular/Self) | 5 |
| Profile | `Siyaq/Stat Card` | Type ×6 | 6 |
| Profile | `Siyaq/Achievement Badge` | State (Unlocked/Locked/New) | 3 |
| Profile | `Siyaq/Progress Bar` | Progress (0/33/66/100%) | 4 |
| Wallet | `Siyaq/Wallet Balance` | Size (Large/Compact) | 2 |
| Wallet | `Siyaq/Transaction Row` | Type (Earned/Spent/Purchase) | 3 |
| Feedback | `Siyaq/Toast` | Type (Success/Error/Warning/Info) | 4 |
| Feedback | `Siyaq/Dialog` | Type (Confirmation/Achievement/Error) | 3 |
| Feedback | `Siyaq/Bottom Sheet` | Type (GameOver/Settings/ShareResult) | 3 |
| Feedback | `Siyaq/Empty State` | Type (NoResults/NoHistory/NoFriends) | 3 |
| Feedback | `Siyaq/Loading Skeleton` | Type (Card/Row/Text) | 3 |
| Settings | `Siyaq/Settings Row` | Type (Toggle/Navigation/Action/Destructive) | 4 |

### Per-family readiness

| Question | Answer |
|---|---|
| Real Figma components? | **Yes** — all 34 are true `COMPONENT_SET`s with `COMPONENT` children. |
| Use variants? | **Yes** — properly named variant properties throughout. This is the system's genuine strength. |
| Use variables? | **Almost never** — 7 bindings across 8 inspected sets; 6 of 8 bind **zero**. |
| Support Light **and** Dark? | **No** — fills are hardcoded dark hexes. Light exists only in Archive posters and validation mockups. |
| Support AR RTL **and** EN LTR? | **Only `Word Guess Input`** carries an explicit `Lang=EN/AR` axis. All 33 others are single-direction. |
| Handle long content? | **No** — `Guess Card` is `w-[350px] h-[64px]` fixed; `Button` is `h-[48px]` fixed. Contradicts the stated 30–50% expansion rule. |
| All required states present? | **No** — **no Focus state on any component**, despite the documented 2px focus-ring rule. Hover exists only as `action/primary-hover` (a colour token with no variant). |
| Dimensions clear enough to implement? | **Partially** — sizes and paddings are readable; **line-height, letter-spacing, shadow values and all motion are absent.** |

---

## 11. Figma inconsistencies or missing specifications

Twenty findings, evidence-backed. These are the items that make the file not-yet-implementable.

### Critical — block implementation

1. **Token architecture is documentation, not implementation.** `get_variable_defs` returns `{}` for Foundations (`18:3`), Semantic Color Tokens (`18:131`), Primitive Palette (`18:56`), Typography (`18:246`), Spacing (`18:285`) and Corner Radius (`18:337`). **7 variable bindings vs 66 raw hex** across 8 component sets. Cover claims *193 tokens / 5 collections / 350+ bindings*.

2. **No component supports Light mode.** Fills are dark hexes (`bg-[#292524]`, `bg-[#d97706]`, `bg-[#be123c]`). The Buttons page annotation states *"Fills and text bound to semantic variables — auto-switches Light ↔ Dark"* — **this is false**. Light components exist only on the **Archive** page.

3. **`Siyaq/Guess Card` docs contradict its variants.** Documented: *"6 variants: Latest, Previous, Best, Improved, Worse, Correct."* Actual: `Distance = Very Far | Far | Closer | Close | Very Close | Correct`. **There is no Latest variant and no Best variant** — the two states the planned gameplay screen depends on.

4. **Validation mockups don't use the approved Guess Card.** The approved component has a 4px left colour bar and fixed 350px width. The validation rows are full-width with no bar, using arrow + text label + number. The two disagree about the core gameplay row.

5. **Destructive button fails WCAG AA — measured.** `text/primary` `#1c1917` on `#be123c` = **2.78:1** (fails AA normal 4.5 *and* AA large 3.0). On `#e11d48` = **3.72:1** (fails normal). Every button type uses `text/primary` because **no `text/on-action` / `on-primary` token exists**. Foundations promises AA on all pairs.

### High — require a decision before build

6. **`Siyaq/Button` docs contradict its variants.** Documented: *"12 variants: 3 styles × 2 sizes (Large, Medium) × 2 states."* Actual: 4 types × 3 states. **No size axis exists**; `Destructive` and `Pressed` are undocumented; `h-[48px]` is the only height.

7. **Two conflicting navigation IAs.** `Tab Bar` → Home / Ranked / Social / Profile. `Nav Item` → Home / Leaderboard / Profile / Settings. The atom and the molecule disagree about the app's tabs.

8. **Radius scale conflict.** Foundations: `lg = 12px`, `xl = 16px`. Bound variables: `radius/lg = 16`, `radius/button = 12`. The same name carries two values.

9. **Token value drift between poster and variables.** `bg/primary` poster `#faf8f5` vs variable `#fafaf7`; `text/disabled` (light) poster `#a8a29e` vs variable `#d6d0c8`; `surface/disabled` (light) poster `#e7e5e4` vs variable `#e7e0d8`.

10. **Semantic collisions — one hex, three meanings.** `action/primary` = `game/solo` = `status/warning` = `#d97706`. `action/destructive` = `game/ranked` = `status/error` = `#e11d48`. Also `status/success` = `game/practice`, `status/info` = `game/multiplayer`. **A ranked-mode surface is indistinguishable from an error surface.**

11. **No focus state anywhere**, contradicting *"Visible focus rings on all interactive components (2px `border/focus` token)"*. **The `border/focus` token does not exist** in the token model or among bound variables.

12. **`border/*` group missing from the documented model** although `border/default` is a live bound variable.

13. **A third, undeclared palette in gameplay.** Guess Card distance colours `#10b981 · #34d399 · #fdd889 · #f59e0b · #fb923c · #fb7185` match neither `status/*` nor `game/*` tokens.

14. **`Distance Label` bands contradict themselves.** Docs: *Exact (0.00), Very Close (≤0.15), Close (≤0.30), Moderate (≤0.50), Far (≤0.75), Very Far (>0.75)* — a **0–1 distance** model with a *Moderate* band. Variants: *Very Far / Far / Closer / Close / Very Close / Correct* — no *Moderate*, and the validation frames show **integer ranks** (830 / 520 / 230), matching the backend rank model rather than a 0–1 float.

15. **Bilingual typography is unresolved.** The system specifies **Inter** for all text, and the Guess Card renders the Arabic word `كلمة` in `Inter:Medium`. **Inter ships no Arabic glyphs**, so this silently falls back. Foundations says only *"system Arabic fonts"* — no family, no line-height compensation. The app bundles Noto Naskh Arabic.

### Medium — specification gaps

16. **Fixed dimensions contradict the text-expansion rule.** `Guess Card` `w-[350px] h-[64px]`, `Button` `h-[48px]`, `Room Code Input` `w-[300px]`. 350px overflows a 320px viewport; fixed heights clip at raised text scale. Foundations requires components to absorb 30–50% expansion.

17. **Validation frames disagree with each other.** Hint counter uses **gem** icons in dark-AR and **star** icons in light-EN. The category chip is a small outlined pill in AR and a large filled amber pill in EN. The heat-ramp segment order also appears reversed between the two.

18. **Numeral system undocumented.** AR frames use Eastern Arabic (`٨٣٠`, `٠١:٤٢`, `٣/٥`); EN uses Western. No rule states which applies when.

19. **A letter-tile row appears in gameplay validation** (`ف ص ا ح ة` / `S H A K E S P E A R E`, wrapping to two rows) but **exists as no component on any approved page** and has no counterpart in the Flutter app.

20. **No motion specification at all** — no durations, easings or transitions anywhere in the file. Also missing: line-height, letter-spacing, and the numeric values behind all 6 effect styles.

---

## 12. Flutter-to-Figma comparison matrix

Classification per your brief: **Reusable** · **Adapt** · **Wrap** (temporarily) · **Replace** · **Remove** · **Create** · **Decide**.

### Foundations

| Area | Flutter today | Figma target | Class | Note |
|---|---|---|---|---|
| Token container | `AppTokens` `ThemeExtension`, 24 roles, L+D | 25 semantic tokens, L+D | **Adapt** | Right shape; remap roles, add `on-action`, `border/focus` |
| Token access | `SC` **static global** | n/a | **Replace** | → `context` extension. **Blocks the gallery** |
| Legacy palette | `AppColors` "Amber Noir" dark-only | — | **Remove** | Still leaks via `heat.dart` |
| Typography defs | `app_typography.dart` | 12 Inter styles | **Remove** | Dead: 0 importers |
| Type helpers | `ST.ar/sys/mono(size)`, 23 sizes | 12 named styles | **Replace** | Named roles, not raw sizes |
| Fonts | Sora, NotoSansArabic (dead), PlusJakarta, NotoNaskh, DMMono | Inter + system Arabic | **Decide** | §22-D1. Remove 944 KB dead |
| Spacing | 18 ad-hoc values | 16-step 4px grid | **Create** | No spacing scale exists |
| Radii | 9 ad-hoc values | 9 named steps | **Adapt** | Values overlap; add names |
| Elevation | `SC.shadow` only | 3 shadows + 3 glows | **Create** | Figma values missing (§3) |
| Motion | `SM` (route/tap/bar/row) | **none specified** | **Reusable** | Keep; Figma cannot supersede |
| Heat ramp | `SiyagHeat` continuous, rank-based | 6 discrete bands | **Decide** | §22-D3 |

### Components

| Flutter | Figma | Class | Note |
|---|---|---|---|
| `SiyagTap` | (interaction primitive) | **Reusable** | Keep as-is |
| `SiyagPrimaryButton` + `SiyagGhostButton` | `Siyaq/Button` 4×3 | **Replace** | One component, `type` + `state`; needs `on-action` token |
| `SiyagAvatar` | `Siyaq/Player Avatar` 8 | **Adapt** | Add named sizes + status ring |
| `Kicker` | Label/Small | **Adapt** | Bind to type scale |
| `SiyagScreenHeader` | `Siyaq/Top App Bar` 3 | **Replace** | Different concept |
| `showSiyagConfirm` | `Siyaq/Dialog` 3 | **Adapt** | Add Achievement + Error types |
| `SiyagHeatBar` | segmented bar | **Decide → Replace** | Continuous vs segmented; fix white-alpha track |
| `SiyagGuessRow` | `Siyaq/Guess Card` 6 | **Replace** | Remove hardcoded RTL + Arabic labels |
| `SiyagSummaryChip` | **no equivalent** | **Wrap** | Keep until Latest/Best variants exist in Figma |
| `SiyagHintPill` | **no equivalent** | **Wrap** | Same |
| `SiyagBottomNav` | `Tab Bar` + `Nav Item` | **Adapt** | Blocked by IA conflict (§11-7) |
| `ConfettiOverlay` | **no equivalent** | **Reusable** | Self-contained, token-light |
| `_CategoryCard`/`_OptionCard`/`_ActionCard`/`_InviteCard`/`_RatingCard`/`_SearchingCard`/`_CodeCard`/`_WeeklyHeroCard`/`_Hero`/`_ModeTile` | `Game Mode Card`, `Notification Card` | **Replace** | 10 → 2 |
| `_Row`/`_PlayerRow`/`_Participant`/`_SharedRow`/`_TierRow` | `Player Row`, `Leaderboard Row` | **Replace** | 5 → 2 |
| `_CoinsPill`/`_PresenceChip`/`_Chip`/`_PlayerIdChip`/`_ConnBadge` | `Category Chip`, `Mode Badge` | **Replace** | 5 → 2 |
| `_AppearanceSelector`/`_LanguageSelector` | `Segmented Control` | **Replace** | 2 → 1 |
| `_Error` (weekly) | `Empty State` 3 | **Replace** | Promote to shared |
| — | `Text Input`, `Search Input`, `Switch`, `Checkbox`, `Progress Bar`, `Toast`, `Bottom Sheet`, `Loading Skeleton`, `Rank Badge`, `Stat Card`, `Achievement Badge`, `Wallet Balance`, `Transaction Row`, `Settings Row`, `Room Code Input`, `Divider`, `Distance Label` | **Create** | **17 families with no Flutter counterpart** |

### Behavioural qualities

| Quality | Flutter | Figma | Class |
|---|---|---|---|
| Light/Dark/System | **Working, persisted** | Documented, unimplemented | **Reusable** — protect |
| Dual-theme in one tree | Impossible | n/a | **Replace** (`SC`) |
| RTL/LTR | Screen-level good; **shared widgets force RTL** | Only `Word Guess Input` bilingual | **Adapt** + **Decide** |
| Localization | **334×2 keys complete** | n/a | **Reusable** — protect |
| Distance labels | Arabic-only in theme layer | `Distance Label` (6) | **Replace** |
| Numerals | Western only | AR Eastern / EN Western | **Decide** §22-D5 |
| Text scaling | **0 handling** | 30–50% expansion promised | **Create** |
| Screen readers | **0 `Semantics`** | non-colour indicators promised | **Create** |
| Focus | 2 refs | promised, **no variant** | **Create** + **Decide** |
| Business logic / API / Riverpod / routing | Working | n/a | **Reusable — do not touch** |

---

## 13. Proposed Flutter design-system scope

### Structure

The repo is already clean feature-first (`lib/core/…`, `lib/features/<feature>/{data,domain,presentation}`) and `flutter analyze` is green. **Do not restructure it.** Extend the existing `lib/core/` seam:

```
lib/core/design/
  tokens/       colors.dart · typography.dart · spacing.dart · radii.dart
                elevation.dart · motion.dart · icons.dart
  theme/        siyaq_tokens.dart (ThemeExtension) · siyaq_theme.dart
                token_context.dart  ← BuildContext extension, replaces SC
  components/   foundation/ (button, text, surface, icon, tap)
                inputs/ · navigation/ · feedback/ · data_display/
  gameplay/     guess_row.dart · distance_label.dart · composer.dart
                hint_tray.dart · heat_indicator.dart
lib/core/widgets/siyag/   ← retained during migration, deleted at the end
```

Rationale: `lib/core/design/` is additive, so old and new coexist and the app stays buildable throughout. `lib/core/widgets/siyag/` is deleted only once nothing imports it. Gameplay components are separated because they are the volatile part.

### What the system must contain

- **Semantic colour model** — port the 25 Figma tokens into `AppTokens`, adding the two the system lacks: **`onAction`** (fixes the 2.78:1 destructive failure) and **`borderFocus`**. Keep the app's existing `success/warning/error/info` roles. Resolve game-mode vs status collisions (§22-D2).
- **Light / Dark / System** — preserve exactly today's behaviour. Non-negotiable regression boundary.
- **`BuildContext` token access** — `context.tokens.surface`. Removes the static global and unlocks dual-theme rendering.
- **Typography** — 12 named roles matching Figma, each carrying family, size, weight, **and a line-height chosen per script** (Figma specifies none). Per-script family resolution so Arabic never falls back through Inter.
- **Spacing / sizing** — the 16-step 4px scale as named constants; a `minTouchTarget = 44` constant enforced by the tap primitive.
- **Radii / borders / elevation / shadows** — named scales; elevation values decided locally since Figma omits them.
- **Motion** — keep the app's existing `SM` values; Figma specifies none.
- **Icons** — a single `SiyaqIcons` surface replacing emoji, tintable and `Semantics`-labelled.
- **Component variants and states** — `type` × `size` × `state` as enums, with **Default / Pressed / Focused / Disabled / Loading** modelled explicitly rather than via `Opacity(0.5)`.
- **RTL/LTR** — direction never hardcoded; `*Directional` insets/alignment/radii throughout; direction taken from `Directionality.of(context)`.
- **Localization** — no user-visible string inside a component; distance labels move from `siyag_theme.dart` into the existing 334-key ARB-equivalent files.
- **Accessibility** — `Semantics` on every interactive component, `semanticLabel` on every icon-only control, visible focus rings, non-colour distance indicators (rank + arrow + label).
- **Text scaling** — components must survive `TextScaler` 2.0; no fixed heights on text-bearing surfaces (min-height + intrinsic instead).
- **Responsive / device range** — no fixed widths; validate at 320 px through tablet. Avoid per-row blur/glow on long lists (the current heat bar draws a `BoxShadow` per row).
- **Android / iOS parity** — one visual system; platform differences confined to page transitions (already themed) and haptics.

---

## 14. Proposed reusable component inventory

`F` foundational · `S` shared · `G` gameplay. "Replaces" cites current Flutter code.

### Foundational

| Component | Responsibility | Variants | States | Key props | Figma | Replaces | T |
|---|---|---|---|---|---|---|---|
| `SiyaqButton` | All button actions | Primary, Secondary, Ghost, Destructive | Default, Pressed, Focused, Disabled, Loading | `label, icon, trailing, size, fullWidth, onPressed` | `Siyaq/Button` | `SiyagPrimaryButton`, `SiyagGhostButton` | F |
| `SiyaqIconButton` | Icon-only actions | Standard, Ghost | + Focused | `icon, semanticLabel*, size` | (derived) | inline `IconButton`s | F |
| `SiyaqText` | Type-scale text | 12 roles | — | `role, color, maxLines, textAlign` | Typography | `ST.ar/sys/mono` | F |
| `SiyaqSurface` | Card/elevated container | Base, Elevated, Interactive, Outlined | Default, Pressed, Disabled | `radius, elevation, padding, onTap` | Cards | **64 inline `BoxDecoration`** | F |
| `SiyaqDivider` | Separator | Default, WithLabel | — | `label` | `Siyaq/Divider` | inline dividers | F |
| `SiyaqTap` | Press feedback + 44px target | — | — | `scale, onTap` | — | `SiyagTap` (keep) | F |
| `SiyaqIcon` | Tintable icon surface | — | — | `icon, size, semanticLabel` | — | **all emoji icons** | F |

### Shared

| Component | Responsibility | Variants | States | Figma | Replaces | T |
|---|---|---|---|---|---|---|
| `SiyaqTextField` | Labelled text input | Standard, Search | Empty, Filled, Focused, Error, Disabled | `Text Input`, `Search Input` | inline `TextField`s | S |
| `SiyaqSwitch` / `SiyaqCheckbox` | Boolean controls | — | On, Off, Disabled, Focused | `Switch`, `Checkbox` | Material defaults | S |
| `SiyaqChip` | Selectable/label chip | Category, Mode, Status | Default, Selected, Disabled | `Category Chip`, `Mode Badge` | `_CoinsPill`, `_PresenceChip`, `_Chip`, `_PlayerIdChip`, `_ConnBadge` | S |
| `SiyaqSegmentedControl` | Exclusive choice | 2–4 segments | Default, Focused, Disabled | `Segmented Control` | `_AppearanceSelector`, `_LanguageSelector` | S |
| `SiyaqAppBar` | Screen header | Home, Detail, Game | — | `Top App Bar` | `SiyagScreenHeader`, `siyag_topbar` | S |
| `SiyaqTabBar` | Root navigation | by active tab | Active, Inactive | `Tab Bar`, `Nav Item` | `SiyagBottomNav` | S |
| `SiyaqListRow` | Generic list item | Default, Player, Leaderboard, Transaction, Settings | Default, Pressed, Selected, Disabled | `Player Row`, `Leaderboard Row`, `Transaction Row`, `Settings Row` | `_Row`, `_PlayerRow`, `_Participant`, `_SharedRow`, `_TierRow` | S |
| `SiyaqModeCard` | Game-mode entry | Solo, Weekly, Multiplayer, Ranked, Practice | Default, Pressed, Disabled | `Game Mode Card` | `_ModeTile`, `_ActionCard`, `_CategoryCard`, `_OptionCard` | S |
| `SiyaqAvatar` | Player identity | XL, L, M, S | Online, Offline, Reconnecting | `Player Avatar` | `SiyagAvatar` | S |
| `SiyaqProgressBar` | Linear progress | Determinate, Indeterminate | — | `Progress Bar` | inline bars | S |
| `SiyaqBadge` | Rank/achievement | Rank tiers, Achievement | Unlocked, Locked, New | `Rank Badge`, `Achievement Badge` | inline | S |
| `SiyaqStatCard` | Single metric | 6 types | Default, Loading | `Stat Card` | inline profile stats | S |
| `SiyaqToast` | Ephemeral feedback | Success, Error, Warning, Info | — | `Siyaq/Toast` | **28 raw `SnackBar` sites** | S |
| `SiyaqDialog` | Modal decision | Confirmation, Achievement, Error | — | `Siyaq/Dialog` | `showSiyagConfirm` | S |
| `SiyaqBottomSheet` | Modal surface | GameOver, Settings, ShareResult | — | `Bottom Sheet` | 2 inline sheets | S |
| `SiyaqEmptyState` | Zero-data | NoResults, NoHistory, NoFriends, Error, Offline | — | `Empty State` | `_Error` + ad-hoc | S |
| `SiyaqSkeleton` | Loading placeholder | Card, Row, Text | — | `Loading Skeleton` | **none — 19 raw spinners** | S |
| `SiyaqRoomCodeInput` | 6-digit code entry | — | Empty, Partial, Complete, Error | `Room Code Input` | `_CodeCard` | S |

### Gameplay — *must not be rebuilt per screen*

Five screens currently render guesses (`practice_game`, `room_game`, `weekly_game`, `ranked_match`, `game_view`). These must share one set.

| Component | Responsibility | Variants | States | Figma | T |
|---|---|---|---|---|---|
| `SiyaqGuessComposer` | Keyboard-anchored input + submit | Solo, Multiplayer | Idle, Typing, Submitting, Error, Disabled | `Word Guess Input` (EN/AR) | G |
| `SiyaqGuessRow` | One ranked guess | Compact, Comfortable | **Latest, Best, History**, Correct, Duplicate | `Guess Card` ⚠ *no Latest/Best variant exists* | G |
| `SiyaqDistanceLabel` | Localized distance band | 6 bands | — | `Distance Label` ⚠ band names conflict | G |
| `SiyaqHeatIndicator` | Proximity visual | Bar, Segmented | Animating, Static, Solved | ⚠ continuous vs segmented unresolved | G |
| `SiyaqHintTray` | Hints from upper area | Collapsed, Expanded | Locked, Loading, Revealed | ⚠ **no component; icons conflict** | G |
| `SiyaqBestGuessBanner` | Best guess near composer | Inline, Pinned | Empty, Populated, Improved | ⚠ **no component; validation puts Best inline** | G |
| `SiyaqLetterTiles` | Revealed-letter row | Single-row, Wrapping | Hidden, Partial, Full | ⚠ **validation-only, not a component** | G |
| `SiyaqRoundHeader` | Round / timer / hints | Solo, Multiplayer, Ranked | Running, Paused, Ended | `Top App Bar (Game)` | G |

**Six of eight gameplay components have unresolved or missing Figma sources.** This is the strongest argument for not starting with the gameplay screen.

---

## 15. Existing widgets that can remain

Keep as-is or with token substitution only.

| Widget / asset | Why |
|---|---|
| `SiyagTap` | Correct interaction primitive; add 44px minimum enforcement |
| `ConfettiOverlay` | Self-contained celebration; token-light; no Figma equivalent |
| `AppTokens` (`ThemeExtension`) | Correct shape — extend, don't rewrite |
| `AppTheme._build` Material theming | Keeps Material widgets aligned; retarget to new tokens |
| `SM` motion constants | Figma specifies no motion — this is the only motion source |
| `AppTokens.systemUiStyleFor` | Correct status/nav bar handling |
| `showSiyagConfirm` **behaviour** | Correct pattern (explicit direction, returns `bool`); restyle only |
| **All** `lib/core/localization/` (334×2) | Complete and symmetric; a real asset |
| **All** `features/*/data`, `domain`, `presentation/controllers` | Riverpod controllers, repos, WS, mappers — **out of scope, do not touch** |
| `siyag_route.dart`, `siyag_shell.dart` navigation behaviour | Routing works; only chrome changes |

---

## 16. Existing widgets that require adaptation

| Widget | Required change |
|---|---|
| `AppTokens` | Add `onAction`, `borderFocus`; remap to the 25 Figma tokens; resolve game/status collisions |
| `AppTheme` | Retarget to new tokens; add focus-ring theming; reconsider `lerp` snap |
| `SiyagAvatar` | Named sizes (XL/L/M/S) + status ring; `Semantics`; keep the network/letter fallback |
| `Kicker` | Bind to `Label/Small`; drop hardcoded 10px/1.8 |
| `SiyagBottomNav` | Rebuild on `SiyaqTabBar` — **blocked** by the Tab Bar vs Nav Item IA conflict (§11-7) |
| `siyag_topbar.dart` | Fold into `SiyaqAppBar` (Home/Detail/Game) |
| `SiyagHeat` | Split: colour ramp → tokens; `labelAr`/`progressMessage` → localization; keep `fromRank` (business logic) |
| `heat.dart` (`HeatTier`) | Stop importing `AppColors`; resolve tier colour from theme |
| `showSiyagConfirm` | Add Achievement + Error types; take copy from localization |
| All 19 `Directionality` screens | Keep the wrappers; remove the *inner* hardcoded `TextDirection.rtl` |

---

## 17. Existing widgets that should be replaced

| Current | Replacement | Reason |
|---|---|---|
| `SC` static accessor | `context.tokens` extension | **Blocks the gallery and dual-theme tests** |
| `ST.ar/sys/mono(size)` | `SiyaqText(role:)` | 23 anonymous sizes → 12 named roles |
| `SiyagPrimaryButton` + `SiyagGhostButton` | `SiyaqButton` | 4 types × 5 states in one component |
| `SiyagScreenHeader` | `SiyaqAppBar` | Different concept in Figma |
| `SiyagGuessRow` | `SiyaqGuessRow` | Hardcoded RTL + Arabic labels + white-alpha fills |
| `SiyagHeatBar` | `SiyaqHeatIndicator` | White-alpha track breaks Light; segmented vs continuous unresolved |
| 10 `_*Card` classes | `SiyaqSurface` + `SiyaqModeCard` | 10 → 2 |
| 5 `_*Row` classes | `SiyaqListRow` | 5 → 2 |
| 5 chip/pill classes | `SiyaqChip` | 5 → 2 |
| `_AppearanceSelector`, `_LanguageSelector` | `SiyaqSegmentedControl` | Near-identical duplicates |
| 28 raw `SnackBar` sites | `SiyaqToast` | 4 typed variants |
| 19 raw `CircularProgressIndicator` | `SiyaqSkeleton` / button `Loading` | Figma specifies skeletons; app has none |
| All emoji icons | `SiyaqIcon` | Tintable, themable, accessible |
| 64 inline `BoxDecoration` | `SiyaqSurface` | Single source of surface styling |

---

## 18. Existing widgets that should eventually be removed

Remove **only after** replacements are integrated and nothing imports them.

| Target | Evidence | When |
|---|---|---|
| `lib/core/theme/app_typography.dart` | **0 importers, 0 usages — already dead** | Immediately safe |
| `lib/core/theme/app_colors.dart` | Reachable only from the dead file + `heat.dart` | After `heat.dart` is detached |
| `Sora-*.ttf` (4) + `NotoSansArabic-*.ttf` (4) + their `pubspec` entries | Referenced only by the dead typography file — **944 KB** | With the two files above |
| `lib/core/widgets/siyag/siyag_common.dart` | Superseded by `SiyaqButton`/`SiyaqAppBar`/`SiyaqAvatar`/`SiyaqDialog` | End of Phase 4 |
| `lib/core/widgets/siyag/siyag_guess.dart` | Superseded by gameplay set | End of gameplay phase |
| `lib/core/widgets/siyag/siyag_bottom_nav.dart` | Superseded by `SiyaqTabBar` | After IA decision |
| 41 screen-local `_*` widget classes | Superseded by shared components | Per screen, as migrated |
| `SC` class | After the last `SC.` reference | End of migration |
| `AppTokens.copyWith` no-op (`=> this`) | Silently ignores arguments — a latent trap | With the token rewrite |

---

## 19. Component-gallery requirements

**Build this before any production screen is refactored.** It is the acceptance harness for the whole migration.

**Hard prerequisite:** the gallery cannot exist while `SC` is a static global — one process cannot render Light and Dark simultaneously. **The `SC` → `context.tokens` refactor is therefore the first task of the implementation session**, not a later cleanup.

### Required coverage

Every representative component must be verifiable across:

| Axis | Values |
|---|---|
| **Theme** | Light · Dark · System — **Light and Dark visible side by side in one screen** |
| **Direction** | Arabic RTL · English LTR — **both visible simultaneously** |
| **Text scale** | 1.0 · 1.3 · **2.0** (`TextScaler`) |
| **Interaction state** | Default · Pressed · Focused · Selected · Disabled |
| **Data state** | Loading · Success · Warning · Error · Empty · Offline |
| **Content** | Nominal · **Long content (+50% expansion)** · single char · numeric extremes (rank 1 vs 999,999) |
| **Viewport** | **320 px** · 390 px · 430 px · tablet |
| **Density** | Compact · comfortable list rows |

### Functional requirements

1. **Live axis toggles** — theme, direction, text scale, viewport switchable without restart.
2. **Matrix rendering** — every variant × state of a component set on one screen (mirrors Figma's variant grids).
3. **Side-by-side theme compare** — the primary regression check for the Light-theme bugs in §6.4.
4. **Long-content and small-screen presets** — one tap to the failure-prone configuration (320 px + 2.0 scale + +50% text).
5. **Token inspector** — render all colour, type, spacing, radius and elevation tokens with names and resolved values per theme; the check against §11's token drift.
6. **Accessibility overlay** — surface `Semantics` labels, computed contrast ratios and touch-target bounds. Must flag the `on-action` contrast issue (§11-5).
7. **Debug-only** — excluded from release builds; must not affect app size or startup.
8. **Golden-test hooks** — each entry renderable headlessly so goldens cover theme × direction without a second harness.

### Coverage gate

A component is "done" only when it renders correctly at **Light/Dark × AR/EN × text-scale 2.0 × 320 px**, with every state present and no fixed height on a text-bearing surface.

*(Definition only — the gallery was not built in this session.)*

---

## 20. Recommended migration order

Each phase leaves the app **buildable, testable and shippable**. No destructive rewrite.

| Phase | Work | Exit criteria |
|---|---|---|
| **0 — Unblock** | Resolve the §22 decisions, especially **D1 (fonts)**, **D2 (token collisions)**, **D6 (Figma completion)**. Fix the Figma token bindings and add the missing `on-action` / `border/focus` tokens. | Design decisions recorded; Figma tokens bound; contrast defect fixed |
| **1 — Token layer** | Build `lib/core/design/tokens/` + `SiyaqTokens` extension. **Refactor `SC` → `context.tokens`.** Delete dead typography/colour files and the 944 KB of dead fonts. | `flutter analyze` clean; app pixel-identical; `SC` gone; both themes renderable in one tree |
| **2 — Gallery** | Build the §19 gallery with all axes and the token inspector. | Light+Dark and AR+EN visible simultaneously; token inspector live |
| **3 — Foundational components** | `SiyaqText`, `SiyaqSurface`, `SiyaqButton`, `SiyaqIcon`, `SiyaqIconButton`, `SiyaqTap`, `SiyaqDivider`. Add `Semantics` + focus + text-scale from the start. | All pass the §19 gate in the gallery; **no production screen changed yet** |
| **4 — Shared components** | Inputs, chips, segmented control, list rows, cards, avatars, badges, progress, stat cards. | Each passes the gate; old widgets still in place |
| **5 — Feedback & states** | `SiyaqToast`, `SiyaqDialog`, `SiyaqBottomSheet`, `SiyaqEmptyState`, `SiyaqSkeleton`. Retire the 28 raw `SnackBar` and 19 raw spinner sites. | Consistent feedback everywhere |
| **6 — Screen migration (low risk first)** | Profile → Settings → Leaderboard → Weekly → Multiplayer hub → Room lobby/create/join. **One screen per PR.** | Behaviour unchanged; per-screen `_*` classes deleted |
| **7 — Gameplay** | **Only after** the gameplay Figma gaps close. Build the gameplay set, then rebuild the core gameplay screen (§21 UX direction). | Guess flow behaviour-identical; all five guess-rendering screens share one component set |
| **8 — Removal** | Delete `lib/core/widgets/siyag/`, `SC`, remaining `_*` classes, dead assets. | Zero references; analyze clean; goldens green |

**Why Profile first (Phase 6):** it is the largest screen (652 lines), has the highest inline-`BoxDecoration` density (10), contains both duplicate selectors, and has **no gameplay risk** — maximum cleanup per unit of risk.

**Why gameplay last:** six of eight gameplay components lack a usable Figma source (§14), and it is the highest-risk surface in the product.

---

## 21. Gameplay context recorded for later work

**No gameplay implementation was performed in this session.** Recorded per your brief: the **core gameplay screen is the first production screen to be rebuilt after the design system lands** (Phase 7).

Intended UX direction:

- Message-composer-style input **fixed above the keyboard**
- **Best guess visible close to the composer**
- **Latest submitted guess clearly visible**
- Remaining guesses ordered by **semantic rank**
- **Compact list items**, not large competing cards
- **Hints controlled from the upper area**, expandable/hideable
- **No uncontrolled horizontal scrolling** for hints
- Clear, consistent **cold→hot** semantic feedback
- Explicit distinction between **latest**, **best**, and **ranked history**

**How the audit bears on this direction:**

| Requirement | Figma status | Consequence |
|---|---|---|
| Composer fixed above keyboard | ✅ Validation frames show exactly this | Implementable; `Word Guess Input` is the only bilingual component |
| Best guess near composer | ❌ Validation places Best **inline in history** (bookmark + amber outline) | **Direct conflict — §22-D4** |
| Latest clearly visible | ❌ **No `Latest` variant exists** (§11-3) | Must be specified |
| Ranked history | ✅ Validation shows rank integers (830/520/230) | Matches `SiyagHeat.fromRank` |
| Compact list items | ⚠️ `Guess Card` is `h-[64px]` fixed, `w-[350px]` fixed | Needs a compact, fluid variant |
| Hints in upper area, expandable | ❌ **No hint component**; validation uses gems (AR) vs stars (EN) | Must be designed |
| No horizontal hint scrolling | ⚠️ Not addressed | Design constraint to enforce |
| Cold→hot feedback | ⚠️ Continuous (Flutter) vs 5-segment (Figma), plus a third palette (§11-13) | **§22-D3** |
| Latest / Best / history distinction | ❌ Only distance bands exist | **The central gameplay gap** |

Also carried forward: the **letter-tile row** appears in gameplay validation but exists as no component (§11-19), and **numeral system** differs by language with no rule (§11-18).

---

## 22. Risks, compatibility concerns, and decisions required

### Risks

| Risk | Severity | Mitigation |
|---|---|---|
| **Figma is not implementable as-is** — 7 bindings vs 66 raw hex; no Light components | **Critical** | Phase 0 gate. Do not start Flutter component work against unbound tokens |
| **`SC` refactor touches 25 files at once** | **High** | Mechanical, compiler-guided; `flutter analyze` is green today; do it alone in one PR with no visual change |
| **Light/Dark regression** — today's working three-way theme is a real asset | **High** | Gallery side-by-side + dual-theme goldens before any screen changes |
| **Gameplay lacks Figma sources** (6 of 8 components) | **High** | Gameplay last; close Figma gaps first |
| **RTL regression** — removing hardcoded `rtl` could break Arabic, the primary locale | **High** | Gallery renders AR+EN simultaneously; migrate one widget at a time |
| **Identity shift** (graphite/gold → stone/saffron) is a product change, not a refactor | **High** | Confirm with stakeholders before Phase 1 (**D2**) |
| **Text-scale/a11y work is net-new** (0 `Semantics`, 0 `textScaler`) | **Medium** | Build into components from Phase 3; never retrofit |
| **Five screens render guesses** — divergence risk | **Medium** | One shared gameplay set; forbid local guess widgets |
| **Font swap risk** — Inter has no Arabic glyphs | **Medium** | Resolve **D1** before typography work |
| **Archive/validation mistaken for source** | **Medium** | This report is the boundary; only the 11 approved pages are normative |
| **Long-list performance** — per-row `BoxShadow` glow | **Low** | Profile on a low-end device; consider static heat colours in lists |
| **App-size regression** | **Low** | Deleting 944 KB dead fonts offsets any Inter addition |

### Compatibility

- **Riverpod controllers, repositories, WebSocket, mappers, routing, auth, notifications — out of scope and untouched.**
- The 334×2 localization keys must survive; new component copy uses existing keys or adds new ones.
- `test/theme/theme_test.dart` and the 15 other test files must keep passing; goldens are additive.
- `flutter analyze` must stay at **"No issues found"** after every phase.
- Backend contract (rank-based distance) is unaffected — but note Figma's `Distance Label` documents a 0–1 float model that **does not match** the rank model the app and validation frames use (§11-14).

### Decisions required before implementation

| # | Decision | Options | Recommendation |
|---|---|---|---|
| **D1** | **Typography for Arabic.** Figma says Inter for all text; Inter has no Arabic glyphs; app bundles Noto Naskh Arabic. | (a) Inter + Noto Naskh Arabic per script (b) Inter + system Arabic (c) keep Plus Jakarta + Noto Naskh | **(a)** — honours Figma for Latin, keeps deterministic Arabic rendering. Needs per-script line-heights, which Figma omits |
| **D2** | **Brand identity + token collisions.** Adopt stone/saffron over graphite/gold? And `action/primary`=`game/solo`=`status/warning`; `action/destructive`=`game/ranked`=`status/error`. | (a) adopt Figma, split colliding roles (b) adopt Figma as-is (c) keep graphite/gold, take Figma structure only | **(a)** — a ranked card must not read as an error. **Product-level call.** |
| **D3** | **Heat/distance visual + scale.** Continuous ramp (Flutter) vs 5-segment (Figma) vs a third Guess-Card palette; 6 bands vs continuous rank. | (a) segmented, tokenized (b) continuous (c) segmented list + continuous detail | **(a)** — matches Figma, is more accessible, and is cheaper in long lists |
| **D4** | **Best-guess placement.** Your UX direction says near the composer; Figma validation marks it inline in history. | (a) pinned near composer (b) inline (c) both | **(a)** — follow the stated product direction; needs a new Figma component |
| **D5** | **Numeral system.** AR Eastern (`٨٣٠`) vs Western; app currently Western everywhere. | (a) locale-driven (b) always Western (c) user setting | **(a)** — matches the validation frames; affects ranks, timers, scores, room codes |
| **D6** | **Who closes the Figma gaps, and when.** Bind tokens, add Light components, add `on-action`/`border/focus`, add Focus variants, add Latest/Best/hint/letter-tile components. | (a) design closes before Phase 3 (b) Flutter defines locally and Figma follows | **(a)** for tokens and gameplay; **(b)** acceptable for elevation and motion, which Figma simply lacks |
| **D7** | **Navigation IA.** `Tab Bar` = Home/Ranked/Social/Profile vs `Nav Item` = Home/Leaderboard/Profile/Settings. | — | Blocks `SiyaqTabBar`. **Product call.** |
| **D8** | **Theme transition.** `AppTokens.lerp` snaps at 0.5; Figma specifies no motion. | (a) keep snap (b) cross-fade | **(a)** — keep, revisit later |

---

## 23. Recommended scope for the next implementation session

**Phases 1–2 only. No production screen may be refactored.**

**Prerequisite:** decisions **D1**, **D2** and **D6** answered. D3–D5, D7 are needed before Phase 3+ but not to start.

### In scope

1. **Create `lib/core/design/tokens/`** — colour (25 Figma tokens + `onAction` + `borderFocus`), typography (12 named roles with per-script line-heights), spacing (16-step 4px), radii (9 named), elevation, motion (carried from `SM`), icons.
2. **Create `SiyaqTokens` `ThemeExtension`** with complete Light and Dark, registered on both `ThemeData`s.
3. **Refactor `SC` → `context.tokens`** across all 25 consuming files. **Mechanical, no visual change.** *This is the session's central deliverable.*
4. **Delete confirmed dead code** — `app_typography.dart`, `app_colors.dart` (after detaching `heat.dart`), and the 8 unused font assets + `pubspec` entries (944 KB).
5. **Build the component gallery** (§19) with all axes and the token inspector — but **only foundational primitives populated**.
6. **Add dual-theme golden tests** for the gallery's token pages.

### Explicitly out of scope

- Any change under `lib/features/*/presentation/screens/`
- Any gameplay component or the gameplay screen
- Shared component replacement (Phases 3–5)
- Any change to controllers, repositories, API, WebSocket, auth, notifications, routing
- Deleting `lib/core/widgets/siyag/` (Phase 8)

### Exit criteria

- `flutter analyze` → **"No issues found!"**
- All 16 existing test files pass
- **The app is visually unchanged** — this phase is infrastructure only
- The gallery renders **Light and Dark simultaneously** and **AR and EN simultaneously**
- Zero `SC.` references remain
- The token inspector displays every token with its resolved value per theme

### Suggested size

One PR for tokens + `SC` refactor + dead-code removal (mechanical, reviewable as a no-op diff), and a second for the gallery. Roughly 25 files touched in PR 1, all compiler-guided.

---

## 24. Confirmation: no application code was modified

**No application source file was created, edited, renamed or deleted in this session.**

- No file under `lib/`, `test/`, `android/`, `ios/`, `assets/` or `design_reference/` was modified.
- No packages installed; `pubspec.yaml` and `pubspec.lock` untouched.
- No themes, screens, widgets or components created or changed.
- **Nothing in Figma was modified** — only read-only MCP calls (`get_metadata`, `get_variable_defs`, `get_design_context`, `get_screenshot`).
- No formatter, code generator or fix command was run.
- No commits, no staged changes, no branches created.

**Commands run were read-only:** `flutter analyze` (analysis only — reported *"No issues found!"*, no files written), plus `grep`, `find`, `wc`, `git status`.

**Temporary artefacts** (MCP client scripts, page dumps, screenshots) were written **only** to the session scratchpad at
`/private/tmp/claude-501/.../scratchpad/`, entirely outside the repository. No temporary file was placed in the project tree.

**The only file added to the repository is this report:** `FIGMA_FLUTTER_UI_AUDIT.md`, created at the repository root as your brief requires.

---

*End of audit. Awaiting review and approval before any implementation begins.*

# Design System — Siyaq

The refined graphite + gold system, implemented as a **context-resolved token
layer** under `lib/core/design/`:

| Concern | File |
|---|---|
| Semantic colours (Light + Dark) | `design/tokens/siyaq_colors.dart` |
| Typography roles + scripts | `design/tokens/siyaq_typography.dart` |
| Spacing / radius | `design/tokens/siyaq_spacing.dart` |
| Elevation / glow | `design/tokens/siyaq_elevation.dart` |
| Motion | `design/tokens/siyaq_motion.dart` |
| Icons | `design/tokens/siyaq_icons.dart` |
| `ThemeData` assembly | `design/theme/siyaq_theme_data.dart` |
| **Access** | `design/theme/context_tokens.dart` |
| Accessibility primitives | `design/a11y/siyaq_a11y.dart` |
| Validation gallery (debug) | `design/gallery/` |

**Never hardcode hex in feature widgets — use a semantic token.**

## Access: `context`, never a global

```dart
Container(color: context.colors.surface)
Text('مرحبا', style: context.type.headingMedium)
```

Both resolve from the enclosing `Theme` via theme extensions. There is **no
static cached palette**, which is what allows Light and Dark (and AR and EN) to
render in the same widget tree — required by the gallery, previews and
dual-theme golden tests.

> The previous `SC` / `ST` static accessors were removed in the Phase 1
> migration. `context.legacyType.*` is a **temporary bridge** that reproduces the
> old `ST.*` pixel metrics while colour resolution moves to context; it is
> replaced role-by-role as components are rebuilt.

## Brand identity

Premium, intelligent, minimal, **Arabic-first** semantic word game. Dark
charcoal foundation, warm **gold** accent. Calm and sophisticated — never
childish, neon, gradient-heavy, or "every component is gold." Gold communicates
**importance and interaction**, not decoration.

## Semantic roles

| Token | Meaning |
|---|---|
| `background` | app canvas |
| `surface` | base card |
| `surfaceElevated` | elevated / interactive card |
| `surfaceStrong` | strong elevated / pressed |
| `surfaceDisabled` | disabled fill |
| `textPrimary` | titles / primary text |
| `textSecondary` | secondary — clearly readable |
| `textMuted` | muted — subdued, **not** disabled |
| `textDisabled` | disabled — visibly lower contrast |
| `textInverse` | text on an inverted surface |
| `border` / `borderStrong` | hairline / emphasized border |
| `borderFocus` | 2px focus ring |
| `primary` | primary interaction colour (gold) |
| `primaryStrong` | pressed / active |
| `primaryContainer` | soft gold fill (chips, badges) |
| `onAction` | contrast-correct label on `primary` |
| `actionSecondary` / `onActionSecondary` | secondary button pair |
| `actionDestructive` / `onActionDestructive` | destructive button pair |
| `success` / `warning` / `error` / `info` | status, each with a `*Subtle` fill |
| `gameSolo` … `gamePractice` | game-mode accents, **distinct from status** |

Two helpers replace the old `SC.onColor`:

- `colors.onAction` — the fixed, AA-verified label colour for primary fills.
- `colors.foregroundOn(fill)` — for *dynamic* fills (game accents, heat colours);
  picks whichever brand foreground measures higher contrast, rather than guessing
  from a luminance threshold.

`colors.onColorLegacy(fill)` reproduces the old threshold rule and exists only so
the Phase 1 migration is provably pixel-identical. It is knowingly wrong in Light
theme (2.19:1 on light gold) and is retired as components adopt `onAction`.

## Dark theme tokens

| Role | Value |
|---|---|
| background | `#17191E` |
| surface (base card) | `#23262D` |
| surfaceElevated | `#2C3038` |
| surfaceStrong | `#343944` |
| textPrimary | `#F4F1EA` (warm near-white) |
| textSecondary | `#C4C8CE` |
| textMuted | `#8C929C` |
| textDisabled | `#5C626C` |
| borderSubtle | `#313640` |
| borderStrong | `#3C424D` |
| divider | `#262A31` |
| primary (gold) | `#DDB75F` |
| primaryStrong | `#C79B45` |
| primaryContainer | gold @ 16% over surface |
| onPrimary | `#1B1D22` |
| success / warning / error / info | `#57B37E` / `#DDB75F` / `#E06B6B` / `#7FA0BE` |

Three→four clearly separated surface levels (17 → 23 → 2C → 34) give depth
without heavy shadows. Avoid muddy brown surfaces.

## Light theme tokens

| Role | Value |
|---|---|
| background | `#F7F5F0` (warm off-white) |
| surface (base card) | `#FFFFFF` |
| surfaceElevated | `#F1ECE2` |
| surfaceStrong | `#E8E2D5` |
| textPrimary | `#262A31` (deep charcoal, not black) |
| textSecondary | `#58606B` |
| textMuted | `#6E747E` (AA ≥ 4.5:1 on surface) |
| textDisabled | `#AEB2BA` |
| borderSubtle | `#E4E0D7` |
| borderStrong | `#D4CFC3` |
| divider | `#ECE8DF` |
| primary (gold) | `#CDA34B` |
| primaryStrong | `#B78D3A` |
| primaryContainer | gold @ 14% |
| onPrimary | `#262A31` |
| success / warning / error / info | `#3E9A66` / `#B78D3A` / `#C85A5A` / `#5B7C9E` |

White + warm neutrals with deliberate contrast — not a flat cream sheet, not
sterile blue-white.

## Hierarchies

- **Surface:** background < base card < elevated/interactive < strong/pressed.
  Cards must separate from the background (tonal step in dark; step + subtle
  border/soft shadow in light).
- **Text:** primary (titles) → secondary (readable) → muted (subdued) →
  disabled (clearly lower). Never create secondary text with opacity; use the
  token. Muted must not read as disabled.
- **Icon:** `iconPrimary` (active/interactive) → `iconSecondary` (supporting) →
  `textDisabled` (disabled) → status colors (success/warning/error/info). Do not
  set arbitrary per-widget opacity.
- **Border:** `borderSubtle` for hairlines, `borderStrong` for emphasis,
  `divider` for list separators.

## Elevation & shadow

- **Dark:** prefer tonal surface steps + faint borders; restrained shadows only
  (no large black drop shadows).
- **Light:** soft, low-opacity warm shadows + subtle borders so white cards do
  not vanish into the background.

## Disabled states

Use `surfaceDisabled`/`textDisabled` (and reduced, not zero, contrast). A
disabled control must look intentionally unavailable; an available control must
never look disabled. Never rely on invisible opacity.

## Gold rules (the accent discipline)

**Use gold for:** primary/CTA buttons (with dark on-gold text), the Weekly
Challenge primary action, active/selected navigation, selected segments/toggles,
`Switch`/slider/progress, achievement/rank/streak highlights, key result
emphasis, important interactive icons, small badge/chip fills (`goldContainer`).

**Do not use gold for:** page/card backgrounds, body text, every icon, every
selected control, generic secondary labels, or disabled states. Gold ≈ 5–10% of
any screen's pixels — a spark, not a wash.

## Accessibility

Target **WCAG AA** (≥ 4.5:1 body text, ≥ 3:1 large text/icons). On-gold content
uses dark charcoal (gold luminance ≈ 0.48 → dark text). Validate both themes and
both languages; never encode meaning by color alone (pair with icon/label).

## Correct vs incorrect

✅ Gold CTA button, dark charcoal label; gray card; secondary text in
`textSecondary`. ✅ Active tab gold, inactive `textMuted`. ✅ Featured weekly card
= elevated surface + subtle gold border + gold CTA.
❌ Gold card background with white text. ❌ Body paragraphs in gold. ❌ Every nav
item gold. ❌ Secondary text as `textPrimary.withOpacity(0.4)`. ❌ Raw `Color(0x…)`
inside a feature widget.

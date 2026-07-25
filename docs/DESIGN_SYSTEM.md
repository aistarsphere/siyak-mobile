# Design System — Siyaq

The refined graphite + gold system. All colors are centralized in
`lib/core/theme/app_tokens.dart` (`AppTokens.light` / `AppTokens.dark`) and
surfaced to custom screens through `SC` (`lib/core/theme/siyag_theme.dart`) and
to Material via `AppTheme` (`lib/core/theme/app_theme.dart`). **Never hardcode
hex in feature widgets — use a semantic token.**

## Brand identity

Premium, intelligent, minimal, **Arabic-first** semantic word game. Dark
charcoal foundation, warm **gold** accent. Calm and sophisticated — never
childish, neon, gradient-heavy, or "every component is gold." Gold communicates
**importance and interaction**, not decoration.

## Semantic roles

`SC` getter → `AppTokens` role (legacy `SC` names kept to avoid churn):

| SC getter | Role | Meaning |
|---|---|---|
| `bg` | `background` | app canvas |
| `surface` | `surface` | base card |
| `surfaceHi` | `surfaceElevated` | elevated / interactive card |
| `surfaceHover` | `surfaceStrong` | strong elevated / pressed |
| `text` | `textPrimary` | titles / primary text |
| `textDim` | `textSecondary` | secondary — clearly readable |
| `textMute` | `textMuted` | muted — subdued, **not** disabled |
| `textFaint` | `textDisabled` | disabled — visibly lower contrast |
| `line` | `borderSubtle` | hairline separation |
| `lineStrong` | `borderStrong` | emphasized border |
| `coral`* | `primary` (gold) | primary interaction color |
| `gold` | `accentGold` (= primary) | achievement / premium / rank |
| `goldStrong` | `primaryStrong` | pressed / active gold |
| `goldContainer` | `primaryContainer` | soft gold fill (chips, badges) |
| `onGold` / `onAccent` | `onPrimary` | dark charcoal on gold |
| `emerald` | `success` | accepted / solved |
| `cyan` | `info` | hint / informational / cold |
| `warning` / `error` | `warning`/`error` | status |

\* `SC.coral` is a historical name that now resolves to the gold **primary**.
`SC.onColor(fill)` returns a readable foreground for any fill (dark on gold,
light on graphite/green/info).

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

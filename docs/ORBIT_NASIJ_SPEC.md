# Orbit — the Nasīj board specification

Extracted from `Siyaq Game Variants.dc.html` (Claude Design project
`a17d4dc4-…`, read 2026-07-30). That file ships the prototype's **own layout
logic**, so this is the design's algorithm, not an interpretation of a picture.

Implemented as a pure model in `lib/features/game/domain/orbit/nasij_geometry.dart`
with 39 tests in `test/unit/nasij_geometry_test.dart`. No rendering yet.

## Vocabulary

The design names things deliberately and the code keeps the names: the board is a
**weave** (نسيج / Nasīj), each guess is a **thread** (خيط) drawn from the rim
inward, its endpoint carries a **bead**, the hull joining nearby tips is the
**rosette**, and the secret at the centre is the **knot**.

## Design space

Authored in a 280×280 viewBox, scaled to the rendered size.

| Constant | Value |
|---|---|
| centre `C` | 140 |
| rim `R` | 118 |
| golden angle `GA` | 137.508° |
| tip clamp | `R − 22` = 96 |
| tip floor | 14 |
| bow | 9° |
| guide rings | 96, 70, 44 (dashed) + 118 rim + 122 filled backdrop |

## Bands

| Band | Score ≥ | `w` | `w2` | Bead |
|---|---|---|---|---|
| Touching | 90 | 5.5 | 6.5 | 4.9 |
| Near | 70 | 4.0 | 5.0 | 4.4 |
| Related | 45 | 3.0 | 4.0 | 3.9 |
| Adjacent | 20 | 2.2 | 3.2 | 3.4 |
| Distant | 0 | 1.5 | 2.4 | 2.9 |

Bead radius is `2.4 + tier × 0.5`. **Stroke width rises with the band**, so
proximity is legible without colour — which is what satisfies the "do not use
colour alone" requirement.

## Placement

```
angle(i)  = (start + sign × i × 137.508°) mod 360      LTR: start 12°,  sign +1
                                                        RTL: start 168°, sign −1
tipRadius = min(96, 14 + (118 − 14) × (1 − score/100))
control   = angle + sign × 9°, at radius (R + tipRadius) / 2
thread    = M rim Q control tip          (quadratic, rim → inward)
label     = tip + 8·(cos a, sin a) + 12·(−sin a, cos a)
anchor    = cos a < −0.15 → end ; > 0.15 → start ; else middle
```

**Collision handling is the golden angle.** Successive threads step by an
irrational fraction of a turn, so directions never repeat and no resolution pass
is needed — verified in test with 40 threads (minimum gap > 1°). This is why the
brief's "deterministic angular placement with collision resolution" needs no
jitter: placement depends only on submission index and score, so a session draws
the same weave on every rebuild, restore and device.

⚠️ **Order is submission order.** The gameplay API returns `previous_guesses`
rank-ordered (see `docs/` release-composition work), so a caller must restore
submission order — `guess_history` carries `attempt_number` — or the board
rearranges itself between frames. Pinned by test.

## Rosette

Hull through the tips of every thread at Adjacent or better, sorted by angle,
joined by quadratic segments whose control points are pulled **28% toward the
centre**. Closed. Drawn only at ≥ 3 qualifying threads; fill `--sy-p4` at 8–9%,
stroke `--sy-p2` at 1–1.4.

## Hint wedge

A pie slice from the centre spanning between the player's **two strongest**
threads, radius `R`, fill `--sy-p3` at 18%. Large-arc when the sweep exceeds π.
The design is explicit: **no numbers are ever shown**.

## Layout choice

Three layouts were designed; the recommendation is **1a "board-led"**:

- board at **286px**, ~42% of the screen, keyboard up
- one last-result row always visible; full history one tap away in a sheet
- input pinned above the keyboard, always in the thumb arc
- **borrowed from 1c:** dismissing the keyboard expands the board to **356px**
  full-bleed "contemplation" view — same screen, two densities
- **borrowed from 1c:** top-3 chips appear only past **12 threads**

1b (196px medallion) was **rejected**: "the weave stops being beautiful and
becomes a badge… the screen edges toward the spreadsheet the brief rules out."
1c as default was rejected for adding a tap before every guess.

Phone frame in the mock: 330×714, radius 40.

## States

| State | Behaviour |
|---|---|
| Empty board | Rings, knot, one line of copy. **Never a skeleton** — the loom is already there. |
| First guess | One thread draws in over **520ms** |
| Several distant | Short stubs at the rim; sparse *is* the information |
| Mixed session | Spread of bands, rosette beginning to close |
| Close guess | Heavy accent thread to the inner ring, bead enlarged, rosette tight |
| Hint active | Wedge between the two strongest threads |
| Selected thread | Tapped thread to full opacity, **all others to 22%**, only its label shown |
| 26 threads | Past **24**, labels below Near collapse to beads and live in the list sheet |
| Reduced motion | Identical final frame, no draw-in: **cross-fade 120ms**, rosette does not re-stitch |

### Victory

Knot grows **7 → 38 over 900ms** (spring); threads hold; the word rises beneath;
glow radius 66 shimmering at 3s. **No confetti — the bloom is the celebration.**

### Defeat

Player threads fade to **40%**; one **dashed** thread (dasharray `6 9`, width 5,
`--sy-p5`) draws in from the rim carrying the answer. Copy in the design: *"It was
teacher. You came within two threads."* **No red, no buzz.**

## Accessibility — the design's own answer

> "The board is **excluded from semantics**; this list is the source of truth and
> announces *'tutor, Touching, rank 1 of 7'*. It is also what large-type mode
> grows into."

So the `CustomPainter` is `ExcludeSemantics`, and a parallel row list carries the
semantics and the taps. Row anatomy: 5×20 pill bar in the band colour, word, band
tag (white on band colour), rank. Nothing is lost when labels collapse — the list
holds every thread.

## Arabic — a different composition, not a mirror

- threads counter-clockwise from **168°**, so the first thread lands where the
  Arabic eye enters the board
- header stack right-weighted; result row reverses
- line-height rises to **1.75**
- **no letter-spacing and no uppercase anywhere** in Arabic
- Arabic-Indic numerals in the mock (`٧ خيوط`, `١#`)

## Discrepancy to resolve

The board's proximity ramp in this file differs from the one in
`Siyaq Prototype.dc.html` recorded in `DESIGN_MCP_EXTRACTION.md`:

| | p1 | p2 | p3 | p4 | p5 |
|---|---|---|---|---|---|
| Prototype (light) | neutral-600 | accent-2-400 | accent-2-500 | accent-400 | `#e2704a` |
| **Game Variants** | neutral-400 | accent-2-300 | accent-2-500 | accent (`#c67139`) | accent-700 (`#8c491a`) |

Game Variants is the gameplay-specific and more recent file, so the board should
use its ramp. `OrganicColors.proximity` currently holds the prototype values;
this needs an explicit decision before the board renders, and is **not** silently
reconciled.

## Not yet extracted

`styles.css`, `_ds_bundle.js`, `Siyaq Design System.dc.html`,
`Siyaq Explorations.dc.html`, `Siyaq Prototype standalone-src.dc.html`. Onboarding
and Profile detail still needs reading from the prototype before those screens are
built.

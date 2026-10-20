# fill. — Design System

Reference canvas: iPhone 16, 393 × 852 pt, portrait. All y-values are from the top of the screen unless marked "from bottom". Match within ±2 pt. Open `prototype/rewards-revamp.html` to see every state animate.

## 1. Color tokens

### 1.1 Challenge palette (one color per challenge, assigned round-robin; user can pick any of the 8)

| Token | Hex | Used for (examples) |
| --- | --- | --- |
| `orange` | `#FF6B1A` | default 1st challenge, welcome |
| `pink` | `#FF2D6F` | rings, onboarding 2 |
| `green` | `#13A866` | jar, onboarding 4 |
| `blue` | `#2F5BFF` | runs, notifications |
| `violet` | `#7A5CFF` | onboarding 3 |
| `teal` | `#00A3BC` | |
| `amber` | `#D99100` | |
| `ink` | `#111216` | (selectable as challenge color) |

Derived from the challenge color C:

- `tint` = C at 12–14% over white (cards, band background, pill background)
- `todayStripe` = repeating 45° stripes of C at 55% and 35% over white, 6 pt each, 2 pt top border in C
- `wave` = C (top edge of the fill)

### 1.2 Neutrals and semantic

| Token | Hex |
| --- | --- |
| `ink` (primary text, dark buttons) | `#111216` |
| `text2` | `#5C626E` |
| `text3` (labels, meta) | `#7A808C` |
| `bg` (sheets, overview) | `#F4F4F6` |
| `surface` | `#FFFFFF` |
| `hairline` | `#EEEFF2` |
| `chipBg` | `#F0F1F3` |
| `danger` (out of reach, missed) | `#E5484D` (missed stub at 75% opacity) |
| `success` (rewarded ✓) | `#13B26B` |
| `switchOn` | `#34C759` |

Dark mode: v1 ships light UI only (`.preferredColorScheme(.light)`). Challenge colors are vivid on white by design.

## 2. Typography

System font (SF Pro) and SF Mono. Use `Font.system(size:weight:design:)` with Dynamic Type scaling via `@ScaledMetric` for the large numbers (cap at 1.3× so hero numbers do not overflow).

| Style | Size / weight | Tracking | Used for |
| --- | --- | --- | --- |
| `hero` | 92 / heavy (62 if value > 4 chars) | −0.06 em | big number on challenge page |
| `heroUnit` | 15 / semibold | 0 | "of 20 wins" |
| `remaining` | 21 / heavy | −0.025 em | "11 wins to go in 18 days" |
| `pageTitle` | 30 / heavy | −0.035 em | challenge name |
| `overviewTitle` | 46 / black | −0.045 em | "Today" |
| `sentence` | 33 / heavy, line-height 1.25 | −0.035 em | Create sentence |
| `panelTitle` | 26 / heavy | −0.03 em | bottom panel titles |
| `onbTitle` | 38 / black | −0.045 em | onboarding titles |
| `welcomeTitle` | 45 / black, 1 line each | −0.05 em | "Reward yourself / to move." |
| `body` | 15–17 / medium | 0 | sub text |
| `monoLabel` | 10.5–13 / bold, UPPERCASE | +0.12…0.16 em | pills, labels, rule line (13, not uppercase) |
| `footValue` | 24 / heavy | −0.03 em | EARNED / NEXT WIN values |
| `celebrateValue` | 52 / heavy | −0.045 em | reward on celebration |

Numbers use tabular figures (`.monospacedDigit()`).

## 3. Spacing, radius, elevation

- Page side margin: 20 pt (onboarding 22–24 pt).
- Radius: pills 99; buttons 28–30 (height 54–60); cards/tiles 18–26; bottom sheets 30 (top corners).
- Shadows: primary buttons `0 10 24 -10 rgba(0,0,0,.35)`; floating bar `0 8 26 rgba(17,18,22,.18)`. Bottom-bar buttons are flat (no shadow) so the fill below them reads as one section.

## 4. Challenge page layout (393 × 852)

```text
y=60  Activity pill (left)          Day 13 of 30 (right, 13/semibold, text3)
y=94  Name (30 heavy)
      Rule line (mono 13, text3)    e.g. "Flexible · 20 of 30 days"
y=172 Day bars, height 40, side margins 20, gap 3 (1 if > 40 days)
y=250 Goal labels (mono 10.5, C)     left: max reward · right: ENDS 5 NOV
y=272 Goal line = 100% (1.5 dashed, C at 70%) ← RT
      —— progress area ——
      Floor: bottom 196 pt always filled with C ← FL (0%)
      Progress range PR = (852 - 272) - 196 = 384 pt
      Solid fill height fb = 196 + 384 × base
      Today band height lh = max(30, 384 × layer) (only if layer > 0), on top of fb
      Fill top fh = fb + lh
bottom 112 Footer grid (2 columns), white
bottom 26  Bottom bar (height 62)
```

Hero block (number + remaining line, ~140 pt tall):

- If fh ≥ 420: inside the fill, white, `bottom = fh - 140`.
- Else: above the fill, in C (remaining line in ink with C numbers), `bottom = fh + 16`; +54 when a today pill sits on the floor; +78 when the Log today button is shown.

Today pill: right-aligned, centered on the today band (`bottom = fb + lh/2 - 12`), white, mono 10.5 bold, C text. Log today button: full width (left/right 20), height 56, ink background, same vertical anchor.

First-win card: top = RT + 34, dashed 2 pt border C at 55%, radius 24, padding 16/18.

Rescue card: left/right 14, bottom 100, white, radius 26, shadow `0 18 40 -12 rgba(0,0,0,.35)`. When shown, fill and today band use `grayscale(.7)` + 45% opacity.

## 5. Components

| Component | Spec |
| --- | --- |
| Fill | Gel in C from bottom, one solid color (matches the pager bleed strip, so the bottom is seamless); top edge = flowing wave (~16 pt tall, two sines), with the striped today band on top while today is in progress. Pressing dents the gel with a jelly bounce and sends ripples along the surface. Tilt with device motion is optional (±3°). |
| TodayBand | Stripes (see 1.1), 2 pt top border, pulse opacity 1→0.65→1 over 1.8 s. |
| DayBars | Won: full height C, radius 3. Won by hand: stripes C/55% 3 pt. Missed: 10 pt tall danger. Today: C at 45% over white, height = todayRatio, 2 pt inset top line C. Future: 6 pt tall hairline gray. |
| GoalLine | 1.5 pt dashed, labels mono 10.5 bold C, 22 pt above the line. |
| ActivityPill | C background, white mono 11 bold uppercase, 13 pt metric icon (steps footprints, rings two circles, exercise bolt, run figure, sleep moon). Status variants: danger red, C for completed/rewarded. |
| Band (overview) | 92 pt, radius 24, tint background, fill C to base %, today segment C at 40%. Text duplicated: dark layer + white layer clipped to the fill width. |
| BottomBar | Left pill (white 92%, blur 20, radius 31, padding 5) with two 52 pt segments; active segment ink with white text. Right: 60 pt ink circle with "+". |
| Sheet | White, top radius 30, grab handle 40×5, scrim black 30%. |
| Stepper | bg container radius 20; 48 pt white square buttons; value 30 heavy in C, tap to type. |
| Chip | bg, radius 99, 13–15 semibold; selected = C background, white text. |
| Blank (Create) | Unfilled: 2.5 pt dashed white 55%, text white 60%, pulse. Locked: 35% opacity, no pulse. Filled: white pill, text C, shadow `0 6 0 rgba(0,0,0,.12)`. |
| Toast | Ink, radius 16, 14 semibold white, bottom 100, slides up, 2.6 s. |

## 6. Motion

| Motion | Duration / curve | SwiftUI |
| --- | --- | --- |
| Fill height, hero position | 1.1 s, cubic(0.3, 0.9, 0.3, 1) | `.timingCurve(0.3, 0.9, 0.3, 1, duration: 1.1)` |
| Sheet in/out | 0.45 s, cubic(0.3, 0.9, 0.2, 1) | same curve |
| Day won overlay | fade in 0.3 s, hold, fade out; total 2.6 s | — |
| Celebration rise | 0.8 s; trophy pop spring (response 0.6, damping 0.55) after 0.55 s; count-up 1.1 s ease-out cubic | — |
| Confetti | 70 pieces, fall 1.8–3.4 s, random spin | `Canvas`/`TimelineView` |
| Blank shake | 0.5 s, x ±6/±4/±3 | — |
| Log today pulse | ring 0→14 pt, 1.8 s ease-out loop | — |
| Welcome roll | every 2.3 s; old slides up & fades, new slides up from below, 0.55 s; background recolor 0.6 s | — |

Reduce Motion: no loops (wave, pulses, roll auto-advance becomes manual swipe), no confetti, fills jump to final value, overlays cross-fade only.

## 7. Haptics

- Day won: `.success`
- Challenge complete: success + 3 light impacts
- Gel touch: light `.impact` (at most once per 0.5 s while dragging)
- Blank locked tap: `.warning`
- Stepper: `.selection`

## 8. Icons

SF Symbols where possible: `figure.walk` (steps), `circle.circle` (rings), `bolt.fill` (exercise), `figure.run` (run), `moon.fill` (sleep), `square.grid.2x2` (All challenges), `gift` (Rewards), `airplane` (trip), `fork.knife` (food), `bag` (buy), `star.fill` (other), `banknote` (money), `pencil` (log today), `lock.fill`, `heart.fill` (Health), `gearshape` (Settings, proposed: 44 pt round chipBg button, top right of Overview at y=60, SPEC §7.11).

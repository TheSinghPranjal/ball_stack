# Primary Reference Analysis — "Helix Drop" web showcase

URL: https://helixdrop.manus-game-showcase.com/  · Inspected: 2026-11-14

## Method and limits

- The page is a single `<canvas>` web app (Vite bundle, three.js renderer, Rapier physics for debris,
  WebAudio-synthesised sound). Automated fetching cannot *play* it, so the observations below come
  from reading the shipped JavaScript bundle and its UI string table **as text** (gameplay rules,
  constants and copy). No code, art, audio or text was copied into this project; the numbers below
  were used only as a feel target and every value in our game is re-tuned and configurable.
- No screenshots could be captured from the sandbox (no browser automation was used). Visual notes come from
  the bundle's materials/colour tables and CSS. See `unknowns_and_assumptions.md`.

## Intro / title

- Title screen shows the live 3D tower behind a menu: *Daily tower* (same seed for everyone, per day),
  *Random practice*, *Leaderboard*, *Settings*, *Personal best*, *Today's best*.
- Hint copy: "A/D, ←/→ or drag to spin the tower". Spinning the tower or pressing Space starts a run.
- Loading copy: "Assembling the tower…".

## Tower and camera

| Property | Observed |
|---|---|
| Segments per floor | 16 equal angular slots (22.5° each) |
| Floor spacing | 3.3 world units |
| Platform | inner radius 0.8, outer radius 2.75, thickness 0.5 |
| Central pillar | radius ~0.85, banded colours |
| Floors per run | 6 stages × (10, 12, 14, 16, 18, 20) = 90 floors |
| Camera | perspective, 52° vertical FOV, follows ball downward, FOV kick on smash |
| Only nearby floors exist | floors from current−2 to current+12 are built; older ones disposed |

## Controls (confirmed from source)

- **Drag horizontally to rotate the tower** (mouse/touch). Drag delta maps directly to rotation; drag sensitivity is a setting.
- Keys A/D or ←/→ spin at a fixed angular speed (≈3.9 rad/s) with fast exponential smoothing.
- **There is no hold-to-fall in the primary reference.** The ball bounces on its own; the player only spins the tower.

## Ball behaviour

- Ball sits at a fixed screen angle, at the radial middle of the platforms; the *tower* rotates under it.
- Gravity ≈ 38 u/s², terminal velocity ≈ 24 u/s, bounce velocity ≈ 11.4 u/s, ball radius 0.3.
- Collision is resolved *logically*: when the ball crosses a floor's top plane while falling, the slot under
  the ball's angle (in tower-local space) decides the outcome.

## Surfaces

| Slot | Effect |
|---|---|
| safe | bounce, combo chain resets |
| gap | ball passes; floor shatters into flying wedges; chain +1 |
| danger (red, emissive) | death ("Hit a hazard!") |
| blink | periodically toggles between safe and danger (with a warning flicker) |
| sweeper | a red arm rotating around the floor; lethal where it currently is |

Gap width shrinks with progress (4 → 3 → 2 slots). Danger count grows per stage (0–5). Generator
protects the landing zone directly under the previous floor's gap from hazards (fairness rule).

## Scoring and combos

- Passing a floor: 10 × min(chain, 8). Chain = floors passed without bouncing.
- **Chain ≥ 3 enables SMASH MODE** ("Crash through the next floor!"): the next landing smashes that floor
  regardless of what is under the ball (+20 bonus), then smash mode ends.
- Near miss (bounce within ~0.16 rad of a hazard): +5, "Close call!".
- Stage clear: (stage+1) × 50. Reaching the base: 500 + time bonus (par 150 s, 5 pts/s).

## Game over / completion

- Death: ball shatters, red flash, slow-motion, results ("Crashed!") with floors, best chain, time, smashes.
- Win: "Reached the base!". Results offer retry, share, leaderboard submit.

## Pause / settings

- Pause: Resume, Restart, Title.
- Settings: language (EN/中文), drag sensitivity, graphics quality (Smooth/Balanced/Fancy),
  "reduce shake and flash", music/sfx volumes.

## Progression / rewards / customisation

- None beyond daily seed, personal best and leaderboard. No coins, no skins, no level map.
  These come from the secondary reference and the master brief.

## Feedback / juice observed

Floor-shatter physics debris, spark particles, paint splats where the ball bounces, ball trail, screen shake
scaled by chain, coloured flash on combo, stage colour-theme cross-fade, adaptive music intensity.

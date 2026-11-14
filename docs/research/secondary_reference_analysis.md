# Secondary Reference Analysis — "Drop Stack Ball – Helix Crash" (Google Play)

URL: https://play.google.com/store/apps/details?id=com.match3blaster.DropStackBallFall

## Method and limits

The Play Store page is client-rendered; the automated fetch only returned the title. Screenshots and
the gameplay video could not be viewed from this environment. The notes below describe the
well-documented "stack ball" sub-genre this listing belongs to and are marked **[assumed]** where they
could not be confirmed against this specific listing. All of them are implemented as a configurable,
separate control mode (`InputMode.smash`) so they never change the primary experience.

## Core loop [assumed, genre-standard]

- Tower of stacked rings rotates **automatically**.
- **Press and hold** → the ball dives and smashes through the ring layer it lands on (whole ring shatters).
- **Release** → the ball bounces normally on whatever it lands on (landing on black while *not* holding is safe).
- Smashing into a **black (dangerous) segment while holding** ends the run.
- Holding through many layers fills a **heat meter**; when full the ball becomes a **fireball**
  (glow + fire trail) that can smash black segments too. The meter drains when released / over time.
- Level ends on reaching the base platform; level number grows, rings get more black segments and
  rotation speeds vary/reverse.

## Meta [assumed]

- Level counter with progress bar between current/next level number.
- Ball skins unlocked with coins/rewards; rewarded-ad revive; interstitials between levels.
- Bright, saturated per-level colour themes, splash particles.

## What we adopt

| Feature | Adopted as |
|---|---|
| Hold-to-smash | `InputMode.smash` (selectable on Home + Settings) |
| Fireball | Heat meter → fireball state (configurable thresholds, duration, drain) |
| Whole-ring shatter | `DestructionSystem` shatters all live segments of the floor |
| Levels/progress bar | 300+ procedurally generated levels with seeds |
| Skins/coins | Ball shop with coin unlocks |
| Revive | Coin-paid revive (ads disabled by default; config switch) |

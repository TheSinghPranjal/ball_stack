# UI/UX Specification

Wireframes: `splash.png home.png level_selection.png gameplay.png pause.png game_over.png level_complete.png ball_shop.png settings.png`
Navigation: `navigation_flow.png`. Regenerate with `python3 tools/gen_wireframes.py`.

## Navigation flow

Splash → Home. Home → Game (Play = current level), Levels → Game, Balls (shop), Settings, Daily reward sheet.
Game → Pause (Resume / Restart / Home) · Game Over (Revive / Retry / Home) · Level Complete (Next / Replay / Home).
Android back: Game → opens Pause; Pause → resumes; other screens → pop.

## Colour palette (UI)

| Token | Hex | Use |
|---|---|---|
| ink | #1B1640 | text, outlines |
| night | #120E2E | dark backdrops |
| candy | #FF5A7A | primary CTA gradient start |
| tangerine | #FF9F43 | primary CTA gradient end |
| sky | #4FC3FF | secondary actions |
| mint | #3EE6B0 | success / owned |
| gold | #FFD447 | coins, stars |
| danger | #FF2E63 | hazards, failure |
| glass | white @ 14% | panels on 3D background |

Gameplay themes have their own palettes (`lib/app/theme/colors.dart` → `GameThemes`).

## Typography

System font, weights 600–900. Scale: display 44/900, h1 30/900, h2 22/800, body 16/600, caption 12/700 (letter-spacing 1.2).
Numbers use tabular figures. HUD score has 2px dark stroke for legibility over any theme.

## Spacing system

4-pt grid: 4, 8, 12, 16, 24, 32, 48. Screen gutters 16 (phones) / 24 (≥600 dp). Radii: chips 14, cards 24, sheets 28, pills = height/2.

## Components

ArcadeButton (primary gradient / secondary glass / icon round), CoinBadge, StatTile, ToggleTile, SegmentedPicker,
SliderTile, GlassPanel, LevelTile (locked/current/completed + stars), SkinTile, ProgressBar (level n → n+1),
PopupText (combo/smash/score), ScreenScaffold (gradient + safe area).

## Interaction specs

- Buttons: press scale 0.94 over 90 ms, release spring back 160 ms, light haptic + click sfx.
- Gameplay spin: horizontal pan anywhere on the 3D view; 1 screen-width ≈ 1.1 turns × sensitivity; release keeps
  momentum which decays (friction 9/s).
- Smash mode: touch-down = dive, touch-up = release; HUD shows heat meter.
- Popups rise 40 px and fade over 900 ms; max 6 alive.
- Overlays fade/scale in 220 ms; the world behind is frozen (pause) or continues debris only (game over).

## Responsive rules

- Portrait locked on phones. The 3D viewport is full-screen; camera framing derives its focal length from the
  shorter of (width, 0.62×height) so the tower is never cropped on tall/narrow or tablet screens.
- HUD sits inside `SafeArea`; top HUD ≤ 120 dp; bottom hint ≤ 64 dp; nothing overlaps the middle 60% of the screen.
- Level grid columns = clamp(width / 92, 4, 8). Shop grid = clamp(width / 96, 4, 7).
- Overlays max width 420 dp, centred.

# Unknowns and Assumptions

| # | Unknown | Assumption | Configurable via |
|---|---|---|---|
| 1 | Primary reference could not be played interactively (no browser automation) | Rules derived from bundle source text; feel tuned by us | `GameConstants` |
| 2 | Play Store screenshots/video not viewable | Genre-standard stack-ball rules | `InputMode.smash`, `FireballConfig` |
| 3 | Exact drag→angle mapping | 1 screen width of drag ≈ 1.1 turns × sensitivity | Settings › Sensitivity |
| 4 | Inertia after release | Primary has none; brief asks for it → light inertia (friction 9/s) | `RotationConfig.inertia` |
| 5 | Leaderboards | No backend in scope → not implemented, no button shown | – |
| 6 | Language | English only; no language row is shown (no dead buttons) | – |
| 7 | Monetisation | Ads SDK not integrated; switch `MonetizationConfig.enabled=false`; revive uses coins | `monetization_config.dart` |
| 8 | Physical-device testing | iPhone present but not in Developer Mode; no Android device/emulator configured. iOS Simulator + Android build used | PROJECT_STATUS.md |

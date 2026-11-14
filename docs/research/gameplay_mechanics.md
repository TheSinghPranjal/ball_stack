# Gameplay Mechanics Specification — Ball Game : Fire Ball

Original title: **Ball Game : Fire Ball**. Genre: helix tower drop. All values live in
`lib/core/constants/game_constants.dart` / `LevelConfig` and are tunable.

## World

- Units: metres-ish. Tower axis = Y. Floor `i` top surface at `y = -i * floorSpacing` (3.2).
- 16 slots per floor, slot `s` covers local angle `[s*Δ, (s+1)*Δ)`, Δ = 2π/16.
- Ball fixed at world angle 0 (facing camera) at radius 1.7. Tower rotation `phi`.
  **Ball local angle = wrap(0 − phi − floor.offset)** → slot index.

## Ball physics (fixed timestep 1/120 s)

```
vy = max(vy - gravity*dt, -terminal)
y += vy*dt
if crossing floor top plane while falling -> CollisionSystem.resolve(floor, localAngle, time)
```

| Param | Default |
|---|---|
| gravity | 36 |
| bounceVelocity | 11.2 |
| terminalVelocity | 23 |
| ballRadius | 0.3 |
| diveVelocity (smash mode hold) | 26 |

## Collision outcomes

| Slot kind | Spin mode | Smash mode (holding) | Smash mode (released) |
|---|---|---|---|
| safe | bounce, chain=0 | shatter ring | bounce |
| gap | fall through | (no gaps in smash mode) | – |
| danger | death (unless smash-ready or shield) | death unless fireball / shield | bounce |
| blink(on) | death | death unless fireball | bounce |
| blink(off) | bounce | shatter | bounce |
| breakable | bounce + segment breaks (+15) | shatter | bounce + break |
| bonus (gold) | bounce + coin (once) | shatter + coin | bounce + coin |
| sweeper arm | death | death unless fireball | bounce |

Edge cases: exact slot boundary uses `floor()` of wrapped angle (deterministic, boundary belongs to the
higher slot); multiple floors crossed in one step are processed in order (loop), so tunnelling is impossible.

## Combo / smash (spin mode)

- Chain +1 for each floor fallen through without bouncing. Max multiplier 8.
- Chain ≥ 3 → **smash-ready**: next landing shatters the floor whatever is there (+20), chain resets.

## Fireball (smash mode)

- Heat +0.12 per ring smashed while holding; heat ≥ 1 → fireball for up to 2.5 s (drains while active).
- When not holding, heat decays at 0.6/s. Fireball smashes danger rings; it never persists between runs.

## Scoring

| Event | Points |
|---|---|
| floor passed | 10 × min(chain, 8) |
| smash | 20 + floor points |
| ring smashed (smash mode) | 5 × min(streak, 8) |
| breakable broken | 15 |
| near miss | 5 (once per floor) |
| level complete | 100 + 5 × level |

## Coins

`coins = floor(score / 25) + bonusCoinsCollected + bestChain + (firstClear ? 25 + level : 0)`. Granted once per run
(run id guard). First-clear bonus granted once per level ever.

## Fail / win

- Death → `gameOver`; optional one revive per run (costs coins, or rewarded ad when monetisation enabled).
- Ball reaches base below last floor → `levelCompleted`.

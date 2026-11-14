# Ball Game : Fire Ball — Technical Architecture

## 1. Package selection and the rendering decision

| Need | Choice | Why |
|---|---|---|
| App state / DI / routing | `get` 4.7 | Required by brief; reactive `Rx` for HUD, bindings for DI |
| Persistence | `shared_preferences` | Profile is one small JSON document + settings; a database is unnecessary (documented) |
| Audio | `audioplayers` 6.8 (`AudioPool` for SFX, looping player for music) | Mature on Android/iOS, low-latency pools |
| 3D rendering | **In-house real-time 3D renderer on `Canvas.drawVertices`** | see below |
| Physics / collision | Custom deterministic Dart | Brief requirement; logical collision instead of mesh overlap |

### three_js evaluation (rejected for v1, swappable later)

`three_js` 0.3.0 (pub.dev, checked 2026-11-14) renders through ANGLE/`flutter_angle` external textures. Its own
README lists open issues on our two target platforms: *"iOS: Protoplanets doesn't function correctly"*, *"Android:
Morph targets fail on some devices; some RGBELoaders crash the app"*, PMREM artifacts on all platforms, and states
GPU support is "currently under development" with the ANGLE backend moving to a package that "does not exist" yet.
The brief requires physical-device validation before committing; no physical device is available in this environment
(the attached iPhone is not in Developer Mode and no Android device is configured), so its texture interop and
lifecycle handling cannot be validated. Committing the core of a commercial game to that is a production risk.

**Alternative chosen:** a small purpose-built 3D pipeline in Dart:

- Real 3D meshes (vertices, normals, per-vertex colours) for ball, tower, platforms, hazards, debris.
- Model/view/perspective transforms, back-face culling, per-vertex Blinn–Phong + hemisphere lighting, depth fog.
- Painter's-algorithm depth sort (O(n) bucket sort) and **one `drawVertices` call per frame** → GPU-rasterised by Skia/Impeller.
- No platform channels, no external textures → identical on Android and iOS, survives backgrounding, trivially disposable.
- Our scene is ≈2–5k triangles; budget measured in `docs/testing/performance.md`.

The renderer sits behind `SceneRenderer`; the game engine only produces a `RenderScene` (meshes + transforms),
so a GPU backend (three_js / flutter_gpu) can replace it without touching gameplay.

## 2. Layering (MVVM, feature-first)

```mermaid
flowchart TB
  subgraph Presentation [View: Flutter widgets]
    Screens[Screens & overlays] --> SceneView[GameSceneView CustomPainter]
  end
  subgraph ViewModel [GetX controllers]
    GameController
    HomeController
    ShopController
    LevelSelectController
    SettingsController
  end
  subgraph Engine [Gameplay engine - pure Dart, no widgets]
    GameEngine --> GameLoop
    GameEngine --> StateMachine[GameStateMachine]
    GameEngine --> Sim[Simulation]
    Sim --> Ball[BallController]
    Sim --> Rot[RotationController]
    Sim --> Coll[CollisionSystem]
    Sim --> Combo[ComboSystem]
    GameEngine --> Destr[DestructionSystem]
    GameEngine --> Part[ParticleSystem]
    GameEngine --> Cam[CameraController]
    GameEngine --> Scene[SceneManager]
    Scene --> Tower[TowerController / PlatformController]
  end
  subgraph Render [core/render3d]
    SceneRenderer --> Mesh & Camera3D & Lighting
  end
  subgraph Data [Repositories / services]
    PlayerRepository --> Storage[(SharedPreferences)]
    SettingsRepository --> Storage
    LevelGenerator
    AudioService
  end
  Screens --> ViewModel
  GameController --> GameEngine
  SceneView --> SceneRenderer
  Scene --> SceneRenderer
  ViewModel --> Data
```

Rules: the engine never imports Flutter widgets or GetX; the renderer never mutates game state; controllers
translate engine events into `Rx` values and persistence.

## 3. Game loop

```mermaid
sequenceDiagram
  participant T as Ticker (vsync)
  participant L as GameLoop
  participant E as GameEngine
  participant S as Simulation (fixed 1/120 s)
  participant V as GameSceneView
  T->>L: tick(elapsed)
  L->>E: frame(dt clamped to 0.1)
  E->>E: read InputController
  loop accumulator >= step
    E->>S: step(step, input)
    S-->>E: List<GameEvent>
  end
  E->>E: dispatch events (state machine, destruction, combo FX, audio, HUD)
  E->>E: update particles, debris, camera (variable dt, interpolated)
  E->>V: notifyListeners()
  V->>V: SceneRenderer.render(canvas)
```

Only one `GameLoop` exists per `GameEngine`; it is owned by the game screen state, stopped on pause and
`AppLifecycleState.paused/inactive`, and disposed with the screen — returning to the app never creates a second loop.

## 4. State machine

```mermaid
stateDiagram-v2
  [*] --> initializing
  initializing --> loading
  loading --> ready
  ready --> intro
  intro --> playing
  playing --> falling
  falling --> bouncing
  bouncing --> falling
  falling --> combo
  combo --> falling
  combo --> destruction
  falling --> destruction
  bouncing --> destruction
  destruction --> falling
  destruction --> bouncing
  playing --> paused
  falling --> paused
  bouncing --> paused
  combo --> paused
  destruction --> paused
  paused --> playing
  falling --> gameOver
  bouncing --> gameOver
  combo --> gameOver
  destruction --> gameOver
  falling --> levelCompleted
  combo --> levelCompleted
  destruction --> levelCompleted
  gameOver --> playing: revive
  gameOver --> restarting
  levelCompleted --> restarting
  paused --> restarting
  restarting --> ready
```

`paused → playing` resumes the remembered active sub-state. Any other transition is rejected (returns `false`, logged).

## 5. Data model

```mermaid
classDiagram
  class LevelConfig {
    int levelId; int seed; Difficulty difficulty; InputMode mode
    int floorCount; double floorSpacing; double platformInnerRadius
    double platformOuterRadius; double platformThickness
    double rotationSpeed; int rotationDirection
    double ballStartHeight; double gravity; double bounceVelocity
    List~FloorSpec~ floors; int themeIndex; double scoreMultiplier
    RewardConfig reward; int parScore
  }
  class FloorSpec { int index; double offset; List~SegmentType~ slots; BlinkSpec? blink; SweeperSpec? sweeper }
  class SegmentType { <<enum>> safe gap danger blink breakable bonus }
  class PlayerProfile { int currentLevel; int highestUnlocked; Map levelStars; Map levelBest; int bestScore; int bestCombo; int coins; Set ownedSkins; String selectedSkin; int shields; String lastDailyClaim; int dailyStreak; Set rewardedRunIds }
  class GameSettings { bool music; bool sfx; bool haptics; GraphicsQuality quality; double sensitivity; bool reduceMotion; InputMode mode }
  class BallSkin { String id; String name; int price; Color base; Color accent; BallPattern pattern; double gloss; Color? emissive; Color trail }
  LevelConfig "1" *-- "many" FloorSpec
  FloorSpec "1" *-- "16" SegmentType
```

Levels are **generated**, not stored: `LevelGenerator.generate(level, mode)` is a pure function of
`(level, mode)` using a seeded PRNG (`seed = fnv1a("spiral-plunge/$mode/$level")`), so restarting a failed level
recreates the identical tower. Generated configs are cached.

## 6. Asset dependencies

```mermaid
flowchart LR
  SkinCatalog --> BallMeshFactory --> SceneManager
  ThemePalette --> PlatformController --> SceneManager
  LevelGenerator --> LevelConfig --> PlatformController
  AudioService --> sfx[(assets/audio/sfx/*.wav)]
  AudioService --> music[(assets/audio/music/*.wav)]
  Splash & Home --> logo[(assets/images/logo/logo.png)]
```

3D geometry is procedural (no model files to load); see `assets/asset_manifest.json`.

## 7. Performance strategy

- Fixed-capacity typed buffers reused every frame; no per-frame `List` growth in the hot path.
- Only floors in `[current−2, current+visibleAhead]` are meshed; meshes cached per floor and rebuilt only on change.
- Back-face culling before lighting; bucket sort instead of comparison sort.
- Debris and sparks come from fixed pools (no allocation during play).
- Graphics quality scales visible floors, arc subdivision, sphere resolution, particle density and trail length.
- HUD uses `Obx` on narrowly scoped `Rx` values; the 3D view repaints via a `Listenable`, not `setState`.

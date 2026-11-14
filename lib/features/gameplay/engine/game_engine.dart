import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme/colors.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/dev/autopilot.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/render3d/color_math.dart';
import '../../../core/render3d/scene_renderer.dart';
import '../../shop/domain/ball_skin.dart';
import '../domain/game_event.dart';
import '../domain/level_config.dart';
import '../domain/quality_profile.dart';
import 'audio_controller.dart';
import 'camera_controller.dart';
import 'collision_system.dart';
import 'game_loop.dart';
import 'game_state_machine.dart';
import 'input_controller.dart';
import 'scene_manager.dart';
import 'simulation.dart';

/// Engine-level settings snapshot (kept free of GetX so the engine stays framework-agnostic).
class EngineSettings {
  const EngineSettings({
    this.quality = GraphicsQuality.high,
    this.sensitivity = 1.0,
    this.reduceMotion = false,
    this.inertia = true,
  });

  final GraphicsQuality quality;
  final double sensitivity;
  final bool reduceMotion;
  final bool inertia;
}

/// One-shot visual cue for the HUD layer (flash colour/strength).
class FlashCue {
  const FlashCue(this.color, this.strength);

  final int color;
  final double strength;
}

/// Orchestrates the game: fixed-step simulation, state machine, FX, camera and rendering.
/// Listeners (the view) are notified once per rendered frame.
class GameEngine extends ChangeNotifier {
  GameEngine({
    required LevelConfig level,
    required BallSkin skin,
    this.settings = const EngineSettings(),
    this.initialShields = 0,
    GameAudioSink? audioSink,
  }) : _level = level,
       _skin = skin,
       audio = AudioController(audioSink),
       input = InputController(mode: level.mode) {
    input.sensitivity = settings.sensitivity;
    camera.reduceMotion = settings.reduceMotion;
    fsm.addListener((from, to) => onPhaseChanged?.call(from, to));
    _load();
  }

  final EngineSettings settings;
  final int initialShields;
  final GameStateMachine fsm = GameStateMachine();
  final CameraController camera = CameraController();
  final SceneRenderer renderer = SceneRenderer();
  final AudioController audio;
  final InputController input;
  final InputFrame _frame = InputFrame();

  LevelConfig _level;
  BallSkin _skin;
  late Simulation sim;
  late SceneManager scene;
  late GameTheme theme;

  /// Fog tint matching the neon-city backdrop drawn behind the scene.
  static const int neonFogColor = 0xFF2C1A78;
  GameLoop? _loop;

  // UI hooks
  void Function(GameEvent e)? onGameEvent;
  void Function(GamePhase from, GamePhase to)? onPhaseChanged;
  void Function(FlashCue cue)? onFlash;

  double _acc = 0;
  double _hitstop = 0;
  double _timeScale = 1;
  double _endTimer = -1;
  bool _endWon = false;
  double _renderTowerAngle = 0;
  double _renderBallY = 0;
  double _squash = 0;
  ui.Size _viewSize = ui.Size.zero;
  int _runCounter = 0;
  late String runId;
  bool _disposed = false;

  LevelConfig get level => _level;
  GamePhase get phase => fsm.state;
  QualityProfile get quality => QualityProfile.of(settings.quality);
  double get averageFrameMs => (_loop?.averageFrame ?? 0) * 1000;
  double get worstFrameMs => (_loop?.worstFrame ?? 0) * 1000;
  bool get isLoopRunning => _loop?.isRunning ?? false;
  double get ballY => _renderBallY;
  double get towerAngle => _renderTowerAngle;

  // ------------------------------------------------------------------ lifecycle

  void _load() {
    fsm.transition(GamePhase.loading);
    _buildWorld();
    fsm.transition(GamePhase.ready);
  }

  void _buildWorld() {
    theme = GameThemes.forIndex(_level.themeIndex);
    sim = Simulation(_level, shields: initialShields);
    scene = SceneManager(
      level: _level,
      theme: theme,
      skin: _skin,
      quality: quality,
      floorStates: sim.floorStates,
      fogColor: neonFogColor,
    );
    sim.rotation.inertiaEnabled = settings.inertia;
    input
      ..mode = _level.mode
      ..reset();
    _acc = 0;
    _hitstop = 0;
    _timeScale = 1;
    _endTimer = -1;
    _squash = 0;
    _renderBallY = sim.ball.y;
    _renderTowerAngle = 0;
    runId = '${_level.levelId}-${DateTime.now().microsecondsSinceEpoch}-${_runCounter++}';
    camera.reset(sim.ball.y);
    scene.sync(dt: 0, towerAngle: 0, ballY: sim.ball.y, time: 0, currentFloor: 0, squash: 0, fire: false, glow: false);
  }

  /// Binds the loop to a vsync provider (the game screen). Safe to call once per screen.
  void attach(TickerProvider vsync) {
    _loop ??= GameLoop(vsync, _onFrame);
  }

  /// ready → intro, starts ticking.
  void begin() {
    if (fsm.state == GamePhase.ready) fsm.transition(GamePhase.intro);
    _loop?.start();
  }

  void pause() {
    if (fsm.pause()) {
      input.reset();
      _loop?.stop();
    }
  }

  void resume() {
    if (fsm.resume()) _loop?.start();
  }

  /// Restarts the current level (or loads [next]) through restarting → ready → intro.
  void restart({LevelConfig? next}) {
    if (!fsm.transition(GamePhase.restarting)) return;
    if (next != null) _level = next;
    _buildWorld();
    fsm.transition(GamePhase.ready);
    begin();
  }

  bool get canRevive => fsm.state == GamePhase.gameOver && sim.canRevive;

  void revive() {
    if (!canRevive) return;
    sim.revive();
    scene.ballVisible = true;
    camera.snapTo(sim.ball.y);
    _timeScale = 1;
    _endTimer = -1;
    fsm.transition(GamePhase.playing);
    _loop?.start();
  }

  void setSkin(BallSkin skin) {
    _skin = skin;
    scene.skin = skin;
  }

  /// Live sensitivity changes from the pause menu.
  void setSensitivity(double s) => input.sensitivity = s;

  // ------------------------------------------------------------------ frame

  bool get _simulating {
    final s = fsm.state;
    return s == GamePhase.playing ||
        s == GamePhase.falling ||
        s == GamePhase.bouncing ||
        s == GamePhase.combo ||
        s == GamePhase.destruction;
  }

  void _onFrame(double rawDt) {
    if (_disposed || fsm.isPaused) return;
    final dt = math.min(rawDt, 0.1);

    if (fsm.state == GamePhase.intro) {
      if (input.touchedSinceReset) camera.skipIntro();
      if (camera.introDone) fsm.transition(GamePhase.playing);
    }

    if (_simulating && !sim.over) {
      Autopilot.drive(this, dt);
      _stepSimulation(dt);
    } else {
      // keep interpolation snapshots consistent while not simulating
      _renderBallY = sim.ball.y;
      _renderTowerAngle = sim.rotation.angle;
    }

    if (fsm.state == GamePhase.playing && !sim.over) fsm.transition(GamePhase.falling);
    if (fsm.state == GamePhase.bouncing && sim.ball.vy < 0) fsm.transition(GamePhase.falling);

    if (_endTimer >= 0) {
      _endTimer -= dt;
      if (_endTimer < 0) {
        fsm.transition(_endWon ? GamePhase.levelCompleted : GamePhase.gameOver);
      }
    }

    _squash = math.max(0, _squash - dt * 6);
    _timeScale += (1 - _timeScale) * (1 - math.exp(-dt * 2.5));
    final fire = sim.fireball || (sim.combo.smashReady && !sim.over);
    if (scene.ballVisible) camera.follow(_renderBallY);
    camera.update(dt);
    scene.sync(
      dt: dt * (_endTimer >= 0 ? math.max(0.35, _timeScale) : 1),
      towerAngle: _renderTowerAngle,
      ballY: _renderBallY,
      time: sim.time,
      currentFloor: math.min(sim.floor, _level.floorCount),
      squash: _squash,
      fire: fire,
      glow: sim.grace > 0 && (sim.time * 12).floor().isEven,
    );
    _applyCamera();
    notifyListeners();
  }

  void _stepSimulation(double dt) {
    if (_hitstop > 0) {
      _hitstop -= dt;
      return;
    }
    _acc += dt * _timeScale;
    const step = GameConstants.fixedStep;
    final expected = math.min((_acc / step).floor(), GameConstants.maxStepsPerFrame);
    var taken = 0;
    while (_acc >= step && taken < GameConstants.maxStepsPerFrame) {
      input.fill(_frame, taken, expected);
      final events = sim.step(step, _frame);
      _acc -= step;
      taken++;
      for (final e in events) {
        _handle(e);
      }
      if (sim.over) {
        _acc = 0;
        break;
      }
    }
    if (taken == GameConstants.maxStepsPerFrame) _acc = 0; // drop backlog after a hitch
    input.endFrame(taken);
    final alpha = (_acc / step).clamp(0.0, 1.0);
    _renderBallY = sim.ball.prevY + (sim.ball.y - sim.ball.prevY) * alpha;
    _renderTowerAngle = sim.rotation.prevAngle + (sim.rotation.angle - sim.rotation.prevAngle) * alpha;
  }

  // ------------------------------------------------------------------ event → FX / state

  void _handle(GameEvent e) {
    audio.onEvent(e, sim.time);
    const r = GameConstants.ballOrbitRadius;
    final y = sim.ball.y;
    switch (e.type) {
      case GameEventType.bounce:
        fsm.transition(GamePhase.bouncing);
        _squash = 1;
        final spec = _level.floors[e.floor];
        final slotColor = CollisionSystem.effectiveType(spec, sim.floorStates[e.floor], e.slot) == SegmentType.danger
            ? theme.dangerRim
            : (e.slot.isEven ? theme.safeA : theme.safeB);
        // Only a short-lived particle splash: persistent paint splats left marks on the tiles.
        scene.particles.splash(0, y - GameConstants.ballRadius, r, ColorMath.lerp(slotColor, 0xFFFFFFFF, 0.3));
      case GameEventType.floorPassed:
        fsm.transition(e.chain >= 2 ? GamePhase.combo : GamePhase.falling);
        scene.destruction.shatterFloor(_level, _level.floors[e.floor], sim.floorStates[e.floor], sim.rotation.angle, 1);
        scene.particles.burst(
          0,
          _level.floorTop(e.floor),
          r,
          count: 10 + e.chain * 3,
          color: theme.accent,
          speed: 3,
          size: 0.1,
          life: 0.5,
        );
        scene.clearSplatsOn(e.floor);
        camera.shake(0.04 + 0.025 * e.chain);
        if (e.chain >= 2) onFlash?.call(FlashCue(theme.accent, math.min(0.12 + e.chain * 0.04, 0.32)));
      case GameEventType.smashReady:
        fsm.transition(GamePhase.destruction);
      case GameEventType.smashed:
        scene.destruction.shatterFloor(_level, _level.floors[e.floor], sim.floorStates[e.floor], sim.rotation.angle, 2);
        scene.particles.burst(0, _level.floorTop(e.floor), r, count: 60, color: 0xFFFFE27A, speed: 8, size: 0.14);
        scene.clearSplatsOn(e.floor);
        fsm.transition(GamePhase.falling);
        camera
          ..shake(0.4)
          ..kick();
        _hitstop = 0.06;
        onFlash?.call(const FlashCue(0xFFFFFFFF, 0.55));
      case GameEventType.ringSmashed:
        scene.destruction.shatterFloor(
          _level,
          _level.floors[e.floor],
          sim.floorStates[e.floor],
          sim.rotation.angle,
          sim.fireball ? 1.8 : 1.2,
        );
        scene.particles.burst(
          0,
          _level.floorTop(e.floor),
          r,
          count: sim.fireball ? 26 : 12,
          color: sim.fireball ? 0xFFFF8A2A : theme.accent,
          speed: 5,
          size: 0.11,
        );
        scene.clearSplatsOn(e.floor);
        fsm.transition(sim.fireball ? GamePhase.destruction : GamePhase.combo);
        camera.shake(sim.fireball ? 0.12 : 0.05);
      case GameEventType.segmentBroken:
        scene.destruction.breakSegment(_level, _level.floors[e.floor], e.slot, sim.rotation.angle);
        scene.tower.markDirty(e.floor);
        scene.particles.burst(0, _level.floorTop(e.floor), r, count: 18, color: theme.safeB, speed: 4);
        camera.shake(0.08);
      case GameEventType.bonusCollected:
        scene.tower.markDirty(e.floor);
        scene.particles.burst(0, y, r, count: 22, color: 0xFFFFD447, speed: 4.5, size: 0.12, gravity: 4);
      case GameEventType.nearMiss:
        break;
      case GameEventType.shieldUsed:
        scene.particles.burst(0, y, r, count: 40, color: 0xFF4FC3FF, speed: 6, size: 0.13);
        camera.shake(0.2);
        onFlash?.call(const FlashCue(0xFF4FC3FF, 0.4));
      case GameEventType.comboReset:
        break;
      case GameEventType.fireballOn:
        fsm.transition(GamePhase.destruction);
        scene.particles.burst(0, y, r, count: 40, color: 0xFFFF8A2A, speed: 6);
        onFlash?.call(const FlashCue(0xFFFF8A2A, 0.35));
      case GameEventType.fireballOff:
        fsm.transition(GamePhase.falling);
      case GameEventType.death:
        scene.ballVisible = false;
        scene.particles
          ..burst(0, y, r, count: 70, color: theme.dangerRim, speed: 7, size: 0.14, life: 0.9)
          ..burst(0, y, r, count: 30, color: scene.skin.base, speed: 5, size: 0.12, life: 0.9);
        camera.shake(0.5);
        _timeScale = 0.35;
        _endTimer = 0.95;
        _endWon = false;
        onFlash?.call(FlashCue(theme.dangerRim, 0.55));
      case GameEventType.levelComplete:
        fsm.transition(GamePhase.falling);
        for (final c in [0xFFFF5A7A, 0xFFFFD447, 0xFF3EE6B0, 0xFF4FC3FF, 0xFFB18CFF]) {
          scene.particles.burst(0, y + 0.5, r, count: 24, color: c, speed: 9, size: 0.13, life: 1.4, upBias: 6);
        }
        camera.shake(0.2);
        _endTimer = 1.2;
        _endWon = true;
        onFlash?.call(FlashCue(theme.accent, 0.4));
    }
    onGameEvent?.call(e);
  }

  // ------------------------------------------------------------------ rendering

  void _applyCamera() {
    if (_viewSize.isEmpty) return;
    camera.apply(scene.scene.camera, _viewSize.width, _viewSize.height);
  }

  /// Called by the view's painter. Never mutates gameplay state.
  void render(ui.Canvas canvas, ui.Size size) {
    if (size != _viewSize) {
      _viewSize = size;
      input.screenWidth = size.width;
      _applyCamera();
    }
    renderer.render(canvas, scene.scene);
  }

  /// Releases the vsync-bound loop. Must be called by the owning screen before its ticker provider is
  /// disposed. The engine can be re-attached afterwards.
  void detach() {
    _loop?.dispose();
    _loop = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _loop?.dispose();
    _loop = null;
    super.dispose();
  }
}

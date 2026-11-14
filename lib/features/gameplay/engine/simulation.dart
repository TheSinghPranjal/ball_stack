import '../../../core/constants/game_constants.dart';
import '../../../core/enums/game_enums.dart';
import '../domain/game_event.dart';
import '../domain/level_config.dart';
import 'ball_controller.dart';
import 'collision_system.dart';
import 'combo_system.dart';
import 'rotation_controller.dart';

/// Input sampled for one fixed simulation step.
class InputFrame {
  double dragDelta = 0;
  double keyAxis = 0;
  bool dragging = false;
  double releaseVelocity = 0;
  bool holding = false;

  void clear() {
    dragDelta = 0;
    keyAxis = 0;
    dragging = false;
    releaseVelocity = 0;
    holding = false;
  }
}

/// The deterministic heart of the game: ball, rotation, collisions, combos, scoring.
/// No rendering, audio, widgets or wall-clock time — same inputs ⇒ same result.
class Simulation {
  Simulation(this.level, {this.shields = 0})
    : ball = BallController(gravity: level.gravity, bounceVelocity: level.bounceVelocity),
      floorStates = List.generate(level.floorCount, (_) => FloorState()) {
    ball.place(level.floorTop(0) + level.ballStartHeight);
  }

  final LevelConfig level;
  final BallController ball;
  final RotationController rotation = RotationController();
  final ComboSystem combo = ComboSystem();
  final CollisionSystem collision = CollisionSystem();
  final List<FloorState> floorStates;

  /// Index of the next floor the ball will meet (== floorCount → base platform).
  int floor = 0;
  double time = 0;
  int score = 0;
  int floorsCleared = 0;
  int smashes = 0;
  int bonusCoins = 0;
  int nearMisses = 0;
  int shields;
  bool passing = false;
  bool over = false;
  bool won = false;
  double grace = 0;

  // smash-mode heat / fireball
  double heat = 0;
  bool fireball = false;
  double fireballTime = 0;

  final Set<int> _nearDone = {};
  final List<GameEvent> _events = [];

  bool get isSmashMode => level.mode == InputMode.smash;
  double get progress => level.floorCount == 0 ? 1 : floorsCleared / level.floorCount;

  int _scaled(int points) => (points * level.scoreMultiplier).round();

  void _emit(GameEvent e) => _events.add(e);

  /// Advances the world by [dt] seconds. The returned list is reused on the next call.
  List<GameEvent> step(double dt, InputFrame input) {
    _events.clear();
    rotation.prevAngle = rotation.angle;
    ball.prevY = ball.y;
    if (over) return _events;
    time += dt;
    if (grace > 0) grace -= dt;

    if (isSmashMode) {
      rotation.stepAuto(dt, level.rotationSpeed, level.rotationDirection);
      _updateHeat(dt, input.holding);
    } else {
      rotation.stepSpin(
        dt,
        dragDelta: input.dragDelta,
        keyAxis: input.keyAxis,
        dragging: input.dragging,
        releaseVelocity: input.releaseVelocity,
      );
    }
    final diving = isSmashMode && (input.holding || fireball);
    ball.integrate(dt, dive: diving);

    // Several floors may be crossed in one step at high speed; resolve them in order (no tunnelling).
    var guard = 0;
    while (!over && guard++ < 6) {
      if (!_resolveNext(diving)) break;
    }
    return _events;
  }

  void _updateHeat(double dt, bool holding) {
    if (fireball) {
      fireballTime -= dt;
      heat = (fireballTime / GameConstants.fireballDuration).clamp(0.0, 1.0);
      if (fireballTime <= 0) {
        fireball = false;
        heat = 0;
        _emit(const GameEvent(GameEventType.fireballOff));
      }
    } else if (!holding && heat > 0) {
      heat = (heat - GameConstants.heatDecay * dt).clamp(0.0, 1.0);
    }
  }

  /// Returns true if a floor was consumed and the next one should be checked in the same step.
  bool _resolveNext(bool diving) {
    final n = level.floorCount;
    if (floor >= n) {
      final baseTop = level.floorTop(n);
      if (ball.bottom <= baseTop) {
        ball.restOn(baseTop);
        _win();
      }
      return false;
    }
    final top = level.floorTop(floor);
    if (passing) {
      if (ball.top < top - level.platformThickness) {
        passing = false;
        _floorPassed();
        return true;
      }
      return false;
    }
    final crossing = ball.vy < 0 && ball.prevBottom >= top - 1e-6 && ball.bottom < top;
    if (!crossing) return false;
    final spec = level.floors[floor];
    final state = floorStates[floor];
    final hit = collision.resolve(spec, state, rotation.angle, time);
    return isSmashMode ? _resolveSmashMode(hit, spec, state, top, diving) : _resolveSpinMode(hit, state, top);
  }

  // ------------------------------------------------------------------ spin mode

  bool _resolveSpinMode(CollisionResult hit, FloorState state, double top) {
    if (hit.kind == CollisionKind.gap) {
      passing = true;
      return _resolveNext(false);
    }
    if (combo.smashReady) {
      final chain = combo.onSmash();
      final points = _scaled(ScoringRules.passPoints(chain) + ScoringRules.smashBonus);
      score += points;
      smashes++;
      state.broken = true;
      _emit(GameEvent(GameEventType.smashed, floor: floor, chain: chain, points: points));
      _advanceFloor();
      if (ball.vy > -7) ball.vy = -7;
      return true;
    }
    switch (hit.kind) {
      case CollisionKind.danger:
        if (grace > 0) {
          _bounce(top, hit, 0);
        } else if (shields > 0) {
          shields--;
          _emit(GameEvent(GameEventType.shieldUsed, floor: floor, slot: hit.slot));
          _bounce(top, hit, 0);
        } else {
          _die(top, hit.cause);
        }
      case CollisionKind.breakable:
        state.destroyed[hit.slot] = true;
        final points = _scaled(ScoringRules.breakable);
        score += points;
        _emit(GameEvent(GameEventType.segmentBroken, floor: floor, slot: hit.slot, points: points));
        _bounce(top, hit, 0);
      case CollisionKind.bonus:
        state.collectedBonus.add(hit.slot);
        bonusCoins++;
        _emit(GameEvent(GameEventType.bonusCollected, floor: floor, slot: hit.slot));
        _bounce(top, hit, 0);
      case CollisionKind.safe:
        var nearPoints = 0;
        if (hit.hazardDistance > 0 && hit.hazardDistance < GameConstants.nearMissAngle && !_nearDone.contains(floor)) {
          _nearDone.add(floor);
          nearMisses++;
          nearPoints = _scaled(ScoringRules.nearMiss);
          score += nearPoints;
          _emit(GameEvent(GameEventType.nearMiss, floor: floor, slot: hit.slot, points: nearPoints));
        }
        _bounce(top, hit, nearPoints);
      case CollisionKind.gap:
        break; // handled above
    }
    return false;
  }

  void _bounce(double top, CollisionResult hit, int points) {
    final lost = combo.onBounce();
    if (lost >= 2) _emit(GameEvent(GameEventType.comboReset, chain: lost));
    ball.bounceOn(top);
    _emit(GameEvent(GameEventType.bounce, floor: floor, slot: hit.slot, points: points));
  }

  void _floorPassed() {
    final activated = combo.onFloorPassed();
    final points = _scaled(ScoringRules.passPoints(combo.chain));
    score += points;
    floorStates[floor].broken = true;
    _emit(GameEvent(GameEventType.floorPassed, floor: floor, chain: combo.chain, points: points));
    if (activated) _emit(GameEvent(GameEventType.smashReady, chain: combo.chain));
    _advanceFloor();
  }

  void _advanceFloor() {
    floorsCleared++;
    floor++;
  }

  // ------------------------------------------------------------------ smash mode

  bool _resolveSmashMode(CollisionResult hit, FloorSpec spec, FloorState state, double top, bool diving) {
    if (!diving) {
      if (hit.kind == CollisionKind.bonus) {
        state.collectedBonus.add(hit.slot);
        bonusCoins++;
        _emit(GameEvent(GameEventType.bonusCollected, floor: floor, slot: hit.slot));
      }
      _bounce(top, hit, 0);
      return false;
    }
    if (hit.kind == CollisionKind.danger && !fireball && grace <= 0) {
      if (shields > 0) {
        shields--;
        _emit(GameEvent(GameEventType.shieldUsed, floor: floor, slot: hit.slot));
      } else {
        _die(top, hit.cause);
        return false;
      }
    }
    if (hit.kind == CollisionKind.bonus) {
      bonusCoins++;
      _emit(GameEvent(GameEventType.bonusCollected, floor: floor, slot: hit.slot));
    }
    combo.onRingSmashed();
    final points = _scaled(ScoringRules.ringSmash * combo.streak.clamp(1, GameConstants.maxMultiplier));
    score += points;
    smashes++;
    state.broken = true;
    _emit(GameEvent(GameEventType.ringSmashed, floor: floor, chain: combo.streak, points: points));
    _advanceFloor();
    if (!fireball) {
      heat = (heat + GameConstants.heatPerRing).clamp(0.0, 1.0);
      if (heat >= 1) {
        fireball = true;
        fireballTime = GameConstants.fireballDuration;
        _emit(const GameEvent(GameEventType.fireballOn));
      }
    }
    return true;
  }

  // ------------------------------------------------------------------ end states

  void _die(double top, String cause) {
    ball.restOn(top);
    over = true;
    won = false;
    _emit(GameEvent(GameEventType.death, floor: floor, cause: cause));
  }

  void _win() {
    final points = _scaled(ScoringRules.levelComplete(level.levelId));
    score += points;
    over = true;
    won = true;
    _emit(GameEvent(GameEventType.levelComplete, points: points));
  }

  bool get canRevive => over && !won;

  /// Continues a failed run from just above the floor that killed the ball, with brief invulnerability.
  void revive() {
    if (!canRevive) return;
    over = false;
    passing = false;
    fireball = false;
    heat = 0;
    combo.onBounce();
    ball.place(level.floorTop(floor) + 1.4);
    ball.vy = level.bounceVelocity * 0.6;
    grace = GameConstants.reviveGrace;
  }

  RunResult result(String runId) => RunResult(
    runId: runId,
    levelId: level.levelId,
    won: won,
    score: score,
    floorsCleared: floorsCleared,
    totalFloors: level.floorCount,
    bestCombo: combo.maxCombo,
    bonusCoins: bonusCoins,
    smashes: smashes,
    seconds: time,
  );
}

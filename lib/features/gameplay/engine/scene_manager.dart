import 'dart:math' as math;

import '../../../app/theme/colors.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/render3d/color_math.dart';
import '../../../core/render3d/mesh.dart';
import '../../../core/render3d/mesh_factory.dart';
import '../../../core/render3d/mesh_instance.dart';
import '../../../core/render3d/scene_renderer.dart';
import '../../shop/data/ball_sprites.dart';
import '../../shop/domain/ball_skin.dart';
import '../domain/level_config.dart';
import '../domain/quality_profile.dart';
import 'collision_system.dart';
import 'destruction_system.dart';
import 'particle_system.dart';
import 'platform_controller.dart';
import 'tower_controller.dart';

class _Splat {
  _Splat(this.obj, this.floor, this.localAngle);

  final MeshInstance obj;
  final int floor;
  final double localAngle;
}

/// Builds the [RenderScene] every frame from game state. Owns all render objects; never mutates gameplay.
class SceneManager {
  SceneManager({
    required this.level,
    required this.theme,
    required BallSkin skin,
    required this.quality,
    required List<FloorState> floorStates,
    this.fogColor,
  }) : _skin = skin {
    platforms = PlatformController(level: level, theme: theme, quality: quality);
    tower = TowerController(level: level, platforms: platforms, theme: theme, floorStates: floorStates);
    particles = ParticleSystem()..density = quality.particleScale;
    destruction = DestructionSystem(platforms: platforms, theme: theme)..density = quality.particleScale;
    ball = MeshInstance(ballMesh(skin, quality.sphereStacks));
    final sb = MeshBuilder();
    MeshFactory.disc(sb, 0.42, 0, 18, 0x99000000, edgeColor: 0x00000000);
    shadow = MeshInstance(sb.build(MeshMaterial.decal))..depthBias = -0.25;
    for (var i = 0; i < quality.trailLength; i++) {
      _trail.add(Billboard());
    }
    _configureLighting();
  }

  final LevelConfig level;
  final GameTheme theme;
  final QualityProfile quality;

  /// Overrides [GameTheme.fog] so distant floors melt into a background image instead of the theme sky.
  final int? fogColor;
  BallSkin _skin;

  final RenderScene scene = RenderScene();
  late final PlatformController platforms;
  late final TowerController tower;
  late final ParticleSystem particles;
  late final DestructionSystem destruction;
  late MeshInstance ball;
  late final MeshInstance shadow;

  final List<Billboard> _trail = [];
  int _trailHead = 0;
  final List<_Splat> _splats = [];
  final Map<int, Mesh> _splatMeshes = {};
  final math.Random _rng = math.Random(5);

  double _rollAngle = 0;
  double _spin = 0;

  /// Pre-rendered realistic ball + flame (falls back to the procedural [ball] mesh until sprites load).
  final SpriteInstance ballSprite = SpriteInstance();
  final SpriteInstance flameSprite = SpriteInstance()
    ..anchorY = BallSpriteSet.flameRoot
    ..depthBias = 0.08;
  double _lastBallY = double.nan;
  double _vy = 0;
  bool ballVisible = true;

  BallSkin get skin => _skin;

  static Mesh ballMesh(BallSkin skin, int stacks) =>
      MeshFactory.sphere(GameConstants.ballRadius, stacks, stacks * 2 - 2, skin.colorAt).build(skin.material);

  set skin(BallSkin s) {
    _skin = s;
    ball.mesh = ballMesh(s, quality.sphereStacks);
  }

  void _configureLighting() {
    final l = scene.lighting
      ..skyColor = theme.skyLight
      ..groundColor = theme.groundLight
      ..fogColor = fogColor ?? theme.fog
      ..fogNear = 15
      ..fogFar = 36
      ..fogMax = 0.9;
    l.normalize();
  }

  /// Leaves a paint splat where the ball bounced (floor-local, rotates with the tower).
  void addSplat(int floor, double towerAngle, int color) {
    if (!quality.splats || floor >= level.floorCount) return;
    final spec = level.floors[floor];
    final local = CollisionSystem.localAngle(towerAngle, spec) + (_rng.nextDouble() - 0.5) * 0.12;
    final mesh = _splatMeshes.putIfAbsent(color, () {
      final b = MeshBuilder();
      const n = 10;
      for (var i = 0; i < n; i++) {
        final a0 = 2 * math.pi * i / n, a1 = 2 * math.pi * (i + 1) / n;
        final r0 = 0.26 + 0.07 * math.sin(i * 2.7), r1 = 0.26 + 0.07 * math.sin((i + 1) * 2.7);
        b.triangle([0, 0, 0], [r0 * math.sin(a0), 0, r0 * math.cos(a0)], [
          r1 * math.sin(a1),
          0,
          r1 * math.cos(a1),
        ], ColorMath.withAlpha(color, 0.75));
      }
      return b.build(MeshMaterial.decal);
    });
    final obj = MeshInstance(mesh)
      ..depthBias = -0.2
      ..setRotationY(_rng.nextDouble() * 6);
    _splats.add(_Splat(obj, floor, local));
    if (_splats.length > 10) _splats.removeAt(0);
  }

  void clearSplatsOn(int floor) => _splats.removeWhere((s) => s.floor == floor);

  void sync({
    required double dt,
    required double towerAngle,
    required double ballY,
    required double time,
    required int currentFloor,
    required double squash,
    required bool fire,
    required bool glow,
  }) {
    tower.ensureWindow(currentFloor, quality.floorsAhead);
    tower.update(towerAngle, time);
    particles.update(dt);
    destruction.update(dt);

    // ---- ball
    const r = GameConstants.ballOrbitRadius;
    final sy = 1 - 0.28 * squash;
    final sxz = 1 + 0.16 * squash;
    _rollAngle += dt * 5;
    _spin = towerAngle;
    ball
      ..visible = ballVisible
      ..sx = sxz
      ..sz = sxz
      ..sy = sy
      ..setPosition(0, ballY - (1 - sy) * GameConstants.ballRadius, r)
      ..setEuler(_rollAngle, _spin * 0.6, 0)
      ..tint = 0xFFFF7A1A
      ..tintAmount = fire && !_skin.fiery ? 0.55 : 0
      ..emissiveBoost = fire ? 0.45 : (glow ? 0.2 : 0);

    // ---- sprite ball + speed-driven flame
    if (dt > 0 && !_lastBallY.isNaN) {
      final v = (ballY - _lastBallY) / dt;
      _vy += (v - _vy) * math.min(1.0, dt * 14);
    }
    _lastBallY = ballY;
    final sprites = BallSprites.instance.of(_skin.id);
    if (sprites != null) {
      const br = GameConstants.ballRadius;
      final size = br / BallSpriteSet.ballRadius;
      // The ball rolls as the tower turns under it, plus a slow idle spin.
      final roll = (towerAngle * 2.2 + time * 0.8) / (2 * math.pi) * BallSpriteSet.frames;
      ballSprite
        ..image = sprites.ball
        ..src = sprites.ballFrame(((roll.floor() % BallSpriteSet.frames) + BallSpriteSet.frames) % BallSpriteSet.frames)
        ..visible = ballVisible
        ..width = size
        ..height = size
        ..scaleX = sxz
        ..scaleY = sy
        ..x = 0
        ..y = ballY - (1 - sy) * br
        ..z = r;

      // Flame trails behind the motion: up while falling, down while rising, full blaze in fireball mode.
      final rising = _vy > 0;
      var k = ((_vy.abs() - 1) / 9).clamp(0.0, 1.0) * (rising ? 0.42 : 1.0);
      if (_skin.fiery) k = math.max(k, 0.45);
      if (fire) k = 1;
      final flames = fire && !_skin.fiery ? (BallSprites.instance.of('ember') ?? sprites) : sprites;
      final w = 2 * br * 1.15 / BallSpriteSet.flameRootWidth;
      flameSprite
        ..image = flames.flame
        ..src = flames.flameFrame((time * 16).floor())
        ..visible = ballVisible && k > 0.02
        ..alpha = 0.45 + 0.55 * k
        ..width = w * (0.9 + 0.2 * k)
        ..height = w * BallSpriteSet.flameH / BallSpriteSet.flameW * (0.55 + 1.1 * k)
        ..rotation = rising ? math.pi : 0
        ..x = 0
        ..y = ballY
        ..z = r;
    }

    // ---- shadow on the floor below
    if (currentFloor < level.floorCount) {
      final spec = level.floors[currentFloor];
      final top = level.floorTop(currentFloor);
      final st = tower.floorStates[currentFloor];
      final slot = CollisionSystem.slotIndex(CollisionSystem.localAngle(towerAngle, spec));
      final over = CollisionSystem.effectiveType(spec, st, slot) != SegmentType.gap && !st.broken;
      final h = ballY - top;
      shadow
        ..visible = ballVisible && over && h > 0
        ..setPosition(0, top + 0.02, r)
        ..setScale(1 - (h / 8).clamp(0.0, 0.5))
        ..alpha = (1 - h / 6).clamp(0.15, 1.0);
    } else {
      shadow
        ..visible = ballVisible
        ..setPosition(0, level.floorTop(level.floorCount) + 0.02, r)
        ..alpha = 1;
    }

    // ---- trail
    final trailColor = fire ? 0xFFFF8A2A : _skin.trail;
    final head = _trail[_trailHead];
    head
      ..active = ballVisible
      ..x = 0
      ..y = ballY
      ..z = r;
    _trailHead = (_trailHead + 1) % _trail.length;
    for (var i = 0; i < _trail.length; i++) {
      final idx = (_trailHead - 1 - i + _trail.length) % _trail.length;
      final b = _trail[idx];
      final k = 1 - i / _trail.length;
      b.size = GameConstants.ballRadius * (fire ? 1.25 : 0.85) * k;
      b.color = ColorMath.withAlpha(trailColor, (fire ? 0.75 : 0.45) * k);
      // The flame sprite replaces the dotted trail when the realistic ball is shown.
      if (!ballVisible || sprites != null) b.active = false;
    }
    if (fire || _skin.fiery) {
      particles.flame(0, ballY, r, color: fire ? 0xFFFF6A1A : _skin.trail);
    }

    // ---- assemble object list (order irrelevant; renderer depth-sorts)
    final objs = scene.objects..clear();
    tower.addTo(objs, currentFloor);
    for (final s in _splats) {
      if (s.floor < level.floorCount && !tower.floorStates[s.floor].broken) {
        final a = towerAngle + level.floors[s.floor].offset + s.localAngle;
        s.obj.setPosition(
          GameConstants.ballOrbitRadius * math.sin(a),
          level.floorTop(s.floor) + 0.012,
          GameConstants.ballOrbitRadius * math.cos(a),
        );
        objs.add(s.obj);
      }
    }
    destruction.addTo(objs);
    if (shadow.visible) objs.add(shadow);
    final sp = scene.sprites..clear();
    if (sprites != null) {
      sp
        ..add(flameSprite)
        ..add(ballSprite);
    } else {
      objs.add(ball);
    }
    final bbs = scene.billboards..clear();
    bbs.addAll(_trail);
    bbs.addAll(particles.billboards);
  }
}

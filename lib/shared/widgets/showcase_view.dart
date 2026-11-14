import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme/colors.dart';
import '../../core/constants/game_constants.dart';
import '../../core/enums/game_enums.dart';
import '../../core/render3d/camera3d.dart';
import '../../core/render3d/mesh.dart';
import '../../core/render3d/mesh_instance.dart';
import '../../core/render3d/scene_renderer.dart';
import '../../features/gameplay/domain/quality_profile.dart';
import '../../features/gameplay/engine/camera_controller.dart';
import '../../features/gameplay/engine/collision_system.dart';
import '../../features/gameplay/engine/scene_manager.dart';
import '../../features/levels/data/level_generator.dart';
import '../../features/shop/domain/ball_skin.dart';
import 'sky_painter.dart';

/// Attract-mode 3D scene (splash/home): a slowly rotating real tower with a bouncing ball.
class ShowcaseView extends StatefulWidget {
  const ShowcaseView({
    super.key,
    required this.level,
    required this.skin,
    this.quality = GraphicsQuality.medium,
    this.stage = false,
    this.stageTopInset = 0,
  });

  final int level;
  final BallSkin skin;
  final GraphicsQuality quality;

  /// Home-screen "stage" mode: no sky (drawn over a background image), tower framed in the upper half,
  /// cut off below a few floors and wrapped in a neon pedestal ring.
  final bool stage;

  /// Stage mode: pixels at the top of this view reserved for overlaid content (the logo). The tower is
  /// fitted between this inset and the bottom edge.
  final double stageTopInset;

  @override
  State<ShowcaseView> createState() => _ShowcaseViewState();
}

class _ShowcaseViewState extends State<ShowcaseView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late SceneManager _scene;
  late GameTheme _theme;
  final SceneRenderer _renderer = SceneRenderer(initialCapacity: 6000);
  final CameraController _cam = CameraController(
    config: const CameraConfig(distance: 12.5, height: 5.5, lookDown: 1.4, viewWidth: 8.2),
  );
  final ValueNotifier<int> _tick = ValueNotifier(0);
  final SkyPainter _sky = SkyPainter(18);
  Duration _last = Duration.zero;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _build();
    _ticker = createTicker(_onTick)..start();
  }

  void _build() {
    final level = LevelGenerator().generate(math.max(1, widget.level), InputMode.spin);
    _theme = GameThemes.forIndex(level.themeIndex);
    _scene = SceneManager(
      level: level,
      theme: _theme,
      skin: widget.skin,
      quality: QualityProfile.of(widget.quality),
      floorStates: List.generate(level.floorCount, (_) => FloorState()),
    );
    _cam.reset(level.floorTop(0) + 0.6, intro: false);
  }

  @override
  void didUpdateWidget(ShowcaseView old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level) {
      _build();
    } else if (old.skin.id != widget.skin.id) {
      _scene.skin = widget.skin;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.0 : math.min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    _t += dt;
    const period = 0.72;
    final phase = (_t % period) / period;
    final h = 4 * phase * (1 - phase) * 2.1;
    final y = _scene.level.floorTop(0) + GameConstants.ballRadius + h;
    final squash = phase < 0.08 ? 1 - phase / 0.08 : (phase > 0.95 ? (phase - 0.95) / 0.05 : 0.0);
    _scene.sync(
      dt: dt,
      towerAngle: _t * 0.45,
      ballY: y,
      time: _t,
      currentFloor: 0,
      squash: squash,
      fire: false,
      glow: false,
    );
    _cam.update(dt);
    _tick.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(size: Size.infinite, painter: _ShowcasePainter(this)),
    );
  }
}

class _ShowcasePainter extends CustomPainter {
  _ShowcasePainter(this.s) : super(repaint: s._tick);

  final _ShowcaseViewState s;

  static const _cyan = Color(0xFF3FE0FF);
  static const _pink = Color(0xFFFF4FD8);

  @override
  void paint(Canvas canvas, Size size) {
    final cam = s._scene.scene.camera;
    if (!s.widget.stage) {
      s._sky.paint(canvas, size, s._theme, s._t, 0);
      s._cam.apply(cam, size.width, size.height);
      s._renderer.render(canvas, s._scene.scene);
      return;
    }

    s._cam.apply(cam, size.width, size.height);

    // Pedestal ring sits just under the second floor; everything below it is faded out.
    final level = s._scene.level;
    final ringY = level.floorTop(1) - GameConstants.platformThickness - 0.8;
    const ringR = GameConstants.platformOuterRadius + 0.45;

    // Fit the tower (ball apex .. front of the ring) into the free band. Screen y is linear in focal and
    // cy (sy = cy - focal * k), so solve for both directly.
    final top = _project(cam, 0, level.floorTop(0) + 2.9, 0);
    final bottom = _project(cam, 0, ringY, ringR);
    if (top != null && bottom != null) {
      final kTop = (cam.cy - top.dy) / cam.focal, kBottom = (cam.cy - bottom.dy) / cam.focal;
      final band = size.height - s.widget.stageTopInset - 22;
      final focal = math.min(cam.focal * 0.85, band / (kTop - kBottom));
      cam
        ..focal = focal
        ..cy = size.height - 14 + focal * kBottom;
    }
    final back = Path(), front = Path(), disc = Path();
    var cutY = 0.0;
    const n = 64;
    for (var i = 0; i <= n; i++) {
      final a = 2 * math.pi * i / n;
      final x = ringR * math.sin(a), z = ringR * math.cos(a);
      final pt = _project(cam, x, ringY, z);
      if (pt == null) continue;
      cutY = math.max(cutY, pt.dy);
      i == 0 ? disc.moveTo(pt.dx, pt.dy) : disc.lineTo(pt.dx, pt.dy);
      // a in (pi/2, 3pi/2) -> z < 0 -> far side of the tower.
      final isBack = z < 0;
      final path = isBack ? back : front;
      final prevA = 2 * math.pi * (i - 1) / n;
      final prevBack = math.cos(prevA) < 0;
      if (i == 0 || prevBack != isBack) {
        if (i > 0) (prevBack ? back : front).lineTo(pt.dx, pt.dy);
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    disc.close();
    final centre = _project(cam, 0, ringY, 0);

    // Pedestal glow + back half of the ring behind the tower.
    final pulse = 0.8 + 0.2 * math.sin(s._t * 2.2);
    if (centre != null) {
      final b = disc.getBounds();
      canvas.drawPath(
        disc,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _cyan.withValues(alpha: 0.5 * pulse),
              const Color(0xFF6A3BFF).withValues(alpha: 0.4),
              const Color(0x00000000),
            ],
            stops: const [0, 0.6, 1],
          ).createShader(b),
      );
    }
    _neon(canvas, back, pulse);

    // Tower, faded out just below the ring.
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    s._renderer.render(canvas, s._scene.scene);
    final fadeTop = (cutY - 26) / size.height, fadeBottom = (cutY - 4) / size.height;
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [fadeTop.clamp(0.0, 1.0), fadeBottom.clamp(0.0, 1.0)],
          colors: const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        ).createShader(bounds),
    );
    canvas.restore();

    _neon(canvas, front, pulse);
  }

  void _neon(Canvas canvas, Path path, double pulse) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [_cyan, _pink, _cyan]).createShader(path.getBounds())
      ..strokeWidth = 22
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
      ..color = Colors.white.withValues(alpha: 0.85 * pulse);
    canvas.drawPath(path, paint);
    paint
      ..strokeWidth = 6
      ..maskFilter = null
      ..color = Colors.white;
    canvas.drawPath(path, paint);
    paint
      ..shader = null
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.8;
    canvas.drawPath(path, paint);
  }

  static Offset? _project(Camera3D c, double x, double y, double z) {
    final dx = x - c.ex, dy = y - c.ey, dz = z - c.ez;
    final zc = dx * c.fx + dy * c.fy + dz * c.fz;
    if (zc < c.near) return null;
    final xc = dx * c.rx + dy * c.ry + dz * c.rz;
    final yc = dx * c.ux + dy * c.uy + dz * c.uz;
    return Offset(c.cx + c.focal * xc / zc, c.cy - c.focal * yc / zc);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Spinning 3D preview of a single ball skin (shop).
class BallPreviewView extends StatefulWidget {
  const BallPreviewView({super.key, required this.skin});

  final BallSkin skin;

  @override
  State<BallPreviewView> createState() => _BallPreviewViewState();
}

class _BallPreviewViewState extends State<BallPreviewView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final RenderScene _scene = RenderScene();
  final SceneRenderer _renderer = SceneRenderer(initialCapacity: 2000);
  late MeshInstance _ball;
  late MeshInstance _pedestal;
  final ValueNotifier<int> _tick = ValueNotifier(0);
  double _t = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ball = MeshInstance(SceneManager.ballMesh(widget.skin, 22));
    final b = MeshBuilder();
    // simple pedestal disc
    for (var j = 0; j < 32; j++) {
      final a0 = 2 * math.pi * j / 32, a1 = 2 * math.pi * (j + 1) / 32;
      b.triangle(
        [0, 0, 0],
        [0.5 * math.sin(a0), 0, 0.5 * math.cos(a0)],
        [0.5 * math.sin(a1), 0, 0.5 * math.cos(a1)],
        0x55FFFFFF,
        0x00FFFFFF,
        0x00FFFFFF,
      );
    }
    _pedestal = MeshInstance(b.build(MeshMaterial.decal))..depthBias = 0.5;
    _scene.lighting
      ..fogNear = 100
      ..fogFar = 200
      ..skyColor = 0xFFE8E0FF
      ..groundColor = 0xFF3A2A70
      ..normalize();
    _scene.objects.addAll([_pedestal, _ball]);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(BallPreviewView old) {
    super.didUpdateWidget(old);
    if (old.skin.id != widget.skin.id) _ball.mesh = SceneManager.ballMesh(widget.skin, 22);
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _t += dt;
    final bob = math.sin(_t * 2.4).abs() * 0.12;
    _ball
      ..setPosition(0, GameConstants.ballRadius + bob, 0)
      ..setEuler(0.35, _t * 1.2, 0.15);
    _pedestal
      ..setPosition(0, 0, 0)
      ..setScale(1 - bob * 1.5);
    _tick.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.infinite, painter: _BallPainter(this));
}

class _BallPainter extends CustomPainter {
  _BallPainter(this.s) : super(repaint: s._tick);

  final _BallPreviewViewState s;

  @override
  void paint(Canvas canvas, Size size) {
    final cam = s._scene.camera
      ..lookAt(0, 0.75, 1.55, 0, 0.3, 0)
      ..cx = size.width / 2
      ..cy = size.height / 2;
    cam.frameWidth(size.shortestSide, 1.25, 1.7);
    s._renderer.render(canvas, s._scene);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

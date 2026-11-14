import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/sky_painter.dart';
import '../../engine/game_engine.dart';

/// Hosts the 3D game: forwards raw pointer/keyboard input to the engine and repaints once per engine frame.
class GameSceneView extends StatefulWidget {
  const GameSceneView({super.key, required this.engine});

  final GameEngine engine;

  @override
  State<GameSceneView> createState() => _GameSceneViewState();
}

class _GameSceneViewState extends State<GameSceneView> {
  final FocusNode _focus = FocusNode();
  final ValueNotifier<ui.Image?> _bg = ValueNotifier(null);
  ImageStream? _bgStream;
  late final ImageStreamListener _bgListener = ImageStreamListener((info, _) => _bg.value = info.image);

  static const _bgAsset = AssetImage('assets/images/bg/home_bg.jpg');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = _bgAsset.resolve(createLocalImageConfiguration(context));
    if (stream.key != _bgStream?.key) {
      _bgStream?.removeListener(_bgListener);
      _bgStream = stream..addListener(_bgListener);
    }
  }

  int get _now => DateTime.now().microsecondsSinceEpoch;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final k = e.logicalKey;
    final left = k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA;
    final right = k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD;
    if (!left && !right) return KeyEventResult.ignored;
    if (e is KeyDownEvent || e is KeyRepeatEvent) {
      widget.engine.input.key(k.keyId, left: left, down: true);
    } else if (e is KeyUpEvent) {
      widget.engine.input.key(k.keyId, left: left, down: false);
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _bgStream?.removeListener(_bgListener);
    _bg.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final input = widget.engine.input;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => input.pointerDown(e.pointer, e.localPosition.dx, _now),
        onPointerMove: (e) => input.pointerMove(e.pointer, e.localPosition.dx, _now),
        onPointerUp: (e) => input.pointerUp(e.pointer, _now),
        onPointerCancel: (e) => input.pointerUp(e.pointer, _now),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _GamePainter(widget.engine, _bg),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  _GamePainter(this.engine, this.bg) : super(repaint: Listenable.merge([engine, bg]));

  final GameEngine engine;
  final ValueListenable<ui.Image?> bg;
  static final SkyPainter _sky = SkyPainter(26);
  static final Paint _bgPaint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    final img = bg.value;
    if (img == null) {
      _sky.paint(canvas, size, engine.theme, engine.sim.time, engine.camera.focusY);
    } else {
      _paintBackdrop(canvas, size, img);
    }
    engine.render(canvas, size);
  }

  /// Cover-fits the neon city slightly oversized and slides it up as the camera descends the tower
  /// (focusY goes negative), so the skyline drifts with the plunge without ever exposing an edge.
  void _paintBackdrop(Canvas canvas, Size size, ui.Image img) {
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    final scale = math.max(size.width / iw, size.height / ih) * 1.12;
    final w = iw * scale, h = ih * scale;
    final slack = h - size.height;
    final depth = engine.level.towerHeight <= 0 ? 0.0 : (-engine.camera.focusY / engine.level.towerHeight);
    final dy = -slack * (0.15 + 0.7 * depth.clamp(0.0, 1.0));
    final dst = Rect.fromLTWH((size.width - w) / 2, dy, w, h);
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, iw, ih), dst, _bgPaint);
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) => old.engine != engine || old.bg != bg;
}

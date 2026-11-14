import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../../../core/logging/log.dart';
import 'skin_catalog.dart';

/// Decoded pre-rendered sprites of one ball skin (see tools/gen_ball_assets.py).
class BallSpriteSet {
  BallSpriteSet(this.ball, this.flame);

  /// 12 roll frames in a 4x3 grid of [cell] px cells.
  final ui.Image ball;

  /// 6 flicker frames in one row of [flameW]x[flameH] cells; the plume points up.
  final ui.Image flame;

  static const int frames = 12;
  static const int cols = 4;
  static const double cell = 160;

  /// Ball radius as a fraction of a cell.
  static const double ballRadius = 0.46;

  static const int flameFrames = 6;
  static const double flameW = 160, flameH = 256;

  /// Where the ball centre sits in a flame cell (fraction of its height from the top).
  static const double flameRoot = 0.80;

  /// Half-width of the plume at its root, as a fraction of half the cell width.
  static const double flameRootWidth = 0.95;

  ui.Rect ballFrame(int i) {
    final f = i % frames;
    return ui.Rect.fromLTWH((f % cols) * cell, (f ~/ cols) * cell, cell, cell);
  }

  ui.Rect flameFrame(int i) => ui.Rect.fromLTWH((i % flameFrames) * flameW, 0, flameW, flameH);
}

/// Loads and caches every skin's sprite sheets once (decoded GPU images shared by the game, home and shop).
class BallSprites {
  BallSprites._();

  static final BallSprites instance = BallSprites._();

  final Map<String, BallSpriteSet> _sets = {};
  Future<void>? _loading;

  bool get isLoaded => _sets.length == SkinCatalog.all.length;

  BallSpriteSet? of(String skinId) => _sets[skinId];

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      await Future.wait([
        for (final s in SkinCatalog.all)
          () async {
            final ball = await _decode('assets/images/balls/${s.id}_ball.png');
            final flame = await _decode('assets/images/balls/${s.id}_flame.png');
            _sets[s.id] = BallSpriteSet(ball, flame);
          }(),
      ]);
    } catch (e) {
      // Sprites are cosmetic: the game falls back to the procedural 3D ball.
      Log.w('BallSprites', 'load failed: $e');
      _loading = null;
    }
  }

  static Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }
}

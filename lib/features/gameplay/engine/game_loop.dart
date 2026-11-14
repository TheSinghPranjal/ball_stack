import 'package:flutter/scheduler.dart';

/// vsync-driven loop. Exactly one ticker per loop; starting twice is a no-op, so navigating or
/// resuming the app can never create duplicate loops.
class GameLoop {
  GameLoop(TickerProvider vsync, this.onFrame) {
    _ticker = vsync.createTicker(_tick);
  }

  final void Function(double dt) onFrame;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _disposed = false;

  /// Frame-time statistics (seconds) for the performance overlay/tests.
  double averageFrame = 1 / 60;
  double worstFrame = 0;
  int frames = 0;

  bool get isRunning => _ticker.isActive;

  void start() {
    if (_disposed || _ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  void stop() {
    if (_ticker.isActive) _ticker.stop();
  }

  void _tick(Duration elapsed) {
    if (_last == Duration.zero) {
      _last = elapsed;
      return;
    }
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    frames++;
    averageFrame = averageFrame * 0.95 + dt * 0.05;
    if (frames > 30 && dt > worstFrame) worstFrame = dt;
    onFrame(dt);
  }

  void dispose() {
    _disposed = true;
    _ticker.dispose();
  }
}

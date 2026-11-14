import 'dart:math' as math;

import '../../../core/constants/game_constants.dart';
import '../../../core/enums/game_enums.dart';
import 'simulation.dart';

/// Converts raw pointer/keyboard input into per-step [InputFrame]s.
/// Drag distance → angle: one screen width = `dragTurnsPerScreen` turns × sensitivity.
class InputController {
  InputController({required this.mode});

  InputMode mode;
  double sensitivity = 1.0;
  double screenWidth = 400;

  bool _pointerDown = false;
  int? _pointerId;
  double _lastX = 0;
  double _pendingDrag = 0;
  double _dragVelocity = 0; // rad/s smoothed
  double _releaseVelocity = 0;
  int _lastMoveMicros = 0;
  final Set<int> _keysLeft = {};
  final Set<int> _keysRight = {};

  /// Set whenever the user interacts (used to skip the intro).
  bool touchedSinceReset = false;

  bool get isHolding => _pointerDown;

  double get _radPerPixel => (2 * math.pi * GameConstants.dragTurnsPerScreen * sensitivity) / math.max(1, screenWidth);

  void pointerDown(int id, double x, int micros) {
    if (_pointerId != null) return;
    _pointerId = id;
    _pointerDown = true;
    _lastX = x;
    _dragVelocity = 0;
    _lastMoveMicros = micros;
    touchedSinceReset = true;
  }

  void pointerMove(int id, double x, int micros) {
    if (id != _pointerId) return;
    final dx = x - _lastX;
    _lastX = x;
    final dAngle = dx * _radPerPixel;
    _pendingDrag += dAngle;
    final dtUs = math.max(1, micros - _lastMoveMicros);
    _lastMoveMicros = micros;
    final instant = dAngle / (dtUs / 1e6);
    _dragVelocity = _dragVelocity * 0.6 + instant * 0.4;
  }

  void pointerUp(int id, int micros) {
    if (id != _pointerId) return;
    _pointerId = null;
    _pointerDown = false;
    // Only carry momentum if the finger was still moving recently.
    final idle = (micros - _lastMoveMicros) / 1e6;
    _releaseVelocity = idle < 0.08 ? _dragVelocity : 0;
    _dragVelocity = 0;
  }

  /// Programmatic rotation (QA autopilot); goes through the same per-step distribution as drags.
  void injectRotation(double radians) => _pendingDrag += radians;

  bool _injectedHold = false;

  /// Programmatic hold (QA autopilot, smash mode).
  void injectHold(bool hold) => _injectedHold = hold;

  void key(int logicalKeyId, {required bool left, required bool down}) {
    final set = left ? _keysLeft : _keysRight;
    if (down) {
      set.add(logicalKeyId);
      touchedSinceReset = true;
    } else {
      set.remove(logicalKeyId);
    }
  }

  /// Fills [frames] fixed steps for this frame; drag is distributed evenly across them.
  void fill(InputFrame frame, int stepIndex, int steps) {
    frame.clear();
    final axis = (_keysRight.isNotEmpty ? 1.0 : 0.0) - (_keysLeft.isNotEmpty ? 1.0 : 0.0);
    frame.keyAxis = axis;
    frame.holding = mode == InputMode.smash && (_pointerDown || _injectedHold);
    frame.dragging = mode == InputMode.spin && _pointerDown;
    if (mode == InputMode.spin && steps > 0) {
      frame.dragDelta = _pendingDrag / steps;
      if (stepIndex == 0) {
        frame.releaseVelocity = _releaseVelocity;
      }
    }
  }

  /// Call once after all steps of a frame were consumed.
  void endFrame(int stepsTaken) {
    if (stepsTaken > 0) {
      _pendingDrag = 0;
      _releaseVelocity = 0;
    }
  }

  void reset() {
    _pointerDown = false;
    _pointerId = null;
    _pendingDrag = 0;
    _dragVelocity = 0;
    _releaseVelocity = 0;
    _keysLeft.clear();
    _keysRight.clear();
    touchedSinceReset = false;
  }
}

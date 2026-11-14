import '../../../core/constants/game_constants.dart';

/// Vertical ball state. The ball stays at a fixed world angle and radius; only Y moves.
class BallController {
  BallController({required this.gravity, required this.bounceVelocity});

  final double gravity;
  final double bounceVelocity;

  double y = 0;
  double prevY = 0;
  double vy = 0;

  /// 0..1 squash amount (visual only, decays in the renderer side).
  double squash = 0;

  double get bottom => y - GameConstants.ballRadius;
  double get prevBottom => prevY - GameConstants.ballRadius;
  double get top => y + GameConstants.ballRadius;

  void place(double atY) {
    y = atY;
    prevY = atY;
    vy = 0;
  }

  /// Delta-time integration (semi-implicit Euler). With [dive] the ball is driven straight down.
  void integrate(double dt, {bool dive = false}) {
    prevY = y;
    if (dive) {
      vy = -GameConstants.diveVelocity;
    } else {
      vy -= gravity * dt;
      if (vy < -GameConstants.terminalVelocity) vy = -GameConstants.terminalVelocity;
    }
    y += vy * dt;
  }

  void bounceOn(double surfaceY) {
    y = surfaceY + GameConstants.ballRadius;
    vy = bounceVelocity;
    squash = 1;
  }

  void restOn(double surfaceY) {
    y = surfaceY + GameConstants.ballRadius;
    vy = 0;
  }
}

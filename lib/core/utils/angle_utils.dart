import 'dart:math' as math;

abstract final class AngleUtils {
  static const double tau = 2 * math.pi;

  /// Wraps into [0, 2π).
  static double wrap(double a) {
    final r = a % tau;
    return r < 0 ? r + tau : r;
  }

  /// Signed shortest difference a−b in (−π, π].
  static double delta(double a, double b) {
    var d = wrap(a - b);
    if (d > math.pi) d -= tau;
    return d;
  }

  /// True if [a] lies within the arc that starts at [start] and spans [width] (counter-clockwise).
  static bool inArc(double a, double start, double width) => wrap(a - start) < width;
}

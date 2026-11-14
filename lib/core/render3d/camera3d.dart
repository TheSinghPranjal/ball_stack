import 'dart:math' as math;

/// Perspective look-at camera. Y is up; the camera never rolls.
class Camera3D {
  double ex = 0, ey = 0, ez = 10;

  // Orthonormal basis: right, up, forward.
  double rx = 1, ry = 0, rz = 0;
  double ux = 0, uy = 1, uz = 0;
  double fx = 0, fy = 0, fz = -1;

  /// Focal length in logical pixels.
  double focal = 600;
  double cx = 0, cy = 0;
  double near = 0.15;

  void lookAt(double eyeX, double eyeY, double eyeZ, double tx, double ty, double tz) {
    ex = eyeX;
    ey = eyeY;
    ez = eyeZ;
    var dx = tx - eyeX, dy = ty - eyeY, dz = tz - eyeZ;
    var l = math.sqrt(dx * dx + dy * dy + dz * dz);
    fx = dx / l;
    fy = dy / l;
    fz = dz / l;
    // right = forward x worldUp(0,1,0)
    var qx = -fz, qz = fx;
    l = math.sqrt(qx * qx + qz * qz);
    if (l < 1e-9) {
      qx = 1;
      qz = 0;
      l = 1;
    }
    rx = qx / l;
    ry = 0;
    rz = qz / l;
    // up = right x forward
    ux = ry * fz - rz * fy;
    uy = rz * fx - rx * fz;
    uz = rx * fy - ry * fx;
  }

  /// Sets focal length so that a horizontal span of [worldWidth] at distance [distance] fills [screenWidth].
  void frameWidth(double screenWidth, double worldWidth, double distance) {
    focal = screenWidth * distance / worldWidth;
  }

  double get distanceToOrigin => math.sqrt(ex * ex + ey * ey + ez * ez);
}

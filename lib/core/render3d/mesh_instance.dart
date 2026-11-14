import 'dart:math' as math;

import 'mesh.dart';

/// A mesh instance in the world: rotation (3x3), non-uniform scale, translation and per-instance tint/alpha.
class MeshInstance {
  MeshInstance(this.mesh);

  Mesh mesh;
  bool visible = true;

  double x = 0, y = 0, z = 0;
  double sx = 1, sy = 1, sz = 1;

  // Row-major rotation matrix.
  double m00 = 1, m01 = 0, m02 = 0;
  double m10 = 0, m11 = 1, m12 = 0;
  double m20 = 0, m21 = 0, m22 = 1;

  /// Multiplies vertex alpha.
  double alpha = 1;

  /// Optional colour the base colour is blended towards by [tintAmount].
  int tint = 0xffffffff;
  double tintAmount = 0;

  /// Additional emissive term (0..1) on top of the material's.
  double emissiveBoost = 0;

  /// Depth bias added to this object's triangles (negative = drawn later / on top).
  double depthBias = 0;

  void setPosition(double px, double py, double pz) {
    x = px;
    y = py;
    z = pz;
  }

  void setScale(double s) {
    sx = sy = sz = s;
  }

  void setRotationY(double a) {
    final c = math.cos(a), s = math.sin(a);
    m00 = c;
    m01 = 0;
    m02 = s;
    m10 = 0;
    m11 = 1;
    m12 = 0;
    m20 = -s;
    m21 = 0;
    m22 = c;
  }

  /// R = Ry(yaw) * Rx(pitch) * Rz(roll).
  void setEuler(double pitch, double yaw, double roll) {
    final cx = math.cos(pitch), sx_ = math.sin(pitch);
    final cy = math.cos(yaw), sy_ = math.sin(yaw);
    final cz = math.cos(roll), sz_ = math.sin(roll);
    // Rx*Rz
    final a00 = cz, a01 = -sz_, a02 = 0.0;
    final a10 = cx * sz_, a11 = cx * cz, a12 = -sx_;
    final a20 = sx_ * sz_, a21 = sx_ * cz, a22 = cx;
    // Ry * (Rx*Rz)
    m00 = cy * a00 + sy_ * a20;
    m01 = cy * a01 + sy_ * a21;
    m02 = cy * a02 + sy_ * a22;
    m10 = a10;
    m11 = a11;
    m12 = a12;
    m20 = -sy_ * a00 + cy * a20;
    m21 = -sy_ * a01 + cy * a21;
    m22 = -sy_ * a02 + cy * a22;
  }
}

/// A camera-facing soft sprite (sparks, trails, glows).
class Billboard {
  double x = 0, y = 0, z = 0;
  double size = 0.1;
  int color = 0xffffffff;
  bool active = false;
}

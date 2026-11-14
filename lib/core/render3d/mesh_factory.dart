import 'dart:math' as math;

import 'color_math.dart';
import 'mesh.dart';

/// Procedural geometry. Angle convention: a point at local angle `a` and radius `r` is `(r·sin a, y, r·cos a)`;
/// angle 0 faces the camera (+Z).
abstract final class MeshFactory {
  static List<double> _p(double r, double a, double y, [double dz = 0]) => [r * math.sin(a), y, r * math.cos(a) + dz];

  /// UV sphere with smooth normals. [colorAt] receives latitude (0 top .. 1 bottom) and longitude (0..1).
  static MeshBuilder sphere(double radius, int stacks, int slices, int Function(double lat, double lon) colorAt) {
    final b = MeshBuilder();
    List<double> pos(int i, int j) {
      final th = math.pi * i / stacks;
      final ph = 2 * math.pi * j / slices;
      return [math.sin(th) * math.sin(ph), math.cos(th), math.sin(th) * math.cos(ph)];
    }

    void v(List<double> n, int color) => b.vertex(n[0] * radius, n[1] * radius, n[2] * radius, n[0], n[1], n[2], color);

    for (var i = 0; i < stacks; i++) {
      for (var j = 0; j < slices; j++) {
        final a = pos(i, j), bb = pos(i + 1, j), c = pos(i + 1, j + 1), d = pos(i, j + 1);
        final ca = colorAt(i / stacks, j / slices);
        final cb = colorAt((i + 1) / stacks, j / slices);
        final cc = colorAt((i + 1) / stacks, (j + 1) / slices);
        final cd = colorAt(i / stacks, (j + 1) / slices);
        if (i != stacks - 1) {
          v(a, ca);
          v(bb, cb);
          v(c, cc);
        }
        if (i != 0) {
          v(a, ca);
          v(c, cc);
          v(d, cd);
        }
      }
    }
    return b;
  }

  /// One platform segment: annular wedge between [a0]..[a1] with a rounded (chamfered) outer edge.
  /// [yTop] is the top surface, [thickness] extends downwards. [dz] shifts the result along Z
  /// (used to centre debris shards on their own origin).
  ///
  /// [capStart]/[capEnd] control the end walls: neighbouring wedges that sit flush against each other
  /// must not emit the walls between them, otherwise those walls fight the tops in the painter's sort and
  /// flicker as dark lines while the tower spins. [seam] (radians) paints a light edge at [a0] and a dark
  /// groove at [a1] directly into the top surface so tile boundaries stay visible without any geometry
  /// that could pop in front. [innerShade] darkens the top towards the pillar (fake ambient occlusion).
  static void wedge(
    MeshBuilder b, {
    required double a0,
    required double a1,
    required double innerR,
    required double outerR,
    required double yTop,
    required double thickness,
    required int topColor,
    int? topAltColor,
    int? sideColor,
    int? bottomColor,
    int subdivisions = 2,
    double bevel = 0.1,
    bool caps = true,
    bool? capStart,
    bool? capEnd,
    double seam = 0,
    double innerShade = 0,
    double innerBand = 0,
    double outerBand = 0,
    int? bandColor,
    double dz = 0,
  }) {
    final side = sideColor ?? ColorMath.scale(topColor, 0.78);
    final bottom = bottomColor ?? ColorMath.scale(topColor, 0.55);
    final yBot = yTop - thickness;
    final bev = math.min(bevel, thickness * 0.45);
    final rTop = outerR - bev;
    final ySide = yTop - bev;
    final rMid = (innerR + rTop) / 2;
    final hasSeam = seam > 0 && seam * 3 < (a1 - a0);
    final seamLight = ColorMath.lerp(topColor, 0xffffffff, 0.45);
    final seamDark = ColorMath.lerp(topColor, 0xff6a3000, 0.6);
    final band = (innerBand > 0 || outerBand > 0) ? (bandColor ?? topColor) : null;

    // Shared angle list for every strip of the wedge, so top, bevel and side edges meet exactly (no
    // T-junction cracks).
    final ts = <double>[];
    if (hasSeam) {
      ts.add(a0);
      final b0 = a0 + seam, b1 = a1 - seam;
      for (var s = 0; s <= subdivisions; s++) {
        ts.add(b0 + (b1 - b0) * s / subdivisions);
      }
      ts.add(a1);
    } else {
      for (var s = 0; s <= subdivisions; s++) {
        ts.add(a0 + (a1 - a0) * s / subdivisions);
      }
    }
    final segs = ts.length - 1;

    for (var s = 0; s < segs; s++) {
      final t0 = ts[s], t1 = ts[s + 1];
      final s0 = math.sin(t0), c0 = math.cos(t0), s1 = math.sin(t1), c1 = math.cos(t1);
      final inner = hasSeam ? s - 1 : s; // index among the non-seam segments
      int top;
      if (hasSeam && s == 0) {
        top = seamLight;
      } else if (hasSeam && s == segs - 1) {
        top = seamDark;
      } else {
        top = topAltColor == null || inner.isEven ? topColor : topAltColor;
      }
      final topIn = innerShade > 0 ? ColorMath.scale(top, 1 - innerShade) : top;
      // top (split radially so painter's sorting stays accurate next to the pillar)
      if (band != null) {
        // Coloured rings painted into the top itself (coplanar, non-overlapping) instead of raised strips.
        final isSeam = hasSeam && (s == 0 || s == segs - 1);
        final bc = isSeam ? top : band;
        final rA = innerR + innerBand, rB = rTop - outerBand;
        if (innerBand > 0) {
          b.quad(_p(innerR, t0, yTop, dz), _p(rA, t0, yTop, dz), _p(rA, t1, yTop, dz), _p(innerR, t1, yTop, dz), bc);
        }
        final rM = (rA + rB) / 2;
        b.quad(_p(rA, t0, yTop, dz), _p(rM, t0, yTop, dz), _p(rM, t1, yTop, dz), _p(rA, t1, yTop, dz), top);
        b.quad(_p(rM, t0, yTop, dz), _p(rB, t0, yTop, dz), _p(rB, t1, yTop, dz), _p(rM, t1, yTop, dz), top);
        if (outerBand > 0) {
          b.quad(_p(rB, t0, yTop, dz), _p(rTop, t0, yTop, dz), _p(rTop, t1, yTop, dz), _p(rB, t1, yTop, dz), bc);
        }
      } else {
        b.triangle(_p(innerR, t0, yTop, dz), _p(rMid, t0, yTop, dz), _p(rMid, t1, yTop, dz), topIn, top, top);
        b.triangle(_p(innerR, t0, yTop, dz), _p(rMid, t1, yTop, dz), _p(innerR, t1, yTop, dz), topIn, top, topIn);
        b.quad(_p(rMid, t0, yTop, dz), _p(rTop, t0, yTop, dz), _p(rTop, t1, yTop, dz), _p(rMid, t1, yTop, dz), top);
      }
      // bevel strip (smooth normals between up and outward)
      if (bev > 0) {
        const k = 0.7071;
        final hi = ColorMath.lerp(top, 0xffffffff, top == seamDark ? 0.0 : 0.22);
        void bv(List<double> p, double sn, double cs, double up, int color) =>
            b.vertex(p[0], p[1], p[2], sn * k, up, cs * k, color);
        final pa = _p(rTop, t0, yTop, dz), pb = _p(outerR, t0, ySide, dz);
        final pc = _p(outerR, t1, ySide, dz), pd = _p(rTop, t1, yTop, dz);
        bv(pa, s0, c0, k, hi);
        bv(pb, s0, c0, k, side);
        bv(pc, s1, c1, k, side);
        bv(pa, s0, c0, k, hi);
        bv(pc, s1, c1, k, side);
        bv(pd, s1, c1, k, hi);
      }
      // outer side (smooth radial normals)
      {
        final sideTop = hasSeam && s == segs - 1 ? ColorMath.scale(side, 0.8) : side;
        final pa = _p(outerR, t0, ySide, dz), pb = _p(outerR, t0, yBot, dz);
        final pc = _p(outerR, t1, yBot, dz), pd = _p(outerR, t1, ySide, dz);
        b.vertex(pa[0], pa[1], pa[2], s0, 0, c0, sideTop);
        b.vertex(pb[0], pb[1], pb[2], s0, 0, c0, bottom);
        b.vertex(pc[0], pc[1], pc[2], s1, 0, c1, bottom);
        b.vertex(pa[0], pa[1], pa[2], s0, 0, c0, sideTop);
        b.vertex(pc[0], pc[1], pc[2], s1, 0, c1, bottom);
        b.vertex(pd[0], pd[1], pd[2], s1, 0, c1, sideTop);
      }
      // inner side
      b.quad(
        _p(innerR, t0, yTop, dz),
        _p(innerR, t1, yTop, dz),
        _p(innerR, t1, yBot, dz),
        _p(innerR, t0, yBot, dz),
        bottom,
      );
      // bottom
      b.quad(
        _p(innerR, t0, yBot, dz),
        _p(innerR, t1, yBot, dz),
        _p(outerR, t1, yBot, dz),
        _p(outerR, t0, yBot, dz),
        bottom,
      );
    }
    if (capStart ?? caps) {
      // cap at a0 (faces decreasing angle)
      b.quad(
        _p(innerR, a0, yTop, dz),
        _p(innerR, a0, yBot, dz),
        _p(outerR, a0, yBot, dz),
        _p(outerR, a0, ySide, dz),
        side,
      );
      b.triangle(_p(innerR, a0, yTop, dz), _p(outerR, a0, ySide, dz), _p(rTop, a0, yTop, dz), side);
    }
    if (capEnd ?? caps) {
      // cap at a1
      b.quad(
        _p(innerR, a1, yTop, dz),
        _p(outerR, a1, ySide, dz),
        _p(outerR, a1, yBot, dz),
        _p(innerR, a1, yBot, dz),
        side,
      );
      b.triangle(_p(innerR, a1, yTop, dz), _p(rTop, a1, yTop, dz), _p(outerR, a1, ySide, dz), side);
    }
  }

  /// Vertical cylinder side between [y0] (bottom) and [y1] (top). [colorAt] gets slice index.
  static void cylinder(
    MeshBuilder b,
    double radius,
    double y0,
    double y1,
    int slices,
    int Function(int slice) colorAt, {
    bool topCap = false,
  }) {
    for (var j = 0; j < slices; j++) {
      final t0 = 2 * math.pi * j / slices, t1 = 2 * math.pi * (j + 1) / slices;
      final s0 = math.sin(t0), c0 = math.cos(t0), s1 = math.sin(t1), c1 = math.cos(t1);
      final color = colorAt(j);
      final pa = _p(radius, t0, y1), pb = _p(radius, t0, y0), pc = _p(radius, t1, y0), pd = _p(radius, t1, y1);
      b.vertex(pa[0], pa[1], pa[2], s0, 0, c0, color);
      b.vertex(pb[0], pb[1], pb[2], s0, 0, c0, color);
      b.vertex(pc[0], pc[1], pc[2], s1, 0, c1, color);
      b.vertex(pa[0], pa[1], pa[2], s0, 0, c0, color);
      b.vertex(pc[0], pc[1], pc[2], s1, 0, c1, color);
      b.vertex(pd[0], pd[1], pd[2], s1, 0, c1, color);
      if (topCap) {
        b.triangle([0, y1, 0], _p(radius, t0, y1), _p(radius, t1, y1), ColorMath.lerp(color, 0xffffffff, 0.1));
      }
    }
  }

  /// Flat disc facing +Y. Optional [edgeColor] gives a radial gradient.
  static void disc(MeshBuilder b, double radius, double y, int segments, int color, {int? edgeColor}) {
    for (var j = 0; j < segments; j++) {
      final t0 = 2 * math.pi * j / segments, t1 = 2 * math.pi * (j + 1) / segments;
      b.triangle([0, y, 0], _p(radius, t0, y), _p(radius, t1, y), color, edgeColor, edgeColor);
    }
  }

  /// Flat annulus facing +Y.
  static void annulus(MeshBuilder b, double innerR, double outerR, double y, int segments, int color) {
    for (var j = 0; j < segments; j++) {
      final t0 = 2 * math.pi * j / segments, t1 = 2 * math.pi * (j + 1) / segments;
      b.quad(_p(innerR, t0, y), _p(outerR, t0, y), _p(outerR, t1, y), _p(innerR, t1, y), color);
    }
  }
}

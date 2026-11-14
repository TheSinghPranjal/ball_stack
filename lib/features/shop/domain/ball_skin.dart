import 'dart:math' as math;

import '../../../core/render3d/color_math.dart';
import '../../../core/render3d/mesh.dart';

enum BallPattern { band, stripes, rainbow, dots, swirl, solid }

/// Material definition of a ball skin. The 3D mesh is generated from it procedurally.
class BallSkin {
  const BallSkin({
    required this.id,
    required this.name,
    required this.price,
    required this.base,
    required this.accent,
    required this.pattern,
    required this.trail,
    this.specular = 0.8,
    this.shininess = 40,
    this.emissive = 0.0,
    this.rim = 0.3,
    this.premium = false,
    this.fiery = false,
  });

  final String id;
  final String name;
  final int price;
  final int base;
  final int accent;
  final BallPattern pattern;
  final int trail;
  final double specular;
  final double shininess;
  final double emissive;
  final double rim;
  final bool premium;

  /// Always leaves a flame trail.
  final bool fiery;

  bool get isFree => price == 0;

  MeshMaterial get material =>
      MeshMaterial(ambient: 0.55, diffuse: 0.8, specular: specular, shininess: shininess, emissive: emissive, rim: rim);

  /// Vertex colour at latitude (0 top..1 bottom) / longitude (0..1).
  int colorAt(double lat, double lon) {
    switch (pattern) {
      case BallPattern.solid:
        return ColorMath.lerp(base, accent, (lat - 0.5).abs() * 0.6);
      case BallPattern.band:
        return (lat > 0.42 && lat < 0.58) ? accent : base;
      case BallPattern.stripes:
        return ((lon * 8).floor().isEven) ? base : accent;
      case BallPattern.rainbow:
        const hues = [0xFFFF4D6D, 0xFFFF9F43, 0xFFFFE066, 0xFF3EE6B0, 0xFF4FC3FF, 0xFF9B6BFF];
        return hues[(lat * hues.length).floor().clamp(0, hues.length - 1)];
      case BallPattern.dots:
        final h = math.sin(lat * 91.7 + lon * 47.3) * 43758.5453;
        final f = h - h.floorToDouble();
        return f > 0.86 ? accent : base;
      case BallPattern.swirl:
        final v = math.sin((lon * 2 * math.pi * 3) + lat * 9);
        return ColorMath.lerp(base, accent, (v * 0.5 + 0.5));
    }
  }
}

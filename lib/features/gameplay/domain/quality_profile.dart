import '../../../core/enums/game_enums.dart';

/// Rendering budget per graphics-quality setting.
class QualityProfile {
  const QualityProfile({
    required this.floorsAhead,
    required this.arcSubdivisions,
    required this.sphereStacks,
    required this.particleScale,
    required this.trailLength,
    required this.bokeh,
    required this.splats,
    required this.pillarSlices,
  });

  final int floorsAhead;
  final int arcSubdivisions;
  final int sphereStacks;
  final double particleScale;
  final int trailLength;
  final int bokeh;
  final bool splats;
  final int pillarSlices;

  static QualityProfile of(GraphicsQuality q) => switch (q) {
        GraphicsQuality.low => const QualityProfile(
            floorsAhead: 7,
            arcSubdivisions: 1,
            sphereStacks: 10,
            particleScale: 0.45,
            trailLength: 6,
            bokeh: 8,
            splats: false,
            pillarSlices: 10),
        GraphicsQuality.medium => const QualityProfile(
            floorsAhead: 9,
            arcSubdivisions: 2,
            sphereStacks: 14,
            particleScale: 0.75,
            trailLength: 10,
            bokeh: 16,
            splats: true,
            pillarSlices: 14),
        GraphicsQuality.high => const QualityProfile(
            floorsAhead: 11,
            arcSubdivisions: 2,
            sphereStacks: 18,
            particleScale: 1.0,
            trailLength: 14,
            bokeh: 26,
            splats: true,
            pillarSlices: 18),
      };
}

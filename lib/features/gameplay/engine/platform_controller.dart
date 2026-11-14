import '../../../app/theme/colors.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/render3d/color_math.dart';
import '../../../core/render3d/mesh.dart';
import '../../../core/render3d/mesh_factory.dart';
import '../domain/level_config.dart';
import '../domain/quality_profile.dart';
import 'collision_system.dart';

/// Meshes for one floor, in floor-local space (y = 0 is the floor's top surface, angle 0 = slot 0 start).
class FloorMeshes {
  Mesh? solid;
  Mesh? hazard;
  Mesh? bonus;
  Mesh? blink;
  Mesh? sweeper;
  late Mesh pillar;
  late Mesh ring;
}

/// Procedurally generates platform, hazard, pillar and base geometry from the level config and theme.
class PlatformController {
  PlatformController({required this.level, required this.theme, required this.quality});

  final LevelConfig level;
  final GameTheme theme;
  final QualityProfile quality;

  static const double _inset = 0.012;
  static const MeshMaterial platformMaterial = MeshMaterial(
    ambient: 0.66,
    diffuse: 0.68,
    specular: 0.38,
    shininess: 22,
  );
  static const MeshMaterial hazardMaterial = MeshMaterial(
    ambient: 0.6,
    diffuse: 0.6,
    specular: 0.5,
    shininess: 30,
    emissive: 0.3,
  );
  static const MeshMaterial bonusMaterial = MeshMaterial(
    ambient: 0.7,
    diffuse: 0.6,
    specular: 0.9,
    shininess: 40,
    emissive: 0.35,
  );
  static const MeshMaterial pillarMaterial = MeshMaterial(
    ambient: 0.66,
    diffuse: 0.6,
    specular: 0.55,
    shininess: 26,
    rim: 0.25,
  );
  static const MeshMaterial ringMaterial = MeshMaterial(unlit: true);

  /// Angular width of the painted seam between neighbouring tiles.
  static const double _seam = 0.022;

  static bool _flush(SegmentType t) => t != SegmentType.gap;

  /// Side colour: warm tops (gold, orange) get a rich orange side like the reference art; cool tops just a
  /// darker shade of themselves so they don't turn muddy.
  int _sideFor(int top) => ColorMath.r(top) > ColorMath.b(top) + 40
      ? ColorMath.lerp(top, 0xFFE0620A, 0.5)
      : ColorMath.scale(top, 0.72);

  final Map<int, Mesh> _shardCache = {};

  double get _ri => level.platformInnerRadius;
  double get _ro => level.platformOuterRadius;
  double get _th => level.platformThickness;

  FloorMeshes build(FloorSpec f, FloorState state) {
    final solid = MeshBuilder(), hazard = MeshBuilder(), bonus = MeshBuilder(), blink = MeshBuilder();
    const d = GameConstants.slotAngle;
    final sub = quality.arcSubdivisions;
    final n = f.slots.length;
    final types = [for (var s = 0; s < n; s++) CollisionSystem.effectiveType(f, state, s)];
    for (var s = 0; s < n; s++) {
      final type = types[s];
      final safeColor = s.isEven ? theme.safeA : theme.safeB;
      // Every tile shares one block shape, so neighbours sit flush as one continuous ring: no gaps, no end
      // walls and no raised/stacked layers between them. Those used to fight the tops in the painter's sort
      // and flicker (dark lines while spinning, glitching red tiles). Walls are only built next to gaps.
      final prevFlush = _flush(types[(s - 1 + n) % n]), nextFlush = _flush(types[(s + 1) % n]);
      final a0 = s * d + (prevFlush ? 0 : _inset), a1 = (s + 1) * d - (nextFlush ? 0 : _inset);
      void tile(
        MeshBuilder into,
        int top, {
        int? side,
        int? bottom,
        int? alt,
        int subdivisions = 0,
        double innerShade = 0.14,
        double innerBand = 0,
        double outerBand = 0,
        int? band,
      }) => MeshFactory.wedge(
        into,
        a0: a0,
        a1: a1,
        innerR: _ri,
        outerR: _ro,
        yTop: 0,
        thickness: _th,
        topColor: top,
        topAltColor: alt,
        sideColor: side ?? _sideFor(top),
        bottomColor: bottom ?? ColorMath.scale(side ?? _sideFor(top), 0.62),
        subdivisions: subdivisions == 0 ? sub : subdivisions,
        capStart: !prevFlush,
        capEnd: !nextFlush,
        seam: _seam,
        innerShade: innerShade,
        innerBand: innerBand,
        outerBand: outerBand,
        bandColor: band,
      );
      switch (type) {
        case SegmentType.gap:
          break;
        case SegmentType.safe:
          tile(solid, safeColor);
        case SegmentType.breakable:
          tile(
            solid,
            ColorMath.lerp(safeColor, 0xFFFFFFFF, 0.5),
            alt: ColorMath.lerp(safeColor, 0xFF000000, 0.15),
            side: _sideFor(safeColor),
            subdivisions: 4,
            innerShade: 0.1,
          );
        case SegmentType.bonus:
          tile(bonus, theme.bonus, alt: ColorMath.lerp(theme.bonus, 0xFFFFFFFF, 0.35), subdivisions: 2);
        case SegmentType.danger:
          tile(
            hazard,
            theme.danger,
            side: ColorMath.lerp(theme.danger, theme.dangerRim, 0.45),
            bottom: ColorMath.scale(theme.danger, 0.6),
            innerShade: 0,
            innerBand: 0.12,
            outerBand: 0.22,
            band: theme.dangerRim,
          );
        case SegmentType.blink:
          tile(blink, 0xFFFFFFFF, side: 0xFFDDDDEE, bottom: 0xFFB0B0C8, innerShade: 0);
      }
    }
    final out = FloorMeshes()
      ..solid = solid.isEmpty ? null : solid.build(platformMaterial)
      ..hazard = hazard.isEmpty ? null : hazard.build(hazardMaterial)
      ..bonus = bonus.isEmpty ? null : bonus.build(bonusMaterial)
      ..blink = blink.isEmpty ? null : blink.build(hazardMaterial)
      ..pillar = _pillar()
      ..ring = _ring();
    if (f.sweeper != null) out.sweeper = _sweeper(f.sweeper!.width);
    return out;
  }

  Mesh _sweeper(double width) {
    final b = MeshBuilder();
    MeshFactory.wedge(
      b,
      a0: 0,
      a1: width,
      innerR: _ri + 0.02,
      outerR: _ro + 0.25,
      yTop: 0.62,
      thickness: 0.24,
      topColor: theme.danger,
      sideColor: theme.dangerRim,
      subdivisions: 2,
    );
    MeshFactory.wedge(
      b,
      a0: 0.03,
      a1: width - 0.03,
      innerR: _ro - 0.2,
      outerR: _ro + 0.18,
      yTop: 0.65,
      thickness: 0.03,
      topColor: theme.dangerRim,
      subdivisions: 2,
      bevel: 0,
      caps: false,
    );
    return b.build(hazardMaterial);
  }

  Mesh? _pillarMesh;

  /// Pillar section spanning from this floor's top down to the next floor's top.
  Mesh _pillar() {
    return _pillarMesh ??= () {
      final b = MeshBuilder();
      final h = level.floorSpacing;
      final slices = quality.pillarSlices;
      // Stacked bands instead of one tall strip: the painter's sort uses each triangle's average depth, and
      // full-height triangles would sort in front of the neon ring and platform edges they sit behind.
      const bands = 4;
      for (var k = 0; k < bands; k++) {
        MeshFactory.cylinder(
          b,
          GameConstants.pillarRadius,
          -h + h * k / bands,
          -h + h * (k + 1) / bands,
          slices,
          (_) => theme.pillar,
        );
      }
      return b.build(pillarMaterial);
    }();
  }

  Mesh? _ringMesh;

  /// Glowing neon band hugging the pillar between floors: a bright core plus a soft halo.
  Mesh _ring() {
    return _ringMesh ??= () {
      final b = MeshBuilder();
      final slices = quality.pillarSlices + 4;
      // The camera looks down, so the front of each platform hides the upper part of the pillar below it;
      // the visible stretch is just above the next floor, so the ring sits there.
      final y = -level.floorSpacing + 0.7;
      const r = GameConstants.pillarRadius;
      final core = ColorMath.lerp(theme.ring, 0xFFFFFFFF, 0.35);
      MeshFactory.cylinder(b, r + 0.09, y - 0.15, y + 0.15, slices, (_) => ColorMath.withAlpha(theme.ring, 0.22));
      MeshFactory.cylinder(b, r + 0.035, y - 0.08, y + 0.08, slices, (_) => core);
      return b.build(ringMaterial);
    }();
  }

  /// Pillar above the first floor, with a rounded cap.
  Mesh pillarTop() {
    final b = MeshBuilder();
    MeshFactory.cylinder(
      b,
      GameConstants.pillarRadius,
      0,
      2.8,
      quality.pillarSlices,
      (_) => theme.pillar,
      topCap: true,
    );
    return b.build(pillarMaterial);
  }

  /// Finish platform under the last floor.
  Mesh base() {
    final b = MeshBuilder();
    const d = GameConstants.slotAngle;
    for (var s = 0; s < GameConstants.slotsPerFloor; s++) {
      MeshFactory.wedge(
        b,
        a0: s * d,
        a1: (s + 1) * d,
        innerR: 0.05,
        outerR: _ro + 0.35,
        yTop: 0,
        thickness: 1.1,
        topColor: s.isEven ? theme.accent : 0xFFFFFFFF,
        sideColor: ColorMath.scale(theme.accent, 0.8),
        subdivisions: 2,
        caps: false,
      );
    }
    MeshFactory.cylinder(b, GameConstants.pillarRadius, -6, -1.1, quality.pillarSlices, (j) => theme.pillar);
    return b.build(bonusMaterial);
  }

  /// Debris wedge for one slot, centred on its own origin. Cached per colour.
  Mesh shard(int color) => _shardCache.putIfAbsent(color, () {
    final b = MeshBuilder();
    const half = GameConstants.slotAngle / 2 - 0.02;
    MeshFactory.wedge(
      b,
      a0: -half,
      a1: half,
      innerR: _ri,
      outerR: _ro,
      yTop: _th / 2,
      thickness: _th,
      topColor: color,
      subdivisions: 1,
      bevel: 0.06,
      dz: -GameConstants.ballOrbitRadius,
    );
    return b.build(platformMaterial);
  });
}

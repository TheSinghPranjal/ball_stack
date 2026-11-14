import 'dart:ui' as ui;

import 'package:ball_stack/core/render3d/mesh.dart';
import 'package:ball_stack/core/render3d/mesh_factory.dart';
import 'package:ball_stack/core/render3d/mesh_instance.dart';
import 'package:ball_stack/core/render3d/scene_renderer.dart';
import 'package:ball_stack/features/levels/data/level_generator.dart';
import 'package:ball_stack/core/enums/game_enums.dart';
import 'package:ball_stack/features/gameplay/engine/collision_system.dart';
import 'package:ball_stack/features/gameplay/engine/platform_controller.dart';
import 'package:ball_stack/features/gameplay/domain/quality_profile.dart';
import 'package:ball_stack/app/theme/colors.dart';
import 'package:flutter_test/flutter_test.dart';

RenderScene sceneWith(Mesh mesh) {
  final s = RenderScene();
  s.camera
    ..lookAt(0, 0, 5, 0, 0, 0)
    ..cx = 200
    ..cy = 200
    ..focal = 400;
  s.objects.add(MeshInstance(mesh));
  return s;
}

int draw(SceneRenderer r, RenderScene s) {
  final rec = ui.PictureRecorder();
  r.render(ui.Canvas(rec), s);
  rec.endRecording().dispose();
  return r.stats.drawn;
}

void main() {
  test('front-facing triangle is drawn, back-facing is culled', () {
    final front = MeshBuilder()..triangle([-1, -1, 0], [1, -1, 0], [0, 1, 0], 0xFFFF0000);
    final back = MeshBuilder()..triangle([-1, -1, 0], [0, 1, 0], [1, -1, 0], 0xFFFF0000);
    final r = SceneRenderer();
    expect(draw(r, sceneWith(front.build())), 1);
    expect(draw(r, sceneWith(back.build())), 0);
  });

  test('closed sphere: roughly half the triangles survive culling', () {
    final m = MeshFactory.sphere(1, 12, 22, (_, _) => 0xFFFFFFFF).build();
    final r = SceneRenderer();
    final n = draw(r, sceneWith(m));
    expect(n, greaterThan(m.triangleCount * 0.35));
    expect(n, lessThan(m.triangleCount * 0.65));
  });

  test('objects behind the camera are clipped', () {
    final m = MeshBuilder()..triangle([-1, -1, 10], [1, -1, 10], [0, 1, 10], 0xFFFFFFFF);
    expect(draw(SceneRenderer(), sceneWith(m.build())), 0);
  });

  test('a full tower floor builds watertight-looking geometry within budget', () {
    final level = LevelGenerator().generate(40, InputMode.spin);
    final pc = PlatformController(
        level: level, theme: GameThemes.all.first, quality: QualityProfile.of(GraphicsQuality.high));
    final meshes = pc.build(level.floors[3], FloorState());
    final tris = (meshes.solid?.triangleCount ?? 0) +
        (meshes.hazard?.triangleCount ?? 0) +
        (meshes.bonus?.triangleCount ?? 0) +
        (meshes.blink?.triangleCount ?? 0);
    expect(tris, greaterThan(100));
    expect(tris, lessThan(1200), reason: 'per-floor triangle budget for mobile');
  });
}

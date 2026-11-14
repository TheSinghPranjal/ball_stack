import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'camera3d.dart';
import 'mesh_instance.dart';

/// Scene-wide lighting and atmosphere.
class SceneLighting {
  /// Direction *towards* the key light (normalised in [normalize]).
  double lx = -0.45, ly = 0.8, lz = 0.55;
  int lightColor = 0xfffff4e8;
  int skyColor = 0xffbfc8ff;
  int groundColor = 0xff3a2a55;
  int fogColor = 0xff2a2160;
  double fogNear = 16;
  double fogFar = 34;
  double fogMax = 0.85;

  void normalize() {
    final l = math.sqrt(lx * lx + ly * ly + lz * lz);
    lx /= l;
    ly /= l;
    lz /= l;
  }
}

/// Everything the renderer needs for one frame. Built and owned by the game (SceneManager).
class RenderScene {
  final Camera3D camera = Camera3D();
  final SceneLighting lighting = SceneLighting();
  final List<MeshInstance> objects = [];
  final List<Billboard> billboards = [];
  final List<SpriteInstance> sprites = [];
}

/// Statistics for profiling overlays and tests.
class RenderStats {
  int submitted = 0;
  int drawn = 0;
  double milliseconds = 0;
}

/// Software 3D pipeline that projects, culls, lights and depth-sorts triangles on the CPU and hands the
/// whole frame to the GPU rasteriser as a single [ui.Canvas.drawVertices] call.
class SceneRenderer {
  SceneRenderer({int initialCapacity = 12000}) {
    _ensure(initialCapacity);
  }

  static const int _buckets = 4096;

  final RenderStats stats = RenderStats();
  final Stopwatch _sw = Stopwatch();
  final ui.Paint _paint = ui.Paint()..isAntiAlias = true;

  int _cap = 0;
  late Float32List _xy; // 6 per tri
  late Int32List _col; // 3 per tri
  late Float32List _depth; // 1 per tri
  late Int32List _order;
  late Float32List _outXy;
  late Int32List _outCol;
  final Int32List _bucketCount = Int32List(_buckets + 1);
  final Int32List _bucketStart = Int32List(_buckets + 1);
  int _tri = 0;

  // Projected sprites for the current frame.
  final List<_ProjectedSprite> _sprites = [];
  final ui.Paint _spritePaint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

  void _ensure(int cap) {
    if (cap <= _cap) return;
    final newCap = math.max(cap, (_cap * 1.5).ceil());
    final xy = Float32List(newCap * 6);
    final col = Int32List(newCap * 3);
    final depth = Float32List(newCap);
    if (_cap > 0) {
      xy.setRange(0, _tri * 6, _xy);
      col.setRange(0, _tri * 3, _col);
      depth.setRange(0, _tri, _depth);
    }
    _xy = xy;
    _col = col;
    _depth = depth;
    _order = Int32List(newCap);
    _outXy = Float32List(newCap * 6);
    _outCol = Int32List(newCap * 3);
    _cap = newCap;
  }

  void render(ui.Canvas canvas, RenderScene scene) {
    _sw
      ..reset()
      ..start();
    _tri = 0;
    stats.submitted = 0;
    final cam = scene.camera;
    final light = scene.lighting;
    for (final o in scene.objects) {
      if (o.visible && o.alpha > 0.004) _emitObject(o, cam, light);
    }
    for (final b in scene.billboards) {
      if (b.active) _emitBillboard(b, cam);
    }
    _sprites.clear();
    for (final s in scene.sprites) {
      if (s.visible && s.image != null && s.alpha > 0.004) _projectSprite(s, cam);
    }
    stats.drawn = _tri;
    if (_tri > 0 || _sprites.isNotEmpty) {
      _sortAndDraw(canvas);
    }
    _sw.stop();
    stats.milliseconds = _sw.elapsedMicroseconds / 1000.0;
  }

  void _emitObject(MeshInstance o, Camera3D cam, SceneLighting light) {
    final mesh = o.mesh;
    final mat = mesh.material;
    final p = mesh.positions;
    final n = mesh.normals;
    final c = mesh.colors;
    final triCount = mesh.triangleCount;
    stats.submitted += triCount;
    _ensure(_tri + triCount + 64);

    final m00 = o.m00, m01 = o.m01, m02 = o.m02;
    final m10 = o.m10, m11 = o.m11, m12 = o.m12;
    final m20 = o.m20, m21 = o.m21, m22 = o.m22;
    final sx = o.sx, sy = o.sy, sz = o.sz;
    final tx = o.x, ty = o.y, tz = o.z;
    final ex = cam.ex, ey = cam.ey, ez = cam.ez;
    final rx = cam.rx, ry = cam.ry, rz = cam.rz;
    final ux = cam.ux, uy = cam.uy, uz = cam.uz;
    final fx = cam.fx, fy = cam.fy, fz = cam.fz;
    final focal = cam.focal, ccx = cam.cx, ccy = cam.cy, near = cam.near;
    final screenW = ccx * 2, screenH = ccy * 2;

    final lx = light.lx, ly = light.ly, lz = light.lz;
    final lr = ((light.lightColor >> 16) & 0xff) / 255.0;
    final lg = ((light.lightColor >> 8) & 0xff) / 255.0;
    final lb = (light.lightColor & 0xff) / 255.0;
    final skr = ((light.skyColor >> 16) & 0xff) / 255.0;
    final skg = ((light.skyColor >> 8) & 0xff) / 255.0;
    final skb = (light.skyColor & 0xff) / 255.0;
    final gr = ((light.groundColor >> 16) & 0xff) / 255.0;
    final gg = ((light.groundColor >> 8) & 0xff) / 255.0;
    final gb = (light.groundColor & 0xff) / 255.0;
    final fogR = ((light.fogColor >> 16) & 0xff).toDouble();
    final fogG = ((light.fogColor >> 8) & 0xff).toDouble();
    final fogB = (light.fogColor & 0xff).toDouble();
    final fogNear = light.fogNear, fogSpan = math.max(0.001, light.fogFar - light.fogNear), fogMax = light.fogMax;
    final useFog = mat.fog;

    final ambient = mat.ambient, diffuse = mat.diffuse, specular = mat.specular, shininess = mat.shininess;
    final emissive = (mat.emissive + o.emissiveBoost).clamp(0.0, 1.0);
    final rim = mat.rim;
    final unlit = mat.unlit;
    final doubleSided = mat.doubleSided;
    final alphaMul = o.alpha;
    final tintAmt = o.tintAmount;
    final tint = o.tint;
    final tintR = ((tint >> 16) & 0xff).toDouble();
    final tintG = ((tint >> 8) & 0xff).toDouble();
    final tintB = (tint & 0xff).toDouble();
    final bias = o.depthBias;

    final xy = _xy;
    final col = _col;
    final depthBuf = _depth;

    // Scratch for the 3 vertices of the current triangle.
    double wx0 = 0, wy0 = 0, wz0 = 0, wx1 = 0, wy1 = 0, wz1 = 0, wx2 = 0, wy2 = 0, wz2 = 0;

    for (var t = 0; t < triCount; t++) {
      final i0 = t * 9;
      // ---- world positions
      {
        final ax = p[i0] * sx, ay = p[i0 + 1] * sy, az = p[i0 + 2] * sz;
        wx0 = m00 * ax + m01 * ay + m02 * az + tx;
        wy0 = m10 * ax + m11 * ay + m12 * az + ty;
        wz0 = m20 * ax + m21 * ay + m22 * az + tz;
        final bx = p[i0 + 3] * sx, by = p[i0 + 4] * sy, bz = p[i0 + 5] * sz;
        wx1 = m00 * bx + m01 * by + m02 * bz + tx;
        wy1 = m10 * bx + m11 * by + m12 * bz + ty;
        wz1 = m20 * bx + m21 * by + m22 * bz + tz;
        final cx = p[i0 + 6] * sx, cy = p[i0 + 7] * sy, cz = p[i0 + 8] * sz;
        wx2 = m00 * cx + m01 * cy + m02 * cz + tx;
        wy2 = m10 * cx + m11 * cy + m12 * cz + ty;
        wz2 = m20 * cx + m21 * cy + m22 * cz + tz;
      }
      // ---- back-face culling (world space)
      final e1x = wx1 - wx0, e1y = wy1 - wy0, e1z = wz1 - wz0;
      final e2x = wx2 - wx0, e2y = wy2 - wy0, e2z = wz2 - wz0;
      final fnx = e1y * e2z - e1z * e2y;
      final fny = e1z * e2x - e1x * e2z;
      final fnz = e1x * e2y - e1y * e2x;
      final facing = fnx * (wx0 - ex) + fny * (wy0 - ey) + fnz * (wz0 - ez);
      if (facing >= 0 && !doubleSided) continue;

      // ---- view space
      final d0x = wx0 - ex, d0y = wy0 - ey, d0z = wz0 - ez;
      final d1x = wx1 - ex, d1y = wy1 - ey, d1z = wz1 - ez;
      final d2x = wx2 - ex, d2y = wy2 - ey, d2z = wz2 - ez;
      final vz0 = d0x * fx + d0y * fy + d0z * fz;
      final vz1 = d1x * fx + d1y * fy + d1z * fz;
      final vz2 = d2x * fx + d2y * fy + d2z * fz;
      if (vz0 < near || vz1 < near || vz2 < near) continue;
      final sx0 = ccx + focal * (d0x * rx + d0y * ry + d0z * rz) / vz0;
      final sy0 = ccy - focal * (d0x * ux + d0y * uy + d0z * uz) / vz0;
      final sx1 = ccx + focal * (d1x * rx + d1y * ry + d1z * rz) / vz1;
      final sy1 = ccy - focal * (d1x * ux + d1y * uy + d1z * uz) / vz1;
      final sx2 = ccx + focal * (d2x * rx + d2y * ry + d2z * rz) / vz2;
      final sy2 = ccy - focal * (d2x * ux + d2y * uy + d2z * uz) / vz2;
      // ---- screen-rect rejection
      if ((sx0 < 0 && sx1 < 0 && sx2 < 0) ||
          (sx0 > screenW && sx1 > screenW && sx2 > screenW) ||
          (sy0 < 0 && sy1 < 0 && sy2 < 0) ||
          (sy0 > screenH && sy1 > screenH && sy2 > screenH)) {
        continue;
      }

      final o6 = _tri * 6;
      xy[o6] = sx0;
      xy[o6 + 1] = sy0;
      xy[o6 + 2] = sx1;
      xy[o6 + 3] = sy1;
      xy[o6 + 4] = sx2;
      xy[o6 + 5] = sy2;
      final avgZ = (vz0 + vz1 + vz2) * (1 / 3);
      depthBuf[_tri] = avgZ + bias;

      // ---- lighting per vertex
      final flip = (facing >= 0 && doubleSided) ? -1.0 : 1.0;
      for (var k = 0; k < 3; k++) {
        final vi = t * 3 + k;
        final base = c[vi];
        final ba = ((base >> 24) & 0xff) * alphaMul;
        var br = ((base >> 16) & 0xff).toDouble();
        var bg = ((base >> 8) & 0xff).toDouble();
        var bb = (base & 0xff).toDouble();
        if (tintAmt > 0) {
          br += (tintR - br) * tintAmt;
          bg += (tintG - bg) * tintAmt;
          bb += (tintB - bb) * tintAmt;
        }
        double r, g, b;
        final vz = k == 0 ? vz0 : (k == 1 ? vz1 : vz2);
        if (unlit) {
          r = br;
          g = bg;
          b = bb;
        } else {
          final ni = vi * 3;
          final nx = n[ni], ny = n[ni + 1], nz = n[ni + 2];
          var wnx = (m00 * nx + m01 * ny + m02 * nz) * flip;
          var wny = (m10 * nx + m11 * ny + m12 * nz) * flip;
          var wnz = (m20 * nx + m21 * ny + m22 * nz) * flip;
          var dif = wnx * lx + wny * ly + wnz * lz;
          if (dif < 0) dif = 0;
          final h = 0.5 + 0.5 * wny;
          final ar = gr + (skr - gr) * h, ag = gg + (skg - gg) * h, ab = gb + (skb - gb) * h;
          r = br * (ambient * ar + diffuse * dif * lr);
          g = bg * (ambient * ag + diffuse * dif * lg);
          b = bb * (ambient * ab + diffuse * dif * lb);
          if (specular > 0 || rim > 0) {
            double px, py, pz;
            if (k == 0) {
              px = d0x;
              py = d0y;
              pz = d0z;
            } else if (k == 1) {
              px = d1x;
              py = d1y;
              pz = d1z;
            } else {
              px = d2x;
              py = d2y;
              pz = d2z;
            }
            final il = 1 / math.sqrt(px * px + py * py + pz * pz);
            final vx = -px * il, vy = -py * il, vzv = -pz * il; // towards eye
            if (specular > 0) {
              var hx = lx + vx, hy = ly + vy, hz = lz + vzv;
              final hl = 1 / math.sqrt(hx * hx + hy * hy + hz * hz);
              hx *= hl;
              hy *= hl;
              hz *= hl;
              final nh = wnx * hx + wny * hy + wnz * hz;
              if (nh > 0) {
                final s = math.pow(nh, shininess) * specular * 255;
                r += s * lr;
                g += s * lg;
                b += s * lb;
              }
            }
            if (rim > 0) {
              var nv = wnx * vx + wny * vy + wnz * vzv;
              if (nv < 0) nv = 0;
              final q = 1 - nv;
              final rr = q * q * q * rim;
              r += (br * 0.6 + 255 * 0.4) * rr;
              g += (bg * 0.6 + 255 * 0.4) * rr;
              b += (bb * 0.6 + 255 * 0.4) * rr;
            }
          }
          if (emissive > 0) {
            r = r * (1 - emissive) + br * emissive * 1.15;
            g = g * (1 - emissive) + bg * emissive * 1.15;
            b = b * (1 - emissive) + bb * emissive * 1.15;
          }
        }
        if (useFog) {
          var ft = (vz - fogNear) / fogSpan;
          if (ft > 0) {
            if (ft > 1) ft = 1;
            ft *= fogMax;
            r += (fogR - r) * ft;
            g += (fogG - g) * ft;
            b += (fogB - b) * ft;
          }
        }
        final ir = r < 0 ? 0 : (r > 255 ? 255 : r.toInt());
        final ig = g < 0 ? 0 : (g > 255 ? 255 : g.toInt());
        final ib = b < 0 ? 0 : (b > 255 ? 255 : b.toInt());
        final ia = ba < 0 ? 0 : (ba > 255 ? 255 : ba.toInt());
        col[_tri * 3 + k] = (ia << 24) | (ir << 16) | (ig << 8) | ib;
      }
      _tri++;
    }
  }

  /// Soft diamond sprite made of 4 triangles: opaque centre, transparent tips.
  void _emitBillboard(Billboard bb, Camera3D cam) {
    final dx = bb.x - cam.ex, dy = bb.y - cam.ey, dz = bb.z - cam.ez;
    final vz = dx * cam.fx + dy * cam.fy + dz * cam.fz;
    if (vz < cam.near) return;
    final sx = cam.cx + cam.focal * (dx * cam.rx + dy * cam.ry + dz * cam.rz) / vz;
    final sy = cam.cy - cam.focal * (dx * cam.ux + dy * cam.uy + dz * cam.uz) / vz;
    final s = cam.focal * bb.size / vz;
    if (s < 0.3) return;
    if (sx + s < 0 || sx - s > cam.cx * 2 || sy + s < 0 || sy - s > cam.cy * 2) return;
    _ensure(_tri + 4);
    final centre = bb.color;
    final edge = centre & 0x00ffffff;
    const offs = [0.0, -1.0, 1.0, 0.0, 0.0, 1.0, -1.0, 0.0, 0.0, -1.0];
    for (var i = 0; i < 4; i++) {
      final o6 = _tri * 6;
      _xy[o6] = sx;
      _xy[o6 + 1] = sy;
      _xy[o6 + 2] = sx + offs[i * 2] * s;
      _xy[o6 + 3] = sy + offs[i * 2 + 1] * s;
      _xy[o6 + 4] = sx + offs[i * 2 + 2] * s;
      _xy[o6 + 5] = sy + offs[i * 2 + 3] * s;
      _col[_tri * 3] = centre;
      _col[_tri * 3 + 1] = edge;
      _col[_tri * 3 + 2] = edge;
      _depth[_tri] = vz - 0.05;
      _tri++;
    }
  }

  void _projectSprite(SpriteInstance s, Camera3D cam) {
    final dx = s.x - cam.ex, dy = s.y - cam.ey, dz = s.z - cam.ez;
    final vz = dx * cam.fx + dy * cam.fy + dz * cam.fz;
    if (vz < cam.near) return;
    final sx = cam.cx + cam.focal * (dx * cam.rx + dy * cam.ry + dz * cam.rz) / vz;
    final sy = cam.cy - cam.focal * (dx * cam.ux + dy * cam.uy + dz * cam.uz) / vz;
    final w = cam.focal * s.width / vz, h = cam.focal * s.height / vz;
    if (w < 0.5 || h < 0.5) return;
    _sprites.add(_ProjectedSprite(s, sx, sy, w, h, vz + s.depthBias));
  }

  void _drawSprite(ui.Canvas canvas, _ProjectedSprite p) {
    final s = p.sprite;
    _spritePaint.color = ui.Color.fromRGBO(255, 255, 255, s.alpha.clamp(0.0, 1.0));
    canvas
      ..save()
      ..translate(p.sx, p.sy)
      ..rotate(s.rotation)
      ..scale(s.scaleX, s.scaleY)
      ..drawImageRect(s.image!, s.src, ui.Rect.fromLTWH(-p.w * s.anchorX, -p.h * s.anchorY, p.w, p.h), _spritePaint)
      ..restore();
  }

  void _drawRange(ui.Canvas canvas, int from, int to) {
    if (to <= from) return;
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(_outXy, from * 6, to * 6),
      colors: Int32List.sublistView(_outCol, from * 3, to * 3),
    );
    canvas.drawVertices(vertices, ui.BlendMode.dst, _paint);
    vertices.dispose();
  }

  void _sortAndDraw(ui.Canvas canvas) {
    final n = _tri;
    if (n == 0) {
      _sprites.sort((a, b) => b.depth.compareTo(a.depth));
      for (final s in _sprites) {
        _drawSprite(canvas, s);
      }
      return;
    }
    var minD = double.infinity, maxD = -double.infinity;
    for (var i = 0; i < n; i++) {
      final d = _depth[i];
      if (d < minD) minD = d;
      if (d > maxD) maxD = d;
    }
    final span = math.max(1e-6, maxD - minD);
    final scale = (_buckets - 1) / span;
    final counts = _bucketCount;
    counts.fillRange(0, _buckets + 1, 0);
    // Far triangles first: bucket key = (maxD - d).
    for (var i = 0; i < n; i++) {
      final k = ((maxD - _depth[i]) * scale).toInt();
      counts[k + 1]++;
    }
    for (var i = 0; i < _buckets; i++) {
      counts[i + 1] += counts[i];
    }
    _bucketStart.setAll(0, counts);
    for (var i = 0; i < n; i++) {
      final k = ((maxD - _depth[i]) * scale).toInt();
      _order[counts[k]++] = i;
    }
    final outXy = _outXy, outCol = _outCol, xy = _xy, col = _col;
    for (var j = 0; j < n; j++) {
      final i = _order[j];
      final s6 = i * 6, d6 = j * 6;
      outXy[d6] = xy[s6];
      outXy[d6 + 1] = xy[s6 + 1];
      outXy[d6 + 2] = xy[s6 + 2];
      outXy[d6 + 3] = xy[s6 + 3];
      outXy[d6 + 4] = xy[s6 + 4];
      outXy[d6 + 5] = xy[s6 + 5];
      final s3 = i * 3, d3 = j * 3;
      outCol[d3] = col[s3];
      outCol[d3 + 1] = col[s3 + 1];
      outCol[d3 + 2] = col[s3 + 2];
    }
    if (_sprites.isEmpty) {
      _drawRange(canvas, 0, n);
      return;
    }
    // Interleave sprites: each one is drawn after every triangle farther away than it (painter's order).
    _sprites.sort((a, b) => b.depth.compareTo(a.depth));
    var drawn = 0;
    for (final s in _sprites) {
      int split;
      if (s.depth >= maxD) {
        split = 0;
      } else if (s.depth <= minD) {
        split = n;
      } else {
        split = _bucketStart[((maxD - s.depth) * scale).toInt()];
      }
      if (split < drawn) split = drawn;
      _drawRange(canvas, drawn, split);
      drawn = split;
      _drawSprite(canvas, s);
    }
    _drawRange(canvas, drawn, n);
  }
}

class _ProjectedSprite {
  _ProjectedSprite(this.sprite, this.sx, this.sy, this.w, this.h, this.depth);

  final SpriteInstance sprite;
  final double sx, sy, w, h, depth;
}

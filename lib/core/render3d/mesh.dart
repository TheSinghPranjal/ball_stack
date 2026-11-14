import 'dart:math' as math;
import 'dart:typed_data';

/// Surface response of a mesh to lighting.
class MeshMaterial {
  const MeshMaterial({
    this.ambient = 0.55,
    this.diffuse = 0.75,
    this.specular = 0.15,
    this.shininess = 16,
    this.emissive = 0.0,
    this.rim = 0.0,
    this.doubleSided = false,
    this.unlit = false,
    this.fog = true,
  });

  final double ambient;
  final double diffuse;
  final double specular;
  final double shininess;

  /// 0..1 — how much of the base colour ignores lighting (glow).
  final double emissive;

  /// Fresnel-like rim highlight strength.
  final double rim;
  final bool doubleSided;

  /// Unlit meshes output their vertex colour (with alpha) verbatim.
  final bool unlit;
  final bool fog;

  static const matte = MeshMaterial();
  static const glossy = MeshMaterial(specular: 0.9, shininess: 48, rim: 0.35, ambient: 0.5);
  static const glow = MeshMaterial(emissive: 0.6, specular: 0.4, shininess: 24);
  static const decal = MeshMaterial(unlit: true, doubleSided: true);
}

/// Immutable, non-indexed triangle mesh: 3 consecutive vertices form a triangle.
/// Vertex colours are ARGB ints; alpha is respected by the renderer.
class Mesh {
  Mesh(this.positions, this.normals, this.colors, this.material)
    : assert(positions.length == normals.length),
      assert(colors.length * 3 == positions.length);

  final Float32List positions;
  final Float32List normals;
  final Int32List colors;
  final MeshMaterial material;

  int get vertexCount => colors.length;
  int get triangleCount => colors.length ~/ 3;
}

/// Accumulates triangles at build time (not used in the per-frame hot path).
class MeshBuilder {
  final List<double> _p = [];
  final List<double> _n = [];
  final List<int> _c = [];

  int get triangleCount => _c.length ~/ 3;
  bool get isEmpty => _c.isEmpty;

  void vertex(double x, double y, double z, double nx, double ny, double nz, int color) {
    _p
      ..add(x)
      ..add(y)
      ..add(z);
    _n
      ..add(nx)
      ..add(ny)
      ..add(nz);
    _c.add(color);
  }

  /// Flat triangle (normal from winding, counter-clockwise = front).
  void triangle(List<double> a, List<double> b, List<double> c, int color, [int? colorB, int? colorC]) {
    final ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
    final vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
    var nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
    final len = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len < 1e-12) return;
    nx /= len;
    ny /= len;
    nz /= len;
    vertex(a[0], a[1], a[2], nx, ny, nz, color);
    vertex(b[0], b[1], b[2], nx, ny, nz, colorB ?? color);
    vertex(c[0], c[1], c[2], nx, ny, nz, colorC ?? color);
  }

  /// Flat quad a-b-c-d (counter-clockwise when seen from the front).
  void quad(List<double> a, List<double> b, List<double> c, List<double> d, int color) {
    triangle(a, b, c, color);
    triangle(a, c, d, color);
  }

  void append(MeshBuilder other) {
    _p.addAll(other._p);
    _n.addAll(other._n);
    _c.addAll(other._c);
  }

  Mesh build([MeshMaterial material = MeshMaterial.matte]) =>
      Mesh(Float32List.fromList(_p), Float32List.fromList(_n), Int32List.fromList(_c), material);
}

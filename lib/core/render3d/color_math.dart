/// Integer ARGB colour helpers used in the render hot path (no `Color` allocations).
abstract final class ColorMath {
  static int argb(int a, int r, int g, int b) =>
      ((a & 0xff) << 24) | ((r & 0xff) << 16) | ((g & 0xff) << 8) | (b & 0xff);

  static int a(int c) => (c >> 24) & 0xff;
  static int r(int c) => (c >> 16) & 0xff;
  static int g(int c) => (c >> 8) & 0xff;
  static int b(int c) => c & 0xff;

  static int lerp(int c1, int c2, double t) {
    if (t <= 0) return c1;
    if (t >= 1) return c2;
    int ch(int s) {
      final x = (c1 >> s) & 0xff, y = (c2 >> s) & 0xff;
      return (x + (y - x) * t).round() & 0xff;
    }

    return (ch(24) << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0);
  }

  /// Multiplies RGB by [k] (keeps alpha).
  static int scale(int c, double k) {
    int ch(int s) => (((c >> s) & 0xff) * k).round().clamp(0, 255);
    return (c & 0xff000000) | (ch(16) << 16) | (ch(8) << 8) | ch(0);
  }

  static int withAlpha(int c, double alpha) => ((alpha.clamp(0.0, 1.0) * 255).round() << 24) | (c & 0x00ffffff);

  static int fromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return int.parse(h.length == 6 ? 'ff$h' : h, radix: 16).toSigned(32);
  }
}

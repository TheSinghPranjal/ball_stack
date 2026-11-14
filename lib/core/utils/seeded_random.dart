/// Small deterministic PRNG (mulberry32-style) so towers regenerate identically on every platform.
class SeededRandom {
  SeededRandom(int seed) : _state = seed & 0xffffffff;

  int _state;

  /// Uniform double in [0, 1).
  double nextDouble() {
    _state = (_state + 0x6D2B79F5) & 0xffffffff;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= (t + _imul(t ^ (t >>> 7), t | 61)) & 0xffffffff;
    t = (t ^ (t >>> 14)) & 0xffffffff;
    return t / 4294967296.0;
  }

  int nextInt(int max) => (nextDouble() * max).floor().clamp(0, max - 1);

  /// Inclusive range.
  int range(int min, int max) => min + nextInt(max - min + 1);

  double between(double a, double b) => a + (b - a) * nextDouble();

  bool chance(double p) => nextDouble() < p;

  static int _imul(int a, int b) => (a * b) & 0xffffffff;
}

/// 32-bit FNV-1a hash of a string; used to derive level seeds.
int fnv1a(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

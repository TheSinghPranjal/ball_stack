/// How the player interacts with the tower.
enum InputMode {
  /// Primary reference: drag to spin the tower; the ball bounces on its own.
  spin,

  /// Secondary reference: tower auto-rotates; hold to dive and smash rings, release to bounce.
  smash,
}

enum GraphicsQuality { low, medium, high }

enum Difficulty { easy, normal, hard, expert, insane }

/// Logical identity of one angular slot of a floor.
enum SegmentType {
  safe,
  gap,
  danger,

  /// Toggles between safe and danger on a timer.
  blink,

  /// Breaks after one bounce and becomes a gap.
  breakable,

  /// Gold slot: bounce on it to collect a coin (once).
  bonus,
}

/// Formal gameplay states (see docs/architecture/ARCHITECTURE.md §4).
enum GamePhase {
  initializing,
  loading,
  ready,
  intro,
  playing,
  falling,
  bouncing,
  combo,
  destruction,
  paused,
  levelCompleted,
  gameOver,
  restarting,
}

enum GameEventType {
  bounce,
  floorPassed,
  smashReady,
  smashed,
  ringSmashed,
  segmentBroken,
  bonusCollected,
  nearMiss,
  shieldUsed,
  comboReset,
  fireballOn,
  fireballOff,
  death,
  levelComplete,
}

/// Emitted by the deterministic simulation; consumed by the engine (FX, audio, state machine) and UI.
class GameEvent {
  const GameEvent(this.type, {this.floor = -1, this.slot = -1, this.chain = 0, this.points = 0, this.cause});

  final GameEventType type;
  final int floor;
  final int slot;
  final int chain;
  final int points;
  final String? cause;

  @override
  String toString() => 'GameEvent(${type.name}, floor=$floor, slot=$slot, chain=$chain, points=$points)';
}

/// Summary of a finished run, handed to progression/reward systems.
class RunResult {
  const RunResult({
    required this.runId,
    required this.levelId,
    required this.won,
    required this.score,
    required this.floorsCleared,
    required this.totalFloors,
    required this.bestCombo,
    required this.bonusCoins,
    required this.smashes,
    required this.seconds,
  });

  final String runId;
  final int levelId;
  final bool won;
  final int score;
  final int floorsCleared;
  final int totalFloors;
  final int bestCombo;
  final int bonusCoins;
  final int smashes;
  final double seconds;
}

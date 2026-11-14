import '../../../core/enums/game_enums.dart';
import '../../../core/logging/log.dart';

/// Formal gameplay state machine. Only transitions listed in [transitions] are accepted.
class GameStateMachine {
  GameStateMachine([this._state = GamePhase.initializing]);

  static const Set<GamePhase> active = {
    GamePhase.intro,
    GamePhase.playing,
    GamePhase.falling,
    GamePhase.bouncing,
    GamePhase.combo,
    GamePhase.destruction,
  };

  static const Map<GamePhase, Set<GamePhase>> transitions = {
    GamePhase.initializing: {GamePhase.loading},
    GamePhase.loading: {GamePhase.ready},
    GamePhase.ready: {GamePhase.intro},
    GamePhase.intro: {GamePhase.playing, GamePhase.paused},
    GamePhase.playing: {
      GamePhase.falling,
      GamePhase.bouncing,
      GamePhase.combo,
      GamePhase.destruction,
      GamePhase.paused,
      GamePhase.gameOver,
      GamePhase.levelCompleted,
    },
    GamePhase.falling: {
      GamePhase.bouncing,
      GamePhase.combo,
      GamePhase.destruction,
      GamePhase.paused,
      GamePhase.gameOver,
      GamePhase.levelCompleted,
    },
    GamePhase.bouncing: {GamePhase.falling, GamePhase.destruction, GamePhase.paused, GamePhase.gameOver},
    GamePhase.combo: {
      GamePhase.falling,
      GamePhase.bouncing,
      GamePhase.destruction,
      GamePhase.paused,
      GamePhase.gameOver,
      GamePhase.levelCompleted,
    },
    GamePhase.destruction: {
      GamePhase.falling,
      GamePhase.bouncing,
      GamePhase.combo,
      GamePhase.paused,
      GamePhase.gameOver,
      GamePhase.levelCompleted,
    },
    // paused → resume target is validated separately in [resume].
    GamePhase.paused: {GamePhase.restarting},
    GamePhase.gameOver: {GamePhase.playing, GamePhase.restarting},
    GamePhase.levelCompleted: {GamePhase.restarting},
    GamePhase.restarting: {GamePhase.ready},
  };

  GamePhase _state;
  GamePhase? _resumeTo;
  final List<void Function(GamePhase from, GamePhase to)> _listeners = [];

  GamePhase get state => _state;
  bool get isActive => active.contains(_state);
  bool get isPaused => _state == GamePhase.paused;

  void addListener(void Function(GamePhase from, GamePhase to) l) => _listeners.add(l);

  bool canTransition(GamePhase to) => to == _state || (transitions[_state]?.contains(to) ?? false);

  /// Attempts a transition. Returns false (and leaves the state unchanged) when it is not allowed.
  bool transition(GamePhase to) {
    if (to == _state) return true;
    if (!canTransition(to)) {
      Log.w('FSM', 'rejected ${_state.name} → ${to.name}');
      return false;
    }
    _set(to);
    return true;
  }

  bool pause() {
    if (!isActive) return false;
    final from = _state;
    if (!transition(GamePhase.paused)) return false;
    _resumeTo = from;
    return true;
  }

  /// Returns to the active sub-state that was interrupted by [pause].
  bool resume() {
    if (_state != GamePhase.paused || _resumeTo == null) return false;
    final to = _resumeTo!;
    _resumeTo = null;
    _set(to);
    return true;
  }

  void _set(GamePhase to) {
    final from = _state;
    _state = to;
    for (final l in _listeners) {
      l(from, to);
    }
  }
}

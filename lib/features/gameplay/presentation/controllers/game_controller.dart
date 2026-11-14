import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/game_constants.dart';
import '../../../../core/dev/autopilot.dart';
import '../../../../core/enums/game_enums.dart';
import '../../../../core/services/audio_service.dart';
import '../../../levels/data/level_generator.dart';
import '../../../player/domain/progression_service.dart';
import '../../../player/presentation/controllers/player_controller.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../../domain/game_event.dart';
import '../../domain/level_config.dart';
import '../../engine/game_engine.dart';

enum PopupKind { score, combo, smash, near, bonus, info, danger }

class Popup {
  Popup(this.id, this.text, this.kind, {this.sub});

  final int id;
  final String text;
  final String? sub;
  final PopupKind kind;
}

/// ViewModel for the game screen. Owns the [GameEngine], mirrors its state into Rx values, and applies
/// results to player progression.
class GameController extends GetxController {
  GameController({required this.levels, required this.player, required this.settings, required this.audio});

  final LevelGenerator levels;
  final PlayerController player;
  final SettingsController settings;
  final AudioService audio;

  late GameEngine engine;
  late LevelConfig levelConfig;

  final phase = GamePhase.initializing.obs;
  final levelId = 1.obs;
  final score = 0.obs;
  final floorsCleared = 0.obs;
  final totalFloors = 1.obs;
  final chain = 0.obs;
  final smashReady = false.obs;
  final heat = 0.0.obs;
  final fireball = false.obs;
  final shields = 0.obs;
  final bonusCoins = 0.obs;
  final popups = <Popup>[].obs;
  final flashTick = 0.obs;
  FlashCue lastFlash = const FlashCue(0xFFFFFFFF, 0);
  final showHint = true.obs;
  final reviveUsed = false.obs;
  final reward = Rxn<RunReward>();
  final runResult = Rxn<RunResult>();
  final newBest = false.obs;

  int _popupId = 0;
  Future<void>? _payoutFuture;
  AppLifecycleListener? _lifecycle;

  InputMode get mode => levelConfig.mode;
  int get reviveCost => ProgressionService.reviveCost(levelId.value);
  bool get canAffordRevive => player.coins.value >= reviveCost;
  bool get monetization => MonetizationConfig.enabled;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    final requested = arg is int ? arg : player.currentLevel.value;
    final lvl = requested.clamp(1, player.highestUnlocked.value);
    levelConfig = levels.generate(lvl, settings.value.mode);
    final s = settings.value;
    engine = GameEngine(
      level: levelConfig,
      skin: player.selectedSkin,
      settings: EngineSettings(quality: s.quality, sensitivity: s.sensitivity, reduceMotion: s.reduceMotion),
      initialShields: player.shields.value,
      audioSink: audio,
    );
    engine.onGameEvent = _onEvent;
    engine.onPhaseChanged = _onPhase;
    engine.onFlash = (cue) {
      if (settings.value.reduceMotion && cue.strength > 0.2) {
        lastFlash = FlashCue(cue.color, 0.2);
      } else {
        lastFlash = cue;
      }
      flashTick.value++;
    };
    engine.addListener(_syncHud);
    _resetRunState();
    _lifecycle = AppLifecycleListener(onStateChange: (state) {
      if (state != AppLifecycleState.resumed) pause();
    });
  }

  /// Called by the screen once it can provide vsync.
  void attach(TickerProvider vsync) {
    engine.attach(vsync);
    engine.begin();
    audio.startMusic();
  }

  void _resetRunState() {
    levelId.value = levelConfig.levelId;
    totalFloors.value = levelConfig.floorCount;
    score.value = 0;
    floorsCleared.value = 0;
    chain.value = 0;
    smashReady.value = false;
    heat.value = 0;
    fireball.value = false;
    bonusCoins.value = 0;
    shields.value = player.shields.value;
    popups.clear();
    reviveUsed.value = false;
    reward.value = null;
    runResult.value = null;
    newBest.value = false;
    showHint.value = !settings.value.tutorialSeen || levelConfig.levelId <= 2;
    _payoutFuture = null;
  }

  void _syncHud() {
    final sim = engine.sim;
    score.value = sim.score;
    floorsCleared.value = sim.floorsCleared;
    chain.value = sim.isSmashMode ? sim.combo.streak : sim.combo.chain;
    smashReady.value = sim.combo.smashReady;
    heat.value = sim.heat;
    fireball.value = sim.fireball;
    shields.value = sim.shields;
    bonusCoins.value = sim.bonusCoins;
    if (showHint.value && (sim.floorsCleared >= 2 || (engine.input.touchedSinceReset && sim.time > 4))) {
      showHint.value = false;
      if (!settings.value.tutorialSeen) settings.markTutorialSeen();
    }
  }

  void _popup(String text, PopupKind kind, {String? sub}) {
    final p = Popup(_popupId++, text, kind, sub: sub);
    popups.add(p);
    while (popups.length > 6) {
      popups.removeAt(0);
    }
    Future.delayed(const Duration(milliseconds: 1100), () => popups.remove(p));
  }

  void _onEvent(GameEvent e) {
    switch (e.type) {
      case GameEventType.floorPassed:
        _popup('+${e.points}', e.chain >= 2 ? PopupKind.combo : PopupKind.score,
            sub: e.chain >= 2 ? '×${e.chain.clamp(1, GameConstants.maxMultiplier)} DROP' : null);
      case GameEventType.smashReady:
        _popup('SMASH READY', PopupKind.smash, sub: 'Crash through the next floor!');
      case GameEventType.smashed:
        _popup('SMASH!', PopupKind.smash, sub: '+${e.points}');
      case GameEventType.ringSmashed:
        if (e.chain > 1 && e.chain % 5 == 0) _popup('×${e.chain}', PopupKind.combo, sub: 'STREAK');
      case GameEventType.nearMiss:
        _popup('CLOSE CALL!', PopupKind.near, sub: '+${e.points}');
      case GameEventType.segmentBroken:
        _popup('+${e.points}', PopupKind.score, sub: 'CRACK!');
      case GameEventType.bonusCollected:
        _popup('+1', PopupKind.bonus, sub: 'COIN');
      case GameEventType.shieldUsed:
        _popup('SHIELD!', PopupKind.info, sub: 'Hazard blocked');
        player.consumeShield();
      case GameEventType.fireballOn:
        _popup('FIREBALL!', PopupKind.smash, sub: 'Unstoppable');
      case GameEventType.death:
        _popup('', PopupKind.danger, sub: e.cause == 'sweeper' ? 'Hit by the sweeper!' : 'Hit a hazard!');
      case GameEventType.levelComplete:
        _popup('+${e.points}', PopupKind.smash, sub: 'TOWER CLEARED');
      case GameEventType.bounce:
      case GameEventType.comboReset:
      case GameEventType.fireballOff:
        break;
    }
  }

  void _onPhase(GamePhase from, GamePhase to) {
    phase.value = to;
    if (Autopilot.enabled && (to == GamePhase.levelCompleted || to == GamePhase.gameOver)) {
      Future.delayed(const Duration(seconds: 3), () => to == GamePhase.levelCompleted ? nextLevel() : retry());
    }
    if (to == GamePhase.levelCompleted) {
      _payout();
    } else if (to == GamePhase.gameOver) {
      final r = engine.sim.result(engine.runId);
      runResult.value = r;
      newBest.value = r.score > player.bestScore.value;
    }
  }

  bool get _finished => phase.value == GamePhase.gameOver || phase.value == GamePhase.levelCompleted;

  /// Applies the run to progression exactly once (concurrent callers share the same future).
  Future<void> _payout() => _payoutFuture ??= _doPayout();

  Future<void> _doPayout() async {
    final r = engine.sim.result(engine.runId);
    runResult.value = r;
    newBest.value = r.score > player.bestScore.value;
    reward.value = await player.finishRun(r, levelConfig);
  }

  // ------------------------------------------------------------------ actions

  void pause() {
    if (engine.fsm.isActive) {
      engine.pause();
      phase.value = engine.phase;
    }
  }

  void resume() {
    engine.resume();
    phase.value = engine.phase;
  }

  void togglePause() => engine.fsm.isPaused ? resume() : pause();

  Future<void> retry() async {
    if (_finished) await _payout();
    engine.restart();
    _resetRunState();
  }

  Future<void> nextLevel() async {
    await _payout();
    final next = (levelConfig.levelId + 1).clamp(1, player.highestUnlocked.value);
    levelConfig = levels.generate(next, settings.value.mode);
    engine.setSkin(player.selectedSkin);
    engine.restart(next: levelConfig);
    _resetRunState();
  }

  Future<void> goHome() async {
    // Only finished runs pay out; abandoning a paused run keeps nothing.
    if (_finished) await _payout();
    Get.offAllNamed(AppRoutes.home);
  }

  Future<bool> reviveWithCoins() async {
    if (reviveUsed.value || !engine.canRevive) return false;
    if (!await player.spend(reviveCost)) return false;
    reviveUsed.value = true;
    runResult.value = null;
    engine.revive();
    return true;
  }

  @override
  void onClose() {
    _lifecycle?.dispose();
    engine.removeListener(_syncHud);
    engine.dispose();
    super.onClose();
  }
}

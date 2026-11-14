import '../../../core/constants/game_constants.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/utils/angle_utils.dart';

/// Periodic hazard toggle for `SegmentType.blink` slots.
class BlinkSpec {
  const BlinkSpec({required this.period, required this.phase, this.duty = 0.5});

  final double period;
  final double phase;
  final double duty;

  /// Whether blink slots are currently lethal.
  bool isDangerAt(double time) => ((time + phase) % period) / period < duty;

  /// 0..1 progress through the current cycle (used for the warning flicker).
  double cycle(double time) => ((time + phase) % period) / period;

  Map<String, dynamic> toJson() => {'period': period, 'phase': phase, 'duty': duty};

  factory BlinkSpec.fromJson(Map<String, dynamic> j) => BlinkSpec(
        period: (j['period'] as num).toDouble(),
        phase: (j['phase'] as num).toDouble(),
        duty: (j['duty'] as num).toDouble(),
      );
}

/// A lethal arm rotating around one floor (in floor-local space).
class SweeperSpec {
  const SweeperSpec({required this.start, required this.width, required this.speed});

  final double start;
  final double width;
  final double speed;

  double angleAt(double time) => AngleUtils.wrap(start + speed * time);

  Map<String, dynamic> toJson() => {'start': start, 'width': width, 'speed': speed};

  factory SweeperSpec.fromJson(Map<String, dynamic> j) => SweeperSpec(
        start: (j['start'] as num).toDouble(),
        width: (j['width'] as num).toDouble(),
        speed: (j['speed'] as num).toDouble(),
      );
}

/// One platform layer. `slots[i]` covers local angles `[offset + i·Δ, offset + (i+1)·Δ)`.
class FloorSpec {
  const FloorSpec({required this.index, required this.offset, required this.slots, this.blink, this.sweeper});

  final int index;
  final double offset;
  final List<SegmentType> slots;
  final BlinkSpec? blink;
  final SweeperSpec? sweeper;

  int count(SegmentType t) => slots.where((s) => s == t).length;

  Map<String, dynamic> toJson() => {
        'index': index,
        'offset': offset,
        'slots': slots.map((s) => s.name).toList(),
        if (blink != null) 'blink': blink!.toJson(),
        if (sweeper != null) 'sweeper': sweeper!.toJson(),
      };

  factory FloorSpec.fromJson(Map<String, dynamic> j) => FloorSpec(
        index: j['index'] as int,
        offset: (j['offset'] as num).toDouble(),
        slots: (j['slots'] as List).map((s) => SegmentType.values.byName(s as String)).toList(),
        blink: j['blink'] == null ? null : BlinkSpec.fromJson(j['blink'] as Map<String, dynamic>),
        sweeper: j['sweeper'] == null ? null : SweeperSpec.fromJson(j['sweeper'] as Map<String, dynamic>),
      );
}

class RewardConfig {
  const RewardConfig({required this.baseCoins, required this.firstClearBonus, required this.coinsPerScore});

  final int baseCoins;
  final int firstClearBonus;

  /// Score points per coin.
  final int coinsPerScore;

  Map<String, dynamic> toJson() =>
      {'baseCoins': baseCoins, 'firstClearBonus': firstClearBonus, 'coinsPerScore': coinsPerScore};

  factory RewardConfig.fromJson(Map<String, dynamic> j) => RewardConfig(
        baseCoins: j['baseCoins'] as int,
        firstClearBonus: j['firstClearBonus'] as int,
        coinsPerScore: j['coinsPerScore'] as int,
      );
}

/// Complete, data-only description of a level. Rendering and simulation are both derived from it.
class LevelConfig {
  const LevelConfig({
    required this.levelId,
    required this.seed,
    required this.mode,
    required this.difficulty,
    required this.floors,
    required this.themeIndex,
    required this.rotationSpeed,
    required this.rotationDirection,
    required this.scoreMultiplier,
    required this.reward,
    required this.parScore,
    this.floorSpacing = GameConstants.floorSpacing,
    this.platformInnerRadius = GameConstants.platformInnerRadius,
    this.platformOuterRadius = GameConstants.platformOuterRadius,
    this.platformThickness = GameConstants.platformThickness,
    this.ballStartHeight = GameConstants.ballStartHeight,
    this.gravity = GameConstants.gravity,
    this.bounceVelocity = GameConstants.bounceVelocity,
  });

  final int levelId;
  final int seed;
  final InputMode mode;
  final Difficulty difficulty;
  final List<FloorSpec> floors;
  final int themeIndex;

  /// Auto-rotation speed (rad/s) used in smash mode.
  final double rotationSpeed;
  final int rotationDirection;
  final double scoreMultiplier;
  final RewardConfig reward;
  final int parScore;

  final double floorSpacing;
  final double platformInnerRadius;
  final double platformOuterRadius;
  final double platformThickness;
  final double ballStartHeight;
  final double gravity;
  final double bounceVelocity;

  int get floorCount => floors.length;

  /// Tower height from the first floor to the base.
  double get towerHeight => floorCount * floorSpacing;

  /// Y of the top surface of floor [i] (the base platform is `floorTop(floorCount)`).
  double floorTop(int i) => -i * floorSpacing;

  int get gapSlots => floors.fold(0, (a, f) => a + f.count(SegmentType.gap));
  int get dangerSlots => floors.fold(0, (a, f) => a + f.count(SegmentType.danger));

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'seed': seed,
        'mode': mode.name,
        'difficulty': difficulty.name,
        'themeIndex': themeIndex,
        'rotationSpeed': rotationSpeed,
        'rotationDirection': rotationDirection,
        'scoreMultiplier': scoreMultiplier,
        'reward': reward.toJson(),
        'parScore': parScore,
        'floorSpacing': floorSpacing,
        'platformInnerRadius': platformInnerRadius,
        'platformOuterRadius': platformOuterRadius,
        'platformThickness': platformThickness,
        'ballStartHeight': ballStartHeight,
        'gravity': gravity,
        'bounceVelocity': bounceVelocity,
        'floors': floors.map((f) => f.toJson()).toList(),
      };

  factory LevelConfig.fromJson(Map<String, dynamic> j) => LevelConfig(
        levelId: j['levelId'] as int,
        seed: j['seed'] as int,
        mode: InputMode.values.byName(j['mode'] as String),
        difficulty: Difficulty.values.byName(j['difficulty'] as String),
        themeIndex: j['themeIndex'] as int,
        rotationSpeed: (j['rotationSpeed'] as num).toDouble(),
        rotationDirection: j['rotationDirection'] as int,
        scoreMultiplier: (j['scoreMultiplier'] as num).toDouble(),
        reward: RewardConfig.fromJson(j['reward'] as Map<String, dynamic>),
        parScore: j['parScore'] as int,
        floorSpacing: (j['floorSpacing'] as num).toDouble(),
        platformInnerRadius: (j['platformInnerRadius'] as num).toDouble(),
        platformOuterRadius: (j['platformOuterRadius'] as num).toDouble(),
        platformThickness: (j['platformThickness'] as num).toDouble(),
        ballStartHeight: (j['ballStartHeight'] as num).toDouble(),
        gravity: (j['gravity'] as num).toDouble(),
        bounceVelocity: (j['bounceVelocity'] as num).toDouble(),
        floors: (j['floors'] as List).map((f) => FloorSpec.fromJson(f as Map<String, dynamic>)).toList(),
      );
}

import '../../../core/enums/game_enums.dart';

class GameSettings {
  const GameSettings({
    this.music = true,
    this.sfx = true,
    this.haptics = true,
    this.musicVolume = 0.6,
    this.sfxVolume = 0.9,
    this.quality = GraphicsQuality.high,
    this.sensitivity = 1.0,
    this.reduceMotion = false,
    this.mode = InputMode.spin,
    this.tutorialSeen = false,
  });

  final bool music;
  final bool sfx;
  final bool haptics;
  final double musicVolume;
  final double sfxVolume;
  final GraphicsQuality quality;
  final double sensitivity;
  final bool reduceMotion;
  final InputMode mode;
  final bool tutorialSeen;

  GameSettings copyWith({
    bool? music,
    bool? sfx,
    bool? haptics,
    double? musicVolume,
    double? sfxVolume,
    GraphicsQuality? quality,
    double? sensitivity,
    bool? reduceMotion,
    InputMode? mode,
    bool? tutorialSeen,
  }) =>
      GameSettings(
        music: music ?? this.music,
        sfx: sfx ?? this.sfx,
        haptics: haptics ?? this.haptics,
        musicVolume: musicVolume ?? this.musicVolume,
        sfxVolume: sfxVolume ?? this.sfxVolume,
        quality: quality ?? this.quality,
        sensitivity: sensitivity ?? this.sensitivity,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        mode: mode ?? this.mode,
        tutorialSeen: tutorialSeen ?? this.tutorialSeen,
      );

  Map<String, dynamic> toJson() => {
        'music': music,
        'sfx': sfx,
        'haptics': haptics,
        'musicVolume': musicVolume,
        'sfxVolume': sfxVolume,
        'quality': quality.name,
        'sensitivity': sensitivity,
        'reduceMotion': reduceMotion,
        'mode': mode.name,
        'tutorialSeen': tutorialSeen,
      };

  factory GameSettings.fromJson(Map<String, dynamic> j) {
    T byName<T extends Enum>(List<T> values, Object? v, T fallback) =>
        values.where((e) => e.name == v).firstOrNull ?? fallback;
    return GameSettings(
      music: j['music'] as bool? ?? true,
      sfx: j['sfx'] as bool? ?? true,
      haptics: j['haptics'] as bool? ?? true,
      musicVolume: (j['musicVolume'] as num?)?.toDouble() ?? 0.6,
      sfxVolume: (j['sfxVolume'] as num?)?.toDouble() ?? 0.9,
      quality: byName(GraphicsQuality.values, j['quality'], GraphicsQuality.high),
      sensitivity: ((j['sensitivity'] as num?)?.toDouble() ?? 1.0).clamp(0.4, 2.0),
      reduceMotion: j['reduceMotion'] as bool? ?? false,
      mode: byName(InputMode.values, j['mode'], InputMode.spin),
      tutorialSeen: j['tutorialSeen'] as bool? ?? false,
    );
  }
}

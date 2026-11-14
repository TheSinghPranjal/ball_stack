import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/enums/game_enums.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/neon_widgets.dart';
import '../controllers/game_controller.dart';

/// Top/bottom HUD. Keeps the middle of the screen free for the tower.
class GameHud extends StatelessWidget {
  const GameHud({super.key, required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            SizedBox(
              height: 92,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PressableScale(onTap: c.pause, semanticLabel: 'Pause', child: const _PauseButton()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Obx(() => _LevelPill(level: c.levelId.value)),
                          const SizedBox(height: 2),
                          Obx(() => _ScoreText(score: c.score.value)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(
                        () => NeonCoinPill(
                          coins: c.player.coins.value + c.bonusCoins.value,
                          compact: true,
                          onAdd: () {
                            c.pause();
                            Get.toNamed<void>(AppRoutes.shop);
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Obx(
                        () => c.shields.value > 0
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset('assets/images/icons/shield.png', width: 20),
                                  const SizedBox(width: 4),
                                  Text('×${c.shields.value}', style: AppText.number.copyWith(fontSize: 14)),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _ProgressBar(c: c),
            const SizedBox(height: 10),
            _ComboBanner(c: c),
            const Spacer(),
            if (c.mode == InputMode.smash) _HeatMeter(c: c),
            Obx(
              () => AnimatedOpacity(
                opacity: c.showHint.value ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: _Hint(mode: c.mode),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.c});

  final GameController c;

  static const _violet = Color(0xFFB06BFF);

  Widget _bubble(String t, bool filled) => AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    width: 46,
    height: 46,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: filled
          ? const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF9A3C), Color(0xFFFF4A1A)],
            )
          : null,
      color: filled ? null : const Color(0xCC1A1250),
      border: Border.all(color: filled ? const Color(0xFFFFD2A0) : _violet, width: 2.5),
      boxShadow: [
        BoxShadow(color: (filled ? const Color(0xFFFF6A2A) : _violet).withValues(alpha: 0.7), blurRadius: 14),
      ],
    ),
    child: Text(t, style: AppText.number.copyWith(fontSize: 19)),
  );

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = (c.floorsCleared.value / math.max(1, c.totalFloors.value)).clamp(0.0, 1.0);
      return Row(
        children: [
          _bubble('${c.levelId.value}', true),
          Expanded(
            child: Container(
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xAA140A38),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD9C8FF), width: 1.5),
                boxShadow: [BoxShadow(color: _violet.withValues(alpha: 0.65), blurRadius: 12)],
              ),
              child: LayoutBuilder(
                builder: (_, cons) => Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: math.max(cons.maxHeight, cons.maxWidth * p),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF7A2A), Color(0xFFFF4FD8)]),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Color(0x99FF6A2A), blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _bubble('${c.levelId.value + 1}', p >= 1),
        ],
      );
    });
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 0.95,
          colors: [Color(0xFFA77BFF), Color(0xFF6A3BE0), Color(0xFF4A1FB0)],
        ),
        border: Border.all(color: const Color(0x99D9C8FF), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x887A4BFF), blurRadius: 16),
          BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: const Icon(Icons.pause_rounded, color: Colors.white, size: 34),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1250),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD27BFF), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x99B04BFF), blurRadius: 14)],
      ),
      child: Text(
        'LEVEL $level',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Big score with a blue neon outline.
class _ScoreText extends StatelessWidget {
  const _ScoreText({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final t = formatNumber(score);
    const base = TextStyle(
      fontSize: 46,
      fontWeight: FontWeight.w900,
      height: 1,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Stack(
      children: [
        Text(
          t,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 7
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF2B5FE0),
            shadows: const [Shadow(color: Color(0xAA3FA9FF), blurRadius: 14)],
          ),
        ),
        Text(t, style: base.copyWith(color: Colors.white)),
      ],
    );
  }
}

class _ComboBanner extends StatelessWidget {
  const _ComboBanner({required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Obx(() {
        final smash = c.smashReady.value || c.fireball.value;
        final n = c.chain.value;
        final show = smash || n >= 2;
        final text = c.fireball.value
            ? 'FIREBALL'
            : (c.smashReady.value ? 'SMASH MODE' : (c.mode == InputMode.smash ? '×$n STREAK' : '×$n DROP'));
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, a) => ScaleTransition(
            scale: a,
            child: FadeTransition(opacity: a, child: child),
          ),
          child: show
              ? Container(
                  key: ValueKey(text),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: smash
                        ? const LinearGradient(colors: [Color(0xFFFF6A1A), Color(0xFFFFC23C)])
                        : AppColors.skyGradient,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: (smash ? const Color(0xFFFF6A1A) : AppColors.sky).withValues(alpha: 0.6),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Text(text, style: AppText.h2.copyWith(fontSize: 20, letterSpacing: 1.5)),
                )
              : const SizedBox.shrink(key: ValueKey('none')),
        );
      }),
    );
  }
}

class _HeatMeter extends StatelessWidget {
  const _HeatMeter({required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFA23C)),
          const SizedBox(width: 6),
          Expanded(
            child: Obx(
              () => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: c.heat.value,
                  minHeight: 12,
                  backgroundColor: const Color(0x55000000),
                  valueColor: AlwaysStoppedAnimation(
                    c.fireball.value ? const Color(0xFFFF4D1A) : const Color(0xFFFFB23C),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.mode});

  final InputMode mode;

  @override
  Widget build(BuildContext context) {
    final text = mode == InputMode.spin ? 'Drag left / right to spin the tower' : 'Hold to smash · release to bounce';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mode == InputMode.spin ? Icons.swipe_rounded : Icons.touch_app_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Flexible(child: Text(text, style: AppText.body.copyWith(fontSize: 15))),
        ],
      ),
    );
  }
}

/// Floating score/combo popups (≤ 6 alive).
class PopupLayer extends StatelessWidget {
  const PopupLayer({super.key, required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Obx(
        () => Stack(
          children: [
            for (var i = 0; i < c.popups.length; i++)
              _PopupWidget(key: ValueKey(c.popups[i].id), popup: c.popups[i], index: i),
          ],
        ),
      ),
    );
  }
}

class _PopupWidget extends StatefulWidget {
  const _PopupWidget({super.key, required this.popup, required this.index});

  final Popup popup;
  final int index;

  @override
  State<_PopupWidget> createState() => _PopupWidgetState();
}

class _PopupWidgetState extends State<_PopupWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
    ..forward();
  late final double _dx = ((widget.popup.id * 37) % 60 - 30).toDouble();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.popup.kind) {
    PopupKind.score => Colors.white,
    PopupKind.combo => AppColors.gold,
    PopupKind.smash => const Color(0xFFFFB23C),
    PopupKind.near => AppColors.mint,
    PopupKind.bonus => AppColors.gold,
    PopupKind.info => AppColors.sky,
    PopupKind.danger => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final big = widget.popup.kind == PopupKind.smash || widget.popup.kind == PopupKind.danger;
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        final t = _a.value;
        final scale = t < 0.15 ? 0.6 + t / 0.15 * 0.6 : 1.2 - math.min(0.2, (t - 0.15) * 0.6);
        final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
        return Align(
          alignment: Alignment(_dx / 200 * (big ? 0 : 1), big ? -0.15 : 0.05),
          child: Transform.translate(
            offset: Offset(0, -50 * t),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.popup.sub != null)
                      Text(
                        widget.popup.sub!,
                        style: AppText.caption.copyWith(color: Colors.white, fontSize: big ? 15 : 12),
                      ),
                    if (widget.popup.text.isNotEmpty)
                      Text(
                        widget.popup.text,
                        style: AppText.h1.copyWith(color: _color, fontSize: big ? 40 : 28, letterSpacing: 1),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen colour flash driven by engine FlashCues.
class FlashLayer extends StatefulWidget {
  const FlashLayer({super.key, required this.c});

  final GameController c;

  @override
  State<FlashLayer> createState() => _FlashLayerState();
}

class _FlashLayerState extends State<FlashLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  Worker? _w;

  @override
  void initState() {
    super.initState();
    _w = ever(widget.c.flashTick, (_) {
      _a.duration = Duration(milliseconds: (160 + widget.c.lastFlash.strength * 260).round());
      _a.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _w?.dispose();
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, _) {
          if (!_a.isAnimating) return const SizedBox.expand();
          final cue = widget.c.lastFlash;
          return ColoredBox(
            color: Color(cue.color).withValues(alpha: (math.min(0.4, cue.strength * 0.65)) * (1 - _a.value)),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

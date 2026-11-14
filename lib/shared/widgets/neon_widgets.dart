import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/typography.dart';
import '../../core/services/audio_service.dart';
import 'common.dart';

/// Shared neon-arcade UI pieces (home + in-game HUD).

void neonClick() {
  if (Get.isRegistered<AudioService>()) Get.find<AudioService>().click();
}

/// Scale-on-press wrapper with click sound.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, required this.onTap, this.semanticLabel, this.selected});

  final Widget child;
  final VoidCallback onTap;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<PressableScale> createState() => PressableScaleState();
}

class PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          neonClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.93 : 1,
          duration: Duration(milliseconds: _down ? 80 : 160),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          child: widget.child,
        ),
      ),
    );
  }
}

class NeonCoinPill extends StatelessWidget {
  const NeonCoinPill({super.key, required this.coins, this.onAdd, this.compact = false});

  final int coins;
  final VoidCallback? onAdd;

  /// Slightly smaller variant for the in-game HUD.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 44 : 48,
      padding: const EdgeInsets.fromLTRB(6, 5, 5, 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xCC2A1F70), Color(0xCC1A1250)]),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x667A8CFF), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x553A6BFF), blurRadius: 14)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/icons/coin.png', width: compact ? 32 : 36, height: compact ? 32 : 36),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: compact ? 36 : 44),
            child: Text(formatNumber(coins), style: AppText.number.copyWith(fontSize: 20)),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 10),
            PressableScale(
              onTap: onAdd!,
              semanticLabel: 'Get coins',
              child: Container(
                width: compact ? 30 : 34,
                height: compact ? 30 : 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF7CF25A), Color(0xFF22B830)],
                  ),
                  border: Border.all(color: const Color(0xAAFFFFFF), width: 1.5),
                  boxShadow: const [BoxShadow(color: Color(0x8844E040), blurRadius: 8)],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
              ),
            ),
          ] else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

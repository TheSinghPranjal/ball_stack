import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/enums/game_enums.dart';
import '../../../../shared/widgets/arcade_button.dart';
import '../../../../shared/widgets/common.dart';
import '../../../player/presentation/controllers/player_controller.dart';
import '../controllers/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<SettingsController>();
    return ScreenScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                RoundIconButton(icon: Icons.arrow_back_rounded, onPressed: () => Get.back<void>(), semanticLabel: 'Back'),
                const Expanded(child: Center(child: Text('SETTINGS', style: AppText.h1))),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              final s = c.settings.value;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _SwitchTile(icon: Icons.music_note_rounded, label: 'Music', value: s.music, onChanged: (_) => c.toggleMusic()),
                  _SwitchTile(icon: Icons.volume_up_rounded, label: 'Sound effects', value: s.sfx, onChanged: (_) => c.toggleSfx()),
                  _SwitchTile(icon: Icons.vibration_rounded, label: 'Haptics', value: s.haptics, onChanged: (_) => c.toggleHaptics()),
                  _SwitchTile(
                      icon: Icons.blur_off_rounded,
                      label: 'Reduce shake & flash',
                      value: s.reduceMotion,
                      onChanged: (_) => c.toggleReduceMotion()),
                  _Card(
                    title: 'Music volume',
                    child: Slider(
                      value: s.musicVolume,
                      onChanged: s.music ? (v) => c.update((x) => x.copyWith(musicVolume: v)) : null,
                    ),
                  ),
                  _Card(
                    title: 'Effects volume',
                    child: Slider(
                      value: s.sfxVolume,
                      onChanged: s.sfx ? (v) => c.update((x) => x.copyWith(sfxVolume: v)) : null,
                    ),
                  ),
                  _Card(
                    title: 'Graphics quality',
                    child: _Segmented<GraphicsQuality>(
                      values: GraphicsQuality.values,
                      selected: s.quality,
                      label: (q) => switch (q) {
                        GraphicsQuality.low => 'Low',
                        GraphicsQuality.medium => 'Medium',
                        GraphicsQuality.high => 'High',
                      },
                      onSelect: c.setQuality,
                    ),
                  ),
                  _Card(
                    title: 'Drag sensitivity  ${s.sensitivity.toStringAsFixed(1)}×',
                    child: Slider(
                      value: s.sensitivity,
                      min: 0.4,
                      max: 2.0,
                      divisions: 16,
                      onChanged: (v) => c.setSensitivity(double.parse(v.toStringAsFixed(1))),
                    ),
                  ),
                  _Card(
                    title: 'Control mode',
                    child: _Segmented<InputMode>(
                      values: InputMode.values,
                      selected: s.mode,
                      label: (m) => m == InputMode.spin ? 'Spin (drag)' : 'Smash (hold)',
                      onSelect: c.setMode,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ArcadeButton(
                    label: 'RESET PROGRESS',
                    style: ArcadeButtonStyle.danger,
                    icon: Icons.delete_forever_rounded,
                    height: 52,
                    fontSize: 17,
                    onPressed: () => _confirmReset(context),
                  ),
                  const SizedBox(height: 18),
                  Center(child: Text('Ball Game : Fire Ball · v1.0.0', style: AppText.caption.copyWith(fontSize: 11))),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Reset all progress?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Levels, stars, coins, skins and shields will be erased. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Get.back<void>(), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await Get.find<PlayerController>().resetProgress();
              Get.back<void>();
              Get.snackbar('Progress reset', 'Starting fresh from level 1.',
                  colorText: Colors.white, backgroundColor: const Color(0xCC1B1640), margin: const EdgeInsets.all(16));
            },
            child: const Text('RESET', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(title, style: AppText.body), const SizedBox(height: 6), child],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.icon, required this.label, required this.value, required this.onChanged});

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppText.body)),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.tangerine,
              activeThumbColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({required this.values, required this.selected, required this.label, required this.onSelect});

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final v in values)
          Expanded(
            child: Semantics(
              button: true,
              selected: v == selected,
              label: label(v),
              child: GestureDetector(
                onTap: () => onSelect(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: v == selected ? AppColors.primaryGradient : null,
                    color: v == selected ? null : const Color(0x33000000),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(label(v), style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

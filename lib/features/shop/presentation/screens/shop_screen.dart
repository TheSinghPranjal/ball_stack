import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/render3d/color_math.dart';
import '../../../../shared/widgets/arcade_button.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/showcase_view.dart';
import '../../../player/domain/progression_service.dart';
import '../../data/skin_catalog.dart';
import '../../domain/ball_skin.dart';
import '../controllers/shop_controller.dart';

class ShopScreen extends GetView<ShopController> {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = controller.player;
    return ScreenScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                RoundIconButton(icon: Icons.arrow_back_rounded, onPressed: () => Get.back<void>(), semanticLabel: 'Back'),
                const Expanded(child: Center(child: Text('BALLS', style: AppText.h1))),
                Obx(() => CoinBadge(coins: p.coins.value, size: 18)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                GlassPanel(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      SizedBox(height: 190, child: Obx(() => BallPreviewView(skin: controller.preview))),
                      Obx(() => Text(controller.preview.name.toUpperCase(), style: AppText.h2)),
                      const SizedBox(height: 4),
                      Obx(() => Text(
                            controller.preview.premium ? 'PREMIUM SKIN' : (controller.preview.fiery ? 'FLAME TRAIL' : 'CLASSIC SKIN'),
                            style: AppText.caption,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (_, cons) {
                  final cols = (cons.maxWidth / 96).floor().clamp(4, 7);
                  return Obx(() {
                    final owned = Set<String>.of(p.ownedSkins);
                    final selected = p.selectedSkinId.value;
                    final preview = controller.previewId.value;
                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                      children: [
                        for (final s in SkinCatalog.all)
                          _SkinTile(
                            skin: s,
                            owned: owned.contains(s.id),
                            selected: selected == s.id,
                            previewing: preview == s.id,
                            onTap: () => controller.showPreview(s.id),
                          ),
                      ],
                    );
                  });
                }),
                const SizedBox(height: 16),
                Obx(() {
                  final owned = controller.previewOwned;
                  final sel = controller.previewSelected;
                  final price = controller.preview.price;
                  return ArcadeButton(
                    label: sel ? 'EQUIPPED' : (owned ? 'EQUIP' : 'UNLOCK'),
                    icon: sel ? Icons.check_rounded : null,
                    trailing: owned
                        ? null
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Image.asset('assets/images/icons/coin.png', width: 22),
                            const SizedBox(width: 4),
                            Text(formatNumber(price),
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                          ]),
                    style: owned ? ArcadeButtonStyle.secondary : ArcadeButtonStyle.primary,
                    onPressed: sel ? null : controller.buyOrSelect,
                  );
                }),
                const SizedBox(height: 24),
                const Text('BOOSTERS', style: AppText.caption),
                const SizedBox(height: 8),
                GlassPanel(
                  padding: const EdgeInsets.all(14),
                  radius: 20,
                  child: Row(
                    children: [
                      Image.asset('assets/images/icons/shield.png', width: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Obx(() => Text('Shield  ×${p.shields.value}/${ProgressionService.maxShields}',
                                style: AppText.body.copyWith(fontWeight: FontWeight.w900))),
                            Text('Blocks one hazard hit. Used automatically.',
                                style: AppText.caption.copyWith(fontSize: 11, letterSpacing: 0.2)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: ArcadeButton(
                          label: '${ProgressionService.shieldPrice}',
                          height: 46,
                          fontSize: 17,
                          icon: Icons.add_rounded,
                          onPressed: controller.buyShield,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinTile extends StatelessWidget {
  const _SkinTile({
    required this.skin,
    required this.owned,
    required this.selected,
    required this.previewing,
    required this.onTap,
  });

  final BallSkin skin;
  final bool owned;
  final bool selected;
  final bool previewing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = Color(skin.base), accent = Color(skin.accent);
    return Semantics(
      button: true,
      label: '${skin.name}, ${owned ? 'owned' : '${skin.price} coins'}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: previewing ? Colors.white.withValues(alpha: 0.22) : AppColors.glass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: selected ? AppColors.mint : (previewing ? Colors.white : AppColors.glassBorder),
                width: selected || previewing ? 3 : 1.5),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.45),
                    colors: [Color(ColorMath.lerp(skin.base, 0xFFFFFFFF, 0.55)), base, Color(ColorMath.scale(skin.base, 0.55))],
                    stops: const [0, 0.45, 1],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.9), width: 3),
                  boxShadow: [BoxShadow(color: Color(skin.trail).withValues(alpha: 0.5), blurRadius: 10)],
                ),
              ),
              if (owned)
                Icon(selected ? Icons.check_circle_rounded : Icons.check_rounded,
                    color: selected ? AppColors.mint : Colors.white, size: 18)
              else
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Image.asset('assets/images/icons/coin.png', width: 14),
                  const SizedBox(width: 3),
                  Flexible(child: Text(formatNumber(skin.price), style: AppText.number.copyWith(fontSize: 12))),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

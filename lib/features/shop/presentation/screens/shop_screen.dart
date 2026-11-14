import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/colors.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/neon_widgets.dart';
import '../../../player/domain/progression_service.dart';
import '../../data/ball_sprites.dart';
import '../../data/skin_catalog.dart';
import '../../domain/ball_skin.dart';
import '../controllers/shop_controller.dart';

const _violetEdge = Color(0x99B9A0FF);

class ShopScreen extends GetView<ShopController> {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = controller.player;
    return Scaffold(
      backgroundColor: const Color(0xFF1A0F4A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/bg/home_bg.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter),
          const ColoredBox(color: Color(0x8C1A0F4A)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Row(
                    children: [
                      PressableScale(
                        onTap: () => Get.back<void>(),
                        semanticLabel: 'Back',
                        child: const _CircleButton(icon: Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: Center(child: _TitlePill('BALLS'))),
                      const SizedBox(width: 10),
                      Obx(() => NeonCoinPill(coins: p.coins.value, compact: true)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      _PreviewCard(controller: controller),
                      const SizedBox(height: 16),
                      Obx(() {
                        final owned = Set<String>.of(p.ownedSkins);
                        final selected = p.selectedSkinId.value;
                        final preview = controller.previewId.value;
                        return GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.9,
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
                      }),
                      const SizedBox(height: 18),
                      Obx(() {
                        final owned = controller.previewOwned;
                        final sel = controller.previewSelected;
                        final price = controller.preview.price;
                        if (sel) {
                          return NeonPillButton(
                            label: 'EQUIPPED',
                            icon: Icons.check_rounded,
                            // Keep it bright like the reference; tapping an equipped ball does nothing.
                            onTap: () {},
                            height: 66,
                            fontSize: 28,
                            colors: const [Color(0xFF6CF27A), Color(0xFF22C840), Color(0xFF14A030)],
                            edge: const Color(0xFF0E7A24),
                            glow: const Color(0xFF3EE65A),
                          );
                        }
                        if (owned) {
                          return NeonPillButton(
                            label: 'EQUIP',
                            icon: Icons.check_rounded,
                            onTap: controller.buyOrSelect,
                            height: 66,
                            fontSize: 28,
                            colors: const [Color(0xFF5CE8FF), Color(0xFF1E9BFF), Color(0xFF1560E0)],
                            edge: const Color(0xFF0B3FA0),
                            glow: const Color(0xFF3FC8FF),
                          );
                        }
                        return NeonPillButton(
                          label: 'UNLOCK',
                          icon: Icons.lock_open_rounded,
                          onTap: controller.buyOrSelect,
                          height: 66,
                          fontSize: 28,
                          colors: const [Color(0xFFFFA43A), Color(0xFFFF5A5A), Color(0xFFF0329E)],
                          edge: const Color(0xFFB0185E),
                          glow: const Color(0xFFFF5A8A),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset('assets/images/icons/coin.png', width: 30),
                              const SizedBox(width: 6),
                              Text(
                                formatNumber(price),
                                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 26),
                      const _SectionHeader('BOOSTERS'),
                      const SizedBox(height: 12),
                      _ShieldCard(controller: controller),
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

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon});

  final IconData icon;
  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
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
      child: Icon(icon, color: Colors.white, size: size * 0.55),
    );
  }
}

class _TitlePill extends StatelessWidget {
  const _TitlePill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1250),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD27BFF), width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x99B04BFF), blurRadius: 16)],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 2,
            shadows: [Shadow(color: Color(0xAA6A2BE0), offset: Offset(0, 3), blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

/// Neon-edged frosted card (preview + boosters).
class _NeonGlassCard extends StatelessWidget {
  const _NeonGlassCard({required this.child, this.padding = const EdgeInsets.all(16), this.radius = 30});

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3FD8FF), Color(0xFF9B6BFF), Color(0xFFFF6BE0)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x77A04BFF), blurRadius: 22)],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius - 2),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE6342080), Color(0xF0221262)],
          ),
        ),
        child: child,
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.controller});

  final ShopController controller;

  void _step(int d) {
    const all = SkinCatalog.all;
    final i = all.indexWhere((s) => s.id == controller.previewId.value);
    controller.showPreview(all[(i + d + all.length) % all.length].id);
  }

  @override
  Widget build(BuildContext context) {
    return _NeonGlassCard(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
      child: Obx(() {
        final skin = controller.preview;
        final tag = skin.premium ? 'PREMIUM SKIN' : (skin.fiery ? 'FLAME TRAIL' : 'CLASSIC SKIN');
        return Column(
          children: [
            SizedBox(
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pre-rendered rolling ball + animated flame (GPU image draws, no CPU 3D work).
                  Positioned.fill(
                    child: RepaintBoundary(child: _BallStage(skin: skin)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PressableScale(
                      onTap: () => _step(-1),
                      semanticLabel: 'Previous ball',
                      child: const _ArrowButton(left: true),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: PressableScale(
                      onTap: () => _step(1),
                      semanticLabel: 'Next ball',
                      child: const _ArrowButton(left: false),
                    ),
                  ),
                ],
              ),
            ),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFF4B8FF)],
              ).createShader(r),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  skin.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 1.5,
                    shadows: [Shadow(color: Color(0xFF7A2BB0), offset: Offset(0, 3))],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0x55120A38),
                border: Border.all(color: const Color(0xFFB98BFF), width: 1.5),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0x44FFFFFF),
        border: Border.all(color: _violetEdge, width: 1.5),
      ),
      child: Icon(left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: Colors.white, size: 36),
    );
  }
}

/// Rolling pre-rendered ball with its flame streaming up-right, over a neon pedestal ring.
class _BallStage extends StatefulWidget {
  const _BallStage({required this.skin});

  final BallSkin skin;

  @override
  State<_BallStage> createState() => _BallStageState();
}

class _BallStageState extends State<_BallStage> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  final Future<void> _ready = BallSprites.instance.ensureLoaded();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (_, snap) {
        final set = BallSprites.instance.of(widget.skin.id);
        if (set == null) {
          // First frame before sprites decode: show the static icon.
          return Image.asset('assets/images/balls/${widget.skin.id}_icon.png', fit: BoxFit.contain);
        }
        return CustomPaint(painter: _BallStagePainter(_a, set, Color(widget.skin.trail)));
      },
    );
  }
}

class _BallStagePainter extends CustomPainter {
  _BallStagePainter(this.anim, this.set, this.color) : super(repaint: anim);

  final Animation<double> anim;
  final BallSpriteSet set;
  final Color color;
  final Paint _img = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    final secs = anim.value * 6;
    final r = size.height * 0.26;
    final c = Offset(size.width / 2, size.height * 0.5);

    // Neon pedestal ring.
    final ring = Rect.fromCenter(center: c + Offset(0, r * 1.15), width: r * 3.4, height: r * 0.62);
    canvas.drawOval(
      ring,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)],
        ).createShader(ring),
    );
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Color.lerp(color, Colors.white, 0.4)!,
    );

    // Flame: root on the ball centre, plume rotated to stream up-right.
    final fw = 2 * r * 1.15 / BallSpriteSet.flameRootWidth;
    final fh = fw * BallSpriteSet.flameH / BallSpriteSet.flameW * 0.95;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(0.7)
      ..drawImageRect(
        set.flame,
        set.flameFrame((secs * 14).floor()),
        Rect.fromLTWH(-fw / 2, -fh * BallSpriteSet.flameRoot, fw, fh),
        _img,
      )
      ..restore();

    // Ball (cell is larger than the ball: radius is 0.46 of the cell).
    final cell = r / BallSpriteSet.ballRadius;
    canvas.drawImageRect(
      set.ball,
      set.ballFrame((secs * 5).floor()),
      Rect.fromCenter(center: c, width: cell, height: cell),
      _img,
    );
  }

  @override
  bool shouldRepaint(covariant _BallStagePainter old) => old.set != set;
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
    final borderColor = selected ? const Color(0xFF3EE6A0) : (previewing ? Colors.white : _violetEdge);
    return PressableScale(
      onTap: onTap,
      semanticLabel: '${skin.name}, ${owned ? (selected ? 'equipped' : 'owned') : '${skin.price} coins'}',
      selected: previewing,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: previewing
                ? const [Color(0x664A3AA8), Color(0x55302080)]
                : const [Color(0x40FFFFFF), Color(0x1AFFFFFF)],
          ),
          border: Border.all(color: borderColor, width: selected || previewing ? 2.5 : 1.5),
          boxShadow: [
            if (selected) const BoxShadow(color: Color(0x883EE6A0), blurRadius: 14),
            if (previewing && !selected) const BoxShadow(color: Color(0x66FFFFFF), blurRadius: 10),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        child: Column(
          children: [
            Expanded(
              // Icons carry transparent margins for the flame; scale up so the ball fills the tile.
              child: Transform.scale(
                scale: 1.3,
                child: Image.asset(
                  'assets/images/balls/${skin.id}_icon.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
            ),
            const SizedBox(height: 2),
            if (selected)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF14243A),
                  border: Border.all(color: const Color(0xFF3EE6A0), width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF3EE6A0), size: 18),
              )
            else
              _PricePill(owned: owned, price: skin.price),
          ],
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.owned, required this.price});

  final bool owned;
  final int price;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x66120A38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66D9C8FF)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: owned
            ? const Text(
                'OWNED',
                style: TextStyle(color: AppColors.mint, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/icons/coin.png', width: 18),
                  const SizedBox(width: 4),
                  Text(
                    formatNumber(price),
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFFF4FD8), Color(0xFF9B6BFF), Color(0x003FD8FF)]),
              boxShadow: [BoxShadow(color: Color(0x88FF4FD8), blurRadius: 6)],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShieldCard extends StatelessWidget {
  const _ShieldCard({required this.controller});

  final ShopController controller;

  @override
  Widget build(BuildContext context) {
    final p = controller.player;
    return _NeonGlassCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x553FD8FF), Color(0x332060E0)],
                ),
                border: Border.all(color: const Color(0x993FD8FF), width: 1.5),
              ),
              child: Image.asset('assets/images/icons/shield.png'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Obx(
                    () => Text(
                      'Shield  ×${p.shields.value}/${ProgressionService.maxShields}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Blocks one hazard hit. Used automatically.',
                    style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Container(width: 1.5, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0x55D9C8FF)),
            Center(
              child: SizedBox(
                width: 100,
                child: NeonPillButton(
                  label: '',
                  icon: Icons.add_rounded,
                  onTap: controller.buyShield,
                  height: 54,
                  fontSize: 20,
                  colors: const [Color(0xFFFF8A5A), Color(0xFFFF4A5A), Color(0xFFE0284A)],
                  edge: const Color(0xFF9A1030),
                  glow: const Color(0xFFFF5A5A),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/icons/coin.png', width: 26),
                      const SizedBox(width: 4),
                      Text(
                        '${ProgressionService.shieldPrice}',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

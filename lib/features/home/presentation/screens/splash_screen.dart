import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/enums/game_enums.dart';
import '../../../../core/logging/log.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/widgets/showcase_view.dart';
import '../../../levels/data/level_generator.dart';
import '../../../player/data/player_repository.dart';
import '../../../player/presentation/controllers/player_controller.dart';
import '../../../settings/data/settings_repository.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../../../shop/data/ball_sprites.dart';
import '../../../shop/data/skin_catalog.dart';

/// Loads storage, profile, settings and audio while the 3D tower spins, then opens Home.
class SplashController extends GetxController {
  final progress = 0.0.obs;
  final status = 'Assembling the tower…'.obs;

  @override
  void onReady() {
    super.onReady();
    _load();
  }

  Future<void> _load() async {
    final started = DateTime.now();
    try {
      final store = await SharedPrefsStore.create();
      progress.value = 0.25;
      if (!Get.isRegistered<PlayerController>()) {
        Get.put(PlayerController(PlayerRepository(store)), permanent: true).load();
      }
      if (!Get.isRegistered<SettingsController>()) {
        Get.put(SettingsController(SettingsRepository(store)), permanent: true).load();
      }
      progress.value = 0.45;
      status.value = 'Tuning the sound…';
      final audio = Get.find<AudioService>();
      await audio.init();
      audio.apply(Get.find<SettingsController>().value);
      progress.value = 0.8;
      status.value = 'Painting the platforms…';
      final player = Get.find<PlayerController>();
      final mode = Get.find<SettingsController>().value.mode;
      Get.find<LevelGenerator>().generate(player.currentLevel.value, mode);
      progress.value = 0.9;
      await BallSprites.instance.ensureLoaded();
      progress.value = 1;
    } catch (e) {
      Log.w('Splash', 'load failed: $e');
      status.value = 'Something went wrong — retrying';
      await Future<void>.delayed(const Duration(seconds: 1));
      return _load();
    }
    final elapsed = DateTime.now().difference(started);
    const minimum = Duration(milliseconds: 1700);
    if (elapsed < minimum) await Future<void>.delayed(minimum - elapsed);
    Get.offAllNamed(AppRoutes.home);
  }
}

class SplashScreen extends GetView<SplashController> {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ShowcaseView(level: 1, skin: SkinCatalog.byId(SkinCatalog.defaultSkinId), quality: GraphicsQuality.medium),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x00000000), Color(0xAA120E2E)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.elasticOut,
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: Image.asset('assets/images/logo/logo.png', width: 300),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Obx(
                    () => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: controller.progress.value),
                        duration: const Duration(milliseconds: 300),
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 12,
                          backgroundColor: AppColors.glass,
                          valueColor: const AlwaysStoppedAnimation(AppColors.tangerine),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Obx(() => Text(controller.status.value, style: AppText.caption)),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/dev/autopilot.dart';
import '../../../../core/enums/game_enums.dart';
import '../../../../core/services/audio_service.dart';
import '../../../player/domain/progression_service.dart';
import '../../../player/presentation/controllers/player_controller.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';

class HomeController extends GetxController {
  HomeController(this.player, this.settings);

  final PlayerController player;
  final SettingsController settings;

  @override
  void onReady() {
    super.onReady();
    Get.find<AudioService>().startMusic();
    player.dailyAvailable.value = ProgressionService.canClaimDaily(player.profile, DateTime.now());
    if (Autopilot.forceMode.isNotEmpty) {
      settings.setMode(InputMode.values.byName(Autopilot.forceMode));
    }
    if (Autopilot.startRoute.isNotEmpty) {
      Future.delayed(const Duration(seconds: 2), () => Get.toNamed(Autopilot.startRoute));
    } else if (Autopilot.enabled) {
      Future.delayed(const Duration(seconds: 3), play);
    }
  }

  void play() => Get.toNamed(AppRoutes.game, arguments: player.currentLevel.value);
  void openLevels() => Get.toNamed(AppRoutes.levels);
  void openShop() => Get.toNamed(AppRoutes.shop);
  void openSettings() => Get.toNamed(AppRoutes.settings);
  void setMode(InputMode m) => settings.setMode(m);
  void toggleSound() => settings.toggleSound();

  int get dailyDay => player.nextDailyDay;
  int get dailyAmount => ProgressionService.dailyAmount(dailyDay);

  Future<int> claimDaily() async {
    final amount = await player.claimDaily();
    if (amount > 0) Get.find<AudioService>().playSfx('coin');
    return amount;
  }
}

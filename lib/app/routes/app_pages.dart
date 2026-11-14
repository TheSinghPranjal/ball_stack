import 'package:get/get.dart';

import '../../core/services/audio_service.dart';
import '../../features/gameplay/presentation/controllers/game_controller.dart';
import '../../features/gameplay/presentation/screens/game_screen.dart';
import '../../features/home/presentation/controllers/home_controller.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/splash_screen.dart';
import '../../features/levels/data/level_generator.dart';
import '../../features/levels/presentation/screens/level_select_screen.dart';
import '../../features/player/presentation/controllers/player_controller.dart';
import '../../features/settings/presentation/controllers/settings_controller.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/shop/presentation/controllers/shop_controller.dart';
import '../../features/shop/presentation/screens/shop_screen.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen(), binding: BindingsBuilder(() {
      Get.put(SplashController());
    })),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
      binding: BindingsBuilder(() {
        Get.put(HomeController(Get.find(), Get.find()));
      }),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.levels,
      page: () => const LevelSelectScreen(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: AppRoutes.game,
      page: () => const GameScreen(),
      binding: BindingsBuilder(() {
        Get.put(GameController(
          levels: Get.find<LevelGenerator>(),
          player: Get.find<PlayerController>(),
          settings: Get.find<SettingsController>(),
          audio: Get.find<AudioService>(),
        ));
      }),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.shop,
      page: () => const ShopScreen(),
      binding: BindingsBuilder(() {
        Get.put(ShopController(Get.find()));
      }),
      transition: Transition.downToUp,
    ),
    GetPage(name: AppRoutes.settings, page: () => const SettingsScreen(), transition: Transition.rightToLeftWithFade),
  ];
}

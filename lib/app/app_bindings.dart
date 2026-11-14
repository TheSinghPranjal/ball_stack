import 'package:get/get.dart';

import '../core/services/audio_service.dart';
import '../features/levels/data/level_generator.dart';

/// App-lifetime dependencies that need no async setup. Async ones (storage, profile, audio preload) are
/// initialised by the splash screen's loader.
class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(LevelGenerator(), permanent: true);
    Get.put(AudioService(), permanent: true);
  }
}

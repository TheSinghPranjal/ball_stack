import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/audio_service.dart';
import '../../../player/domain/progression_service.dart';
import '../../../player/presentation/controllers/player_controller.dart';
import '../../data/skin_catalog.dart';
import '../../domain/ball_skin.dart';

class ShopController extends GetxController {
  ShopController(this.player);

  final PlayerController player;
  late final RxString previewId = player.selectedSkinId.value.obs;

  BallSkin get preview => SkinCatalog.byId(previewId.value);
  bool get previewOwned => player.ownedSkins.contains(previewId.value);
  bool get previewSelected => player.selectedSkinId.value == previewId.value;
  bool get canAffordPreview => player.coins.value >= preview.price;

  void showPreview(String id) => previewId.value = id;

  Future<void> buyOrSelect() async {
    final r = await player.buyOrSelectSkin(previewId.value);
    switch (r) {
      case PurchaseResult.purchased:
        Get.find<AudioService>().playSfx('coin');
        _toast('Unlocked ${preview.name}!');
      case PurchaseResult.selected:
        _toast('${preview.name} equipped');
      case PurchaseResult.insufficientCoins:
        _toast('Not enough coins — need ${preview.price - player.coins.value} more');
      case PurchaseResult.maxReached:
        break;
    }
  }

  Future<void> buyShield() async {
    final r = await player.buyShield();
    switch (r) {
      case PurchaseResult.purchased:
        Get.find<AudioService>().playSfx('shield');
        _toast('Shield ready — it blocks one hazard hit');
      case PurchaseResult.insufficientCoins:
        _toast('Not enough coins for a shield');
      case PurchaseResult.maxReached:
        _toast('You can carry up to ${ProgressionService.maxShields} shields');
      case PurchaseResult.selected:
        break;
    }
  }

  void _toast(String msg) {
    Get.closeAllSnackbars();
    Get.snackbar(
      'Shop',
      msg,
      colorText: Colors.white,
      backgroundColor: const Color(0xCC1B1640),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );
  }
}

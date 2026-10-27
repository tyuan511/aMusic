import 'package:flutter/foundation.dart';

import '../../router.dart';

/// Lets code outside the now playing page (keyboard shortcuts, the mini
/// player) switch its panel while it is open.
class PlayerPanelController {
  PlayerPanelController._();

  static final PlayerPanelController instance = PlayerPanelController._();

  /// `true` while the now playing route is mounted.
  final ValueNotifier<bool> isOpen = ValueNotifier(false);

  /// One-shot requests, consumed by the page.
  final ValueNotifier<PlayerPanel?> request = ValueNotifier(null);

  /// Installed by the open page; reports the panel on screen.
  PlayerPanel Function()? visibleResolver;

  /// The panel the open page shows (`cover` on phones means "no panel").
  PlayerPanel get visible => visibleResolver?.call() ?? PlayerPanel.cover;

  /// Asks the open page to show [panel].
  void show(PlayerPanel panel) {
    // Re-asserting the same request must notify again.
    request.value = null;
    request.value = panel;
  }
}

/// Opens the player on [panel], or switches the panel when it is already
/// open. Asking for the visible panel again toggles back to the cover.
void showPlayerPanel(PlayerPanel panel) {
  final controller = PlayerPanelController.instance;
  if (!controller.isOpen.value) {
    openPlayerGlobal(panel: panel);
    return;
  }
  controller.show(
    controller.visible == panel && panel != PlayerPanel.cover
        ? PlayerPanel.cover
        : panel,
  );
}

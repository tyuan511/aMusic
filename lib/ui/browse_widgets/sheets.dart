import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../widgets/kit.dart';

/// One entry of [showActionSheet].
class SheetAction {
  const SheetAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.destructive = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool destructive;
  final bool enabled;
}

/// Shows [builder] as a bottom sheet on the ROOT navigator.
///
/// The shell draws the mini player and the floating navigation inside the
/// page tree (a `Stack` under the `Scaffold` body), so a sheet pushed on a
/// branch navigator — or on the shell's own navigator — renders *below* that
/// chrome and gets covered by it. Pushing on the root navigator puts the sheet
/// in the app-wide overlay, above everything the shell floats.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: useSafeArea,
    isScrollControlled: isScrollControlled,
    builder: builder,
  );
}

/// Row used by action sheets: round charcoal icon + label, press scale.
class SheetActionRow extends StatelessWidget {
  const SheetActionRow({super.key, required this.action, this.index = 0});

  final SheetAction action;
  final int index;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final color = !action.enabled
        ? s.textTertiary
        : (action.destructive
              ? context.colors.error
              : context.colors.onSurface);
    return Pressable(
      pressedScale: 0.98,
      onTap: action.enabled ? action.onSelected : null,
      semanticLabel: action.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: s.chip, shape: BoxShape.circle),
              child: Icon(action.icon, size: 20, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                action.label,
                style: context.text.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with a title and a list of actions. The sheet closes before
/// the selected action runs, so actions may navigate or open dialogs.
Future<void> showActionSheet(
  BuildContext context, {
  String? title,
  Widget? header,
  required List<SheetAction> actions,
}) {
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?header,
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sheetContext.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                for (var i = 0; i < actions.length; i++)
                  SheetActionRow(
                    index: i,
                    action: SheetAction(
                      icon: actions[i].icon,
                      label: actions[i].label,
                      destructive: actions[i].destructive,
                      enabled: actions[i].enabled,
                      onSelected: () {
                        Navigator.of(sheetContext).pop();
                        actions[i].onSelected();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Yes / no dialog. Resolves to `true` only when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '确定',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: dialogContext.colors.error,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Floating snackbar helper shared by browsing screens.
void showToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}

/// Same as [showToast] with a pre-captured messenger (safe after a pop).
void showToastOn(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
}

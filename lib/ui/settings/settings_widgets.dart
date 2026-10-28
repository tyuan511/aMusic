import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';

/// A titled group of settings rendered as one rounded card.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.index = 0,
  });

  final String title;
  final IconData? icon;
  final List<Widget> children;

  /// Entrance stagger slot.
  final int index;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return EntranceFade(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: s.lime),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: s.card,
                borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
                border: Border.all(color: s.hairline),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 18,
                          endIndent: 18,
                          color: s.hairline,
                        ),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row: label + optional subtitle on the left, [trailing] on the right,
/// or [below] stacked under the label for wide controls (sliders).
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.label,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.below,
    this.onTap,
  });

  final String label;
  final String? subtitle;

  /// Widget variant of [subtitle], laid out in the same slot (tight under the
  /// label) for async content such as cache sizes.
  final Widget? subtitleWidget;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      AnimatedSwitcher(
                        duration: AppMotion.quick,
                        child: Text(
                          subtitle!,
                          key: ValueKey(subtitle),
                          style: context.text.bodySmall?.copyWith(
                            color: s.textTertiary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    if (subtitleWidget != null) ...[
                      const SizedBox(height: 3),
                      subtitleWidget!,
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 14), trailing!],
            ],
          ),
          if (below != null) ...[
            const SizedBox(height: 8),
            // Loosen the cross-axis constraints so shrink-wrapping children
            // (AnimatedSwitcher's centered Stack, AnimatedSize, ...) align to
            // the start instead of being centered across the full row.
            Align(alignment: Alignment.centerLeft, child: below!),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Pressable(onTap: onTap, pressedScale: 0.99, child: content);
  }
}

/// Small charcoal pill showing the current choice; opens a menu of [values].
class ChoiceButton<T> extends StatelessWidget {
  const ChoiceButton({
    super.key,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onSelected,
  });

  final T value;
  final List<T> values;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(s.card),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppMetrics.radiusSm),
            side: BorderSide(color: s.hairline),
          ),
        ),
      ),
      menuChildren: [
        for (final option in values)
          MenuItemButton(
            onPressed: () => onSelected(option),
            leadingIcon: AnimatedOpacity(
              duration: AppMotion.quick,
              opacity: option == value ? 1 : 0,
              child: Icon(Icons.check_rounded, size: 18, color: s.lime),
            ),
            child: Text(labelOf(option)),
          ),
      ],
      builder: (context, controller, _) => Pressable(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: AnimatedContainer(
          duration: AppMotion.standard,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: s.chip,
            borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.quick,
                child: Text(
                  labelOf(value),
                  key: ValueKey(value),
                  style: context.text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.unfold_more_rounded, size: 16, color: s.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slider row with the current value shown as a lime badge.
class SliderTile extends StatelessWidget {
  const SliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
    this.onChangeEnd,
    this.divisions,
    this.subtitle,
    this.enabled = true,
    this.footer,
  });

  final String label;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool enabled;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return SettingsTile(
      label: label,
      subtitle: subtitle,
      trailing: AnimatedContainer(
        duration: AppMotion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: enabled ? s.lime.withValues(alpha: 0.16) : s.chip,
          borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
        ),
        child: Text(
          valueLabel,
          style: context.text.labelMedium?.copyWith(
            color: enabled ? s.lime : s.textTertiary,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedOpacity(
            duration: AppMotion.standard,
            opacity: enabled ? 1 : 0.45,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
          ?footer,
        ],
      ),
    );
  }
}

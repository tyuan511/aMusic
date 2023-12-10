import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:laji_music/providers/config.dart';
import 'package:laji_music/widgets/setting_item.dart';

class SettingScreen extends HookConsumerWidget {
  SettingScreen({Key? key}) : super(key: key);

  final themes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

  @override
  Widget build(BuildContext context, ref) {
    final config = ref.watch(configProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: SafeArea(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("系统设置", style: Theme.of(context).textTheme.titleLarge),
          SettingItem(
            label: '主题切换',
            value: ToggleButtons(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              selectedColor: Theme.of(context).colorScheme.onPrimary,
              selectedBorderColor: Theme.of(context).colorScheme.primary,
              fillColor: Theme.of(context).colorScheme.primary,
              color: Theme.of(context).colorScheme.secondary,
              constraints: const BoxConstraints(
                minHeight: 32,
                minWidth: 60,
              ),
              isSelected: themes.map((theme) => config.themeMode == theme).toList(),
              children: const [Text("自动"), Text("浅色"), Text("深色")],
              onPressed: (index) {
                ref.read(configProvider.notifier).changeThemeMode(themes[index]);
              },
            ),
          )
        ],
      )),
    );
  }
}

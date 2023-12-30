// import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:amusic/extensions/theme_mode.dart';
import 'package:amusic/providers/config.dart';
// import 'package:amusic/providers/player.dart';
// import 'package:amusic/widgets/equalizer_controls.dart';
import 'package:amusic/widgets/setting_item.dart';

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
            value: DropdownMenu(
              initialSelection: config.themeMode,
              onSelected: (ThemeMode? value) {
                if (value != null) {
                  ref.read(configProvider.notifier).changeThemeMode(value);
                }
              },
              dropdownMenuEntries: ThemeMode.values
                  .map<DropdownMenuEntry<ThemeMode>>(
                      (ThemeMode value) => DropdownMenuEntry<ThemeMode>(value: value, label: value.label))
                  .toList(),
            ),
          ),
          SettingItem(
            label: '启动后自动播放',
            value: Switch(
                value: config.autoPlay,
                onChanged: (v) {
                  ref.read(configProvider.notifier).changeAutoPlay(v);
                }),
          ),
          SettingItem(
            label: '全屏沉浸',
            value: Switch(
                value: config.fullscreen,
                onChanged: (v) {
                  ref.read(configProvider.notifier).changeFullscreen(v);
                }),
          ),
          // if (Platform.isAndroid) ...[
          //   SettingItem(
          //     label: '均衡器',
          //     value: Switch(
          //       value: config.equalizerEnabled,
          //       onChanged: (v) {
          //         ref.read(configProvider.notifier).changeEqualizerEnabled(v);
          //       },
          //     ),
          //   ),
          //   SizedBox(
          //     height: 300,
          //     child: EqualizerControls(equalizer: ref.read(playerProvider.notifier).getEqualizer()),
          //   )
          // ]
        ],
      )),
    );
  }
}

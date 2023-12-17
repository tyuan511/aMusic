// import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:laji_music/extensions/theme_mode.dart';
import 'package:laji_music/providers/config.dart';
// import 'package:laji_music/providers/player.dart';
// import 'package:laji_music/widgets/equalizer_controls.dart';
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
              inputDecorationTheme: InputDecorationTheme(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                constraints: BoxConstraints.tight(const Size.fromHeight(48)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
          //   const SizedBox(height: 24),
          //   Text("音效设置", style: Theme.of(context).textTheme.titleLarge),
          //   SettingItem(
          //     label: '响度增强',
          //     value: Row(
          //       children: [
          //         Slider(
          //           min: -10,
          //           max: 10,
          //           value: config.loudness,
          //           onChanged: (v) {
          //             ref.read(configProvider.notifier).changeLoudness(v);
          //           },
          //         ),
          //         SizedBox(
          //           width: 48,
          //           child: Text(
          //             '${config.loudness.round()}分贝',
          //             textAlign: TextAlign.right,
          //           ),
          //         )
          //       ],
          //     ),
          //   ),
          //   SettingItem(label: '均衡器', value: Container()),
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

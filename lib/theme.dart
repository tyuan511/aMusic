import 'package:flutter/material.dart';

const seedColor = Color(0xFFD23A35);

class _PageTransitionsBuilder extends PageTransitionsBuilder {
  const _PageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget? child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }
}

PageTransitionsTheme _getPageTransitions() {
  return PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values) platform: const _PageTransitionsBuilder(),
    },
  );
}

final inputDecorationTheme = InputDecorationTheme(
  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
  constraints: BoxConstraints.tight(const Size.fromHeight(44)),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
  ),
);

final theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
  useMaterial3: true,
  pageTransitionsTheme: _getPageTransitions(),
  inputDecorationTheme: inputDecorationTheme,
);

final darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
  useMaterial3: true,
  pageTransitionsTheme: _getPageTransitions(),
  inputDecorationTheme: inputDecorationTheme,
);

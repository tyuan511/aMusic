import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Semantic colours and design tokens that Material's `ColorScheme` does not
/// cover.
///
/// The look is "midnight lime": a near black canvas, soft charcoal surfaces,
/// pill shaped chips, one acid-lime accent for the active thing on screen and
/// a lavender / peach pair for hero cards and ambient glows.
@immutable
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  const AppSurfaces({
    required this.sidebar,
    required this.playerBar,
    required this.card,
    required this.cardHover,
    required this.chip,
    required this.glass,
    required this.textSecondary,
    required this.textTertiary,
    required this.hairline,
    required this.scrim,
    required this.lime,
    required this.onLime,
    required this.lavender,
    required this.plum,
    required this.peach,
    required this.brandGradient,
    required this.glow,
  });

  /// Desktop sidebar background.
  final Color sidebar;

  /// Player bar / floating nav base colour (drawn translucent over a blur).
  final Color playerBar;

  /// List rows, cards, panels.
  final Color card;
  final Color cardHover;

  /// Unselected chip and round icon button fill.
  final Color chip;

  /// Frosted overlay tint for floating bars.
  final Color glass;

  final Color textSecondary;
  final Color textTertiary;
  final Color hairline;
  final Color scrim;

  /// The single accent: selected chip, active nav item, play button, progress.
  final Color lime;
  final Color onLime;

  /// Hero card fill and its deep play button.
  final Color lavender;
  final Color plum;

  /// Warm ambient colour used in backdrops next to [lavender].
  final Color peach;

  /// Ambient sweep (lavender -> pink -> peach) for backdrops and the brand mark.
  final List<Color> brandGradient;

  /// Coloured shadow under raised accent surfaces.
  final Color glow;

  LinearGradient get brand => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brandGradient,
  );

  @override
  AppSurfaces copyWith({
    Color? sidebar,
    Color? playerBar,
    Color? card,
    Color? cardHover,
    Color? chip,
    Color? glass,
    Color? textSecondary,
    Color? textTertiary,
    Color? hairline,
    Color? scrim,
    Color? lime,
    Color? onLime,
    Color? lavender,
    Color? plum,
    Color? peach,
    List<Color>? brandGradient,
    Color? glow,
  }) => AppSurfaces(
    sidebar: sidebar ?? this.sidebar,
    playerBar: playerBar ?? this.playerBar,
    card: card ?? this.card,
    cardHover: cardHover ?? this.cardHover,
    chip: chip ?? this.chip,
    glass: glass ?? this.glass,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    hairline: hairline ?? this.hairline,
    scrim: scrim ?? this.scrim,
    lime: lime ?? this.lime,
    onLime: onLime ?? this.onLime,
    lavender: lavender ?? this.lavender,
    plum: plum ?? this.plum,
    peach: peach ?? this.peach,
    brandGradient: brandGradient ?? this.brandGradient,
    glow: glow ?? this.glow,
  );

  @override
  AppSurfaces lerp(covariant AppSurfaces? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSurfaces(
      sidebar: mix(sidebar, other.sidebar),
      playerBar: mix(playerBar, other.playerBar),
      card: mix(card, other.card),
      cardHover: mix(cardHover, other.cardHover),
      chip: mix(chip, other.chip),
      glass: mix(glass, other.glass),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      hairline: mix(hairline, other.hairline),
      scrim: mix(scrim, other.scrim),
      lime: mix(lime, other.lime),
      onLime: mix(onLime, other.onLime),
      lavender: mix(lavender, other.lavender),
      plum: mix(plum, other.plum),
      peach: mix(peach, other.peach),
      brandGradient: [
        for (var i = 0; i < brandGradient.length; i++)
          mix(
            brandGradient[i],
            other.brandGradient[i % other.brandGradient.length],
          ),
      ],
      glow: mix(glow, other.glow),
    );
  }
}

/// Motion tokens shared by every animated surface, so the app moves with one
/// rhythm instead of a different duration per widget.
class AppMotion {
  AppMotion._();

  static const Duration instant = Duration(milliseconds: 90);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration emphasized = Duration(milliseconds: 360);
  static const Duration page = Duration(milliseconds: 420);

  /// Decelerating curve for things entering or settling.
  static const Curve enter = Cubic(0.2, 0.8, 0.2, 1);

  /// Accelerating curve for things leaving.
  static const Curve exit = Curves.easeInCubic;

  /// Slight overshoot for small elements that pop (buttons, badges).
  static const Curve pop = Curves.easeOutBack;
}

/// Radii, spacing and sizes shared across screens.
class AppMetrics {
  AppMetrics._();

  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 26;
  static const double radiusPill = 999;

  /// Horizontal page gutter on phones / desktop content.
  static const double gutter = 20;

  /// Height of the floating bottom navigation on compact layouts.
  static const double floatingNavHeight = 68;

  /// Space reserved below scrolling content on compact layouts so the last
  /// row is not hidden behind the floating player + navigation.
  static const double compactBottomInset = 168;
}

class AppTheme {
  AppTheme._();

  /// Acid lime: the single accent. Kept as `seed` for older call sites.
  static const Color seed = Color(0xFFC8F04A);
  static const Color lime = seed;

  /// Deeper lime that stays legible as text on light surfaces.
  static const Color limeInk = Color(0xFF5C7A00);
  static const Color lavender = Color(0xFFC9A0F2);
  static const Color plum = Color(0xFF4B1D5E);
  static const Color peach = Color(0xFFF6A97C);
  static const Color pink = Color(0xFFE56FB4);

  /// Kept for call sites that sweep an album accent into a cool tone.
  static const Color violet = Color(0xFF8B5CF6);

  static const List<Color> _ambient = [
    Color(0xFF9B6BE0),
    Color(0xFFE56FB4),
    Color(0xFFF6A97C),
  ];

  static const AppSurfaces _darkSurfaces = AppSurfaces(
    sidebar: Color(0xFF0B0B10),
    playerBar: Color(0xFF17171E),
    card: Color(0xFF15151B),
    cardHover: Color(0xFF1E1E26),
    chip: Color(0xFF1F1F27),
    glass: Color(0xB31C1C24),
    textSecondary: Color(0xFFA6A6B0),
    textTertiary: Color(0xFF6E6E7A),
    hairline: Color(0x14FFFFFF),
    scrim: Color(0xCC000000),
    lime: lime,
    onLime: Color(0xFF0E1200),
    lavender: lavender,
    plum: plum,
    peach: peach,
    brandGradient: _ambient,
    glow: Color(0x55C8F04A),
  );

  static const AppSurfaces _lightSurfaces = AppSurfaces(
    sidebar: Color(0xFFF1F1EC),
    playerBar: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardHover: Color(0xFFF2F2EC),
    chip: Color(0xFFE9E9E2),
    glass: Color(0xCCFFFFFF),
    textSecondary: Color(0xFF55555E),
    textTertiary: Color(0xFF8C8C95),
    hairline: Color(0x14000000),
    scrim: Color(0xB3FFFFFF),
    lime: lime,
    onLime: Color(0xFF0E1200),
    lavender: lavender,
    plum: plum,
    peach: peach,
    brandGradient: _ambient,
    glow: Color(0x405C7A00),
  );

  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final surfaces = dark ? _darkSurfaces : _lightSurfaces;
    final background = dark ? const Color(0xFF0A0A0E) : const Color(0xFFF7F7F3);
    final onSurface = dark ? const Color(0xFFF4F4F6) : const Color(0xFF111114);

    // The scheme is pinned rather than derived from a seed: generated tones
    // desaturate the lime into an olive that no longer reads as the accent.
    final scheme =
        ColorScheme.fromSeed(
          seedColor: lime,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ).copyWith(
          primary: dark ? lime : limeInk,
          onPrimary: dark ? surfaces.onLime : Colors.white,
          primaryContainer: dark
              ? const Color(0xFF2B3410)
              : const Color(0xFFE6F5B5),
          onPrimaryContainer: dark ? lime : const Color(0xFF2B3A00),
          secondary: lavender,
          onSecondary: plum,
          tertiary: peach,
          onTertiary: const Color(0xFF3A1A08),
          surface: background,
          onSurface: onSurface,
          surfaceContainerLowest: background,
          surfaceContainerLow: surfaces.card,
          surfaceContainer: surfaces.card,
          surfaceContainerHigh: surfaces.cardHover,
          surfaceContainerHighest: surfaces.chip,
          outline: surfaces.textTertiary,
          outlineVariant: surfaces.hairline,
          error: const Color(0xFFFF6B6B),
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: InkSparkle.splashFactory,
      extensions: [surfaces],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );

    StadiumBorder pill() => const StadiumBorder();

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: onSurface,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        iconTheme: IconThemeData(color: onSurface, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surfaces.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: surfaces.hairline,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 56,
        iconColor: surfaces.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.radiusSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaces.chip,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        hintStyle: base.textTheme.bodyMedium?.copyWith(
          color: surfaces.textTertiary,
        ),
        prefixIconColor: surfaces.textSecondary,
        suffixIconColor: surfaces.textSecondary,
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(scheme.primary.withValues(alpha: 0.7)),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: surfaces.lime,
          foregroundColor: surfaces.onLime,
          disabledBackgroundColor: surfaces.chip,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: pill(),
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: surfaces.chip,
          foregroundColor: onSurface,
          elevation: 0,
          shape: pill(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(0, 42),
          shape: pill(),
          side: BorderSide(color: surfaces.hairline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: surfaces.textSecondary,
          shape: pill(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: onSurface,
          shape: const CircleBorder(),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaces.chip,
        selectedColor: surfaces.lime,
        disabledColor: surfaces.chip,
        side: BorderSide.none,
        showCheckmark: false,
        labelStyle: base.textTheme.labelLarge?.copyWith(color: onSurface),
        secondaryLabelStyle: base.textTheme.labelLarge?.copyWith(
          color: surfaces.onLime,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: pill(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? surfaces.onLime
              : surfaces.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? surfaces.lime
              : surfaces.chip,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : surfaces.textTertiary,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? surfaces.lime
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(surfaces.onLime),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? surfaces.lime
                : surfaces.chip,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? surfaces.onLime
                : onSurface,
          ),
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        trackHeight: 4,
        activeTrackColor: surfaces.lime,
        inactiveTrackColor: surfaces.textTertiary.withValues(alpha: 0.28),
        thumbColor: surfaces.lime,
        overlayColor: surfaces.lime.withValues(alpha: 0.16),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: ShapeDecoration(shape: pill(), color: surfaces.lime),
        labelColor: surfaces.onLime,
        unselectedLabelColor: surfaces.textSecondary,
        labelStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: base.textTheme.labelLarge,
        splashBorderRadius: BorderRadius.circular(AppMetrics.radiusPill),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: surfaces.playerBar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: surfaces.lime,
        indicatorShape: pill(),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? surfaces.onLime
                : surfaces.textSecondary,
          ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? const Color(0xFF26262F)
            : const Color(0xFF1E1E24),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        actionTextColor: lime,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
        ),
        insetPadding: const EdgeInsets.all(16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF16161D) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.radiusLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? const Color(0xFF14141A) : Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: surfaces.textTertiary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppMetrics.radiusLg),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: dark ? const Color(0xFF1C1C24) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            dark ? const Color(0xFF1C1C24) : Colors.white,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2A2A33) : const Color(0xFF2A2A30),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: surfaces.textTertiary.withValues(alpha: 0.2),
        circularTrackColor: surfaces.textTertiary.withValues(alpha: 0.2),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          surfaces.textTertiary.withValues(alpha: 0.4),
        ),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        crossAxisMargin: 2,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
    borderSide: BorderSide(color: color, width: 1.4),
  );

  /// Geometric, medium-weight type scale (the reference uses w500/w600 rather
  /// than heavy bold), on the platform font so CJK glyphs render natively.
  static TextTheme _textTheme(TextTheme base, Color onSurface) {
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.8,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          labelLarge: base.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        )
        .apply(bodyColor: onSurface, displayColor: onSurface);
  }
}

/// Exposes the album art accent without rebuilding the whole app.
///
/// Only the player surfaces read this, so a track change repaints the mini
/// player and the now playing screen instead of the entire widget tree.
class AccentScope extends InheritedNotifier<ValueNotifier<Color?>> {
  const AccentScope({
    super.key,
    required ValueNotifier<Color?> accent,
    required super.child,
  }) : super(notifier: accent);

  /// The album accent, falling back to the brand lime.
  static Color of(BuildContext context) {
    final accent = context
        .dependOnInheritedWidgetOfExactType<AccentScope>()
        ?.notifier
        ?.value;
    return accent ?? Theme.of(context).extension<AppSurfaces>()!.lime;
  }

  /// The album accent or `null` while unknown (for backdrops that should not
  /// flash the brand colour between tracks).
  static Color? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AccentScope>()
      ?.notifier
      ?.value;
}

extension AppThemeContext on BuildContext {
  AppSurfaces get surfaces => Theme.of(this).extension<AppSurfaces>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get scaffoldBackground => Theme.of(this).scaffoldBackgroundColor;
}

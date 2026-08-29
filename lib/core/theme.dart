import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Raw brand constants and the category artwork. Anything whose value depends
/// on light or dark lives in [AppPalette] instead, reached through
/// `context.palette`, so a widget never has to know which mode it is in.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF0F6E5C);
  static const Color primaryDark = Color(0xFF0A4C40);

  /// Lifted for dark mode: the light primary sits at 2.4:1 on the dark canvas,
  /// which fails as a text or icon colour.
  static const Color primaryOnDark = Color(0xFF3FBF9F);

  static const Color accent = Color(0xFFF2994A);

  /// Category gradients stand in for photography. Two stops each, dark enough
  /// that white overlay text always clears contrast — which also means they
  /// need no separate dark-mode variant.
  static const Map<String, List<Color>> categoryGradients = {
    'Mountains': [Color(0xFF1B3A4B), Color(0xFF3F7A8C)],
    'Valleys': [Color(0xFF14472F), Color(0xFF3E8E5A)],
    'Hills': [Color(0xFF2B4B3C), Color(0xFF5E8C6A)],
    'Lakes': [Color(0xFF0C3D63), Color(0xFF2E7FB8)],
    'Beaches': [Color(0xFF04568C), Color(0xFF2496B8)],
    'Historical': [Color(0xFF5A3A28), Color(0xFF97694A)],
    'City': [Color(0xFF2B2258), Color(0xFF5A4CB0)],
    'Desert': [Color(0xFF7A4A1F), Color(0xFFB07B3A)],
  };

  static List<Color> gradientFor(String category) =>
      categoryGradients[category] ?? categoryGradients['Mountains']!;

  static Color series(int slot, Brightness brightness) {
    final list = brightness == Brightness.dark
        ? AppPalette.dark.series
        : AppPalette.light.series;
    return list[slot % list.length];
  }

  static Color seriesOf(BuildContext context, int slot) =>
      context.palette.series[slot % context.palette.series.length];

  static IconData iconFor(String category) {
    switch (category) {
      case 'Mountains':
        return Icons.landscape_rounded;
      case 'Valleys':
        return Icons.forest_rounded;
      case 'Hills':
        return Icons.terrain_rounded;
      case 'Lakes':
      case 'Lake':
        return Icons.water_rounded;
      case 'Beaches':
      case 'Beach':
      case 'Island':
        return Icons.beach_access_rounded;
      case 'Historical':
        return Icons.account_balance_rounded;
      case 'City':
        return Icons.location_city_rounded;
      case 'Desert':
        return Icons.wb_sunny_rounded;
      case 'Pass':
        return Icons.signpost_rounded;
      case 'Trek':
      case 'Walk':
        return Icons.hiking_rounded;
      case 'Meadow':
      case 'Plateau':
      case 'Park':
      case 'Nature':
        return Icons.grass_rounded;
      case 'Waterfall':
      case 'Spring':
        return Icons.water_drop_rounded;
      case 'Viewpoint':
        return Icons.photo_camera_rounded;
      case 'Resort':
        return Icons.downhill_skiing_rounded;
      case 'Culture':
        return Icons.festival_rounded;
      case 'Bazaar':
        return Icons.storefront_rounded;
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Valley':
        return Icons.filter_hdr_rounded;
      case 'Transit':
        return Icons.alt_route_rounded;
      case 'Glacier':
        return Icons.ac_unit_rounded;
      case 'River':
        return Icons.waves_rounded;
      default:
        return Icons.place_rounded;
    }
  }
}

/// Every colour that differs between light and dark, in one object.
///
/// Widgets read `context.palette.ink` rather than a constant, which is what
/// makes a single widget tree correct in both modes. Before this existed the
/// dark theme was defined but unusable: 46 references to the light constants
/// were compiled into the widgets and stayed light-on-light.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.primary,
    required this.success,
    required this.caution,
    required this.serious,
    required this.danger,
    required this.series,
    required this.shadowCard,
    required this.shadowRaised,
  });

  final Brightness brightness;

  /// Page background.
  final Color canvas;

  /// Cards and sheets.
  final Color surface;

  /// A step away from [surface], for a panel inside a card.
  final Color surfaceAlt;

  final Color line;

  /// Primary, secondary and tertiary text.
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;

  /// The brand green, lifted in dark mode so it stays legible.
  final Color primary;

  // Status colours, contrast-checked against [surface] in their own mode.
  final Color success;
  final Color caution;
  final Color serious;
  final Color danger;

  /// Categorical chart palette, in fixed slot order. A cost category owns its
  /// slot for life, so sorting a legend by amount never repaints anything.
  final List<Color> series;

  final List<BoxShadow> shadowCard;
  final List<BoxShadow> shadowRaised;

  bool get isDark => brightness == Brightness.dark;

  /// Light mode. Status colours are the darkened steps of the ramp: the bright
  /// steps sit near 2:1 on white and would fail as small text.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    canvas: Color(0xFFF6F8F9),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF2F5F7),
    line: Color(0xFFE3E9EE),
    ink: Color(0xFF0E1A24),
    inkSoft: Color(0xFF5A6B78),
    inkFaint: Color(0xFF78899A),
    primary: AppColors.primary,
    success: Color(0xFF067A06), // 5.2:1 on white
    caution: Color(0xFFA15F00), // 5.1:1
    serious: Color(0xFFB34A20), // 5.4:1
    danger: Color(0xFFD03B3B), // 4.7:1
    series: [
      Color(0xFF2A78D6), // 0 travel
      Color(0xFFEB6834), // 1 accommodation
      Color(0xFF1BAF7A), // 2 food
      Color(0xFFEDA100), // 3 entry tickets
      Color(0xFFE87BA4), // 4 local transport
      Color(0xFF008300), // 5 tolls and parking
      Color(0xFF4A3AA7), // 6 contingency
    ],
    shadowCard: [
      BoxShadow(color: Color(0x0F0E1A24), blurRadius: 18, offset: Offset(0, 6)),
    ],
    shadowRaised: [
      BoxShadow(color: Color(0x1A0E1A24), blurRadius: 28, offset: Offset(0, 12)),
    ],
  );

  /// Dark mode. Not an inversion: the surfaces are a desaturated blue-slate that
  /// keeps the brand's cool cast, and every status colour is re-picked for at
  /// least 4.5:1 on the dark surface rather than reused from light.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    canvas: Color(0xFF0B1116),
    surface: Color(0xFF141D24),
    surfaceAlt: Color(0xFF1B262E),
    line: Color(0xFF25323B),
    ink: Color(0xFFE9EFF3),
    inkSoft: Color(0xFF9DB0BC),
    inkFaint: Color(0xFF6C7F8C),
    primary: AppColors.primaryOnDark,
    success: Color(0xFF4ADE80), // 9.7:1 on the dark surface
    caution: Color(0xFFF0B542), // 9.4:1
    serious: Color(0xFFFF9469), // 7.9:1
    danger: Color(0xFFFF7070), // 6.4:1
    series: [
      Color(0xFF5AA0F0),
      Color(0xFFFF8A5C),
      Color(0xFF35C892),
      Color(0xFFF5BE3F),
      Color(0xFFF48FB4),
      Color(0xFF56C15A),
      Color(0xFF9C8CF0),
    ],
    // Shadow does almost nothing on a dark ground; depth comes from the surface
    // step instead, so these stay faint rather than muddy.
    shadowCard: [
      BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6)),
    ],
    shadowRaised: [
      BoxShadow(color: Color(0x59000000), blurRadius: 26, offset: Offset(0, 12)),
    ],
  );

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? line,
    Color? ink,
    Color? inkSoft,
    Color? inkFaint,
    Color? primary,
    Color? success,
    Color? caution,
    Color? serious,
    Color? danger,
    List<Color>? series,
    List<BoxShadow>? shadowCard,
    List<BoxShadow>? shadowRaised,
  }) =>
      AppPalette(
        brightness: brightness ?? this.brightness,
        canvas: canvas ?? this.canvas,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        line: line ?? this.line,
        ink: ink ?? this.ink,
        inkSoft: inkSoft ?? this.inkSoft,
        inkFaint: inkFaint ?? this.inkFaint,
        primary: primary ?? this.primary,
        success: success ?? this.success,
        caution: caution ?? this.caution,
        serious: serious ?? this.serious,
        danger: danger ?? this.danger,
        series: series ?? this.series,
        shadowCard: shadowCard ?? this.shadowCard,
        shadowRaised: shadowRaised ?? this.shadowRaised,
      );

  /// Lerped so switching mode can crossfade rather than snap.
  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      line: c(line, other.line),
      ink: c(ink, other.ink),
      inkSoft: c(inkSoft, other.inkSoft),
      inkFaint: c(inkFaint, other.inkFaint),
      primary: c(primary, other.primary),
      success: c(success, other.success),
      caution: c(caution, other.caution),
      serious: c(serious, other.serious),
      danger: c(danger, other.danger),
      series: [
        for (var i = 0; i < series.length; i++) c(series[i], other.series[i]),
      ],
      shadowCard: t < 0.5 ? shadowCard : other.shadowCard,
      shadowRaised: t < 0.5 ? shadowRaised : other.shadowRaised,
    );
  }
}

extension PaletteAccess on BuildContext {
  /// The palette for the mode currently in force.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

class AppRadius {
  const AppRadius._();
  static const BorderRadius sm = BorderRadius.all(Radius.circular(10));
  static const BorderRadius md = BorderRadius.all(Radius.circular(16));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(22));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

class AppTheme {
  const AppTheme._();

  /// Bundled with the app, not fetched. See the `fonts:` block in pubspec.yaml
  /// for why that matters.
  static const String fontFamily = 'Plus Jakarta Sans';

  static TextStyle _font({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static const SystemUiOverlayStyle lightOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  static const SystemUiOverlayStyle darkOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  static ThemeData light() => _build(AppPalette.light);

  static ThemeData dark() => _build(AppPalette.dark);

  /// One builder for both modes. Anything that differs is already resolved on
  /// the palette, so the two themes cannot drift apart the way two hand-written
  /// copies did.
  static ThemeData _build(AppPalette p) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: p.brightness,
    ).copyWith(
      primary: p.primary,
      secondary: AppColors.accent,
      surface: p.surface,
      onSurface: p.ink,
      error: p.danger,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      extensions: [p],
      scaffoldBackgroundColor: p.canvas,
      textTheme: _text(base.textTheme, p),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: p.ink,
        systemOverlayStyle: p.isDark ? darkOverlay : lightOverlay,
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.isDark ? p.surface : p.canvas,
        selectedColor: p.primary.withValues(alpha: p.isDark ? 0.22 : 0.14),
        side: BorderSide(color: p.line),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
        labelStyle: _font(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.ink),
        secondaryLabelStyle: _font(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: p.primary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          textStyle: _font(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: p.line),
          foregroundColor: p.ink,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          textStyle: _font(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: _font(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
      ),
      iconTheme: IconThemeData(color: p.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: p.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
        hintStyle: _font(color: p.inkFaint, fontSize: 14.5),
        labelStyle: _font(color: p.inkSoft, fontSize: 14.5),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: p.primary,
        thumbColor: p.primary,
        inactiveTrackColor: p.line,
        trackHeight: 5,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? p.surfaceAlt : p.ink,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
        contentTextStyle: _font(color: p.isDark ? p.ink : Colors.white, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.line,
        circularTrackColor: p.line,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.isDark ? p.surfaceAlt : p.ink,
          borderRadius: AppRadius.sm,
        ),
        textStyle: _font(color: p.isDark ? p.ink : Colors.white, fontSize: 12.5),
      ),
    );
  }

  static TextTheme _text(TextTheme base, AppPalette p) {
    final t = base.apply(fontFamily: fontFamily);
    final ink = p.ink;
    return t.copyWith(
      displaySmall: t.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: ink, height: 1.1),
      headlineMedium:
          t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: ink, height: 1.15),
      headlineSmall:
          t.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: ink, height: 1.2),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: ink),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: ink),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: ink),
      bodyLarge: t.bodyLarge?.copyWith(color: ink, height: 1.45),
      bodyMedium: t.bodyMedium?.copyWith(color: ink, height: 1.45),
      bodySmall: t.bodySmall?.copyWith(color: p.inkSoft, height: 1.4),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: ink),
    );
  }
}

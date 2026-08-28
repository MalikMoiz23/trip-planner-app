import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF0F6E5C);
  static const Color primaryDark = Color(0xFF0A4C40);
  static const Color accent = Color(0xFFF2994A);
  static const Color ink = Color(0xFF0E1A24);
  static const Color inkSoft = Color(0xFF5A6B78);
  static const Color line = Color(0xFFE3E9EE);
  static const Color canvas = Color(0xFFF6F8F9);
  static const Color surface = Colors.white;

  // Status colours are reserved for advisories and never used as a series hue.
  // These are the darkened steps of the status ramp: they double as icon and
  // label colours on the light surface, where the bright steps sit near 2:1 and
  // would fail as small text.
  static const Color danger = Color(0xFFD03B3B); // 4.7:1 on white
  static const Color caution = Color(0xFFB26A00); // amber, 4.5:1 on white
  static const Color serious = Color(0xFFB34A20); // 5.4:1 on white
  static const Color success = Color(0xFF067A06); // 5.2:1 on white

  /// Categorical series palette, in fixed slot order. Validated for lightness
  /// band, chroma floor, adjacent CVD separation (protan/deutan/tritan) and
  /// contrast against both chart surfaces. A cost category owns its slot for
  /// life — sorting the legend by amount never repaints anything.
  static const List<Color> seriesLight = [
    Color(0xFF2A78D6), // 0 travel
    Color(0xFFEB6834), // 1 accommodation
    Color(0xFF1BAF7A), // 2 food
    Color(0xFFEDA100), // 3 entry tickets
    Color(0xFFE87BA4), // 4 local transport
    Color(0xFF008300), // 5 tolls and parking
    Color(0xFF4A3AA7), // 6 contingency
  ];

  static const List<Color> seriesDark = [
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
    Color(0xFFC98500),
    Color(0xFFD55181),
    Color(0xFF008300),
    Color(0xFF9085E9),
  ];

  static Color series(int slot, Brightness brightness) {
    final list = brightness == Brightness.dark ? seriesDark : seriesLight;
    return list[slot % list.length];
  }

  static Color seriesOf(BuildContext context, int slot) =>
      series(slot, Theme.of(context).brightness);

  /// Category gradients stand in for photography. Two stops each, dark enough
  /// that white overlay text always clears contrast.
  static const Map<String, List<Color>> categoryGradients = {
    'Mountains': [Color(0xFF1B3A4B), Color(0xFF3F7A8C)],
    'Valleys': [Color(0xFF14472F), Color(0xFF3E8E5A)],
    'Hills': [Color(0xFF2B4B3C), Color(0xFF5E8C6A)],
    'Lakes': [Color(0xFF0C3D63), Color(0xFF2E7FB8)],
    'Beaches': [Color(0xFF04568C), Color(0xFF29A2C6)],
    'Historical': [Color(0xFF5A3A28), Color(0xFF97694A)],
    'City': [Color(0xFF2B2258), Color(0xFF5A4CB0)],
    'Desert': [Color(0xFF7A4A1F), Color(0xFFC08A45)],
  };

  static List<Color> gradientFor(String category) =>
      categoryGradients[category] ?? categoryGradients['Mountains']!;

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
      default:
        return Icons.place_rounded;
    }
  }
}

class AppRadius {
  const AppRadius._();
  static const BorderRadius sm = BorderRadius.all(Radius.circular(10));
  static const BorderRadius md = BorderRadius.all(Radius.circular(16));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(22));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

class AppShadows {
  const AppShadows._();
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F0E1A24), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x1A0E1A24), blurRadius: 28, offset: Offset(0, 12)),
  ];
}

class AppTheme {
  const AppTheme._();

  /// Bundled with the app, not fetched. See the `fonts:` block in pubspec.yaml
  /// for why that matters.
  static const String fontFamily = 'Plus Jakarta Sans';
  static const String _fontFamily = fontFamily;

  static TextStyle _font({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: _fontFamily,
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

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: _text(base.textTheme, AppColors.ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.ink,
        systemOverlayStyle: lightOverlay,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.canvas,
        side: const BorderSide(color: AppColors.line),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
        labelStyle: _font(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
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
          side: const BorderSide(color: AppColors.line),
          foregroundColor: AppColors.ink,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          textStyle: _font(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: _font(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.line),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.primary, width: 1.6),
        ),
        hintStyle: _font(color: AppColors.inkSoft, fontSize: 14.5),
        labelStyle: _font(color: AppColors.inkSoft, fontSize: 14.5),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
        inactiveTrackColor: AppColors.line,
        trackHeight: 5,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
        contentTextStyle: _font(color: Colors.white, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    const ink = Color(0xFFE8EEF2);
    const canvas = Color(0xFF0C1418);
    const surface = Color(0xFF141F25);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF3FBF9F),
      secondary: AppColors.accent,
      surface: surface,
      error: AppColors.danger,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      textTheme: _text(base.textTheme, ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: ink,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF23323A), thickness: 1, space: 1),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          textStyle: _font(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: Color(0xFF23323A)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: Color(0xFF23323A)),
        ),
        hintStyle: _font(color: const Color(0xFF8FA2AE), fontSize: 14.5),
      ),
    );
  }

  static TextTheme _text(TextTheme base, Color ink) {
    final t = base.apply(fontFamily: _fontFamily);
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
      bodySmall: t.bodySmall?.copyWith(color: ink.withValues(alpha: 0.72), height: 1.4),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: ink),
    );
  }
}

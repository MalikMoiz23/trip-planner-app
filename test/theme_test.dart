import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/theme.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // A dark theme that was defined but never switched on had 46 light-palette
  // constants compiled into the widgets. These assertions are what stop the two
  // modes drifting apart again.
  group('palette contrast', () {
    for (final entry in {'light': AppPalette.light, 'dark': AppPalette.dark}.entries) {
      final name = entry.key;
      final p = entry.value;

      test('$name body text clears 4.5:1 on both grounds', () {
        expect(contrast(p.ink, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.ink, p.canvas), greaterThanOrEqualTo(4.5));
        expect(contrast(p.ink, p.surfaceAlt), greaterThanOrEqualTo(4.5));
      });

      test('$name secondary text clears 4.5:1', () {
        expect(contrast(p.inkSoft, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.inkSoft, p.canvas), greaterThanOrEqualTo(4.5));
      });

      test('$name tertiary text clears the 3:1 large-text bar', () {
        // inkFaint is only ever used for captions at 11 px and up in weight, and
        // never for anything a decision rests on.
        expect(contrast(p.inkFaint, p.surface), greaterThanOrEqualTo(3.0));
      });

      test('$name status colours clear 4.5:1 on the surface', () {
        for (final pair in {
          'success': p.success,
          'caution': p.caution,
          'serious': p.serious,
          'danger': p.danger,
        }.entries) {
          expect(
            contrast(pair.value, p.surface),
            greaterThanOrEqualTo(4.5),
            reason: '$name ${pair.key} is unreadable on the surface',
          );
        }
      });

      test('$name primary clears 4.5:1, since it is used for text and icons', () {
        expect(contrast(p.primary, p.surface), greaterThanOrEqualTo(4.5));
      });

      test('$name has a full series palette with no duplicates', () {
        expect(p.series.length, 7);
        expect(p.series.toSet().length, 7);
      });

      test('$name separator is visible but not a line of text', () {
        final c = contrast(p.line, p.surface);
        expect(c, greaterThan(1.05), reason: 'a border nobody can see is not a border');
        expect(c, lessThan(4.5), reason: 'a border this strong reads as content');
      });
    }

    test('the two modes are genuinely different, not one inverted', () {
      // An inversion would put dark.canvas at exactly the light ink and so on.
      expect(AppPalette.dark.canvas, isNot(AppPalette.light.ink));
      expect(AppPalette.dark.isDark, isTrue);
      expect(AppPalette.light.isDark, isFalse);
    });
  });

  group('theme wiring', () {
    test('both themes carry their palette as an extension', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();

      expect(light.extension<AppPalette>(), isNotNull);
      expect(dark.extension<AppPalette>(), isNotNull);
      expect(light.extension<AppPalette>()!.isDark, isFalse);
      expect(dark.extension<AppPalette>()!.isDark, isTrue);
    });

    test('brightness reaches the colour scheme', () {
      expect(AppTheme.light().colorScheme.brightness, Brightness.light);
      expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
    });

    test('scaffold and card colours come from the palette', () {
      final dark = AppTheme.dark();
      expect(dark.scaffoldBackgroundColor, AppPalette.dark.canvas);
      expect(dark.cardTheme.color, AppPalette.dark.surface);
    });

    test('the palette lerps rather than snapping, so the mode switch can fade', () {
      final mid = AppPalette.light.lerp(AppPalette.dark, 0.5);
      expect(mid.canvas, isNot(AppPalette.light.canvas));
      expect(mid.canvas, isNot(AppPalette.dark.canvas));
      expect(mid.series.length, 7);
    });

    test('every category gradient is dark enough for white overlay text', () {
      for (final entry in AppColors.categoryGradients.entries) {
        for (final stop in entry.value) {
          expect(
            contrast(Colors.white, stop),
            greaterThanOrEqualTo(3.0),
            reason: '${entry.key} has a stop too light for the white label on it',
          );
        }
      }
    });
  });
}

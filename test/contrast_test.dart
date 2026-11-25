import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:planit/core/theme/app_colors.dart';
import 'package:planit/core/theme/app_theme.dart';
import 'package:planit/core/utils/icons.dart';
import 'package:planit/domain/enums.dart';

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final high = l1 > l2 ? l1 : l2;
  final low = l1 > l2 ? l2 : l1;
  return (high + 0.05) / (low + 0.05);
}

void main() {
  final themes = <String, ThemeData>{
    'Midnight dark': AppTheme.dark,
    'Midnight light': AppTheme.light,
    'Digital dark': AppTheme.digitalDark,
    'Digital light': AppTheme.digitalLight,
  };

  for (final entry in themes.entries) {
    final theme = entry.value;
    final digital = entry.key.startsWith('Digital');

    test('${entry.key}: selected navigation label is readable', () {
      final bar = theme.navigationBarTheme;
      final label = bar.labelTextStyle
          ?.resolve(<WidgetState>{WidgetState.selected})
          ?.color;
      final background = bar.backgroundColor ?? theme.colorScheme.surface;
      expect(label, isNotNull);
      expect(_contrast(label!, background), greaterThanOrEqualTo(4.5));
    });

    test('${entry.key}: card border meets the 3:1 UI threshold', () {
      final cardColor =
          theme.cardTheme.color ?? theme.colorScheme.surface;
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      final side = shape.side;
      expect(_contrast(side.color, cardColor), greaterThanOrEqualTo(3.0));
    });

    test('${entry.key}: navigation rail selection is readable', () {
      final rail = theme.navigationRailTheme;
      final icon = rail.selectedIconTheme?.color;
      final indicator =
          rail.indicatorColor ?? theme.colorScheme.secondaryContainer;
      expect(icon, isNotNull);
      expect(_contrast(icon!, indicator), greaterThanOrEqualTo(3.0));
    });

    test('${entry.key}: status glyphs stay visible on cards', () {
      final cardColor =
          theme.cardTheme.color ?? theme.colorScheme.surface;
      for (final status in LogStatus.values) {
        final color = AppColors.outcome(status, theme, digital: digital);
        expect(
          _contrast(color, cardColor),
          greaterThanOrEqualTo(3.0),
          reason: '${status.label} on ${entry.key}',
        );
      }
      expect(
        _contrast(AppColors.missed(theme, digital: digital), cardColor),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('${entry.key}: form labels and errors meet AA', () {
      final surface = theme.cardTheme.color ?? theme.colorScheme.surface;
      final floating = theme.inputDecorationTheme.floatingLabelStyle?.color;
      final error = theme.inputDecorationTheme.errorStyle?.color;
      expect(floating, isNotNull);
      expect(error, isNotNull);
      expect(_contrast(floating!, surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(error!, surface), greaterThanOrEqualTo(4.5));
    });
  }

  test('status icon vocabulary is shared', () {
    expect(AppIcons.done, Phosphor.checkCircle);
    expect(AppIcons.late, Phosphor.clock);
    expect(AppIcons.skipped, Phosphor.xCircle);
    expect(AppIcons.missed, Phosphor.minusCircle);
    expect(AppIcons.today, Phosphor.calendarCheck);
  });
}
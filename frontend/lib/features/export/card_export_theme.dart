import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'card_export_pdf.dart';

/// What visual theme to use when rasterizing MTG-style cards for PDF export.
sealed class CardExportThemeSelection {
  const CardExportThemeSelection();
}

/// Use whatever theme is active where export runs (`Theme.of(context)`).
final class CardExportMatchApp extends CardExportThemeSelection {
  const CardExportMatchApp();

  @override
  bool operator ==(Object other) => other is CardExportMatchApp;

  @override
  int get hashCode => 96731;
}

/// Low-ink grayscale cards (not tied to an app theme family).
final class CardExportPrintFriendly extends CardExportThemeSelection {
  const CardExportPrintFriendly();

  @override
  bool operator ==(Object other) => other is CardExportPrintFriendly;

  @override
  int get hashCode => 96733;
}

/// Use a fixed [AppThemeId] (resolved via [AppThemes.forId]).
final class CardExportAppTheme extends CardExportThemeSelection {
  const CardExportAppTheme(this.id);

  final AppThemeId id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CardExportAppTheme && id == other.id;

  @override
  int get hashCode => Object.hash(CardExportAppTheme, id);
}

/// Resolves [ThemeData] for card rasterization (export preview and PDF).
ThemeData themeForCardExport(
  BuildContext context,
  CardExportThemeSelection selection,
) {
  return switch (selection) {
    CardExportMatchApp() => Theme.of(context),
    CardExportPrintFriendly() => printFriendlyCardExportTheme(),
    CardExportAppTheme(:final id) => AppThemes.forId(id),
  };
}

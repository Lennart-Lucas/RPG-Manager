import 'package:flutter/material.dart';

enum AppThemeId {
  defaultTheme,
  warlock;

  String get storageValue => switch (this) {
        AppThemeId.defaultTheme => 'default',
        AppThemeId.warlock => 'warlock',
      };

  String get label => switch (this) {
        AppThemeId.defaultTheme => 'Default',
        AppThemeId.warlock => 'Warlock',
      };

  String get subtitle => switch (this) {
        AppThemeId.defaultTheme => 'Neutral light Material look',
        AppThemeId.warlock => 'Black and purple arcane dark',
      };

  static AppThemeId fromStorage(String? value) {
    return switch (value) {
      'warlock' => AppThemeId.warlock,
      _ => AppThemeId.defaultTheme,
    };
  }
}

abstract final class AppThemes {
  static ThemeData forId(AppThemeId id) => switch (id) {
        AppThemeId.defaultTheme => defaultTheme,
        AppThemeId.warlock => warlock,
      };

  static ThemeData get defaultTheme {
    const seed = Color(0xFF3D5A80); // slate
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      drawerTheme: const DrawerThemeData(width: 300),
    );
  }

  static ThemeData get warlock {
    const scaffold = Color(0xFF0B0612);
    const surface = Color(0xFF140A1C);
    const primary = Color(0xFF9B5DE5);
    const secondary = Color(0xFF6B2D9B);
    const tertiary = Color(0xFFC77DFF);
    const onSurface = Color(0xFFE8DFF5);
    const onSurfaceVariant = Color(0xFFB9A8D1);

    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: Color(0xFF1A0B2E),
      primaryContainer: Color(0xFF3B1F5E),
      onPrimaryContainer: tertiary,
      secondary: secondary,
      onSecondary: onSurface,
      secondaryContainer: Color(0xFF2A1540),
      onSecondaryContainer: tertiary,
      tertiary: tertiary,
      onTertiary: Color(0xFF1A0B2E),
      error: Color(0xFFFF8A80),
      onError: Color(0xFF3B0000),
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: Color(0xFF5A4570),
      outlineVariant: Color(0xFF3A2A4E),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: onSurface,
      onInverseSurface: scaffold,
      inversePrimary: secondary,
      surfaceTint: primary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      drawerTheme: const DrawerThemeData(
        width: 300,
        backgroundColor: surface,
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: primary,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.55),
        iconColor: onSurfaceVariant,
        textColor: onSurface,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: tertiary,
        collapsedIconColor: onSurfaceVariant,
        textColor: onSurface,
        collapsedTextColor: onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: scheme.onPrimary,
          backgroundColor: primary,
        ),
      ),
    );
  }
}

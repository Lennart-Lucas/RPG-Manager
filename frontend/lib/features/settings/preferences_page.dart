import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';

/// Preferences content shown inside [AppShell] (no own AppBar/drawer).
class PreferencesBody extends StatelessWidget {
  const PreferencesBody({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Theme',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...AppThemeId.values.map((id) {
              final selected = themeController.themeId == id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected
                      ? scheme.primaryContainer.withValues(alpha: 0.55)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: selected ? scheme.primary : scheme.outlineVariant,
                      ),
                    ),
                    leading: Icon(
                      id == AppThemeId.warlock
                          ? Icons.nightlight_round
                          : Icons.wb_sunny_outlined,
                      color: selected ? scheme.primary : null,
                    ),
                    title: Text(id.label),
                    subtitle: Text(id.subtitle),
                    trailing: selected
                        ? Icon(Icons.check_circle, color: scheme.primary)
                        : const Icon(Icons.circle_outlined),
                    onTap: () => themeController.setTheme(id),
                  ),
                ),
              );
            }),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('API base URL'),
              subtitle: Text(AppConfig.apiBaseUrl),
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('App'),
              subtitle: Text('RPG Manager'),
            ),
          ],
        );
      },
    );
  }
}

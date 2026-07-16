import 'package:flutter/material.dart';

import '../auth/state/auth_controller.dart';
import 'app_page.dart';

class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    required this.auth,
    required this.currentPage,
    required this.onOpenPreferences,
  });

  final AuthController auth;
  final AppPage currentPage;
  final VoidCallback onOpenPreferences;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  static const _expansionStyle = AnimationStyle(
    duration: Duration(milliseconds: 280),
    curve: Curves.easeInOutCubic,
    reverseCurve: Curves.easeInOutCubic,
  );

  final _settingsController = ExpansibleController();

  void _close(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _openPreferences(BuildContext context) {
    widget.onOpenPreferences();
    _close(context);
  }

  String _initials(String? email) {
    final value = (email ?? '').trim();
    if (value.isEmpty) {
      return '?';
    }
    final local = value.split('@').first;
    final parts = local.split(RegExp(r'[._\-+]')).where((p) => p.isNotEmpty);
    if (parts.length >= 2) {
      return ('${parts.elementAt(0)[0]}${parts.elementAt(1)[0]}').toUpperCase();
    }
    return local.substring(0, local.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    final isDm = user?.isDm == true;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preferencesSelected = widget.currentPage == AppPage.preferences;

    return Drawer(
      width: 300,
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: scheme.primary.withValues(alpha: 0.15),
                    foregroundColor: scheme.primary,
                    child: Text(
                      _initials(user?.email),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RPG Manager',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDm ? 'Dungeon Master' : 'Player',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: ListTileTheme(
                selectedColor: scheme.primary,
                selectedTileColor: scheme.primaryContainer.withValues(
                  alpha: 0.45,
                ),
                iconColor: scheme.onSurfaceVariant,
                textColor: scheme.onSurface,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    ExpansionTile(
                      controller: _settingsController,
                      leading: Icon(
                        Icons.settings_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: const Text('Settings'),
                      initiallyExpanded: preferencesSelected,
                      expansionAnimationStyle: _expansionStyle,
                      childrenPadding: const EdgeInsets.only(left: 8),
                      children: [
                        ListTile(
                          leading: const Icon(Icons.tune_outlined),
                          title: const Text('Preferences'),
                          selected: preferencesSelected,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () => _openPreferences(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: AnimatedBuilder(
                animation: widget.auth,
                builder: (context, _) {
                  return FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      foregroundColor: scheme.onSecondaryContainer,
                      backgroundColor: scheme.secondaryContainer,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: widget.auth.busy
                        ? null
                        : () async {
                            _close(context);
                            await widget.auth.logout();
                          },
                    icon: widget.auth.busy
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          )
                        : const Icon(Icons.logout),
                    label: const Text('Log out'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

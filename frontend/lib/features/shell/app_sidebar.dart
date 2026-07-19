import 'package:flutter/material.dart';

import '../auth/state/auth_controller.dart';
import '../dm_tools/resources/resources_icons.dart';
import '../mechanics/mechanics_icons.dart';
import '../player_options/player_options_icons.dart';
import '../world/world_icons.dart';
import 'app_page.dart';

class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    required this.auth,
    required this.currentPage,
    required this.onOpenPage,
  });

  final AuthController auth;
  final AppPage currentPage;
  final ValueChanged<AppPage> onOpenPage;

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
  final _dmToolsController = ExpansibleController();
  final _playerOptionsController = ExpansibleController();
  final _mechanicsController = ExpansibleController();
  final _worldController = ExpansibleController();

  void _close(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _openPage(BuildContext context, AppPage page) {
    widget.onOpenPage(page);
    _close(context);
  }

  void _collapseOthers(ExpansibleController keep) {
    for (final controller in [
      _settingsController,
      _dmToolsController,
      _playerOptionsController,
      _mechanicsController,
      _worldController,
    ]) {
      if (!identical(controller, keep) && controller.isExpanded) {
        controller.collapse();
      }
    }
  }

  void _onSettingsExpansionChanged(bool expanded) {
    if (expanded) {
      _collapseOthers(_settingsController);
    }
  }

  void _onDmToolsExpansionChanged(bool expanded) {
    if (expanded) {
      _collapseOthers(_dmToolsController);
    }
  }

  void _onPlayerOptionsExpansionChanged(bool expanded) {
    if (expanded) {
      _collapseOthers(_playerOptionsController);
    }
  }

  void _onMechanicsExpansionChanged(bool expanded) {
    if (expanded) {
      _collapseOthers(_mechanicsController);
    }
  }

  void _onWorldExpansionChanged(bool expanded) {
    if (expanded) {
      _collapseOthers(_worldController);
    }
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
    final resourcesSelected = widget.currentPage == AppPage.resources;
    final playerOptionSelected = switch (widget.currentPage) {
      AppPage.classes ||
      AppPage.feats ||
      AppPage.items ||
      AppPage.languages ||
      AppPage.races ||
      AppPage.skills ||
      AppPage.spells =>
        true,
      _ => false,
    };
    final mechanicsSelected = switch (widget.currentPage) {
      AppPage.conditions ||
      AppPage.damageTypes ||
      AppPage.itemProperties ||
      AppPage.rules ||
      AppPage.spellTags ||
      AppPage.features =>
        true,
      _ => false,
    };
    final worldSelected = switch (widget.currentPage) {
      AppPage.creatures || AppPage.atlas || AppPage.characters => true,
      _ => false,
    };

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
                    _navTile(
                      context,
                      icon: Icons.home_outlined,
                      label: 'Home',
                      page: AppPage.home,
                    ),
                    ExpansionTile(
                      controller: _playerOptionsController,
                      leading: Icon(
                        playerOptionsMenuIcon,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: const Text('Player options'),
                      initiallyExpanded: playerOptionSelected,
                      onExpansionChanged: _onPlayerOptionsExpansionChanged,
                      expansionAnimationStyle: _expansionStyle,
                      childrenPadding: const EdgeInsets.only(left: 8),
                      children: [
                        _navTile(
                          context,
                          icon: classesPageIcon,
                          label: 'Classes',
                          page: AppPage.classes,
                        ),
                        _navTile(
                          context,
                          icon: featsPageIcon,
                          label: 'Feats',
                          page: AppPage.feats,
                        ),
                        _navTile(
                          context,
                          icon: itemsPageIcon,
                          label: 'Items',
                          page: AppPage.items,
                        ),
                        _navTile(
                          context,
                          icon: languagesPageIcon,
                          label: 'Languages',
                          page: AppPage.languages,
                        ),
                        _navTile(
                          context,
                          icon: racesPageIcon,
                          label: 'Races',
                          page: AppPage.races,
                        ),
                        _navTile(
                          context,
                          icon: skillsPageIcon,
                          label: 'Skills',
                          page: AppPage.skills,
                        ),
                        _navTile(
                          context,
                          icon: spellsPageIcon,
                          label: 'Spells',
                          page: AppPage.spells,
                        ),
                      ],
                    ),
                    ExpansionTile(
                      controller: _mechanicsController,
                      leading: Icon(
                        mechanicsMenuIcon,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: const Text('Mechanics'),
                      initiallyExpanded: mechanicsSelected,
                      onExpansionChanged: _onMechanicsExpansionChanged,
                      expansionAnimationStyle: _expansionStyle,
                      childrenPadding: const EdgeInsets.only(left: 8),
                      children: [
                        _navTile(
                          context,
                          icon: conditionsPageIcon,
                          label: 'Conditions',
                          page: AppPage.conditions,
                        ),
                        _navTile(
                          context,
                          icon: damageTypesPageIcon,
                          label: 'Damage Types',
                          page: AppPage.damageTypes,
                        ),
                        _navTile(
                          context,
                          icon: itemPropertiesPageIcon,
                          label: 'Item Properties',
                          page: AppPage.itemProperties,
                        ),
                        _navTile(
                          context,
                          icon: rulesPageIcon,
                          label: 'Rules',
                          page: AppPage.rules,
                        ),
                        _navTile(
                          context,
                          icon: spellTagsPageIcon,
                          label: 'Spell Tags',
                          page: AppPage.spellTags,
                        ),
                        _navTile(
                          context,
                          icon: featuresPageIcon,
                          label: 'Features',
                          page: AppPage.features,
                        ),
                      ],
                    ),
                    ExpansionTile(
                      controller: _worldController,
                      leading: Icon(
                        worldMenuIcon,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: const Text('World'),
                      initiallyExpanded: worldSelected,
                      onExpansionChanged: _onWorldExpansionChanged,
                      expansionAnimationStyle: _expansionStyle,
                      childrenPadding: const EdgeInsets.only(left: 8),
                      children: [
                        _navTile(
                          context,
                          icon: creaturesPageIcon,
                          label: 'Creatures',
                          page: AppPage.creatures,
                        ),
                        _navTile(
                          context,
                          icon: atlasPageIcon,
                          label: 'Atlas',
                          page: AppPage.atlas,
                        ),
                        _navTile(
                          context,
                          icon: charactersPageIcon,
                          label: 'Characters',
                          page: AppPage.characters,
                        ),
                      ],
                    ),
                    if (isDm)
                      ExpansionTile(
                        controller: _dmToolsController,
                        leading: Icon(
                          Icons.auto_stories_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                        title: const Text('DM Tools'),
                        initiallyExpanded: resourcesSelected,
                        onExpansionChanged: _onDmToolsExpansionChanged,
                        expansionAnimationStyle: _expansionStyle,
                        childrenPadding: const EdgeInsets.only(left: 8),
                        children: [
                          _navTile(
                            context,
                            icon: resourcesMenuIcon,
                            label: 'Resources',
                            page: AppPage.resources,
                          ),
                        ],
                      ),
                    ExpansionTile(
                      controller: _settingsController,
                      leading: Icon(
                        Icons.settings_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: const Text('Settings'),
                      initiallyExpanded: preferencesSelected,
                      onExpansionChanged: _onSettingsExpansionChanged,
                      expansionAnimationStyle: _expansionStyle,
                      childrenPadding: const EdgeInsets.only(left: 8),
                      children: [
                        _navTile(
                          context,
                          icon: Icons.tune_outlined,
                          label: 'Preferences',
                          page: AppPage.preferences,
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

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required AppPage page,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: widget.currentPage == page,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: () => _openPage(context, page),
    );
  }
}

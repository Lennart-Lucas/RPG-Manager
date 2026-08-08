import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_marker.dart';
import '../../core/offline/offline_sync_controller.dart';
import '../../core/routing/app_paths.dart';
import '../../core/theme/theme_controller.dart';
import '../auth/state/auth_controller.dart';
import 'app_page.dart';
import 'app_sidebar.dart';
import 'shell_page_app_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.auth,
    required this.themeController,
    required this.currentPage,
    required this.child,
  });

  final AuthController auth;
  final ThemeController themeController;
  final AppPage currentPage;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String get _pageKey => widget.currentPage.name;

  String get _title => switch (widget.currentPage) {
        AppPage.home => 'RPG Manager',
        AppPage.preferences => 'Preferences',
        AppPage.generator => 'Generator',
        AppPage.resources => 'Resources',
        AppPage.mapMaker => 'Map maker',
        AppPage.playlists => 'Playlists',
        AppPage.classes => 'Classes',
        AppPage.feats => 'Feats',
        AppPage.items => 'Items',
        AppPage.languages => 'Languages',
        AppPage.races => 'Races',
        AppPage.transformations => 'Transformations',
        AppPage.skills => 'Skills',
        AppPage.spells => 'Spells',
        AppPage.conditions => 'Conditions',
        AppPage.damageTypes => 'Damage Types',
        AppPage.itemProperties => 'Item Properties',
        AppPage.rules => 'Rules',
        AppPage.spellTags => 'Spell Tags',
        AppPage.features => 'Features',
        AppPage.creatures => 'Creatures',
        AppPage.atlas => 'Atlas',
        AppPage.characters => 'Characters',
        AppPage.organisations => 'Organisations',
        AppPage.events => 'Events',
        AppPage.story => 'Story',
      };

  @override
  void initState() {
    super.initState();
    ShellPageAppBarStore.instance.addListener(_onShellAppBarChanged);
    OfflineSyncController.instance.addListener(_onShellAppBarChanged);
    OfflineSyncController.instance.onSyncError = (message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    };
  }

  @override
  void dispose() {
    ShellPageAppBarStore.instance.removeListener(_onShellAppBarChanged);
    OfflineSyncController.instance.removeListener(_onShellAppBarChanged);
    super.dispose();
  }

  void _onShellAppBarChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final barStore = ShellPageAppBarStore.instance;
    barStore.activeShellPageKey = _pageKey;
    final pageBar = barStore.forPage(_pageKey);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          const OfflineAppBarMarker(),
          ...?pageBar?.actions,
        ],
      ),
      drawer: AppSidebar(
        auth: widget.auth,
        currentPage: widget.currentPage,
        onOpenPage: (page) => context.go(AppPaths.page(page)),
      ),
      body: widget.child,
    );
  }
}

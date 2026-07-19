import 'package:flutter/material.dart';

import '../../core/theme/theme_controller.dart';
import '../auth/state/auth_controller.dart';
import '../auth/ui/home_screen.dart';
import '../catalog/data/catalog_kind.dart';
import '../catalog/ui/catalog_body.dart';
import '../dm_tools/resources/resources_icons.dart';
import '../dm_tools/resources/ui/resources_body.dart';
import '../dm_tools/ui/dm_tool_placeholder_body.dart';
import '../mechanics/mechanics_icons.dart';
import '../mechanics/features/ui/features_body.dart';
import '../mechanics/spell_tags/ui/spell_tags_body.dart';
import '../player_options/classes/ui/classes_body.dart';
import '../player_options/items/ui/items_body.dart';
import '../player_options/player_options_icons.dart';
import '../player_options/spells/ui/spells_body.dart';
import '../settings/preferences_page.dart';
import '../settings/settings_icons.dart';
import '../world/creatures/ui/creatures_body.dart';
import '../world/world_icons.dart';
import 'app_page.dart';
import 'app_sidebar.dart';
import 'shell_page_app_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.auth,
    required this.themeController,
  });

  final AuthController auth;
  final ThemeController themeController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppPage _page = AppPage.home;

  String get _pageKey => _page.name;

  String get _title => switch (_page) {
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
      };

  @override
  void initState() {
    super.initState();
    ShellPageAppBarStore.instance.addListener(_onShellAppBarChanged);
  }

  @override
  void dispose() {
    ShellPageAppBarStore.instance.removeListener(_onShellAppBarChanged);
    super.dispose();
  }

  void _onShellAppBarChanged() {
    if (mounted) setState(() {});
  }

  void _openPage(AppPage page) {
    setState(() => _page = page);
  }

  Widget _catalog(CatalogKind kind, IconData icon) {
    return CatalogBody(
      auth: widget.auth,
      kind: kind,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final barStore = ShellPageAppBarStore.instance;
    barStore.activeShellPageKey = _pageKey;
    final pageBar = barStore.forPage(_pageKey);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: pageBar?.actions,
      ),
      drawer: AppSidebar(
        auth: widget.auth,
        currentPage: _page,
        onOpenPage: _openPage,
      ),
      body: switch (_page) {
        AppPage.home => HomeBody(auth: widget.auth),
        AppPage.preferences => PreferencesBody(
            auth: widget.auth,
            themeController: widget.themeController,
          ),
        AppPage.generator =>
          _catalog(CatalogKind.generators, generatorPageIcon),
        AppPage.resources => ResourcesBody(auth: widget.auth),
        AppPage.mapMaker => const DmToolPlaceholderBody(
            title: 'Map maker',
            icon: mapMakerPageIcon,
          ),
        AppPage.playlists => const DmToolPlaceholderBody(
            title: 'Playlists',
            icon: playlistsPageIcon,
          ),
        AppPage.classes => ClassesBody(auth: widget.auth),
        AppPage.feats => _catalog(CatalogKind.feats, featsPageIcon),
        AppPage.items => ItemsBody(auth: widget.auth),
        AppPage.languages =>
          _catalog(CatalogKind.languages, languagesPageIcon),
        AppPage.races => _catalog(CatalogKind.races, racesPageIcon),
        AppPage.skills => _catalog(CatalogKind.skills, skillsPageIcon),
        AppPage.spells => SpellsBody(auth: widget.auth),
        AppPage.conditions =>
          _catalog(CatalogKind.conditions, conditionsPageIcon),
        AppPage.damageTypes =>
          _catalog(CatalogKind.damageTypes, damageTypesPageIcon),
        AppPage.itemProperties =>
          _catalog(CatalogKind.itemProperties, itemPropertiesPageIcon),
        AppPage.rules => _catalog(CatalogKind.rules, rulesPageIcon),
        AppPage.spellTags => SpellTagsBody(auth: widget.auth),
        AppPage.features => FeaturesBody(auth: widget.auth),
        AppPage.creatures => CreaturesBody(auth: widget.auth),
        AppPage.atlas => _catalog(CatalogKind.locations, atlasPageIcon),
        AppPage.characters =>
          _catalog(CatalogKind.characters, charactersPageIcon),
        AppPage.organisations =>
          _catalog(CatalogKind.organisations, organisationsPageIcon),
      },
    );
  }
}

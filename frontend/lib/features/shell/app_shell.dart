import 'package:flutter/material.dart';

import '../../core/theme/theme_controller.dart';
import '../auth/state/auth_controller.dart';
import '../auth/ui/home_screen.dart';
import '../catalog/data/catalog_kind.dart';
import '../catalog/ui/catalog_body.dart';
import '../dm_tools/resources/ui/resources_body.dart';
import '../mechanics/mechanics_icons.dart';
import '../mechanics/spell_tags/ui/spell_tags_body.dart';
import '../player_options/classes/ui/classes_body.dart';
import '../player_options/player_options_icons.dart';
import '../player_options/spells/ui/spells_body.dart';
import '../settings/preferences_page.dart';
import 'app_page.dart';
import 'app_sidebar.dart';

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

  String get _title => switch (_page) {
        AppPage.home => 'RPG Manager',
        AppPage.preferences => 'Settings',
        AppPage.resources => 'Resources',
        AppPage.classes => 'Classes',
        AppPage.feats => 'Feats',
        AppPage.languages => 'Languages',
        AppPage.races => 'Races',
        AppPage.skills => 'Skills',
        AppPage.spells => 'Spells',
        AppPage.conditions => 'Conditions',
        AppPage.damageTypes => 'Damage Types',
        AppPage.itemProperties => 'Item Properties',
        AppPage.rules => 'Rules',
        AppPage.spellTags => 'Spell Tags',
      };

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
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      drawer: AppSidebar(
        auth: widget.auth,
        currentPage: _page,
        onOpenPage: _openPage,
      ),
      body: switch (_page) {
        AppPage.home => HomeBody(auth: widget.auth),
        AppPage.preferences => PreferencesBody(
            themeController: widget.themeController,
          ),
        AppPage.resources => ResourcesBody(auth: widget.auth),
        AppPage.classes => ClassesBody(auth: widget.auth),
        AppPage.feats => _catalog(CatalogKind.feats, featsPageIcon),
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
      },
    );
  }
}

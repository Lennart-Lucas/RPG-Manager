import 'package:flutter/material.dart';

import '../../core/theme/theme_controller.dart';
import '../auth/state/auth_controller.dart';
import '../auth/ui/home_screen.dart';
import '../dm_tools/resources/ui/resources_body.dart';
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
      };

  void _openPage(AppPage page) {
    setState(() => _page = page);
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
        onOpenPreferences: () => _openPage(AppPage.preferences),
        onOpenResources: () => _openPage(AppPage.resources),
      ),
      body: switch (_page) {
        AppPage.home => HomeBody(auth: widget.auth),
        AppPage.preferences => PreferencesBody(
            themeController: widget.themeController,
          ),
        AppPage.resources => ResourcesBody(auth: widget.auth),
      },
    );
  }
}

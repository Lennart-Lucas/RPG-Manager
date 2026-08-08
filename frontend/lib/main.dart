import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/offline/offline_marker.dart';
import 'core/offline/offline_sync_controller.dart';
import 'core/platform/client_platform.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/ui/app_scroll_behavior.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/auth/ui/register_screen.dart';
import 'features/settings/obsidian/data/obsidian_export_controller.dart';
import 'features/shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Widget app = const RpgManagerApp();
  // Flutter's Windows accessibility_bridge still fails on common semantics
  // reparenting (ExpansionTile, Tooltip, …) and spams AXTree errors.
  // See https://github.com/flutter/flutter/issues/182444
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    app = ExcludeSemantics(child: app);
  }
  runApp(app);
}

class RpgManagerApp extends StatefulWidget {
  const RpgManagerApp({super.key});

  @override
  State<RpgManagerApp> createState() => _RpgManagerAppState();
}

class _RpgManagerAppState extends State<RpgManagerApp> {
  late final AuthController _auth;
  late final ThemeController _theme;
  bool _showRegister = false;

  @override
  void initState() {
    super.initState();
    _auth = AuthController();
    _theme = ThemeController();
    final sync = OfflineSyncController.instance;
    sync.onSyncError = (message) {
      // SnackBars need a context; AppShell / overlay can listen later.
      debugPrint('Offline sync: $message');
    };
    sync.start(tokenProvider: _auth.requireAccessToken);
    _auth.addListener(_onAuthChangedForTheme);
    if (detectClientPlatform() == ClientPlatform.desktop) {
      ObsidianExportController.instance.start(
        tokenProvider: _auth.requireAccessToken,
      );
      _auth.addListener(_onAuthChangedForObsidian);
    }
    _auth.bootstrap();
    _theme.bootstrap();
  }

  void _onAuthChangedForTheme() {
    final campaignTheme = _auth.user?.campaignThemeId;
    if (campaignTheme == null) return;
    _theme.applyCampaignTheme(AppThemeId.fromStorage(campaignTheme));
  }

  void _onAuthChangedForObsidian() {
    if (_auth.status == AuthStatus.authenticated) {
      ObsidianExportController.instance.scheduleExport();
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChangedForTheme);
    _auth.removeListener(_onAuthChangedForObsidian);
    OfflineSyncController.instance.stop();
    ObsidianExportController.instance.stop();
    _auth.dispose();
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _auth,
        _theme,
        OfflineSyncController.instance,
      ]),
      builder: (context, _) {
        return MaterialApp(
          title: 'RPG Manager',
          theme: _theme.themeData,
          scrollBehavior: const AppScrollBehavior(),
          builder: (context, child) {
            return OfflineStatusOverlay(child: child);
          },
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    switch (_auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        return AppShell(auth: _auth, themeController: _theme);
      case AuthStatus.unauthenticated:
        if (_showRegister) {
          return RegisterScreen(
            auth: _auth,
            onGoToLogin: () => setState(() => _showRegister = false),
          );
        }
        return LoginScreen(
          auth: _auth,
          onGoToRegister: () => setState(() => _showRegister = true),
        );
    }
  }
}

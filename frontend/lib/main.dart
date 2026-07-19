import 'package:flutter/material.dart';

import 'core/theme/theme_controller.dart';
import 'core/ui/app_scroll_behavior.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/auth/ui/register_screen.dart';
import 'features/shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RpgManagerApp());
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
    _auth.bootstrap();
    _theme.bootstrap();
  }

  @override
  void dispose() {
    _auth.dispose();
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_auth, _theme]),
      builder: (context, _) {
        return MaterialApp(
          title: 'RPG Manager',
          theme: _theme.themeData,
          scrollBehavior: const AppScrollBehavior(),
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

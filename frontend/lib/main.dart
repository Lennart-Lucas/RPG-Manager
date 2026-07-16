import 'package:flutter/material.dart';

import 'features/auth/state/auth_controller.dart';
import 'features/auth/ui/home_screen.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/auth/ui/register_screen.dart';

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
  bool _showRegister = false;

  @override
  void initState() {
    super.initState();
    _auth = AuthController();
    _auth.bootstrap();
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RPG Manager',
      home: AnimatedBuilder(
        animation: _auth,
        builder: (context, _) {
          switch (_auth.status) {
            case AuthStatus.unknown:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            case AuthStatus.authenticated:
              return HomeScreen(auth: _auth);
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
        },
      ),
    );
  }
}

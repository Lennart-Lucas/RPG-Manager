import 'package:flutter/material.dart';

import '../state/auth_controller.dart';

/// Home content shown inside [AppShell] (no own AppBar/drawer).
class HomeBody extends StatelessWidget {
  const HomeBody({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user?.email ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              user?.isDm == true ? 'Dungeon Master' : 'Player',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}

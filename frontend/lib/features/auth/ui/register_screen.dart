import 'package:flutter/material.dart';

import '../../../core/platform/client_platform.dart';
import '../state/auth_controller.dart';
import 'backend_connection_panel.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.auth,
    required this.onGoToLogin,
  });

  final AuthController auth;
  final VoidCallback onGoToLogin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _platform = detectClientPlatform();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await widget.auth.register(
      _emailController.text,
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dmHint = _platform == ClientPlatform.desktop
        ? 'Desktop registration creates a DM account.'
        : 'This platform creates a player account (not DM).';

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AnimatedBuilder(
              animation: widget.auth,
              builder: (context, _) {
                return Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'RPG Manager',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create account',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dmHint,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (widget.auth.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.auth.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: widget.auth.busy ? null : _submit,
                        child: widget.auth.busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Register'),
                      ),
                      TextButton(
                        onPressed: widget.auth.busy ? null : widget.onGoToLogin,
                        child: const Text('Already have an account? Sign in'),
                      ),
                      const BackendConnectionPanel(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

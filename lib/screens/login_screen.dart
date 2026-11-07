import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../widgets/common.dart';

/// Registration, login, or continue anonymously.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _userName = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;

  @override
  void dispose() {
    _userName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthState>();
    try {
      if (_registering) {
        await auth.register(_userName.text.trim(), _password.text);
      } else {
        await auth.login(_userName.text.trim(), _password.text);
      }
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.public, size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text('Globly', textAlign: TextAlign.center, style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _userName,
                    decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.length < 3 || s.length > 32) return '3-32 characters';
                      if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(s)) return 'Letters, numbers, . _ - only';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    obscureText: true,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => (v?.length ?? 0) < 8 ? 'At least 8 characters' : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_registering ? 'Create account' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _registering = !_registering),
                    child: Text(_registering ? 'Already have an account? Sign in' : 'No account? Register'),
                  ),
                  const Divider(height: 32),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => context.read<AuthState>().continueAsGuest(),
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('Browse without an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

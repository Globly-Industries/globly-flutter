import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/language_menu.dart';

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
  final _turnstile = TurnstileController();
  bool _registering = false;
  bool _busy = false;
  bool _obscure = true;

  /// Turnstile site key from the API; null = human check disabled on the server.
  String? _captchaSiteKey;
  String? _captchaToken;

  @override
  void initState() {
    super.initState();
    context.read<ApiClient>().captchaSiteKey().then((key) {
      if (mounted) setState(() => _captchaSiteKey = key);
    }).catchError((_) {/* offline: the register call will report it */});
  }

  @override
  void dispose() {
    _userName.dispose();
    _password.dispose();
    _turnstile.dispose();
    super.dispose();
  }

  bool get _needsCaptcha => _registering && _captchaSiteKey != null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_needsCaptcha && _captchaToken == null) {
      showMessage(context, context.l10n.humanCheckRequired);
      return;
    }
    setState(() => _busy = true);
    final auth = context.read<AuthState>();
    try {
      if (_registering) {
        await auth.register(_userName.text.trim(), _password.text, captchaToken: _captchaToken);
      } else {
        await auth.login(_userName.text.trim(), _password.text);
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, e);
      // Turnstile tokens are single-use: get a fresh one for the next attempt.
      if (_needsCaptcha) {
        setState(() => _captchaToken = null);
        _turnstile.refreshToken();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Fixed brand colours so the white text stays readable in light and dark mode.
            colors: AppTheme.brandGradient,
          ),
        ),
        child: SafeArea(
          child: Stack(children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Image.asset('assets/logo.png', width: 56, height: 56, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(l.appTitle,
                        style: theme.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(l.tagline, textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                    const SizedBox(height: 28),
                    GlassPanel(
                      strong: true,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _form,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            SegmentedButton<bool>(
                              segments: [
                                ButtonSegment(value: false, label: Text(l.signIn)),
                                ButtonSegment(value: true, label: Text(l.register)),
                              ],
                              selected: {_registering},
                              showSelectedIcon: false,
                              onSelectionChanged: _busy ? null : (s) => setState(() => _registering = s.first),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _userName,
                              decoration: InputDecoration(
                                labelText: l.username,
                                prefixIcon: const Icon(Icons.person_outline_rounded),
                              ),
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.username],
                              validator: (v) {
                                final s = v?.trim() ?? '';
                                if (s.length < 3 || s.length > 32) return l.usernameLength;
                                if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(s)) return l.usernameChars;
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              decoration: InputDecoration(
                                labelText: l.password,
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              obscureText: _obscure,
                              autofillHints: [_registering ? AutofillHints.newPassword : AutofillHints.password],
                              onFieldSubmitted: (_) => _submit(),
                              validator: (v) => (v?.length ?? 0) < 8 ? l.passwordLength : null,
                            ),
                            if (_needsCaptcha) ...[
                              const SizedBox(height: 16),
                              Center(
                                child: CloudflareTurnstile(
                                  siteKey: _captchaSiteKey!,
                                  baseUrl: AppConfig.turnstileBaseUrl,
                                  controller: _turnstile,
                                  options: TurnstileOptions(
                                    language: Localizations.localeOf(context).languageCode,
                                    theme: theme.brightness == Brightness.dark ? TurnstileTheme.dark : TurnstileTheme.light,
                                  ),
                                  onTokenReceived: (token) => setState(() => _captchaToken = token),
                                  onTokenExpired: () => setState(() => _captchaToken = null),
                                  onError: (_) => setState(() => _captchaToken = null),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                                  : Text(_registering ? l.createAccount : l.signIn),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(l.or, style: TextStyle(color: scheme.onSurfaceVariant)),
                                ),
                                const Expanded(child: Divider()),
                              ]),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => context.read<AuthState>().continueAsGuest(),
                              icon: const Icon(Icons.travel_explore_rounded),
                              label: Text(l.browseAsGuest),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const Positioned(
              top: 4,
              right: 4,
              child: IconTheme(data: IconThemeData(color: Colors.white), child: LanguageButton()),
            ),
          ]),
        ),
      ),
    );
  }
}

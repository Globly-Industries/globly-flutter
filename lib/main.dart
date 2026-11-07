import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/auth_state.dart';
import 'state/filter_state.dart';
import 'state/settings_state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  final auth = AuthState(api)..restore();
  final settings = SettingsState()..load();

  runApp(MultiProvider(
    providers: [
      Provider.value(value: api),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider(create: (_) => FilterState()),
    ],
    child: const GloblyApp(),
  ));
}

class GloblyApp extends StatelessWidget {
  const GloblyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: context.watch<SettingsState>().locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _AuthGate(),
    );
  }
}

/// Shows the login screen until the user signs in or chooses to browse as a guest.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return switch (context.watch<AuthState>().status) {
      AuthStatus.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.guest || AuthStatus.signedIn => const HomeShell(),
    };
  }
}

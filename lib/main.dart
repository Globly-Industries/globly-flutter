import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/auth_state.dart';
import 'state/filter_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  final auth = AuthState(api)..restore();

  runApp(MultiProvider(
    providers: [
      Provider.value(value: api),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => FilterState()),
    ],
    child: const GloblyApp(),
  ));
}

class GloblyApp extends StatelessWidget {
  const GloblyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF1E88E5);
    return MaterialApp(
      title: 'Globly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
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

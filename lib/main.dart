import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show MapboxOptions;
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'config.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/auth_state.dart';
import 'state/filter_state.dart';
import 'state/notifications_state.dart';
import 'state/push_service.dart';
import 'state/settings_state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(AppConfig.mapboxToken);
  final api = ApiClient();
  final auth = AuthState(api)..restore();
  final settings = SettingsState()..load();
  final notifications = NotificationsState(api, auth);
  final navigatorKey = GlobalKey<NavigatorState>();

  runApp(MultiProvider(
    providers: [
      Provider.value(value: api),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider(create: (_) => FilterState()),
      ChangeNotifierProvider.value(value: notifications),
    ],
    child: GloblyApp(navigatorKey: navigatorKey),
  ));
  PushService(api, auth, settings, notifications, navigatorKey).start();
}

class GloblyApp extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  const GloblyApp({super.key, this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  AuthStatus? _previous;

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthState>().status;

    // On becoming signed out (sign out, "sign in" as a guest, expired session), close any pages
    // open on top of this one, or they would keep covering the login screen.
    if (status == AuthStatus.signedOut && _previous != AuthStatus.signedOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    _previous = status;

    return switch (status) {
      AuthStatus.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.guest || AuthStatus.signedIn => const HomeShell(),
    };
  }
}

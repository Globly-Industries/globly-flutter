import 'dart:async';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../screens/post_detail_screen.dart';
import 'auth_state.dart';
import 'notifications_state.dart';
import 'settings_state.dart';

/// Push notifications (Android only, via Firebase Cloud Messaging). The API sends a push for each
/// in-app notification to every device the user is signed in on, addressed by its installation ID (FID).
class PushService {
  final ApiClient _api;
  final AuthState _auth;
  final SettingsState _settings;
  final NotificationsState _notifications;
  final GlobalKey<NavigatorState> _navigator;

  /// "user|fid|language" last sent to the API, so it is only re-sent when something changes.
  String? _registered;
  bool _wasSignedIn = false;
  String? _reportedError;
  bool _ready = false;
  String? _initError;
  Future<void> _queue = Future.value();

  static const _stepTimeout = Duration(seconds: 30);

  PushService(this._api, this._auth, this._settings, this._notifications, this._navigator);

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> start() async {
    if (!supported) return;
    _auth.addListener(_sync);
    _settings.addListener(_sync);
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Reported once signed in, by _syncNow.
      _initError = 'initializeApp: $e';
      await _sync();
      return;
    }
    _ready = true;
    final messaging = FirebaseMessaging.instance;
    // In the foreground Android shows nothing; just update the badge.
    FirebaseMessaging.onMessage.listen((_) => _notifications.refresh());
    FirebaseMessaging.onMessageOpenedApp.listen(_open);
    // A (re)registration, e.g. after sign-in or a reinstall: tell the API again.
    messaging.onRegistered.listen((_) => _sync(force: true));

    // A push tapped while the app was closed.
    final initial = await messaging.getInitialMessage();
    if (initial != null) _open(initial);
    await _sync();
  }

  /// One at a time: auth and settings can notify in quick bursts.
  Future<void> _sync({bool force = false}) => _queue = _queue.then((_) => _syncNow(force));

  Future<void> _syncNow(bool force) async {
    if (!_ready) {
      if (_initError != null && _auth.isSignedIn) await _report(_initError!);
      return;
    }
    final messaging = FirebaseMessaging.instance;
    if (!_auth.isSignedIn) {
      if (_wasSignedIn) {
        _wasSignedIn = false;
        _registered = null;
        // Pushes for the old account stop reaching this device.
        await messaging.unregister().catchError((_) {});
      }
      return;
    }
    _wasSignedIn = true;
    var step = 'requestPermission';
    try {
      final settings = await messaging.requestPermission().timeout(_stepTimeout);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      step = 'register';
      await messaging.register().timeout(_stepTimeout);
      step = 'getId';
      final fid = await FirebaseInstallations.instance.getId().timeout(_stepTimeout);
      if (!_auth.isSignedIn) return;
      final language = (_settings.locale ?? PlatformDispatcher.instance.locale).languageCode;
      final key = '${_auth.user?.id}|$fid|$language';
      if (key == _registered && !force) return;
      step = 'registerDevice';
      await _api.registerDevice(fid, language);
      _registered = key;
    } catch (e) {
      await _report('$step: $e');
    }
  }

  /// Sends a setup failure to the API's log, once per distinct error.
  Future<void> _report(String error) async {
    debugPrint('Push setup failed: $error');
    if (error == _reportedError) return;
    _reportedError = error;
    try {
      await _api.reportPushError(error.length > 2000 ? error.substring(0, 2000) : error);
    } catch (_) {/* offline: nothing more to do */}
  }

  /// Tapped push: open its post, after the current frame so the navigator exists.
  void _open(RemoteMessage message) {
    final postId = message.data['postId'] as String?;
    final notificationId = message.data['notificationId'] as String?;
    if (postId == null) return;
    if (notificationId != null) {
      _api.markNotificationRead(notificationId).then((_) => _notifications.refresh(), onError: (_) {});
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigator.currentState?.push(MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)));
    });
  }
}

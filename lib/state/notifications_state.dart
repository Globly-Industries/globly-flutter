import 'dart:async';

import 'package:flutter/widgets.dart';

import '../api/api_client.dart';
import 'auth_state.dart';

/// Unread notification count for the bell badge. Polls while signed in and the app is in the foreground.
class NotificationsState extends ChangeNotifier with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 60);

  final ApiClient _api;
  final AuthState _auth;
  Timer? _timer;
  int _unread = 0;
  bool _resumed = true;

  NotificationsState(this._api, this._auth) {
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_update);
    _update();
  }

  int get unread => _unread;

  void _update() {
    _timer?.cancel();
    _timer = null;
    if (!_auth.isSignedIn) {
      _setUnread(0);
      return;
    }
    if (!_resumed) return;
    refresh();
    _timer = Timer.periodic(_pollInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    if (!_auth.isSignedIn) return;
    try {
      _setUnread(await _api.unreadNotificationCount());
    } catch (_) {/* offline: keep the last count */}
  }

  /// Local update after reading notifications, so the badge doesn't wait for the next poll.
  void markRead({bool all = false}) => _setUnread(all ? 0 : (_unread - 1).clamp(0, _unread));

  void _setUnread(int value) {
    if (value == _unread) return;
    _unread = value;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _resumed) return;
    _resumed = resumed;
    _update();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _auth.removeListener(_update);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

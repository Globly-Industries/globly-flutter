import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../models/models.dart';

enum AuthStatus { loading, signedOut, guest, signedIn }

/// Session state: anonymous guest (view only) or registered user (view, post, rate).
class AuthState extends ChangeNotifier {
  static const _tokenKey = 'token';
  static const _userKey = 'user';
  static const _guestKey = 'guest';

  final ApiClient api;
  final FlutterSecureStorage _storage;

  AuthStatus _status = AuthStatus.loading;
  User? _user;

  AuthState(this.api, {FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage() {
    api.onUnauthorized = signOut;
  }

  AuthStatus get status => _status;
  User? get user => _user;
  bool get isSignedIn => _status == AuthStatus.signedIn;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> restore() async {
    String? token, userJson, guest;
    try {
      token = await _storage.read(key: _tokenKey);
      userJson = await _storage.read(key: _userKey);
      guest = await _storage.read(key: _guestKey);
      if (token != null && userJson != null) _user = User.fromJson(jsonDecode(userJson));
    } catch (_) {
      // Unreadable (e.g. restored from a backup without its Keystore key): start fresh, or we'd hang on loading.
      token = null;
      guest = null;
      _user = null;
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
    if (token != null && _user != null) {
      api.token = token;
      _status = AuthStatus.signedIn;
      notifyListeners();
      // Refresh roles/validity in the background; a 401 triggers signOut via onUnauthorized.
      try {
        _user = await api.me();
        await _storage.write(key: _userKey, value: jsonEncode(_user!.toJson()));
        notifyListeners();
      } catch (_) {/* offline: keep cached user */}
      return;
    }
    _status = guest == '1' ? AuthStatus.guest : AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> login(String userName, String password) async =>
      _applySession(await api.login(userName, password));

  Future<void> register(String userName, String password, {String? captchaToken}) async =>
      _applySession(await api.register(userName, password, captchaToken: captchaToken));

  Future<void> continueAsGuest() async {
    await _storage.write(key: _guestKey, value: '1');
    _status = AuthStatus.guest;
    notifyListeners();
  }

  /// Shows the login screen again (from guest mode).
  Future<void> requestSignIn() async {
    await _storage.delete(key: _guestKey);
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> signOut() async {
    api.token = null;
    _user = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> _applySession((String, User) session) async {
    final (token, user) = session;
    api.token = token;
    _user = user;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    await _storage.delete(key: _guestKey);
    _status = AuthStatus.signedIn;
    notifyListeners();
  }
}

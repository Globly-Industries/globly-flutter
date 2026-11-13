import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/models.dart';

enum ApiErrorKind { connection, timeout, server }

/// Failed API call. The UI turns this into a translated message (see widgets/errors.dart):
/// [code] is the API's machine-readable error code, [detail] its English fallback text.
class ApiException implements Exception {
  final ApiErrorKind kind;
  final int? statusCode;
  final String? code;
  final String? detail;

  ApiException(this.kind, {this.statusCode, this.code, this.detail});

  @override
  String toString() => detail ?? code ?? 'API error ${statusCode ?? kind.name}';
}

/// Thin typed wrapper over the Globly REST API.
class ApiClient {
  final Dio _dio;
  String? _token;

  /// Called when the server rejects our token (expired / user deleted).
  void Function()? onUnauthorized;

  ApiClient({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          listFormat: ListFormat.multi,
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) options.headers['Authorization'] = 'Bearer $_token';
        handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401 && _token != null) onUnauthorized?.call();
        handler.next(e);
      },
    ));
  }

  set token(String? value) => _token = value;

  // ---------- Auth ----------

  /// Turnstile site key for the registration human check, or null when the check is disabled.
  Future<String?> captchaSiteKey() async =>
      (await _call(() => _dio.get('/api/auth/config')))['captchaSiteKey'] as String?;

  Future<(String token, User user)> login(String userName, String password) =>
      _authRequest('/api/auth/login', {'userName': userName, 'password': password});

  Future<(String token, User user)> register(String userName, String password, {String? captchaToken}) =>
      _authRequest('/api/auth/register', {'userName': userName, 'password': password, 'captchaToken': captchaToken});

  Future<(String, User)> _authRequest(String path, Map<String, dynamic> body) async {
    final data = await _call(() => _dio.post(path, data: body));
    return (data['token'] as String, User.fromJson(data['user']));
  }

  Future<User> me() async => User.fromJson(await _call(() => _dio.get('/api/auth/me')));

  // ---------- Posts ----------

  Future<List<MapPoint>> mapPoints({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required double zoom,
    PostFilter filter = const PostFilter(),
    CancelToken? cancelToken,
  }) async {
    final data = await _call(() => _dio.get('/api/posts/map',
        queryParameters: {
          'minLat': minLat.clamp(-90, 90),
          'minLng': minLng.clamp(-180, 180),
          'maxLat': maxLat.clamp(-90, 90),
          'maxLng': maxLng.clamp(-180, 180),
          'zoom': zoom.clamp(0, 22),
          ...filter.toQuery(),
        },
        cancelToken: cancelToken));
    return (data as List).map((e) => MapPoint.fromJson(e)).toList();
  }

  Future<Paged<Post>> feed({int page = 1, PostFilter filter = const PostFilter()}) async {
    final data = await _call(() => _dio.get('/api/posts/feed', queryParameters: {'page': page, ...filter.toQuery()}));
    return Paged.fromJson(data, Post.fromJson);
  }

  Future<List<Post>> nearby(double lat, double lng, {double radiusKm = 25, PostFilter filter = const PostFilter()}) async {
    final data = await _call(() => _dio.get('/api/posts/nearby',
        queryParameters: {'lat': lat, 'lng': lng, 'radiusKm': radiusKm, ...filter.toQuery()}));
    return (data as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<Paged<Post>> myPosts({int page = 1}) async =>
      Paged.fromJson(await _call(() => _dio.get('/api/posts/mine', queryParameters: {'page': page})), Post.fromJson);

  Future<Post> post(String id) async => Post.fromJson(await _call(() => _dio.get('/api/posts/$id')));

  // ---------- Capture tickets ----------

  /// Asked for right before the camera or recorder opens; returns the ticket id.
  Future<String> startCapture(MediaType type) async =>
      (await _call(() => _dio.post('/api/captures', data: {'mediaType': type.apiName})))['id'] as String;

  /// Binds the finished capture to its ticket. Safe to repeat with the same hash.
  Future<void> sealCapture(String captureId, String sha256) =>
      _call(() => _dio.post('/api/captures/$captureId/seal', data: {'sha256': sha256}));

  Future<Post> createPost({
    required String title,
    String? description,
    required MediaType mediaType,
    required double latitude,
    required double longitude,
    int? locationRadiusMeters,
    XFile? file,
    String? captureId,
    String? attestation,
    String? attestationError,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'mediaType': mediaType.apiName,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      if (locationRadiusMeters != null) 'locationRadiusMeters': locationRadiusMeters.toString(),
      'captureId': ?captureId,
      'attestation': ?attestation,
      'attestationError': ?attestationError,
      if (file != null)
        // Web has no file system: upload from memory there, stream from disk on Android.
        'file': kIsWeb
            ? MultipartFile.fromBytes(await file.readAsBytes(), filename: file.name)
            : await MultipartFile.fromFile(file.path, filename: file.name),
    });
    final data = await _call(() => _dio.post('/api/posts',
        data: form,
        onSendProgress: onProgress,
        options: Options(sendTimeout: const Duration(minutes: 10), receiveTimeout: const Duration(minutes: 2))));
    return Post.fromJson(data);
  }

  Future<Post> updatePost(String id, {required String title, String? description}) async => Post.fromJson(
      await _call(() => _dio.put('/api/posts/$id', data: {'title': title, 'description': description})));

  Future<void> deletePost(String id) => _call(() => _dio.delete('/api/posts/$id'));

  // ---------- Ratings ----------

  /// value: 1 up, -1 down, 0 remove. Returns new totals and whether the post got hidden.
  Future<({int upvotes, int downvotes, bool hidden})> vote(String postId, int value) async {
    final data = await _call(() => _dio.put('/api/posts/$postId/vote', data: {'value': value}));
    return (upvotes: data['upvotes'] as int, downvotes: data['downvotes'] as int, hidden: data['isHidden'] as bool);
  }

  Future<Paged<Comment>> comments(String postId, {int page = 1}) async => Paged.fromJson(
      await _call(() => _dio.get('/api/posts/$postId/comments', queryParameters: {'page': page})), Comment.fromJson);

  Future<Comment> addComment(String postId, String body) async =>
      Comment.fromJson(await _call(() => _dio.post('/api/posts/$postId/comments', data: {'body': body})));

  Future<void> deleteComment(String id) => _call(() => _dio.delete('/api/comments/$id'));

  /// Returns true when this report made the post hidden.
  Future<bool> report(String postId, String? reason) async =>
      (await _call(() => _dio.post('/api/posts/$postId/report', data: {'reason': reason})))['isHidden'] as bool;

  // ---------- Notifications ----------

  Future<Paged<AppNotification>> notifications({int page = 1}) async => Paged.fromJson(
      await _call(() => _dio.get('/api/notifications', queryParameters: {'page': page})), AppNotification.fromJson);

  Future<int> unreadNotificationCount() async =>
      (await _call(() => _dio.get('/api/notifications/unread-count')))['count'] as int;

  Future<void> markNotificationRead(String id) => _call(() => _dio.post('/api/notifications/$id/read'));

  /// Registers this device (its Firebase installation ID) for the signed-in user's pushes, in [language].
  Future<void> registerDevice(String fid, String language) =>
      _call(() => _dio.put('/api/devices', data: {'fid': fid, 'language': language}));

  Future<void> markAllNotificationsRead() => _call(() => _dio.post('/api/notifications/read-all'));

  // ---------- Admin ----------

  Future<Paged<Post>> adminPosts({bool hiddenOnly = true, int page = 1}) async => Paged.fromJson(
      await _call(() => _dio.get('/api/admin/posts', queryParameters: {'hiddenOnly': hiddenOnly, 'page': page})),
      Post.fromJson);

  Future<void> adminRestore(String postId) => _call(() => _dio.post('/api/admin/posts/$postId/restore'));

  Future<void> adminHide(String postId) => _call(() => _dio.post('/api/admin/posts/$postId/hide'));

  Future<void> adminDeletePost(String postId) => _call(() => _dio.delete('/api/admin/posts/$postId'));

  Future<Paged<AdminUser>> adminUsers({String? search, int page = 1}) async => Paged.fromJson(
      await _call(() => _dio.get('/api/admin/users', queryParameters: {'search': ?search, 'page': page})),
      AdminUser.fromJson);

  Future<void> adminDeleteUser(String userId) => _call(() => _dio.delete('/api/admin/users/$userId'));

  // ---------- Plumbing ----------

  Future<dynamic> _call(Future<Response> Function() request) async {
    try {
      return (await request()).data;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw _toApiException(e);
    }
  }

  static ApiException _toApiException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return ApiException(ApiErrorKind.connection);
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(ApiErrorKind.timeout);
      default:
        final data = e.response?.data;
        final map = data is Map ? data : const {};
        return ApiException(
          ApiErrorKind.server,
          statusCode: e.response?.statusCode,
          code: map['code'] as String?,
          detail: (map['detail'] ?? map['title']) as String?,
        );
    }
  }
}

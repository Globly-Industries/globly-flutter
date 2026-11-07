import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/models.dart';

/// Error with a user-readable message extracted from the API's ProblemDetails.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
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

  Future<(String token, User user)> login(String userName, String password) =>
      _authRequest('/api/auth/login', userName, password);

  Future<(String token, User user)> register(String userName, String password) =>
      _authRequest('/api/auth/register', userName, password);

  Future<(String, User)> _authRequest(String path, String userName, String password) async {
    final data = await _call(() => _dio.post(path, data: {'userName': userName, 'password': password}));
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

  Future<Post> createPost({
    required String title,
    String? description,
    required MediaType mediaType,
    required double latitude,
    required double longitude,
    XFile? file,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'mediaType': mediaType.apiName,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
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

  /// value: 1 up, -1 down, 0 remove. Returns (upvotes, downvotes).
  Future<(int, int)> vote(String postId, int value) async {
    final data = await _call(() => _dio.put('/api/posts/$postId/vote', data: {'value': value}));
    return (data['upvotes'] as int, data['downvotes'] as int);
  }

  /// kind: 'All', 'Text' or 'Emoji'.
  Future<Paged<Comment>> comments(String postId, {int page = 1, String kind = 'All'}) async => Paged.fromJson(
      await _call(() => _dio.get('/api/posts/$postId/comments', queryParameters: {'page': page, 'kind': kind})),
      Comment.fromJson);

  Future<Map<String, int>> emojiSummary(String postId) async {
    final data = await _call(() => _dio.get('/api/posts/$postId/emoji')) as List;
    return {for (final e in data) e['emoji'] as String: e['count'] as int};
  }

  Future<Comment> addComment(String postId, {String? body, String? emoji}) async => Comment.fromJson(
      await _call(() => _dio.post('/api/posts/$postId/comments', data: {'body': body, 'emoji': emoji})));

  Future<void> deleteComment(String id) => _call(() => _dio.delete('/api/comments/$id'));

  Future<void> report(String postId, String? reason) =>
      _call(() => _dio.post('/api/posts/$postId/report', data: {'reason': reason}));

  // ---------- Admin ----------

  Future<Paged<Post>> adminPosts({bool flaggedOnly = true, int page = 1}) async => Paged.fromJson(
      await _call(() => _dio.get('/api/admin/posts', queryParameters: {'flaggedOnly': flaggedOnly, 'page': page})),
      Post.fromJson);

  Future<void> adminDismissReports(String postId) => _call(() => _dio.post('/api/admin/posts/$postId/dismiss-reports'));

  Future<void> adminDeletePost(String postId) => _call(() => _dio.delete('/api/admin/posts/$postId'));

  Future<Paged<AdminUser>> adminUsers({String? search, int page = 1}) async => Paged.fromJson(
      await _call(() => _dio.get('/api/admin/users', queryParameters: {if (search != null) 'search': search, 'page': page})),
      AdminUser.fromJson);

  Future<void> adminDeleteUser(String userId) => _call(() => _dio.delete('/api/admin/users/$userId'));

  // ---------- Plumbing ----------

  Future<dynamic> _call(Future<Response> Function() request) async {
    try {
      return (await request()).data;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw ApiException(_messageFor(e), e.response?.statusCode);
    }
  }

  static String _messageFor(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        return errors.values.expand((v) => v is List ? v : [v]).join('\n');
      }
      if (data['detail'] is String) return data['detail'];
      if (data['title'] is String) return data['title'];
    }
    return switch (e.type) {
      DioExceptionType.connectionTimeout || DioExceptionType.connectionError => 'Cannot reach the server.',
      DioExceptionType.sendTimeout || DioExceptionType.receiveTimeout => 'The server took too long to respond.',
      _ => switch (e.response?.statusCode) {
          401 => 'Please sign in again.',
          403 => 'You are not allowed to do that.',
          404 => 'Not found.',
          413 => 'File is too large.',
          429 => 'Too many attempts. Try again in a minute.',
          _ => 'Something went wrong (${e.response?.statusCode ?? e.type.name}).',
        },
    };
  }
}

enum MediaType {
  text,
  image,
  video,
  audio;

  /// Server sends/accepts enum names in PascalCase ("Image").
  String get apiName => name[0].toUpperCase() + name.substring(1);

  static MediaType fromApi(String value) =>
      MediaType.values.firstWhere((t) => t.apiName == value, orElse: () => MediaType.text);
}

enum HiddenReason {
  none,
  reports,
  downvotes,
  admin;

  static HiddenReason fromApi(String? value) =>
      HiddenReason.values.firstWhere((r) => r.name.toLowerCase() == value?.toLowerCase(), orElse: () => HiddenReason.none);
}

class User {
  final String id;
  final String userName;
  final bool isAdmin;

  const User({required this.id, required this.userName, required this.isAdmin});

  factory User.fromJson(Map<String, dynamic> j) =>
      User(id: j['id'], userName: j['userName'], isAdmin: j['isAdmin'] ?? false);

  Map<String, dynamic> toJson() => {'id': id, 'userName': userName, 'isAdmin': isAdmin};
}

class Author {
  final String id;
  final String userName;

  const Author(this.id, this.userName);

  factory Author.fromJson(Map<String, dynamic> j) => Author(j['id'], j['userName']);
}

class Media {
  final String url;
  final String contentType;
  final int contentLength;

  const Media(this.url, this.contentType, this.contentLength);

  factory Media.fromJson(Map<String, dynamic> j) =>
      Media(j['url'], j['contentType'], j['contentLength']);
}

class Post {
  final String id;
  final Author author;
  final String title;
  final String? description;
  final MediaType mediaType;
  final Media? media;
  final double latitude;
  final double longitude;

  /// Null when precise; otherwise the location is only known to within this many meters.
  final int? locationRadiusMeters;
  final int views;
  final int upvotes;
  final int downvotes;
  final int commentCount;
  final int myVote;
  final int reportCount;
  final bool isHidden;
  final HiddenReason hiddenReason;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Post({
    required this.id,
    required this.author,
    required this.title,
    required this.description,
    required this.mediaType,
    required this.media,
    required this.latitude,
    required this.longitude,
    this.locationRadiusMeters,
    required this.views,
    required this.upvotes,
    required this.downvotes,
    required this.commentCount,
    required this.myVote,
    required this.reportCount,
    required this.isHidden,
    required this.hiddenReason,
    required this.createdAt,
    required this.updatedAt,
  });

  int get score => upvotes - downvotes;

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: j['id'],
        author: Author.fromJson(j['author']),
        title: j['title'],
        description: j['description'],
        mediaType: MediaType.fromApi(j['mediaType']),
        media: j['media'] == null ? null : Media.fromJson(j['media']),
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        locationRadiusMeters: j['locationRadiusMeters'],
        views: j['views'],
        upvotes: j['upvotes'],
        downvotes: j['downvotes'],
        commentCount: j['commentCount'],
        myVote: j['myVote'] ?? 0,
        reportCount: j['reportCount'] ?? 0,
        isHidden: j['isHidden'] ?? false,
        hiddenReason: HiddenReason.fromApi(j['hiddenReason']),
        createdAt: DateTime.parse(j['createdAt']),
        updatedAt: j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt']),
      );

  Post copyWith({String? title, String? description, int? upvotes, int? downvotes, int? myVote, bool? isHidden}) => Post(
        id: id,
        author: author,
        title: title ?? this.title,
        description: description ?? this.description,
        mediaType: mediaType,
        media: media,
        latitude: latitude,
        longitude: longitude,
        locationRadiusMeters: locationRadiusMeters,
        views: views,
        upvotes: upvotes ?? this.upvotes,
        downvotes: downvotes ?? this.downvotes,
        commentCount: commentCount,
        myVote: myVote ?? this.myVote,
        reportCount: reportCount,
        isHidden: isHidden ?? this.isHidden,
        hiddenReason: hiddenReason,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// A single post (count == 1) or a cluster of posts on the map.
class MapPoint {
  final double latitude;
  final double longitude;
  final int count;
  final String? postId;
  final MediaType? mediaType;
  final String? title;

  /// Null when precise; otherwise a single post's location is only known to within this many meters.
  final int? locationRadiusMeters;

  const MapPoint(
    this.latitude,
    this.longitude,
    this.count,
    this.postId,
    this.mediaType,
    this.title, [
    this.locationRadiusMeters,
  ]);

  bool get isCluster => count > 1;

  factory MapPoint.fromJson(Map<String, dynamic> j) => MapPoint(
        (j['latitude'] as num).toDouble(),
        (j['longitude'] as num).toDouble(),
        j['count'],
        j['postId'],
        j['mediaType'] == null ? null : MediaType.fromApi(j['mediaType']),
        j['title'],
        j['locationRadiusMeters'],
      );
}

class Comment {
  final String id;
  final Author author;
  final String? body;
  final String? emoji;
  final DateTime createdAt;

  const Comment(this.id, this.author, this.body, this.emoji, this.createdAt);

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        j['id'],
        Author.fromJson(j['author']),
        j['body'],
        j['emoji'],
        DateTime.parse(j['createdAt']),
      );
}

class AdminUser {
  final String id;
  final String userName;
  final bool isAdmin;
  final int postCount;

  const AdminUser(this.id, this.userName, this.isAdmin, this.postCount);

  factory AdminUser.fromJson(Map<String, dynamic> j) =>
      AdminUser(j['id'], j['userName'], j['isAdmin'], j['postCount']);
}

class Paged<T> {
  final List<T> items;
  final bool hasMore;

  const Paged(this.items, this.hasMore);

  factory Paged.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) parse) =>
      Paged((j['items'] as List).map((e) => parse(e as Map<String, dynamic>)).toList(), j['hasMore']);
}

/// Filters shared by map and feed.
class PostFilter {
  final Set<MediaType> types;
  final Duration? maxAge;
  final int? minScore;

  const PostFilter({this.types = const {}, this.maxAge, this.minScore});

  bool get isActive => types.isNotEmpty || maxAge != null || minScore != null;

  Map<String, dynamic> toQuery() => {
        if (types.isNotEmpty) 'types': types.map((t) => t.apiName).toList(),
        if (maxAge != null) 'since': DateTime.now().toUtc().subtract(maxAge!).toIso8601String(),
        if (minScore != null) 'minScore': minScore,
      };
}

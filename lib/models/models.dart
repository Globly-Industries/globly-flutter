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
  admin,

  /// The NSFW filter is nearly sure the media is explicit.
  automatic,

  unverified;

  static HiddenReason fromApi(String? value) =>
      HiddenReason.values.firstWhere((r) => r.name.toLowerCase() == value?.toLowerCase(), orElse: () => HiddenReason.none);
}

class User {
  final String id;
  final String userName;
  final bool isAdmin;
  final String? avatarUrl;

  /// Whether followers see this user's likes in their feeds.
  final bool shareLikes;

  const User({required this.id, required this.userName, required this.isAdmin, this.avatarUrl, this.shareLikes = true});

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        userName: j['userName'],
        isAdmin: j['isAdmin'] ?? false,
        avatarUrl: j['avatarUrl'],
        shareLikes: j['shareLikes'] ?? true,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'userName': userName, 'isAdmin': isAdmin, 'avatarUrl': avatarUrl, 'shareLikes': shareLikes};

  User withAvatar(String? url) =>
      User(id: id, userName: userName, isAdmin: isAdmin, avatarUrl: url, shareLikes: shareLikes);

  User withShareLikes(bool share) =>
      User(id: id, userName: userName, isAdmin: isAdmin, avatarUrl: avatarUrl, shareLikes: share);
}

/// People you follow who liked a post: the latest few names and how many in all.
class LikedBy {
  final List<String> userNames;
  final int count;

  const LikedBy(this.userNames, this.count);

  factory LikedBy.fromJson(Map<String, dynamic> j) =>
      LikedBy((j['userNames'] as List).cast<String>(), j['count']);
}

class Author {
  final String id;
  final String userName;

  /// Profile picture; null shows initials.
  final String? avatarUrl;

  const Author(this.id, this.userName, [this.avatarUrl]);

  factory Author.fromJson(Map<String, dynamic> j) => Author(j['id'], j['userName'], j['avatarUrl']);
}

/// Someone's public profile.
class UserProfile {
  final String id;
  final String userName;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final bool isFollowing;
  final String? avatarUrl;

  const UserProfile({
    required this.id,
    required this.userName,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    required this.isFollowing,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'],
        userName: j['userName'],
        postCount: j['postCount'],
        followerCount: j['followerCount'],
        followingCount: j['followingCount'],
        isFollowing: j['isFollowing'] ?? false,
        avatarUrl: j['avatarUrl'],
      );

  UserProfile withFollow(bool following, int followers) => UserProfile(
        id: id,
        userName: userName,
        postCount: postCount,
        followerCount: followers,
        followingCount: followingCount,
        isFollowing: following,
        avatarUrl: avatarUrl,
      );
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

  /// Admins only: the NSFW filter's score (0-1); null until scanned, and for everyone else.
  final double? nsfwScore;

  /// Admins only: visible, but the NSFW filter queued it for review.
  final bool needsReview;

  /// Set while the author has it in the spotlight (boosted in the feeds).
  final DateTime? spotlightUntil;
  final int awardCount;

  /// Whether the signed-in user gave it an award.
  final bool myAward;

  /// Feeds only: people you follow who liked it.
  final LikedBy? likedBy;

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
    this.nsfwScore,
    this.needsReview = false,
    this.spotlightUntil,
    this.awardCount = 0,
    this.myAward = false,
    this.likedBy,
  });

  int get score => upvotes - downvotes;

  bool get isSpotlit => spotlightUntil?.isAfter(DateTime.now()) ?? false;

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
        nsfwScore: (j['nsfwScore'] as num?)?.toDouble(),
        needsReview: j['needsReview'] ?? false,
        spotlightUntil: j['spotlightUntil'] == null ? null : DateTime.parse(j['spotlightUntil']),
        awardCount: j['awardCount'] ?? 0,
        myAward: j['myAward'] ?? false,
        likedBy: j['likedBy'] == null ? null : LikedBy.fromJson(j['likedBy']),
      );

  Post copyWith({
    String? title,
    String? description,
    int? upvotes,
    int? downvotes,
    int? commentCount,
    int? myVote,
    bool? isHidden,
    DateTime? spotlightUntil,
    int? awardCount,
    bool? myAward,
  }) =>
      Post(
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
        commentCount: commentCount ?? this.commentCount,
        myVote: myVote ?? this.myVote,
        reportCount: reportCount,
        isHidden: isHidden ?? this.isHidden,
        hiddenReason: hiddenReason,
        createdAt: createdAt,
        updatedAt: updatedAt,
        nsfwScore: nsfwScore,
        needsReview: needsReview,
        spotlightUntil: spotlightUntil ?? this.spotlightUntil,
        awardCount: awardCount ?? this.awardCount,
        myAward: myAward ?? this.myAward,
        likedBy: likedBy,
      );
}

/// The signed-in user's points and what a spotlight costs them now.
class PointsInfo {
  final int balance;
  final int spotlightCost;
  final int spotlightHours;
  final String? spotlightPostId;
  final DateTime? spotlightUntil;
  final int awardCost;
  final int awardsLeftToday;

  const PointsInfo(this.balance, this.spotlightCost, this.spotlightHours, this.spotlightPostId, this.spotlightUntil,
      [this.awardCost = 5, this.awardsLeftToday = 0]);

  factory PointsInfo.fromJson(Map<String, dynamic> j) => PointsInfo(
        j['balance'],
        j['spotlightCost'],
        j['spotlightHours'],
        j['spotlightPostId'],
        j['spotlightUntil'] == null ? null : DateTime.parse(j['spotlightUntil']),
        j['awardCost'] ?? 5,
        j['awardsLeftToday'] ?? 0,
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
  final String body;
  final DateTime createdAt;

  const Comment(this.id, this.author, this.body, this.createdAt);

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        j['id'],
        Author.fromJson(j['author']),
        j['body'],
        DateTime.parse(j['createdAt']),
      );
}

enum NotificationType { comment, mention, follow, award }

/// A comment or mention on a post, or a new follower ([postId] and the rest are then null).
class AppNotification {
  final String id;
  final NotificationType type;
  final Author actor;
  final String? postId;
  final String? postTitle;
  final String? commentBody;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification(
      this.id, this.type, this.actor, this.postId, this.postTitle, this.commentBody, this.createdAt, this.isRead);

  AppNotification markedRead() => AppNotification(id, type, actor, postId, postTitle, commentBody, createdAt, true);

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        j['id'],
        switch (j['type']) {
          'Mention' => NotificationType.mention,
          'Follow' => NotificationType.follow,
          'Award' => NotificationType.award,
          _ => NotificationType.comment,
        },
        Author.fromJson(j['actor']),
        j['postId'],
        j['postTitle'],
        j['commentBody'],
        DateTime.parse(j['createdAt']),
        j['isRead'],
      );
}

/// A user in a followers or following list.
class FollowUser {
  final String id;
  final String userName;

  /// Whether the signed-in user follows them.
  final bool isFollowing;
  final String? avatarUrl;

  const FollowUser(this.id, this.userName, this.isFollowing, [this.avatarUrl]);

  Author get author => Author(id, userName, avatarUrl);

  FollowUser withFollowing(bool following) => FollowUser(id, userName, following, avatarUrl);

  factory FollowUser.fromJson(Map<String, dynamic> j) =>
      FollowUser(j['id'], j['userName'], j['isFollowing'] ?? false, j['avatarUrl']);
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

/// Feed tabs; the server ranks each one differently.
enum FeedTab {
  recent,
  nearby,
  following;

  String get apiName => name[0].toUpperCase() + name.substring(1);
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

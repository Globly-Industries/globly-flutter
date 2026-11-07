import 'package:flutter_test/flutter_test.dart';
import 'package:globly/models/models.dart';

void main() {
  test('MediaType round-trips the API enum names', () {
    for (final t in MediaType.values) {
      expect(MediaType.fromApi(t.apiName), t);
    }
    expect(MediaType.image.apiName, 'Image');
  });

  test('Post parses API JSON', () {
    final post = Post.fromJson({
      'id': '0193f1c2-0000-7000-8000-000000000001',
      'author': {'id': 'u1', 'userName': 'alice'},
      'title': 'Hello',
      'description': null,
      'mediaType': 'Image',
      'media': {'url': 'https://media.example/x.jpg', 'contentType': 'image/jpeg', 'contentLength': 1234},
      'latitude': 56.95,
      'longitude': 24.1,
      'views': 3,
      'upvotes': 5,
      'downvotes': 1,
      'commentCount': 2,
      'myVote': 1,
      'reportCount': 0,
      'isHidden': false,
      'hiddenReason': 'None',
      'createdAt': '2026-11-07T12:00:00Z',
      'updatedAt': null,
    });
    expect(post.mediaType, MediaType.image);
    expect(post.score, 4);
    expect(post.media!.url, contains('x.jpg'));
  });

  test('MapPoint distinguishes clusters from single posts', () {
    final cluster = MapPoint.fromJson({'latitude': 1, 'longitude': 2, 'count': 7, 'postId': null, 'mediaType': null, 'title': null});
    final single = MapPoint.fromJson({'latitude': 1, 'longitude': 2, 'count': 1, 'postId': 'p', 'mediaType': 'Video', 'title': 't'});
    expect(cluster.isCluster, isTrue);
    expect(single.isCluster, isFalse);
    expect(single.mediaType, MediaType.video);
  });
}

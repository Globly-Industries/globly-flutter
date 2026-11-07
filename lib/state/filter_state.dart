import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Post filters shared by the map and the feed.
class FilterState extends ChangeNotifier {
  PostFilter _filter = const PostFilter();

  PostFilter get filter => _filter;

  set filter(PostFilter value) {
    _filter = value;
    notifyListeners();
  }
}

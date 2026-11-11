// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Globly';

  @override
  String get tagline => 'Share moments from around the world';

  @override
  String get languageName => 'English';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get register => 'Register';

  @override
  String get createAccount => 'Create account';

  @override
  String get browseAsGuest => 'Browse without an account';

  @override
  String get or => 'or';

  @override
  String get usernameLength => '3–32 characters';

  @override
  String get usernameChars => 'Letters, numbers, . _ - only';

  @override
  String get passwordLength => 'At least 8 characters';

  @override
  String get humanCheckRequired => 'Please complete the human check first.';

  @override
  String get navMap => 'Map';

  @override
  String get navFeed => 'Feed';

  @override
  String get navProfile => 'Profile';

  @override
  String get newPost => 'New post';

  @override
  String get signInToPost => 'Sign in to publish posts.';

  @override
  String get signInToRate => 'Sign in to rate posts.';

  @override
  String get filters => 'Filters';

  @override
  String get contentType => 'Content type';

  @override
  String get mediaText => 'Text';

  @override
  String get mediaImage => 'Photo';

  @override
  String get mediaVideo => 'Video';

  @override
  String get mediaAudio => 'Audio';

  @override
  String get posted => 'Posted';

  @override
  String get anyTime => 'Any time';

  @override
  String get last24h => '24 hours';

  @override
  String get last7d => '7 days';

  @override
  String get last30d => '30 days';

  @override
  String get positiveOnly => 'Only positively rated';

  @override
  String get reset => 'Reset';

  @override
  String get apply => 'Apply';

  @override
  String get newest => 'Newest';

  @override
  String get nearby => 'Nearby';

  @override
  String get noPostsYet => 'No posts here yet';

  @override
  String get noPostsHint => 'Be the first to share something!';

  @override
  String get retry => 'Retry';

  @override
  String get open => 'Open';

  @override
  String get comments => 'Comments';

  @override
  String get addComment => 'Add a comment…';

  @override
  String get noComments => 'No comments yet.';

  @override
  String viewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count views',
      one: '1 view',
    );
    return '$_temp0';
  }

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get report => 'Report';

  @override
  String get reportTitle => 'Report this post?';

  @override
  String get reportHint =>
      'If enough people report a post, it is hidden until a moderator reviews it.';

  @override
  String get reportReason => 'Reason (optional)';

  @override
  String get reportThanks => 'Thanks for the report.';

  @override
  String get reportHidden => 'Thanks. The post is now hidden for review.';

  @override
  String get editPost => 'Edit post';

  @override
  String get title => 'Title';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get text => 'Text';

  @override
  String get deletePostTitle => 'Delete post?';

  @override
  String get deletePostBody =>
      'The post and its media will be removed permanently.';

  @override
  String get deleteCommentTitle => 'Delete comment?';

  @override
  String get cannotUndo => 'This cannot be undone.';

  @override
  String get hidden => 'Hidden';

  @override
  String get hiddenReports =>
      'Hidden: several people reported this post. A moderator will review it.';

  @override
  String get hiddenDownvotes =>
      'Hidden: this post received mostly negative ratings. A moderator will review it.';

  @override
  String get hiddenAdmin => 'Hidden by a moderator.';

  @override
  String get publish => 'Publish';

  @override
  String get published => 'Post published.';

  @override
  String uploading(int percent) {
    return 'Uploading… $percent%';
  }

  @override
  String get chooseFileFirst => 'Choose a file first.';

  @override
  String get titleRequired => 'Title is required';

  @override
  String get writeSomething => 'Write something';

  @override
  String get location => 'Location';

  @override
  String get retake => 'Retake';

  @override
  String get recording => 'Recording…';

  @override
  String get stopRecording => 'Stop';

  @override
  String get microphoneNeeded => 'Allow microphone access to record audio.';

  @override
  String get captureFailed => 'Could not start recording. Please try again.';

  @override
  String approximateLocation(String distance) {
    return 'Within about $distance';
  }

  @override
  String get moreFilters => 'More filters';

  @override
  String get whereCaptured => 'Where was this captured?';

  @override
  String get gettingLocation => 'Getting your location…';

  @override
  String get useMyLocation => 'Use my location';

  @override
  String get locationRequired => 'Location is required.';

  @override
  String get locationServicesOff => 'Location services are turned off.';

  @override
  String get locationDenied => 'Location permission was not granted.';

  @override
  String get locationUnavailable => 'Could not get your location.';

  @override
  String get couldNotLoadVideo => 'Could not load video';

  @override
  String get guestTitle => 'You\'re browsing as a guest';

  @override
  String get guestBody => 'Sign in to publish posts, comment and rate.';

  @override
  String get signInOrRegister => 'Sign in or register';

  @override
  String get myPosts => 'My posts';

  @override
  String get noMyPosts => 'You haven\'t posted anything yet.';

  @override
  String get signOut => 'Sign out';

  @override
  String get administration => 'Administration';

  @override
  String get language => 'Language';

  @override
  String get systemLanguage => 'System default';

  @override
  String get posts => 'Posts';

  @override
  String get score => 'Score';

  @override
  String get admin => 'Admin';

  @override
  String get hiddenPosts => 'Hidden posts';

  @override
  String get users => 'Users';

  @override
  String get nothingToReview => 'Nothing to review.';

  @override
  String get restore => 'Restore';

  @override
  String get hide => 'Hide';

  @override
  String reasonReports(int count) {
    return '$count reports';
  }

  @override
  String get reasonDownvotes => 'Mostly downvoted';

  @override
  String get reasonAdmin => 'Hidden by moderator';

  @override
  String get searchUsers => 'Search users';

  @override
  String userPostCount(int count) {
    return '$count posts';
  }

  @override
  String deleteUserTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteUserBody =>
      'Their account and all their posts will be removed.';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String hoursAgo(int n) {
    return '$n h ago';
  }

  @override
  String daysAgo(int n) {
    return '$n d ago';
  }

  @override
  String get errCannotReach =>
      'Can\'t reach the server. Check your connection.';

  @override
  String get errTimeout => 'The server took too long to respond.';

  @override
  String get errUsernameTaken => 'That username is already taken.';

  @override
  String get errInvalidCredentials => 'Incorrect username or password.';

  @override
  String get errLockedOut => 'Too many failed attempts. Try again later.';

  @override
  String get errCaptcha => 'The human check failed. Please try again.';

  @override
  String get errContentRejected => 'This content isn\'t allowed.';

  @override
  String get errInvalidFile => 'This file type isn\'t supported.';

  @override
  String get errFileTooLarge => 'The file is too large.';

  @override
  String get errTextRequired => 'Write something first.';

  @override
  String get errCommentEmpty => 'Write a comment first.';

  @override
  String get errCannotDeleteSelf => 'You can\'t delete your own account here.';

  @override
  String get errSignInAgain => 'Please sign in again.';

  @override
  String get errForbidden => 'You\'re not allowed to do that.';

  @override
  String get errNotFound => 'Not found. It may have been removed.';

  @override
  String get errTooMany => 'Too many attempts. Try again in a minute.';

  @override
  String get errInvalidInput => 'Please check what you entered.';

  @override
  String get errGeneric => 'Something went wrong.';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get upToDate => 'You have the latest version.';

  @override
  String get updateCheckFailed => 'Couldn\'t check for updates.';

  @override
  String get updateAvailable => 'Update available';

  @override
  String updateAvailableBody(String version, String current) {
    return 'Version $version is available. You have $current.';
  }

  @override
  String get updateLater => 'Later';

  @override
  String get updateNow => 'Update';

  @override
  String updateDownloading(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get updateFailed => 'The update couldn\'t be downloaded.';
}

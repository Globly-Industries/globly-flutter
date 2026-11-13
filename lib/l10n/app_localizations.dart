import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_lv.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('lv'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Globly'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Share moments from around the world'**
  String get tagline;

  /// No description provided for @languageName.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @browseAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Browse without an account'**
  String get browseAsGuest;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @usernameLength.
  ///
  /// In en, this message translates to:
  /// **'3–32 characters'**
  String get usernameLength;

  /// No description provided for @usernameChars.
  ///
  /// In en, this message translates to:
  /// **'Letters, numbers, . _ - only'**
  String get usernameChars;

  /// No description provided for @passwordLength.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordLength;

  /// No description provided for @humanCheckRequired.
  ///
  /// In en, this message translates to:
  /// **'Please complete the human check first.'**
  String get humanCheckRequired;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get navFeed;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @newPost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get newPost;

  /// No description provided for @signInToPost.
  ///
  /// In en, this message translates to:
  /// **'Sign in to publish posts.'**
  String get signInToPost;

  /// No description provided for @signInToRate.
  ///
  /// In en, this message translates to:
  /// **'Sign in to rate posts.'**
  String get signInToRate;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @contentType.
  ///
  /// In en, this message translates to:
  /// **'Content type'**
  String get contentType;

  /// No description provided for @mediaText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get mediaText;

  /// No description provided for @mediaImage.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get mediaImage;

  /// No description provided for @mediaVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get mediaVideo;

  /// No description provided for @mediaAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get mediaAudio;

  /// No description provided for @posted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get posted;

  /// No description provided for @anyTime.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get anyTime;

  /// No description provided for @last24h.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get last24h;

  /// No description provided for @last7d.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get last7d;

  /// No description provided for @last30d.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get last30d;

  /// No description provided for @positiveOnly.
  ///
  /// In en, this message translates to:
  /// **'Only positively rated'**
  String get positiveOnly;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @newest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts here yet'**
  String get noPostsYet;

  /// No description provided for @noPostsHint.
  ///
  /// In en, this message translates to:
  /// **'Be the first to share something!'**
  String get noPostsHint;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @addComment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get addComment;

  /// No description provided for @noComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get noComments;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get noNotifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllRead;

  /// No description provided for @notificationComment.
  ///
  /// In en, this message translates to:
  /// **'{user} commented on \"{post}\"'**
  String notificationComment(String user, String post);

  /// No description provided for @notificationMention.
  ///
  /// In en, this message translates to:
  /// **'{user} mentioned you on \"{post}\"'**
  String notificationMention(String user, String post);

  /// No description provided for @viewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 view} other{{count} views}}'**
  String viewsCount(int count);

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this post?'**
  String get reportTitle;

  /// No description provided for @reportHint.
  ///
  /// In en, this message translates to:
  /// **'If enough people report a post, it is hidden until a moderator reviews it.'**
  String get reportHint;

  /// No description provided for @reportReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get reportReason;

  /// No description provided for @reportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for the report.'**
  String get reportThanks;

  /// No description provided for @reportHidden.
  ///
  /// In en, this message translates to:
  /// **'Thanks. The post is now hidden for review.'**
  String get reportHidden;

  /// No description provided for @editPost.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get editPost;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @deletePostTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete post?'**
  String get deletePostTitle;

  /// No description provided for @deletePostBody.
  ///
  /// In en, this message translates to:
  /// **'The post and its media will be removed permanently.'**
  String get deletePostBody;

  /// No description provided for @deleteCommentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete comment?'**
  String get deleteCommentTitle;

  /// No description provided for @cannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get cannotUndo;

  /// No description provided for @hidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hidden;

  /// No description provided for @hiddenReports.
  ///
  /// In en, this message translates to:
  /// **'Hidden: several people reported this post. A moderator will review it.'**
  String get hiddenReports;

  /// No description provided for @hiddenDownvotes.
  ///
  /// In en, this message translates to:
  /// **'Hidden: this post received mostly negative ratings. A moderator will review it.'**
  String get hiddenDownvotes;

  /// No description provided for @hiddenAdmin.
  ///
  /// In en, this message translates to:
  /// **'Hidden by a moderator.'**
  String get hiddenAdmin;

  /// No description provided for @hiddenAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Hidden: our filter flagged this post as possibly explicit. A moderator will review it.'**
  String get hiddenAutomatic;

  /// No description provided for @hiddenUnverified.
  ///
  /// In en, this message translates to:
  /// **'Hidden: this media could not be verified as captured with the Globly Android app on this spot. A moderator will review it.'**
  String get hiddenUnverified;

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publish;

  /// No description provided for @published.
  ///
  /// In en, this message translates to:
  /// **'Post published.'**
  String get published;

  /// No description provided for @publishedForReview.
  ///
  /// In en, this message translates to:
  /// **'Post sent. It could not be verified as captured with the Globly Android app, so a moderator will review it before others see it.'**
  String get publishedForReview;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading… {percent}%'**
  String uploading(int percent);

  /// No description provided for @chooseFileFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a file first.'**
  String get chooseFileFirst;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleRequired;

  /// No description provided for @writeSomething.
  ///
  /// In en, this message translates to:
  /// **'Write something'**
  String get writeSomething;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording…'**
  String get recording;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopRecording;

  /// No description provided for @microphoneNeeded.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access to record audio.'**
  String get microphoneNeeded;

  /// No description provided for @captureFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start recording. Please try again.'**
  String get captureFailed;

  /// No description provided for @approximateLocation.
  ///
  /// In en, this message translates to:
  /// **'Within about {distance}'**
  String approximateLocation(String distance);

  /// No description provided for @moreFilters.
  ///
  /// In en, this message translates to:
  /// **'More filters'**
  String get moreFilters;

  /// No description provided for @whereCaptured.
  ///
  /// In en, this message translates to:
  /// **'Where was this captured?'**
  String get whereCaptured;

  /// No description provided for @gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting your location…'**
  String get gettingLocation;

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// No description provided for @locationRequired.
  ///
  /// In en, this message translates to:
  /// **'Location is required.'**
  String get locationRequired;

  /// No description provided for @locationServicesOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off.'**
  String get locationServicesOff;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was not granted.'**
  String get locationDenied;

  /// No description provided for @locationDeniedBrowser.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked for this site. Allow it in your browser\'s site settings (on iPhone also check Settings → Privacy & Security → Location Services → Safari Websites → While Using the App), then tap Retry.'**
  String get locationDeniedBrowser;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location.'**
  String get locationUnavailable;

  /// No description provided for @couldNotLoadVideo.
  ///
  /// In en, this message translates to:
  /// **'Could not load video'**
  String get couldNotLoadVideo;

  /// No description provided for @guestTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re browsing as a guest'**
  String get guestTitle;

  /// No description provided for @guestBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to publish posts, comment and rate.'**
  String get guestBody;

  /// No description provided for @signInOrRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign in or register'**
  String get signInOrRegister;

  /// No description provided for @myPosts.
  ///
  /// In en, this message translates to:
  /// **'My posts'**
  String get myPosts;

  /// No description provided for @noMyPosts.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t posted anything yet.'**
  String get noMyPosts;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @administration.
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get administration;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemLanguage;

  /// No description provided for @posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get posts;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @hiddenPosts.
  ///
  /// In en, this message translates to:
  /// **'To review'**
  String get hiddenPosts;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @nothingToReview.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review.'**
  String get nothingToReview;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @reasonReports.
  ///
  /// In en, this message translates to:
  /// **'{count} reports'**
  String reasonReports(int count);

  /// No description provided for @reasonDownvotes.
  ///
  /// In en, this message translates to:
  /// **'Mostly downvoted'**
  String get reasonDownvotes;

  /// No description provided for @reasonAdmin.
  ///
  /// In en, this message translates to:
  /// **'Hidden by moderator'**
  String get reasonAdmin;

  /// No description provided for @reasonAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Auto-hidden: NSFW {percent}%'**
  String reasonAutomatic(int percent);

  /// No description provided for @reasonUnverified.
  ///
  /// In en, this message translates to:
  /// **'Capture not verified'**
  String get reasonUnverified;

  /// No description provided for @reasonFlagged.
  ///
  /// In en, this message translates to:
  /// **'Flagged: NSFW {percent}%'**
  String reasonFlagged(int percent);

  /// No description provided for @searchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search users'**
  String get searchUsers;

  /// No description provided for @userPostCount.
  ///
  /// In en, this message translates to:
  /// **'{count} posts'**
  String userPostCount(int count);

  /// No description provided for @deleteUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteUserTitle(String name);

  /// No description provided for @deleteUserBody.
  ///
  /// In en, this message translates to:
  /// **'Their account and all their posts will be removed.'**
  String get deleteUserBody;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String minutesAgo(int n);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String hoursAgo(int n);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String daysAgo(int n);

  /// No description provided for @errCannotReach.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check your connection.'**
  String get errCannotReach;

  /// No description provided for @errTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond.'**
  String get errTimeout;

  /// No description provided for @errUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is already taken.'**
  String get errUsernameTaken;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect username or password.'**
  String get errInvalidCredentials;

  /// No description provided for @errLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Try again later.'**
  String get errLockedOut;

  /// No description provided for @errCaptcha.
  ///
  /// In en, this message translates to:
  /// **'The human check failed. Please try again.'**
  String get errCaptcha;

  /// No description provided for @errContentRejected.
  ///
  /// In en, this message translates to:
  /// **'This content isn\'t allowed.'**
  String get errContentRejected;

  /// No description provided for @errInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t supported.'**
  String get errInvalidFile;

  /// No description provided for @errFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is too large.'**
  String get errFileTooLarge;

  /// No description provided for @errCaptureInvalid.
  ///
  /// In en, this message translates to:
  /// **'This media could not be verified as captured in Globly. Please capture it again.'**
  String get errCaptureInvalid;

  /// No description provided for @errCaptureExpired.
  ///
  /// In en, this message translates to:
  /// **'This capture is too old to post. Please capture it again.'**
  String get errCaptureExpired;

  /// No description provided for @errCaptureUnverified.
  ///
  /// In en, this message translates to:
  /// **'Media can only be posted from the Globly Android app.'**
  String get errCaptureUnverified;

  /// No description provided for @errTextRequired.
  ///
  /// In en, this message translates to:
  /// **'Write something first.'**
  String get errTextRequired;

  /// No description provided for @errCommentEmpty.
  ///
  /// In en, this message translates to:
  /// **'Write a comment first.'**
  String get errCommentEmpty;

  /// No description provided for @errCannotDeleteSelf.
  ///
  /// In en, this message translates to:
  /// **'You can\'t delete your own account here.'**
  String get errCannotDeleteSelf;

  /// No description provided for @errSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get errSignInAgain;

  /// No description provided for @errForbidden.
  ///
  /// In en, this message translates to:
  /// **'You\'re not allowed to do that.'**
  String get errForbidden;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found. It may have been removed.'**
  String get errNotFound;

  /// No description provided for @errTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in a minute.'**
  String get errTooMany;

  /// No description provided for @errInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Please check what you entered.'**
  String get errInvalidInput;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errGeneric;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersion(String version);

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version.'**
  String get upToDate;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates.'**
  String get updateCheckFailed;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailable;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available. You have {current}.'**
  String updateAvailableBody(String version, String current);

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String updateDownloading(int percent);

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'The update couldn\'t be downloaded.'**
  String get updateFailed;

  /// No description provided for @feedViewImmersive.
  ///
  /// In en, this message translates to:
  /// **'Full-screen feed'**
  String get feedViewImmersive;

  /// No description provided for @feedViewList.
  ///
  /// In en, this message translates to:
  /// **'List feed'**
  String get feedViewList;

  /// No description provided for @showOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get showOnMap;

  /// No description provided for @soundOn.
  ///
  /// In en, this message translates to:
  /// **'Turn sound on'**
  String get soundOn;

  /// No description provided for @soundOff.
  ///
  /// In en, this message translates to:
  /// **'Turn sound off'**
  String get soundOff;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get readMore;

  /// No description provided for @postDetails.
  ///
  /// In en, this message translates to:
  /// **'Post details'**
  String get postDetails;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'lv'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'lv':
      return AppLocalizationsLv();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

import 'package:flutter/widgets.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import 'location.dart';

/// Turns any error into a message in the current language.
String errorMessage(BuildContext context, Object error) {
  final l = AppLocalizations.of(context);

  if (error is LocationError) {
    return switch (error) {
      LocationError.servicesOff => l.locationServicesOff,
      LocationError.denied => l.locationDenied,
      LocationError.unavailable => l.locationUnavailable,
    };
  }

  if (error is! ApiException) return l.errGeneric;

  switch (error.kind) {
    case ApiErrorKind.connection:
      return l.errCannotReach;
    case ApiErrorKind.timeout:
      return l.errTimeout;
    case ApiErrorKind.server:
      break;
  }

  final byCode = switch (error.code) {
    'username_taken' => l.errUsernameTaken,
    'invalid_credentials' => l.errInvalidCredentials,
    'locked_out' => l.errLockedOut,
    'captcha_failed' => l.errCaptcha,
    'content_rejected' => l.errContentRejected,
    'invalid_file' => l.errInvalidFile,
    'file_too_large' => l.errFileTooLarge,
    'file_required' => l.chooseFileFirst,
    'text_required' => l.errTextRequired,
    'comment_empty' => l.errCommentEmpty,
    'cannot_delete_self' => l.errCannotDeleteSelf,
    _ => null,
  };
  if (byCode != null) return byCode;

  return switch (error.statusCode) {
    400 => l.errInvalidInput,
    401 => l.errSignInAgain,
    403 => l.errForbidden,
    404 => l.errNotFound,
    413 => l.errFileTooLarge,
    429 => l.errTooMany,
    _ => l.errGeneric,
  };
}

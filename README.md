# Globly (Flutter, Android)

Geospatial social media app: browse photo / video / audio / text posts on a world map or in a feed,
publish posts tied to where they were captured, rate them with votes, emoji and comments.

Backend: [`globly-api`](https://github.com/Globly-Industries/globly-api).

## First-time setup

The repo contains `lib/`, `pubspec.yaml` and the Android manifests. Generate the rest of the
Android project once (existing files are kept):

```bash
flutter create . --project-name globly --org com.globly --platforms android,web
flutter pub get
```

`flutter create` also generates `test/widget_test.dart` for a counter app; delete it.

If pub reports version conflicts with your Flutter version, run `flutter pub upgrade --major-versions`.

### Android build notes
- Needs the Android SDK (Android Studio), accepted licenses (`flutter doctor --android-licenses`) and
  NDK 28.2.13676358 (SDK Manager -> SDK Tools -> NDK, "Show Package Details").
- `pubspec.yaml` overrides `flutter_inappwebview` (used by the Turnstile widget) to the 6.2.0 beta:
  the stable 6.1.x Android package doesn't build with the current Android Gradle Plugin. Remove the
  override when 6.2.0 is stable.
- Build/install: `flutter build apk --release`, then `flutter install` (or `adb install -r
  build/app/outputs/flutter-apk/app-release.apk`). Local release builds use the debug signing key
  unless `android/key.properties` exists.

## Android releases

Pushing a version tag builds a signed APK and publishes it as a GitHub release
(`.github/workflows/android-release.yml`):

```bash
git tag v0.1.1
git push origin v0.1.1
```

To install, open the release on the phone, download the `.apk` and allow installs from that app when
Android asks. Later releases install as updates over the old one.

One-time setup: create an upload key with a letters-and-digits password, and back up the file and
password outside the repo. If the key is lost, testers have to uninstall to move to a new one.

```bash
keytool -genkeypair -keystore upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000
```

Add these repository secrets under Settings -> Secrets and variables -> Actions:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | output of `base64 -w0 upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |

## Running

Start the API (see its README), then:

```bash
# Android emulator -> API on the host machine (default)
flutter run

# Physical phone on the same Wi-Fi
flutter run --dart-define=API_BASE_URL=http://<pc-lan-ip>:5021

# Against the server behind Cloudflare Tunnel
flutter run --release   # uses https://api.dagnis.my.id by default
```

Debug builds allow plain HTTP (`android/app/src/debug`); release builds are HTTPS only.

## Web demo

The same code runs in a browser. It is hosted as static files on Cloudflare (Workers static
assets) at `https://globly.dagnis.my.id`, separate from the home server (which only serves the API).
The hosting config, including the custom domain, is in `wrangler.jsonc`.

```bash
# Local development in Chrome (API on http://localhost:5021)
flutter run -d chrome

# Build and deploy (first time: `npx wrangler login`)
flutter build web --release
npx wrangler deploy
```

Requirements on the backend side (already configured, see the API README):
- The API allows `https://globly.dagnis.my.id` via CORS (`Cors:AllowedOrigins`).
- The R2 bucket needs a CORS rule so the web app can load images.

Web differences: desktop browsers offer only text and audio posts (they have no camera flow, only a
file dialog), files are uploaded from memory, and the login token is kept in browser storage.

For local web dev with local media storage, run the API with
`Storage__Local__PublicBaseUrl=http://localhost:5021/media` (the default `10.0.2.2` only works in the emulator).

## Languages
English and Latvian. The app follows the device language by default; users can switch in
Profile -> Language (or the translate icon on the login screen).

Strings live in `lib/l10n/app_en.arb` (template) and `lib/l10n/app_lv.arb`. After editing them,
`flutter gen-l10n` (or any `flutter run/build`) regenerates `app_localizations*.dart`. API errors are
translated from their `code` in `lib/widgets/errors.dart`.

## Structure

```
lib/
  main.dart              app + auth gate (login / guest / signed in), languages
  theme.dart             colours, component styles, per-content-type accent colours
  l10n/                  English + Latvian strings (.arb) and generated localizations
  config.dart            API URL (--dart-define), map tiles
  api/api_client.dart    REST client (dio), error messages from ProblemDetails
  models/models.dart     Post, MapPoint, Comment, User, PostFilter...
  state/                 AuthState (token in secure storage), FilterState, SettingsState (language)
  screens/
    login_screen         register / sign in / browse anonymously
    home_shell           bottom bar: Map, Feed + post wheel; profile opens from the top right
    map_screen           Mapbox globe + server-side clusters, tap to zoom/open
    feed_screen          newest (paged) or nearby
    post_detail_screen   media playback, votes, emoji, comments, report, edit/delete
    create_post_screen   post form for captured media (retake), current GPS location, upload with progress
    profile_screen       my posts, sign out, admin entry
    admin_screen         reported-post queue, user removal
  widgets/               glass kit, post wheel, media capture, post card, media player, filter sheet, location helper
```

## Notes
- `assets/logo.svg` is the source logo. It isn't bundled: the app uses `assets/logo.png`, Android
  `res/drawable/ic_launcher_foreground.xml` + `res/mipmap-*`, and web `web/favicon.png` + `web/icons/`.
  These were generated from the SVG, so regenerate them if the logo changes.
- If a user gives the app only an approximate location (Android 12+ / iOS permission prompt), posts
  send a radius and show as an area on the map instead of a pin. The app can't request this per post:
  once precise access is granted it gets the precise position.
- The map is Mapbox's Standard style, with its day or night lighting following the app theme. The
  public token is in `lib/config.dart`; override it with `--dart-define=MAPBOX_TOKEN=...`. Free tier:
  25,000 monthly active users on mobile and 50,000 map loads per month on web.
- Media is streamed directly from Cloudflare R2 using URLs from the API.
- Uploads are limited to ~95 MB (Cloudflare request body limit).

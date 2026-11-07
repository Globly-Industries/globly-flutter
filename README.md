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

The same code runs in a browser. It is hosted as static files on Cloudflare Pages at
`https://globly.dagnis.my.id`, separate from the home server (which only serves the API).

```bash
# Local development in Chrome (API on http://localhost:5021)
flutter run -d chrome

# Build and deploy (first run asks you to log in to Cloudflare and creates the "globly" project)
flutter build web --release
npx wrangler pages deploy build/web --project-name globly
```

Once, in the Cloudflare dashboard: Workers & Pages -> `globly` -> Custom domains -> add `globly.dagnis.my.id`.

Requirements on the backend side (already configured, see the API README):
- The API allows `https://globly.dagnis.my.id` via CORS (`Cors:AllowedOrigins`).
- The R2 bucket needs a CORS rule so the web app can load images.

Web differences: uploads use the browser file picker, files are uploaded from memory, and the
login token is kept in browser storage.

For local web dev with local media storage, run the API with
`Storage__Local__PublicBaseUrl=http://localhost:5021/media` (the default `10.0.2.2` only works in the emulator).

## Structure

```
lib/
  main.dart              app + auth gate (login / guest / signed in)
  config.dart            API URL (--dart-define), map tiles
  api/api_client.dart    REST client (dio), error messages from ProblemDetails
  models/models.dart     Post, MapPoint, Comment, User, PostFilter...
  state/                 AuthState (token in secure storage), FilterState
  screens/
    login_screen         register / sign in / browse anonymously
    home_shell           bottom nav: Map, Feed, Profile + new post button
    map_screen           flutter_map + server-side clusters, tap to zoom/open
    feed_screen          newest (paged) or nearby
    post_detail_screen   media playback, votes, emoji, comments, report, edit/delete
    create_post_screen   pick media, GPS or tap-on-map location, upload with progress
    profile_screen       my posts, sign out, admin entry
    admin_screen         reported-post queue, user removal
  widgets/               post card, media player, filter sheet, location helper
```

## Notes
- Map tiles come from the public OpenStreetMap server, which is fine for development but not allowed
  for production traffic. Switch `AppConfig.tileUrlTemplate` to a provider (MapTiler, Stadia, Thunderforest,
  or self-hosted) before release.
- Media is streamed directly from Cloudflare R2 using URLs from the API.
- Uploads are limited to ~95 MB (Cloudflare request body limit).

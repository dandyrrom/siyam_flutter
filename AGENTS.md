# AGENTS.md

## Cursor Cloud specific instructions

SIYAM is a **Flutter Web** app (single product, no monorepo). It runs fully
standalone on an in-memory **mock backend by default** (`USE_MOCK=true`) — no
database, secrets, or external services are required. Supabase is an optional
backend only used when `USE_MOCK=false` (see `README.md`).

### Environment
- Flutter (stable, ~3.47 / Dart ~3.13) is preinstalled at `/opt/flutter` and
  symlinked into `/usr/local/bin`, so `flutter`/`dart` are on `PATH` for all
  shells. Chrome is at `/usr/local/bin/google-chrome`.
- The startup update script runs only `flutter pub get`.

### Non-obvious caveats
- `flutter pub get` auto-rewrites `analysis_options.yaml` (adds an `analyzer:
  exclude:` block for platform/build dirs) and bumps a few Flutter-SDK-pinned
  transitive packages in `pubspec.lock`. This regenerates on every run; it is
  safe to leave uncommitted or `git checkout --` those two files.
- Do **not** run `flutter create` as routine setup. `android/` and `web/` are
  already tracked in the repo, so it is unnecessary, and it drops a default
  template `test/widget_test.dart` (a counter smoke test referencing `MyApp`)
  that does not match this app and **breaks `flutter test`**. If you ever run
  `flutter create`, delete `test/widget_test.dart` afterward.

### Run / build / lint / test
- Dev run: `flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0`
  then open `http://localhost:8080` in Chrome (`flutter run -d chrome` also
  works). The first web compile takes ~20-30s.
- Lint: `flutter analyze` (one pre-existing info-level lint in
  `lib/pages/register_page.dart` is expected).
- Test: `flutter test`.
- Build: `flutter build web --release --dart-define=USE_MOCK=true`.

### Seeded mock accounts (password `password123`)
`manager@siyam.test`, `staff@siyam.test`, `donor@siyam.test`. Mock data is
in-memory and resets on every restart.

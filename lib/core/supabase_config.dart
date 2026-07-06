/// Supabase project credentials.
///
/// These come from compile-time environment variables (via
/// `--dart-define-from-file`), NOT hardcoded values -- so the real
/// project URL/key never gets committed to source control.
///
/// Setup: see env/README.md. Short version:
///   1. Copy env/config.example.json to env/config.json
///   2. Fill in your real values from Supabase Dashboard -> Project
///      Settings -> API
///   3. Run with: flutter run -d chrome --dart-define-from-file=env/config.json
///      (or just hit Run/F5 in VS Code -- .vscode/launch.json already
///      passes that flag for you)
///
/// env/config.json is gitignored. If either value below is empty, main.dart
/// shows a clear on-screen error instead of silently hitting the wrong host.
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');

  static const String publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
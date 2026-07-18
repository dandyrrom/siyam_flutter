/// Supabase connection settings, injected at build time via --dart-define
/// (typically through `--dart-define-from-file=env/supabase.json`).
///
/// The publishable/anon key is safe to ship in a client build -- access is
/// enforced server-side by Row Level Security, not by hiding this key.
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True when both values were provided at build time.
  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}

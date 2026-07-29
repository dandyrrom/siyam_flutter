import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/supabase_config.dart';
import 'mock/mock_database.dart';
import 'services/backend.dart';
import 'state/auth_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kUseMock) {
    MockDatabase.instance.seed();
  } else {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'USE_MOCK=false but SUPABASE_URL/SUPABASE_ANON_KEY are not set. '
        'Run with --dart-define-from-file=env/supabase.json (or the '
        '"SIYAM (Chrome, Supabase)" launch config).',
      );
    }
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }

  assert(() {
    // ignore: avoid_print
    print(kUseMock
        ? '[SIYAM] Backend: MOCK (sessions do not survive refresh)'
        : '[SIYAM] Backend: SUPABASE (${SupabaseConfig.url})');
    return true;
  }());

  final auth = AuthController();
  // Restore any persisted GoTrue session before the first frame so a
  // browser refresh doesn't bounce through /login.
  await auth.restoreSession();

  runApp(
    ChangeNotifierProvider.value(
      value: auth,
      child: const SiyamApp(),
    ),
  );
}

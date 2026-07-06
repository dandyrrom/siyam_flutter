import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/supabase_config.dart';
import 'state/auth_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Real runtime check (not `assert`, which gets stripped in release
  // builds) -- if env/config.json wasn't passed in via
  // --dart-define-from-file, fail loudly with an on-screen error instead
  // of silently sending requests to the wrong host.
  if (!SupabaseConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthController()..init(),
      child: const SiyamApp(),
    ),
  );
}

/// Shown instead of the real app when Supabase config is missing, so the
/// failure is obvious instead of a confusing blank screen or 404s.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

@override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 48, color: Colors.orange),
                SizedBox(height: 16),
                Text(
                  'Missing Supabase configuration',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                Text(
                  'env/config.json is missing or wasn\'t passed in.\n\n'
                  'Run with:\n'
                  'flutter run -d chrome --dart-define-from-file=env/config.json\n\n'
                  'See env/README.md for setup steps.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/supabase_config.dart';
import 'state/auth_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(() {
    if (SupabaseConfig.url.contains('YOUR-PROJECT-REF') ||
        SupabaseConfig.publishableKey.contains('YOUR-SUPABASE')) {
      throw StateError(
        'SupabaseConfig still has placeholder values. '
        'Edit lib/core/supabase_config.dart with your real project URL '
        'and publishable/anon key from Supabase Dashboard -> Project Settings -> API.',
      );
    }
    return true;
  }());

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

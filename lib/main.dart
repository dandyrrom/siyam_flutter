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
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthController(),
      child: const SiyamApp(),
    ),
  );
}

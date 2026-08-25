import 'package:flutter/material.dart'; 
import 'package:provider/provider.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'app.dart'; 
import 'core/supabase_config.dart'; 
import 'mock/mock_database.dart'; 
import 'models/inventory_item.dart'; 
import 'services/backend.dart'; 
import 'services/settings_service.dart'; 
import 'state/auth_state.dart'; 
 
Future<void> main() async { 
  WidgetsFlutterBinding.ensureInitialized(); 

  // Backup screen instead of Flutter's raw red error page.
  ErrorWidget.builder = (_) => const Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh_rounded,
                size: 36,
                color: Color(0xFF6B7D6D),
              ),
              SizedBox(height: 12),
              Text(
                'Please refresh the page',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF202520),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'This can happen when several actions are processed close together.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
 
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
 
  // Load the low-stock threshold before any page can read it via 
  // lowStockPurchaseUnitThreshold. Only attempt this when a session was 
  // restored: system_settings' RLS policies require the authenticated role, 
  // so an anon-role request here would just fail with a 406. 
  if (auth.isAuthenticated) { 
    try { 
      final settings = await SettingsService().fetchSettings(); 
      lowStockPurchaseUnitThreshold = settings.lowStockThreshold; 
    } catch (_) { 
      // Keep the default seeded above if settings can't be loaded. 
    } 
  } 
 
  runApp( 
    ChangeNotifierProvider.value( 
      value: auth, 
      child: const SiyamApp(), 
    ), 
  ); 
} 
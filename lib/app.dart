import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'routing/app_router.dart';
import 'state/auth_state.dart';

class SiyamApp extends StatefulWidget {
  const SiyamApp({super.key});

  @override
  State<SiyamApp> createState() => _SiyamAppState();
}

class _SiyamAppState extends State<SiyamApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Built once. GoRouter re-evaluates redirects on its own whenever
    // authState (the refreshListenable) notifies listeners.
    _router = buildRouter(context.read<AuthController>());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SIYAM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}

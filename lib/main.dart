import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'mock/mock_database.dart';
import 'state/auth_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MockDatabase.instance.seed();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthController(),
      child: const SiyamApp(),
    ),
  );
}

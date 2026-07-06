import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.pets, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 20),
              const Text('SIYAM',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const Text('Dumaguete Animal Sanctuary',
                  style: TextStyle(color: AppColors.mutedForeground)),
              const SizedBox(height: 32),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () => context.go('/login'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Text('Sign In'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/register'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Text('Become a Donor'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

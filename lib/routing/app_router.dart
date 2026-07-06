import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/landing_page.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/inventory_page.dart';
import '../pages/inventory_item_page.dart';
import '../pages/donations_page.dart';
import '../pages/donor/impacts_page.dart';
import '../pages/donor/donation_history_page.dart';
import '../pages/reports_page.dart';
import '../pages/medical_records_page.dart';
import '../pages/animal_records_page.dart';
import '../pages/suppliers_page.dart';
import '../pages/audit_trail_page.dart';
import '../pages/profile_page.dart';
import '../pages/notifications_page.dart';
import '../pages/settings_page.dart';
import '../state/auth_state.dart';
import '../widgets/app_shell.dart';
import 'nav_config.dart';

const _publicPaths = {'/', '/login', '/register'};

GoRouter buildRouter(AuthController authState) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authState,
    redirect: (context, state) {
      final loggedIn = authState.isAuthenticated;
      final goingToPublic = _publicPaths.contains(state.matchedLocation);

      // Still resolving the session -> don't redirect yet.
      if (authState.status == AuthStatus.unknown) return null;

      if (!loggedIn && !goingToPublic) return '/login';
      if (loggedIn && (state.matchedLocation == '/login' || state.matchedLocation == '/register')) {
        return '/dashboard';
      }

      // Role gate: bounce a signed-in user away from a tab that isn't
      // theirs (e.g. a Donor typing /animal-records into the URL bar).
      if (loggedIn) {
        final allowedRoles = rolesAllowedFor(state.matchedLocation);
        final userRole = authState.profile?.role;
        if (allowedRoles != null && userRole != null && !allowedRoles.contains(userRole)) {
          return '/dashboard';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LandingPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),

      ShellRoute(
        builder: (context, state, child) {
          return AppShell(currentPath: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
          GoRoute(path: '/inventory', builder: (context, state) => const InventoryPage()),
          GoRoute(path: '/inventory', builder: (context, state) => const InventoryPage()),
          GoRoute(
            path: '/inventory/:id',
            builder: (context, state) =>
                InventoryItemPage(itemId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/donations', builder: (context, state) => const DonationsPage()),
          GoRoute(path: '/impacts', builder: (context, state) => const ImpactsPage()),
          GoRoute(
              path: '/donation-history',
              builder: (context, state) => const DonorDonationsPage()),
          GoRoute(path: '/reports', builder: (context, state) => const ReportsPage()),
          GoRoute(
              path: '/medical-records',
              builder: (context, state) => const MedicalRecordsPage()),
          GoRoute(
              path: '/animal-records',
              builder: (context, state) => const AnimalRecordsPage()),
          GoRoute(path: '/suppliers', builder: (context, state) => const SuppliersPage()),
          GoRoute(
              path: '/audit-trail',
              builder: (context, state) => const AuditTrailPage()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
          GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationsPage()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
}

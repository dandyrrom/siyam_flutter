import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/landing_page.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/inventory_page.dart';
import '../pages/inventory_item_page.dart';
import '../pages/donations_page.dart';
import '../pages/donor/donate_page.dart';
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
        // Every route below uses pageBuilder + NoTransitionPage instead of
        // builder. These are tab switches within the same app shell, not
        // full page navigations -- and Material's default animated page
        // transition (Zoom) briefly relayouts the outgoing tab's content
        // with squeezed constraints mid-animation, which throws spurious
        // "RenderFlex overflowed" errors for pages that render fine on
        // their own. Removing the transition removes the cause.
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardPage()),
          ),
          GoRoute(
            path: '/inventory',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: InventoryPage()),
          ),
          GoRoute(
            path: '/inventory/:id',
            pageBuilder: (context, state) => NoTransitionPage(
              child: InventoryItemPage(itemId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/donations',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DonationsPage()),
          ),
          GoRoute(
            path: '/donate',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DonatePage()),
          ),
          GoRoute(
            path: '/impacts',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ImpactsPage()),
          ),
          GoRoute(
            path: '/donation-history',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DonorDonationsPage()),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReportsPage()),
          ),
          GoRoute(
            path: '/medical-records',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MedicalRecordsPage()),
          ),
          GoRoute(
            path: '/animal-records',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AnimalRecordsPage()),
          ),
          GoRoute(
            path: '/suppliers',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SuppliersPage()),
          ),
          GoRoute(
            path: '/audit-trail',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AuditTrailPage()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
          GoRoute(
            path: '/notifications',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: NotificationsPage()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsPage()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
}

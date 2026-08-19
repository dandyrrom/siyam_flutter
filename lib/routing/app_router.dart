import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/app_user.dart';

import '../pages/login_page.dart';
import '../pages/register_page.dart';

import '../pages/dashboard_page.dart';
import '../pages/inventory_page.dart';
import '../pages/inventory_item_page.dart';
import '../pages/add_item_page.dart';
import '../pages/add_treatment_page.dart';
import '../pages/donations_page.dart';
import '../pages/submission_detail_page.dart';
import '../pages/purchase_orders_page.dart';
import '../pages/purchase_trans_page.dart';

import '../pages/dashboard/donor_dashboard.dart';
import '../pages/donor/donate_page.dart';
import '../pages/donor/impacts_page.dart';
import '../pages/donor/donation_history_page.dart';

import '../pages/reports_page.dart';
import '../pages/medical_records_page.dart';
import '../pages/animal_medical_history_page.dart';

import '../pages/treatment_detail_page.dart';
import '../pages/animal_records_page.dart';
import '../pages/suppliers_page.dart';
import '../pages/audit_trail_page.dart';
import '../pages/profile_page.dart';
import '../pages/notifications_page.dart';
import '../pages/notification_detail_page.dart';
import '../pages/settings_page.dart';

import '../widgets/notification_alerts.dart';
import '../state/auth_state.dart';
import '../widgets/app_shell.dart';

import 'nav_config.dart';

// ============================================================================
// PUBLIC ROUTES
// ============================================================================

const _publicPaths = {
  '/login',
  '/register',
};

// ============================================================================
// HOME ROUTE BY ROLE
// ============================================================================

String _homeForRole(AppRole? role) {
  if (role == AppRole.donor) {
    return '/donor';
  }

  return '/dashboard';
}

// ============================================================================
// ROUTER
// ============================================================================

GoRouter buildRouter(
  AuthController authState,
) {
  return GoRouter(
    initialLocation: '/login',

    refreshListenable:
        authState.routerRefreshListenable,

    // ========================================================================
    // AUTH + ROLE REDIRECT
    // ========================================================================

    redirect: (
      context,
      state,
    ) {
      final status =
          authState.status;

      final loggedIn =
          authState.isAuthenticated;

      final currentPath =
          state.matchedLocation;

      final goingToPublic =
          _publicPaths.contains(
        currentPath,
      );

      // ----------------------------------------------------------------------
      // 1. AUTH IS STILL BEING RESOLVED
      // ----------------------------------------------------------------------

      if (status ==
          AuthStatus.unknown) {
        return null;
      }

      // ----------------------------------------------------------------------
      // 2. USER IS NOT LOGGED IN
      // ----------------------------------------------------------------------

      if (!loggedIn) {
        if (!goingToPublic) {
          return '/login';
        }

        return null;
      }

      // ----------------------------------------------------------------------
      // 3. AUTHENTICATED USER NEEDS A PROFILE
      // ----------------------------------------------------------------------

      final userRole =
          authState.profile?.role;

      if (userRole == null) {
        return null;
      }

      final homeRoute =
          _homeForRole(userRole);

      // ----------------------------------------------------------------------
      // 4. LOGGED-IN USER VISITS LOGIN / REGISTER
      // ----------------------------------------------------------------------

      if (goingToPublic) {
        return homeRoute;
      }

      // ----------------------------------------------------------------------
      // 5. PREVENT DONORS FROM OPENING STAFF DASHBOARD
      // ----------------------------------------------------------------------

      if (userRole ==
              AppRole.donor &&
          currentPath ==
              '/dashboard') {
        return '/donor';
      }

      // ----------------------------------------------------------------------
      // 6. PREVENT STAFF/MANAGER FROM OPENING DONOR DASHBOARD
      // ----------------------------------------------------------------------

      if (userRole !=
              AppRole.donor &&
          currentPath == '/donor') {
        return '/dashboard';
      }

      // ----------------------------------------------------------------------
      // 7. ROLE GATE
      // ----------------------------------------------------------------------

      final allowedRoles =
          rolesAllowedFor(
        currentPath,
      );

      if (allowedRoles != null &&
          !allowedRoles.contains(
            userRole,
          )) {
        return homeRoute;
      }

      return null;
    },

    // ========================================================================
    // ROUTES
    // ========================================================================

    routes: [
      // ----------------------------------------------------------------------
      // PUBLIC
      // ----------------------------------------------------------------------

      GoRoute(
        path: '/login',
        pageBuilder: (
          context,
          state,
        ) =>
            const NoTransitionPage(
          child: LoginPage(),
        ),
      ),

      GoRoute(
        path: '/register',
        pageBuilder: (
          context,
          state,
        ) =>
            const NoTransitionPage(
          child: RegisterPage(),
        ),
      ),

      // ----------------------------------------------------------------------
      // AUTHENTICATED APPLICATION
      // ----------------------------------------------------------------------

      ShellRoute(
        builder: (
          context,
          state,
          child,
        ) {
          return AppShell(
            currentPath:
                state.matchedLocation,
            child: child,
          );
        },
        routes: [
          // ==================================================================
          // DONOR DASHBOARD
          // ==================================================================

          GoRoute(
            path: '/donor',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child: DonorDashboard(),
            ),
          ),

          // ==================================================================
          // STAFF DASHBOARD
          // ==================================================================

          GoRoute(
            path: '/dashboard',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child: DashboardPage(),
            ),
          ),

          // ==================================================================
          // INVENTORY
          // ==================================================================

          GoRoute(
            path: '/inventory',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child: InventoryPage(),
            ),
          ),

          GoRoute(
            path: '/inventory/add',
            pageBuilder: (
              context,
              state,
            ) =>
                NoTransitionPage(
              child: AddItemPage(
                itemId: state
                    .uri
                    .queryParameters['itemId'],
                type: state
                    .uri
                    .queryParameters['type'],
                subId: state
                    .uri
                    .queryParameters['subId'],
              ),
            ),
          ),

          GoRoute(
            path: '/inventory/:id',
            pageBuilder: (
              context,
              state,
            ) =>
                NoTransitionPage(
              child: InventoryItemPage(
                itemId: state
                    .pathParameters['id']!,
              ),
            ),
          ),

          // ==================================================================
          // STAFF DONATIONS
          // ==================================================================

          GoRoute(
            path: '/donations',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child: DonationsPage(),
            ),
          ),

          GoRoute(
            path: '/donations/:id',
            pageBuilder: (
              context,
              state,
            ) =>
                NoTransitionPage(
              child:
                  SubmissionDetailPage(
                subId: state
                    .pathParameters['id']!,
              ),
            ),
          ),

          // ==================================================================
          // DONOR PAGES
          // ==================================================================

          GoRoute(
            path: '/donate',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child: DonatePage(),
            ),
          ),

          GoRoute(
            path: '/impacts',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child: ImpactsPage(),
            ),
          ),

          GoRoute(
            path:
                '/donation-history',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child:
                  DonorDonationsPage(),
            ),
          ),

          // ==================================================================
          // PURCHASES & REPLENISHMENT
          // ==================================================================
          //
          // Main combined staff module.
          // ==================================================================

          GoRoute(
            path:
                '/purchase-orders',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child:
                  PurchaseOrdersPage(),
            ),
          ),

          GoRoute(
            path:
                '/purchase-orders/:id',
            pageBuilder: (
              context,
              state,
            ) =>
                NoTransitionPage(
              child: PurchaseTransPage(
                purId: state
                    .pathParameters['id']!,
              ),
            ),
          ),

          // ------------------------------------------------------------------
          // LEGACY REPLENISHMENT ROUTE
          // ------------------------------------------------------------------
          //
          // Existing dashboard links/bookmarks do not break. They are forwarded
          // into the merged module.
          // ------------------------------------------------------------------

          GoRoute(
            path: '/replenishment',
            redirect: (
              context,
              state,
            ) =>
                '/purchase-orders',
          ),

          // ==================================================================
          // REPORTS
          // ==================================================================

          GoRoute(
            path: '/reports',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child: ReportsPage(),
            ),
          ),

          // ==================================================================
          // MEDICAL RECORDS
          // ==================================================================

          GoRoute(
            path:
                '/medical-records',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child:
                  MedicalRecordsPage(),
            ),
          ),

          GoRoute(
            path:
                '/medical-records/add',
            pageBuilder: (
              context,
              state,
            ) =>
                NoTransitionPage(
              child: AddTreatmentPage(
                prefillItemId: state
                    .uri
                    .queryParameters['itemId'],
                prefillQty: state
                    .uri
                    .queryParameters['qty'],
              ),
            ),
          ),

          GoRoute(
            path:
                '/medical-records/pet/:petId',
            pageBuilder: (
              context,
              state,
            ) =>
                NoTransitionPage(
              child:
                  AnimalMedicalHistoryPage(
                petId: state
                    .pathParameters['petId']!,
              ),
            ),
          ),

          GoRoute(
            path:
                '/medical-records/:id',
            pageBuilder: (
              context,
              state,
            ) =>
                NoTransitionPage(
              child:
                  TreatmentDetailPage(
                treatId: state
                    .pathParameters['id']!,
              ),
            ),
          ),

          // ==================================================================
          // ANIMAL RECORDS
          // ==================================================================

          GoRoute(
            path: '/animal-records',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child:
                  AnimalRecordsPage(),
            ),
          ),

          // ==================================================================
          // SUPPLIERS
          // ==================================================================

          GoRoute(
            path: '/suppliers',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child: SuppliersPage(),
            ),
          ),

          // ==================================================================
          // AUDIT
          // ==================================================================

          GoRoute(
            path: '/audit-trail',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child: AuditTrailPage(),
            ),
          ),

          // ==================================================================
          // PROFILE
          // ==================================================================

          GoRoute(
            path: '/profile',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child: ProfilePage(),
            ),
          ),

          // ==================================================================
          // NOTIFICATIONS
          // ==================================================================

          GoRoute(
            path: '/notifications',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child:
                  NotificationsPage(),
            ),
          ),

          GoRoute(
            path:
                '/notifications/:kind/:id',
            pageBuilder: (
              context,
              state,
            ) {
              final kind =
                  NotifKindRoute
                          .fromRouteSegment(
                        state.pathParameters[
                            'kind']!,
                      ) ??
                      NotifKind.zeroStock;

              return NoTransitionPage(
                child:
                    NotificationDetailPage(
                  kind: kind,
                  itemId: state
                      .pathParameters['id']!,
                ),
              );
            },
          ),

          // ==================================================================
          // SETTINGS
          // ==================================================================

          GoRoute(
            path: '/settings',
            pageBuilder: (
              context,
              state,
            ) =>
                const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
        ],
      ),
    ],

    // ========================================================================
    // UNKNOWN ROUTE
    // ========================================================================

    errorBuilder: (
      context,
      state,
    ) {
      return Scaffold(
        body: Center(
          child: Text(
            'Page not found: ${state.uri}',
          ),
        ),
      );
    },
  );
}

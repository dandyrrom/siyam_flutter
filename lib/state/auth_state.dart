import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

// ============================================================================
// AUTH STATUS
// ============================================================================

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
}

// ============================================================================
// AUTH CONTROLLER
// ============================================================================

/// Central authentication/session state for SIYAM.
///
/// There are two separate notification systems:
///
/// 1. notifyListeners()
///    → Provider/UI updates
///
/// 2. routerRefreshListenable
///    → GoRouter authentication redirects
///
/// Normal UI changes should not unnecessarily rebuild the route tree.
class AuthController extends ChangeNotifier {
  final AuthService _authService =
      AuthService();

  // ==========================================================================
  // ROUTER REFRESH NOTIFIER
  // ==========================================================================

  final ValueNotifier<int>
      _routerRefresh =
      ValueNotifier<int>(0);

  Listenable get routerRefreshListenable =>
      _routerRefresh;

  // ==========================================================================
  // AUTH STATE
  // ==========================================================================

  AuthStatus status =
      AuthStatus.unknown;

  AppUser? profile;

  String? errorMessage;

  bool isBusy = false;

  // ==========================================================================
  // SINGLE-DEVICE SESSION HEARTBEAT
  // ==========================================================================

  Timer? _sessionHeartbeat;
  bool _heartbeatInFlight = false;

  // ==========================================================================
  // GETTERS
  // ==========================================================================

  bool get isAuthenticated =>
      status ==
      AuthStatus.authenticated;

  bool get isAuthResolved =>
      status !=
      AuthStatus.unknown;

  // ==========================================================================
  // AUTH STATUS CHANGE
  // ==========================================================================

  /// Used for login, registration and session restoration.
  ///
  /// Logout intentionally does NOT use this helper because logout uses one
  /// explicit navigation from the UI after Supabase successfully signs out.
  void _setStatus(
    AuthStatus newStatus,
  ) {
    if (status ==
        newStatus) {
      return;
    }

    status =
        newStatus;

    _routerRefresh.value++;
  }

  // ==========================================================================
  // SINGLE-DEVICE SESSION HEARTBEAT
  // ==========================================================================
  //
  // While the account is authenticated, SIYAM refreshes the active-session
  // timestamp every 30 seconds.
  //
  // If this browser/device no longer owns the active session, it is signed out
  // and GoRouter is refreshed to the login page.
  // ==========================================================================

  void _startSessionHeartbeat() {
    _sessionHeartbeat?.cancel();

    if (!isAuthenticated) {
      return;
    }

    _sessionHeartbeat = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        _verifyActiveSession();
      },
    );
  }

  void _stopSessionHeartbeat() {
    _sessionHeartbeat?.cancel();
    _sessionHeartbeat = null;
  }

  Future<void> _verifyActiveSession() async {
    if (_heartbeatInFlight ||
        !isAuthenticated) {
      return;
    }

    _heartbeatInFlight = true;

    try {
      final valid =
          await _authService.touchSession();

      if (valid ||
          !isAuthenticated) {
        return;
      }

      _stopSessionHeartbeat();

      try {
        await _authService.signOut();
      } catch (_) {
        // Even if the local Supabase sign-out cannot complete, immediately
        // remove access to the authenticated SIYAM interface.
      }

      profile = null;
      errorMessage =
          'Your account is no longer active on this device. Please sign in again.';

      _setStatus(
        AuthStatus.unauthenticated,
      );

      notifyListeners();
    } catch (_) {
      // Temporary connection failures do not log the user out.
      // The next heartbeat will try again.
    } finally {
      _heartbeatInFlight = false;
    }
  }

  // ==========================================================================
  // RESTORE SESSION
  // ==========================================================================

  Future<void>
      restoreSession() async {
    errorMessage = null;
    profile = null;

    _stopSessionHeartbeat();

    _setStatus(
      AuthStatus.unknown,
    );

    notifyListeners();

    try {
      final user =
          await _authService
              .restoreSession();

      if (user != null) {
        profile = user;

        _setStatus(
          AuthStatus.authenticated,
        );

        _startSessionHeartbeat();
      } else {
        profile = null;

        _setStatus(
          AuthStatus.unauthenticated,
        );
      }
    } catch (_) {
      profile = null;

      _setStatus(
        AuthStatus.unauthenticated,
      );
    }

    notifyListeners();
  }

  // ==========================================================================
  // LOGIN
  // ==========================================================================

  Future<bool> login(
    String email,
    String password,
  ) async {
    if (isBusy) {
      return false;
    }

    isBusy = true;
    errorMessage = null;
    profile = null;

    _stopSessionHeartbeat();

    _setStatus(
      AuthStatus.unknown,
    );

    notifyListeners();

    try {
      final user =
          await _authService
              .signIn(
        email: email,
        password: password,
      );

      profile =
          user;

      _setStatus(
        AuthStatus.authenticated,
      );

      _startSessionHeartbeat();

      return true;
    } catch (e) {
      profile = null;

      _setStatus(
        AuthStatus.unauthenticated,
      );

      errorMessage = e
          .toString()
          .replaceFirst(
            'Exception: ',
            '',
          );

      return false;
    } finally {
      isBusy = false;

      notifyListeners();
    }
  }

  // ==========================================================================
  // REGISTER DONOR
  // ==========================================================================

  Future<bool> registerDonor({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? contactNum,
  }) async {
    if (isBusy) {
      return false;
    }

    isBusy = true;
    errorMessage = null;
    profile = null;

    _stopSessionHeartbeat();

    // Keep the router neutral while Supabase creates the account.
    // Registration should NOT send the user into the authenticated app.
    _setStatus(
      AuthStatus.unknown,
    );

    notifyListeners();

    try {
      final user =
          await _authService
              .signUpDonor(
        firstName:
            firstName,
        lastName:
            lastName,
        email:
            email,
        password:
            password,
        contactNum:
            contactNum,
      );

      // Public SIYAM registration is donor-only.
      //
      // Both the mock and Supabase service already create donor accounts.
      // This guard prevents the public registration flow from accepting any
      // unexpected Staff / Manager profile.
      if (user.role != AppRole.donor) {
        try {
          await _authService.signOut();
        } catch (_) {
          // Continue to reject the registration flow even if cleanup fails.
        }

        throw Exception(
          'Public registration can only create donor accounts.',
        );
      }

      // Supabase may create a temporary authenticated session when email
      // confirmation is disabled. Clear that session before returning so the
      // user remains on the public auth flow and signs in normally afterward.
      await _authService.signOut();

      profile = null;

      _setStatus(
        AuthStatus.unauthenticated,
      );

      return true;
    } catch (e) {
      profile = null;

      _setStatus(
        AuthStatus.unauthenticated,
      );

      errorMessage = e
          .toString()
          .replaceFirst(
            'Exception: ',
            '',
          );

      return false;
    } finally {
      isBusy = false;

      notifyListeners();
    }
  }

  // ==========================================================================
  // LOGOUT
  // ==========================================================================
  //
  // SIMPLE LOGOUT FLOW:
  //
  // 1. Sign out from Supabase.
  // 2. Clear the local authenticated user.
  // 3. Set auth status directly to unauthenticated.
  // 4. Return true.
  // 5. SideNav / MobileDrawer performs ONE context.go('/login').
  //
  // IMPORTANT:
  //
  // Logout does NOT call:
  //
  //   _setStatus(...)
  //   _routerRefresh.value++
  //   notifyListeners()
  //
  // on success.
  //
  // This avoids GoRouter destroying the authenticated widget tree while the
  // logout button callback is still executing.
  // ==========================================================================

  Future<bool> logout() async {
    if (isBusy) {
      return false;
    }

    isBusy = true;
    errorMessage = null;

    _stopSessionHeartbeat();

    try {
      // ----------------------------------------------------------------------
      // SUPABASE SIGN OUT
      // ----------------------------------------------------------------------

      await _authService
          .signOut();

      // ----------------------------------------------------------------------
      // CLEAR LOCAL SESSION
      // ----------------------------------------------------------------------

      profile =
          null;

      status =
          AuthStatus.unauthenticated;

      isBusy =
          false;

      // ----------------------------------------------------------------------
      // DO NOT notify or refresh GoRouter here.
      //
      // side_nav.dart / mobile_drawer.dart will navigate once to:
      //
      // context.go('/login');
      // ----------------------------------------------------------------------

      return true;
    } catch (e) {
      isBusy =
          false;

      errorMessage = e
          .toString()
          .replaceFirst(
            'Exception: ',
            '',
          );

      // Logout failed, so the authenticated page remains mounted.
      // It is safe to update the UI with the error.
      if (isAuthenticated) {
        _startSessionHeartbeat();
      }

      notifyListeners();

      return false;
    }
  }

  // ==========================================================================
  // UPDATE PROFILE
  // ==========================================================================

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    String? contactNum,
  }) async {
    final userId =
        profile?.userId;

    if (userId == null ||
        isBusy) {
      return false;
    }

    isBusy = true;
    errorMessage = null;

    notifyListeners();

    bool success =
        false;

    try {
      final updatedProfile =
          await _authService
              .updateProfile(
        userId:
            userId,
        firstName:
            firstName,
        lastName:
            lastName,
        contactNum:
            contactNum,
      );

      profile =
          updatedProfile;

      success =
          true;
    } catch (_) {
      errorMessage =
          'Could not update your profile. Please try again.';
    } finally {
      isBusy =
          false;

      notifyListeners();
    }

    return success;
  }

  // ==========================================================================
  // CHANGE PASSWORD
  // ==========================================================================

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final userId =
        profile?.userId;

    if (userId == null ||
        isBusy) {
      return false;
    }

    isBusy = true;
    errorMessage = null;

    notifyListeners();

    bool success =
        false;

    try {
      await _authService
          .changePassword(
        userId:
            userId,
        currentPassword:
            currentPassword,
        newPassword:
            newPassword,
      );

      // Password verification may rotate the Supabase session.
      // The service transfers the SIYAM lock; touch it once immediately.
      await _authService.touchSession();

      success =
          true;
    } catch (e) {
      errorMessage = e
          .toString()
          .replaceFirst(
            'Exception: ',
            '',
          );
    } finally {
      isBusy =
          false;

      notifyListeners();
    }

    return success;
  }

  // ==========================================================================
  // CLEANUP
  // ==========================================================================

  @override
  void dispose() {
    _stopSessionHeartbeat();

    _routerRefresh
        .dispose();

    super.dispose();
  }
}
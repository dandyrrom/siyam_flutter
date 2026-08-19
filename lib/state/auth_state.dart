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
///    → GoRouter authentication redirects only
///
/// This prevents normal UI changes such as isBusy/profile updates from
/// unnecessarily forcing GoRouter to re-process the route tree.
class AuthController extends ChangeNotifier {
  final AuthService _authService =
      AuthService();

  // ==========================================================================
  // ROUTER REFRESH NOTIFIER
  // ==========================================================================
  //
  // IMPORTANT:
  // GoRouter should listen to THIS instead of the entire AuthController.
  //
  final ValueNotifier<int> _routerRefresh =
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
  //
  // ROUTER LOCATOR:
  // This is the ONLY helper that refreshes GoRouter.
  //
  void _setStatus(
    AuthStatus newStatus,
  ) {
    if (status == newStatus) {
      return;
    }

    status = newStatus;

    // ------------------------------------------------------------------------
    // ROUTER REFRESH:
    // Only authentication-state changes should cause route redirects.
    // ------------------------------------------------------------------------
    _routerRefresh.value++;
  }

  // ==========================================================================
  // RESTORE SESSION
  // ==========================================================================

  Future<void> restoreSession() async {
    errorMessage = null;
    profile = null;

    // ------------------------------------------------------------------------
    // AUTH RESOLUTION:
    // Session state is temporarily unresolved.
    // ------------------------------------------------------------------------
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

    // ------------------------------------------------------------------------
    // UI UPDATE:
    // Update Provider widgets after session resolution.
    // ------------------------------------------------------------------------
    notifyListeners();
  }

  // ==========================================================================
  // LOGIN
  // ==========================================================================

  Future<bool> login(
    String email,
    String password,
  ) async {
    // ------------------------------------------------------------------------
    // DOUBLE-SUBMISSION GUARD
    // ------------------------------------------------------------------------
    if (isBusy) {
      return false;
    }

    isBusy = true;
    errorMessage = null;

    profile = null;

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

      // ----------------------------------------------------------------------
      // LOGIN SUCCESS
      // ----------------------------------------------------------------------

      profile = user;

      _setStatus(
        AuthStatus.authenticated,
      );

      return true;
    } catch (e) {
      // ----------------------------------------------------------------------
      // LOGIN FAILED
      // ----------------------------------------------------------------------

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
    // ------------------------------------------------------------------------
    // DOUBLE-SUBMISSION GUARD
    // ------------------------------------------------------------------------

    if (isBusy) {
      return false;
    }

    isBusy = true;
    errorMessage = null;

    profile = null;

    _setStatus(
      AuthStatus.unknown,
    );

    notifyListeners();

    try {
      final user =
          await _authService
              .signUpDonor(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        contactNum: contactNum,
      );

      // ----------------------------------------------------------------------
      // REGISTRATION SUCCESS
      // ----------------------------------------------------------------------

      profile = user;

      _setStatus(
        AuthStatus.authenticated,
      );

      return true;
    } catch (e) {
      // ----------------------------------------------------------------------
      // REGISTRATION FAILED
      // ----------------------------------------------------------------------

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

  /// Logs the user out.
  ///
  /// IMPORTANT:
  ///
  /// SideNav and MobileDrawer should NOT manually navigate to /login.
  ///
  /// _setStatus(AuthStatus.unauthenticated) tells GoRouter to evaluate its
  /// redirect rule, and GoRouter handles the navigation.
  Future<void> logout() async {
    // ------------------------------------------------------------------------
    // DOUBLE-LOGOUT GUARD
    // ------------------------------------------------------------------------

    if (isBusy) {
      return;
    }

    isBusy = true;
    errorMessage = null;

    // ------------------------------------------------------------------------
    // LOGOUT IMPORTANT:
    //
    // Do NOT call notifyListeners() here.
    //
    // There is no reason to rebuild the authenticated AppShell immediately
    // before it is about to be removed.
    // ------------------------------------------------------------------------

    try {
      await _authService.signOut();
    } catch (e) {
      // ----------------------------------------------------------------------
      // LOGOUT ERROR
      // ----------------------------------------------------------------------
      //
      // Clear local authentication anyway.
      //
      errorMessage = e
          .toString()
          .replaceFirst(
            'Exception: ',
            '',
          );
    } finally {
  profile = null;
  isBusy = false;

  // ============================================================
  // LOGOUT ROUTER TRIGGER
  // ============================================================
  // GoRouter handles redirecting to /login.
  // Do not notify Provider while the protected widget tree
  // is being removed.
  _setStatus(AuthStatus.unauthenticated);

  // IMPORTANT:
  // No notifyListeners() here.
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

    bool success = false;

    try {
      final updatedProfile =
          await _authService
              .updateProfile(
        userId: userId,
        firstName: firstName,
        lastName: lastName,
        contactNum: contactNum,
      );

      // ----------------------------------------------------------------------
      // PROFILE UPDATE:
      // This should update Provider/UI, NOT trigger GoRouter.
      // ----------------------------------------------------------------------

      profile =
          updatedProfile;

      success = true;
    } catch (_) {
      errorMessage =
          'Could not update your profile. Please try again.';
    } finally {
      isBusy = false;

      // ----------------------------------------------------------------------
      // ONE FINAL UI NOTIFICATION
      // ----------------------------------------------------------------------

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

    bool success = false;

    try {
      await _authService
          .changePassword(
        userId: userId,
        currentPassword:
            currentPassword,
        newPassword:
            newPassword,
      );

      success = true;
    } catch (e) {
      errorMessage = e
          .toString()
          .replaceFirst(
            'Exception: ',
            '',
          );
    } finally {
      isBusy = false;

      notifyListeners();
    }

    return success;
  }

  // ==========================================================================
  // CLEANUP
  // ==========================================================================

  @override
  void dispose() {
    // ------------------------------------------------------------------------
    // ROUTER NOTIFIER CLEANUP
    // ------------------------------------------------------------------------

    _routerRefresh.dispose();

    super.dispose();
  }
}
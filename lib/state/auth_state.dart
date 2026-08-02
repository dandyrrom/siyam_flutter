import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Central auth/session state for the app. Exposed via Provider and also
/// passed to GoRouter as a refreshListenable so routes re-evaluate whenever
/// auth status changes.
///
/// Starts as [AuthStatus.unknown] until [restoreSession] finishes. On the
/// Supabase backend that reloads the persisted GoTrue session; on mock it
/// resolves immediately to unauthenticated (no persistence).
class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus status = AuthStatus.unknown;
  AppUser? profile;
  String? errorMessage;
  bool isBusy = false;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Reloads any persisted session into [profile]. Call once at startup
  /// (before or as the UI mounts) so a browser refresh stays signed in.
  Future<void> restoreSession() async {
    try {
      final user = await _authService.restoreSession();
      if (user != null) {
        profile = user;
        status = AuthStatus.authenticated;
      } else {
        profile = null;
        status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      profile = null;
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final user = await _authService.signIn(email: email, password: password);
      profile = user;
      status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> registerDonor({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? contactNum,
  }) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final user = await _authService.signUpDonor(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        contactNum: contactNum,
      );
      profile = user;
      status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
    profile = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    String? contactNum,
  }) async {
    final userId = profile?.userId;
    if (userId == null) return false;

    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      profile = await _authService.updateProfile(
        userId: userId,
        firstName: firstName,
        lastName: lastName,
        contactNum: contactNum,
      );
      return true;
    } catch (e) {
      errorMessage = 'Could not update your profile. Please try again.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final userId = profile?.userId;
    if (userId == null) return false;

    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _authService.changePassword(
        userId: userId,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}

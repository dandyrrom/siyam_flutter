import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Central auth/session state for the app. Exposed via Provider and
/// also passed to GoRouter as a refreshListenable so routes re-evaluate
/// whenever auth status changes.
class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus status = AuthStatus.unknown;
  AppUser? profile;
  String? errorMessage;
  bool isBusy = false;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  void init() {
    // React to sign-in / sign-out / token refresh events.
    _authService.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session == null) {
        status = AuthStatus.unauthenticated;
        profile = null;
        notifyListeners();
        return;
      }
      await _loadProfile(session.user.id);
    });

    // Handle the case where a session already exists on cold start.
    final existing = _authService.currentSession;
    if (existing != null) {
      _loadProfile(existing.user.id);
    } else {
      status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final p = await _authService.fetchProfile(userId);
      profile = p;
      status = p != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    } catch (_) {
      status = AuthStatus.unauthenticated;
      profile = null;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _authService.signIn(email: email, password: password);
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (e) {
      errorMessage = 'Something went wrong. Please try again.';
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
      await _authService.signUpDonor(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        contactNum: contactNum,
      );
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (e) {
      errorMessage = 'Could not create your account. Please try again.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() => _authService.signOut();
}

// ─────────────────────────────────────────────────────────────
//  admin_auth_provider.dart
//  Riverpod StateNotifier that owns ALL admin authentication state.
//
//  States:
//    initial         → cold start, session restoration in progress
//    loading         → sign-in / sign-out in progress
//    authenticated   → session valid AND role == "admin"
//    accessDenied    → logged in but role != "admin"
//    unauthenticated → no session / signed out
//    error           → network / credential error
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/domain/entities/auth_user_entity.dart';
import '../services/admin_auth_service.dart';

// ─────────────────────────────────────────────────────────────
//  Status enum
// ─────────────────────────────────────────────────────────────
enum AdminAuthStatus {
  initial,
  loading,
  authenticated,
  accessDenied,
  unauthenticated,
  error,
}

// ─────────────────────────────────────────────────────────────
//  Immutable state snapshot
// ─────────────────────────────────────────────────────────────
class AdminAuthState {
  final AdminAuthStatus status;
  final AuthUserEntity? user;
  final String? errorMessage;
  final AdminAuthErrorCode? errorCode;

  const AdminAuthState({
    this.status = AdminAuthStatus.initial,
    this.user,
    this.errorMessage,
    this.errorCode,
  });

  // ── Convenience booleans ──────────────────────────────────
  bool get isLoading         => status == AdminAuthStatus.loading;
  bool get isAuthenticated   => status == AdminAuthStatus.authenticated;
  bool get isAccessDenied    => status == AdminAuthStatus.accessDenied;
  bool get isUnauthenticated => status == AdminAuthStatus.unauthenticated;
  bool get hasError          => status == AdminAuthStatus.error;
  bool get isInitial         => status == AdminAuthStatus.initial;

  AdminAuthState copyWith({
    AdminAuthStatus? status,
    AuthUserEntity? user,
    String? errorMessage,
    AdminAuthErrorCode? errorCode,
    bool clearError = false,
    bool clearUser  = false,
  }) =>
      AdminAuthState(
        status:       status       ?? this.status,
        user:         clearUser    ? null : (user  ?? this.user),
        errorMessage: clearError   ? null : (errorMessage ?? this.errorMessage),
        errorCode:    clearError   ? null : (errorCode    ?? this.errorCode),
      );

  @override
  String toString() =>
      'AdminAuthState(status: $status, user: ${user?.email}, '
      'error: $errorMessage)';
}

// ─────────────────────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────────────────────
class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  final AdminAuthService _service;

  AdminAuthNotifier(this._service)
      : super(const AdminAuthState()) {
    _bootstrap();
  }

  // ── Cold-start: restore any existing admin session ────────
  Future<void> _bootstrap() async {
    try {
      if (!_service.isLoggedIn) {
        state = const AdminAuthState(
            status: AdminAuthStatus.unauthenticated);
        return;
      }

      final user = await _service.currentUser();
      if (user == null) {
        state = const AdminAuthState(
            status: AdminAuthStatus.unauthenticated);
        return;
      }

      if (!user.isAdmin) {
        // Session exists but for a non-admin – revoke it.
        await _service.signOut();
        state = const AdminAuthState(
          status: AdminAuthStatus.accessDenied,
          errorMessage:
              'This portal is for administrators only.',
        );
        return;
      }

      state = AdminAuthState(
        status: AdminAuthStatus.authenticated,
        user: user,
      );
    } catch (e) {
      state = AdminAuthState(
        status: AdminAuthStatus.unauthenticated,
        errorMessage: _mapGenericError(e),
      );
    }
  }

  // ── Sign in ───────────────────────────────────────────────
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AdminAuthStatus.loading, clearError: true);

    try {
      final user = await _service.signInWithEmail(
        email: email,
        password: password,
      );
      state = AdminAuthState(
        status: AdminAuthStatus.authenticated,
        user: user,
      );
    } on AdminAuthException catch (e) {
      state = AdminAuthState(
        status: e.code == AdminAuthErrorCode.accessDenied
            ? AdminAuthStatus.accessDenied
            : AdminAuthStatus.error,
        errorMessage: e.message,
        errorCode: e.code,
      );
    } on AuthException catch (e) {
      state = AdminAuthState(
        status: AdminAuthStatus.error,
        errorMessage: _mapSupabaseError(e.message),
        errorCode: AdminAuthErrorCode.invalidCredentials,
      );
    } catch (e) {
      state = AdminAuthState(
        status: AdminAuthStatus.error,
        errorMessage: _mapGenericError(e),
        errorCode: AdminAuthErrorCode.networkError,
      );
    }
  }

  // ── Sign out ──────────────────────────────────────────────
  Future<void> signOut() async {
    state = state.copyWith(status: AdminAuthStatus.loading, clearError: true);
    try {
      await _service.signOut();
    } catch (_) {
      // Ignore sign-out errors; treat as unauthenticated regardless.
    } finally {
      state = const AdminAuthState(
          status: AdminAuthStatus.unauthenticated);
    }
  }

  // ── Clear error / access-denied banner ───────────────────
  void clearError() {
    state = state.copyWith(
      status: AdminAuthStatus.unauthenticated,
      clearError: true,
    );
  }

  // ── Error mapping helpers ─────────────────────────────────
  static String _mapSupabaseError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login')) {
      return 'Invalid email or password.\nPlease check your credentials and try again.';
    }
    if (m.contains('email not confirmed')) {
      return 'Your email address has not been confirmed.\nCheck your inbox for a confirmation link.';
    }
    if (m.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment before trying again.';
    }
    if (m.contains('network')) {
      return 'A network error occurred. Please check your connection.';
    }
    return msg;
  }

  static String _mapGenericError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socketexception') || s.contains('network')) {
      return 'No internet connection. Please check your network.';
    }
    if (s.contains('timeout')) {
      return 'The request timed out. Please try again.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}

// ─────────────────────────────────────────────────────────────
//  Top-level provider
// ─────────────────────────────────────────────────────────────
final adminAuthProvider =
    StateNotifierProvider<AdminAuthNotifier, AdminAuthState>((ref) {
  return AdminAuthNotifier(ref.watch(adminAuthServiceProvider));
});

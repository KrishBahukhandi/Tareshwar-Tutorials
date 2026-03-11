// ─────────────────────────────────────────────────────────────
//  teacher_auth_provider.dart
//  Riverpod StateNotifier that owns ALL teacher-auth state.
//
//  States:
//    initial        → cold start, session check in progress
//    loading        → sign-in / sign-out in progress
//    authenticated  → user is a teacher, session is valid
//    accessDenied   → user logged in but role != "teacher"
//    unauthenticated→ no session
//    error          → network / credential error
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/domain/entities/auth_user_entity.dart';
import '../services/teacher_auth_service.dart';

// ─────────────────────────────────────────────────────────────
//  State enum
// ─────────────────────────────────────────────────────────────
enum TeacherAuthStatus {
  initial,
  loading,
  authenticated,
  accessDenied,
  unauthenticated,
  error,
}

// ─────────────────────────────────────────────────────────────
//  Immutable state
// ─────────────────────────────────────────────────────────────
class TeacherAuthState {
  final TeacherAuthStatus status;
  final AuthUserEntity? user;
  final String? errorMessage;
  final TeacherAuthErrorCode? errorCode;

  const TeacherAuthState({
    this.status = TeacherAuthStatus.initial,
    this.user,
    this.errorMessage,
    this.errorCode,
  });

  // ── Convenience booleans ──────────────────────────────────
  bool get isLoading         => status == TeacherAuthStatus.loading;
  bool get isAuthenticated   => status == TeacherAuthStatus.authenticated;
  bool get isAccessDenied    => status == TeacherAuthStatus.accessDenied;
  bool get isUnauthenticated => status == TeacherAuthStatus.unauthenticated;
  bool get hasError          => status == TeacherAuthStatus.error;
  bool get isInitial         => status == TeacherAuthStatus.initial;

  TeacherAuthState copyWith({
    TeacherAuthStatus? status,
    AuthUserEntity? user,
    String? errorMessage,
    TeacherAuthErrorCode? errorCode,
    bool clearError = false,
    bool clearUser  = false,
  }) =>
      TeacherAuthState(
        status:       status       ?? this.status,
        user:         clearUser    ? null : (user  ?? this.user),
        errorMessage: clearError   ? null : (errorMessage ?? this.errorMessage),
        errorCode:    clearError   ? null : (errorCode    ?? this.errorCode),
      );

  @override
  String toString() =>
      'TeacherAuthState(status: $status, user: ${user?.email}, '
      'error: $errorMessage)';
}

// ─────────────────────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────────────────────
class TeacherAuthNotifier extends StateNotifier<TeacherAuthState> {
  final TeacherAuthService _service;

  TeacherAuthNotifier(this._service)
      : super(const TeacherAuthState()) {
    _bootstrap();
  }

  // ── Cold-start: restore any existing teacher session ─────
  Future<void> _bootstrap() async {
    try {
      if (!_service.isLoggedIn) {
        state = const TeacherAuthState(
            status: TeacherAuthStatus.unauthenticated);
        return;
      }

      final user = await _service.currentUser();
      if (user == null) {
        state = const TeacherAuthState(
            status: TeacherAuthStatus.unauthenticated);
        return;
      }

      if (user.isTeacher) {
        state = TeacherAuthState(
          status: TeacherAuthStatus.authenticated,
          user: user,
        );
      } else {
        // Session belongs to a non-teacher — revoke it silently
        await _service.signOut();
        state = const TeacherAuthState(
          status: TeacherAuthStatus.accessDenied,
          errorMessage:
              'Access denied. This portal is for teachers only.',
        );
      }
    } catch (_) {
      state = const TeacherAuthState(
          status: TeacherAuthStatus.unauthenticated);
    }
  }

  // ── Sign in ───────────────────────────────────────────────
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
        status: TeacherAuthStatus.loading, clearError: true);

    try {
      final user = await _service.signInWithEmail(
        email: email,
        password: password,
      );
      state = TeacherAuthState(
        status: TeacherAuthStatus.authenticated,
        user: user,
      );
    } on TeacherAuthException catch (e) {
      state = TeacherAuthState(
        status: e.code == TeacherAuthErrorCode.accessDenied
            ? TeacherAuthStatus.accessDenied
            : TeacherAuthStatus.error,
        errorMessage: e.message,
        errorCode: e.code,
      );
    } on AuthException catch (e) {
      state = TeacherAuthState(
        status: TeacherAuthStatus.error,
        errorMessage: _mapSupabaseError(e.message),
        errorCode: TeacherAuthErrorCode.invalidCredentials,
      );
    } catch (e) {
      state = TeacherAuthState(
        status: TeacherAuthStatus.error,
        errorMessage: _mapGenericError(e),
        errorCode: TeacherAuthErrorCode.unknown,
      );
    }
  }

  // ── Sign out ──────────────────────────────────────────────
  Future<void> signOut() async {
    state = state.copyWith(status: TeacherAuthStatus.loading);
    try {
      await _service.signOut();
    } catch (_) {
      // Sign out locally even if network call fails
    }
    state = const TeacherAuthState(
        status: TeacherAuthStatus.unauthenticated);
  }

  // ── Dismiss error ─────────────────────────────────────────
  void clearError() {
    if (state.hasError || state.isAccessDenied) {
      state = TeacherAuthState(
        status: TeacherAuthStatus.unauthenticated,
      );
    }
  }

  // ── Error mapping ─────────────────────────────────────────
  String _mapSupabaseError(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('invalid') || m.contains('credentials') ||
        m.contains('wrong')) {
      return 'Wrong email or password. Please try again.';
    }
    if (m.contains('user not found') || m.contains('no user')) {
      return 'No account found with this email address.';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Too many attempts. Please wait a few minutes.';
    }
    if (m.contains('network') || m.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    return raw.isNotEmpty ? raw : 'Login failed. Please try again.';
  }

  String _mapGenericError(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('network') || m.contains('socket')) {
      return 'No internet connection. Please check your network.';
    }
    if (m.contains('timeout')) return 'Request timed out. Please retry.';
    return 'Something went wrong. Please try again.';
  }
}

// ─────────────────────────────────────────────────────────────
//  Public providers
// ─────────────────────────────────────────────────────────────

/// Primary teacher-auth state — watch this in all teacher screens.
final teacherAuthProvider =
    StateNotifierProvider<TeacherAuthNotifier, TeacherAuthState>((ref) {
  return TeacherAuthNotifier(ref.watch(teacherAuthServiceProvider));
});

/// Convenience: the signed-in teacher entity (null when logged out).
final teacherUserProvider = Provider<AuthUserEntity?>((ref) {
  return ref.watch(teacherAuthProvider).user;
});

/// True once the bootstrap session-check is done.
final teacherAuthReadyProvider = Provider<bool>((ref) {
  return ref.watch(teacherAuthProvider).status !=
      TeacherAuthStatus.initial;
});

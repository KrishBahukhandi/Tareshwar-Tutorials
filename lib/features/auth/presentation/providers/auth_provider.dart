// ─────────────────────────────────────────────────────────────
//  auth_provider.dart  –  Riverpod AuthState + AuthNotifier
//
//  ▸ Single source of truth for all authentication state.
//  ▸ Screens watch [authProvider]; navigation is driven by state.
//  ▸ Every public method is safe to call from any widget.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/services/supabase_service.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

// ─────────────────────────────────────────────────────────────
//  Internal dependency providers
// ─────────────────────────────────────────────────────────────
final _authRemoteDsProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(_authRemoteDsProvider));
});

// ─────────────────────────────────────────────────────────────
//  AuthStatus  –  all possible states
// ─────────────────────────────────────────────────────────────
enum AuthStatus {
  initial, // cold start – session check pending
  authenticated, // valid session + user loaded
  unauthenticated, // no session / signed out
  loading, // async operation in progress
  otpSent, // phone OTP dispatched; waiting for code input
  emailSent, // password-reset email dispatched
  verificationEmailSent, // signup requires email confirmation
  error, // last operation failed; errorMessage is set
}

// ─────────────────────────────────────────────────────────────
//  AuthState  –  immutable snapshot
// ─────────────────────────────────────────────────────────────
class AuthState {
  final AuthStatus status;
  final AuthUserEntity? user;
  final String? errorMessage;

  /// Phone number kept alive across the OTP flow
  final String? pendingPhone;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.pendingPhone,
  });

  // ── Convenience booleans ──────────────────────────────────
  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get hasError => status == AuthStatus.error;
  bool get otpSent => status == AuthStatus.otpSent;
  bool get emailSent => status == AuthStatus.emailSent;
  bool get verificationEmailSent => status == AuthStatus.verificationEmailSent;
  bool get isInitial => status == AuthStatus.initial;

  AuthState copyWith({
    AuthStatus? status,
    AuthUserEntity? user,
    String? errorMessage,
    String? pendingPhone,
    bool clearError = false,
    bool clearPhone = false,
    bool clearUser = false,
  }) => AuthState(
    status: status ?? this.status,
    user: clearUser ? null : (user ?? this.user),
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    pendingPhone: clearPhone ? null : (pendingPhone ?? this.pendingPhone),
  );

  @override
  String toString() =>
      'AuthState(status: $status, user: ${user?.id}, error: $errorMessage)';
}

// ─────────────────────────────────────────────────────────────
//  AuthNotifier
// ─────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState()) {
    _init();
  }

  // ── Bootstrap: restore session on cold start ──────────────
  Future<void> _init() async {
    try {
      final user = await _repo.fetchCurrentUser();
      state = AuthState(
        status: user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: user,
      );
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  // ── Email / Password sign-in ──────────────────────────────
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final user = await _repo.signInWithEmail(
        email: email,
        password: password,
      );
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _mapAuthError(e.message),
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _mapGenericError(e),
      );
    }
  }

  // ── Sign up ───────────────────────────────────────────────
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _repo.signUp(
        email: email,
        password: password,
        name: name,
      );
      await _repo.signOut();
      state = const AuthState(status: AuthStatus.verificationEmailSent);
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _mapAuthError(e.message),
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _mapGenericError(e),
      );
    }
  }

  // ── Phone OTP: send ───────────────────────────────────────
  Future<void> sendPhoneOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _repo.sendPhoneOtp(phone);
      state = state.copyWith(status: AuthStatus.otpSent, pendingPhone: phone);
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _mapAuthError(e.message),
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _mapGenericError(e),
      );
    }
  }

  // ── Phone OTP: verify ─────────────────────────────────────
  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final user = await _repo.verifyPhoneOtp(phone: phone, token: token);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _mapAuthError(e.message),
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _mapGenericError(e),
      );
    }
  }

  // ── Forgot password ───────────────────────────────────────
  Future<void> resetPassword(String email) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _repo.resetPassword(email);
      state = state.copyWith(status: AuthStatus.emailSent);
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _mapAuthError(e.message),
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _mapGenericError(e),
      );
    }
  }

  // ── Sign out ──────────────────────────────────────────────
  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.signOut();
    } catch (_) {
      // Sign out locally even if network fails
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // ── Utility actions ───────────────────────────────────────
  void clearError() => state = state.copyWith(
    clearError: true,
    status: state.status == AuthStatus.error
        ? AuthStatus.unauthenticated
        : state.status,
  );

  /// Put back into otpSent to let the user re-enter the code.
  void resetToOtpSent() =>
      state = state.copyWith(status: AuthStatus.otpSent, clearError: true);

  // ── Error message mapping ─────────────────────────────────
  String _mapAuthError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login') ||
        msg.contains('invalid credentials') ||
        msg.contains('wrong password')) {
      return 'Wrong email or password. Please try again.';
    }
    if (msg.contains('email already') || msg.contains('already registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('user not found') || msg.contains('no user')) {
      return 'No account found with this email.';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Too many attempts. Please try again in a few minutes.';
    }
    if (msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('host lookup') ||
        msg.contains('name_not_resolved') ||
        msg.contains('failed to fetch')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('expired')) {
      return 'OTP has expired. Please request a new one.';
    }
    if (msg.contains('invalid otp') ||
        msg.contains('otp verification') ||
        msg.contains('invalid_grant') ||
        msg.contains('type sms') ||
        msg.contains('type otp') ||
        msg.contains('otp')) {
      return 'Invalid OTP. Please check and try again.';
    }
    if (msg.contains('weak password')) {
      return 'Password is too weak. Use at least 8 characters with numbers.';
    }
    if (msg.contains('phone')) {
      return 'Invalid phone number format. Include country code (e.g. +91).';
    }
    return raw.isNotEmpty ? raw : 'Something went wrong. Please try again.';
  }

  String _mapGenericError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('disabled') || msg.contains('inactive')) {
      return 'Your account has been disabled. Please contact the institute administrator.';
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('host lookup') ||
        msg.contains('name_not_resolved') ||
        msg.contains('failed to fetch')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

// ─────────────────────────────────────────────────────────────
//  Public providers
// ─────────────────────────────────────────────────────────────

/// Primary auth state provider – watch this in every auth screen.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

/// Convenience: just the currently authenticated user (null = logged out).
final authUserProvider = Provider<AuthUserEntity?>((ref) {
  return ref.watch(authProvider).user;
});

/// True when the app has finished checking for an existing session.
final authReadyProvider = Provider<bool>((ref) {
  final status = ref.watch(authProvider).status;
  return status != AuthStatus.initial;
});

// ─────────────────────────────────────────────────────────────
//  admin_auth_service.dart
//  Admin-scoped authentication layer (Supabase).
//
//  Delegates actual network calls to the shared [AuthRepository],
//  but adds a strict role-gate: if the signed-in user does NOT
//  have role == "admin", the Supabase session is immediately
//  revoked and an [AdminAuthException] is thrown so the UI can
//  display an "Access Denied" screen.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../features/auth/domain/entities/auth_user_entity.dart';
import '../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';

/// Riverpod provider – wired to the shared [authRepositoryProvider].
final adminAuthServiceProvider = Provider<AdminAuthService>((ref) {
  return AdminAuthService(ref.watch(authRepositoryProvider));
});

// ─────────────────────────────────────────────────────────────
class AdminAuthService {
  final AuthRepository _repo;

  const AdminAuthService(this._repo);

  // ── Session helpers ───────────────────────────────────────

  /// `true` when a valid Supabase session exists.
  bool get isLoggedIn => _repo.isLoggedIn;

  /// Role string sourced from the JWT metadata (no network call).
  String? get currentRole => _repo.currentRole;

  /// Full profile of the currently authenticated user.
  /// Returns `null` when there is no active session.
  Future<AuthUserEntity?> currentUser() => _repo.fetchCurrentUser();

  // ── Sign in ───────────────────────────────────────────────

  /// Signs in via email + password and then enforces `role == "admin"`.
  ///
  /// Throws [AdminAuthException] with [AdminAuthErrorCode.accessDenied]
  /// when the credentials are valid but the account is not an admin.
  /// In that case the session is immediately revoked so the user is not
  /// left in a partially-authenticated state.
  Future<AuthUserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final user = await _repo.signInWithEmail(
      email: email,
      password: password,
    );

    if (user.role != AppConstants.roleAdmin) {
      // Revoke session immediately – don't leave a non-admin logged in.
      await _repo.signOut();
      throw AdminAuthException(
        'Access denied.\n'
        'This portal is for administrators only.\n'
        'Please use the correct app to sign in.',
        code: AdminAuthErrorCode.accessDenied,
      );
    }

    return user;
  }

  // ── Sign out ──────────────────────────────────────────────

  Future<void> signOut() => _repo.signOut();

  // ── Auth-state stream ─────────────────────────────────────

  /// Emits the current admin user whenever Supabase auth state changes.
  /// Emits `null` when there is no session or the user is not an admin.
  Stream<AuthUserEntity?> get adminAuthStream =>
      _repo.authStateStream.map((user) {
        if (user == null) return null;
        return user.isAdmin ? user : null;
      });
}

// ─────────────────────────────────────────────────────────────
//  Error types
// ─────────────────────────────────────────────────────────────
enum AdminAuthErrorCode {
  invalidCredentials,
  accessDenied,
  networkError,
  unknown,
}

class AdminAuthException implements Exception {
  final String message;
  final AdminAuthErrorCode code;

  const AdminAuthException(
    this.message, {
    this.code = AdminAuthErrorCode.unknown,
  });

  @override
  String toString() => 'AdminAuthException($code): $message';
}

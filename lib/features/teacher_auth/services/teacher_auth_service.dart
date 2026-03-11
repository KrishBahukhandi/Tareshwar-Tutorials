// ─────────────────────────────────────────────────────────────
//  teacher_auth_service.dart
//  Teacher-scoped authentication layer.
//
//  Delegates actual Supabase calls to AuthRepository (shared),
//  but adds a role-gate: if the signed-in user is not a teacher
//  the session is immediately revoked and an exception is thrown.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/domain/entities/auth_user_entity.dart';
import '../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';

/// Riverpod provider – wired to the shared [authRepositoryProvider].
final teacherAuthServiceProvider = Provider<TeacherAuthService>((ref) {
  return TeacherAuthService(ref.watch(authRepositoryProvider));
});

// ─────────────────────────────────────────────────────────────
class TeacherAuthService {
  final AuthRepository _repo;

  const TeacherAuthService(this._repo);

  // ── Session ───────────────────────────────────────────────

  /// Whether a Supabase session currently exists.
  bool get isLoggedIn => _repo.isLoggedIn;

  /// Role string from JWT metadata (fast, no network).
  String? get currentRole => _repo.currentRole;

  /// Full profile of the currently authenticated user.
  /// Returns `null` if no session exists.
  Future<AuthUserEntity?> currentUser() => _repo.fetchCurrentUser();

  // ── Sign in ───────────────────────────────────────────────

  /// Signs in with email + password **and** verifies `role == "teacher"`.
  ///
  /// Throws [TeacherAuthException] with an appropriate message if:
  ///   • Credentials are invalid  (propagated from Supabase)
  ///   • Role is not "teacher"    (access denied – session revoked)
  Future<AuthUserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final user = await _repo.signInWithEmail(
      email: email,
      password: password,
    );

    if (user.role != AppConstants.roleTeacher) {
      // Revoke the session so the user is not left in a half-logged-in state.
      await _repo.signOut();
      throw TeacherAuthException(
        'Access denied. This portal is for teachers only.\n'
        'Please use the student app to log in.',
        code: TeacherAuthErrorCode.accessDenied,
      );
    }

    return user;
  }

  // ── Sign out ──────────────────────────────────────────────

  Future<void> signOut() => _repo.signOut();

  // ── Session stream ────────────────────────────────────────

  /// Emits the current [AuthUserEntity] whenever Supabase auth state
  /// changes. Only emits non-null values whose role is "teacher".
  Stream<AuthUserEntity?> get teacherAuthStream =>
      _repo.authStateStream.map((user) {
        if (user == null) return null;
        return user.isTeacher ? user : null;
      });
}

// ─────────────────────────────────────────────────────────────
//  Custom exception
// ─────────────────────────────────────────────────────────────
enum TeacherAuthErrorCode {
  invalidCredentials,
  accessDenied,
  networkError,
  unknown,
}

class TeacherAuthException implements Exception {
  final String message;
  final TeacherAuthErrorCode code;

  const TeacherAuthException(
    this.message, {
    this.code = TeacherAuthErrorCode.unknown,
  });

  @override
  String toString() => 'TeacherAuthException[$code]: $message';
}

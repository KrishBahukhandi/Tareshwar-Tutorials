// ─────────────────────────────────────────────────────────────
//  auth_repository.dart  –  Abstract auth contract (domain)
// ─────────────────────────────────────────────────────────────
import '../entities/auth_user_entity.dart';

abstract class AuthRepository {
  /// True when a valid Supabase session exists.
  bool get isLoggedIn;

  /// The role string stored in JWT metadata.
  String? get currentRole;

  /// Stream that emits the current user whenever auth state changes.
  Stream<AuthUserEntity?> get authStateStream;

  // ── Email / Password ──────────────────────────────────────
  Future<AuthUserEntity> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUserEntity> signUp({
    required String email,
    required String password,
    required String name,
  });

  Future<void> resetPassword(String email);

  // ── Phone OTP ─────────────────────────────────────────────
  Future<void> sendPhoneOtp(String phone);

  Future<AuthUserEntity> verifyPhoneOtp({
    required String phone,
    required String token,
  });

  // ── Session ───────────────────────────────────────────────
  Future<void> signOut();

  Future<AuthUserEntity?> fetchCurrentUser();
}

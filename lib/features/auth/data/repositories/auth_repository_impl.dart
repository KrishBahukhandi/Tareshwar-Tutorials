// ─────────────────────────────────────────────────────────────
//  auth_repository_impl.dart  –  Concrete auth repository
// ─────────────────────────────────────────────────────────────
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  AuthRepositoryImpl(this._remote);

  @override
  bool get isLoggedIn => _remote.isLoggedIn;

  @override
  String? get currentRole => _remote.currentRole;

  @override
  Stream<AuthUserEntity?> get authStateStream => _remote.authStateStream;

  @override
  Future<AuthUserEntity> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _remote.signInWithEmail(email: email, password: password);

  @override
  Future<AuthUserEntity> signUp({
    required String email,
    required String password,
    required String name,
  }) =>
      _remote.signUp(email: email, password: password, name: name);

  @override
  Future<void> resetPassword(String email) => _remote.resetPassword(email);

  @override
  Future<void> sendPhoneOtp(String phone) => _remote.sendPhoneOtp(phone);

  @override
  Future<AuthUserEntity> verifyPhoneOtp({
    required String phone,
    required String token,
  }) =>
      _remote.verifyPhoneOtp(phone: phone, token: token);

  @override
  Future<void> signOut() => _remote.signOut();

  @override
  Future<AuthUserEntity?> fetchCurrentUser() => _remote.fetchCurrentUser();
}

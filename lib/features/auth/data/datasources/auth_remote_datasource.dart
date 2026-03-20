// ─────────────────────────────────────────────────────────────
//  auth_remote_datasource.dart  –  Supabase auth data source
// ─────────────────────────────────────────────────────────────
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart' as supa show User;
import '../../domain/entities/auth_user_entity.dart';

class AuthRemoteDataSource {
  final SupabaseClient _client;
  AuthUserEntity? _currentProfile;

  AuthRemoteDataSource(this._client);

  // ── Helpers ───────────────────────────────────────────────
  Future<AuthUserEntity> _profileFromId(String userId) async {
    final data = await _client.from('users').select().eq('id', userId).single();
    return _entityFromJson(data);
  }

  AuthUserEntity _entityFromJson(Map<String, dynamic> j) => AuthUserEntity(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Student',
    email: j['email'] as String? ?? '',
    phone: j['phone'] as String?,
    role: j['role'] as String? ?? 'student',
    avatarUrl: j['avatar_url'] as String?,
    isActive: j['is_active'] as bool? ?? true,
    createdAt: j['created_at'] != null
        ? DateTime.parse(j['created_at'] as String)
        : DateTime.now(),
  );

  Future<AuthUserEntity> _loadAndValidateProfile(String userId) async {
    final profile = await _profileFromId(userId);
    _currentProfile = profile;

    if (!profile.isActive) {
      await _client.auth.signOut();
      throw const InactiveAccountException();
    }

    return profile;
  }

  // ── Auth state stream ─────────────────────────────────────
  Stream<AuthUserEntity?> get authStateStream async* {
    yield* _client.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) {
        _currentProfile = null;
        return null;
      }
      try {
        return await _loadAndValidateProfile(user.id);
      } catch (_) {
        return null;
      }
    });
  }

  bool get isLoggedIn => _client.auth.currentSession != null;
  String? get currentRole =>
      _currentProfile?.role ??
      _client.auth.currentUser?.userMetadata?['role'] as String?;

  // ── Email sign-in ─────────────────────────────────────────
  Future<AuthUserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.user == null) throw Exception('Login failed');
    return _loadAndValidateProfile(res.user!.id);
  }

  // ── Sign up ───────────────────────────────────────────────
  Future<AuthUserEntity> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'role': 'student'},
    );
    if (res.user == null) throw Exception('Sign up failed');

    // Upsert profile row
    await _client.from('users').upsert({
      'id': res.user!.id,
      'name': name,
      'email': email,
      'role': 'student',
    });

    return _loadAndValidateProfile(res.user!.id);
  }

  // ── Reset password ────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ── Phone OTP ─────────────────────────────────────────────
  Future<void> sendPhoneOtp(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  Future<AuthUserEntity> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    final res = await _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
    if (res.user == null) throw Exception('OTP verification failed');

    // Upsert minimal profile for new phone users
    await _client.from('users').upsert({
      'id': res.user!.id,
      'phone': phone,
      'role': 'student',
      'name': 'Student',
      'email': res.user!.email ?? '',
    });

    return _loadAndValidateProfile(res.user!.id);
  }

  // ── Sign out ──────────────────────────────────────────────
  Future<void> signOut() async {
    _currentProfile = null;
    await _client.auth.signOut();
  }

  // ── Fetch current user ────────────────────────────────────
  Future<AuthUserEntity?> fetchCurrentUser() async {
    final supa.User? user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      return await _loadAndValidateProfile(user.id);
    } catch (_) {
      return null;
    }
  }
}

class InactiveAccountException implements Exception {
  final String message;

  const InactiveAccountException([
    this.message =
        'Your account has been disabled. Please contact the institute administrator.',
  ]);

  @override
  String toString() => message;
}

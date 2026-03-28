// ─────────────────────────────────────────────────────────────
//  auth_service.dart  –  Authentication service (Supabase)
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'supabase_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.userStream;
});

class AuthService {
  final SupabaseClient _client;
  UserModel? _cachedProfile;

  AuthService(this._client);

  // ── State ─────────────────────────────────────────────────
  bool get isLoggedIn =>
      _client.auth.currentSession != null && (_cachedProfile?.isActive ?? true);
  User? get currentAuthUser => _client.auth.currentUser;
  String? get currentRole =>
      _cachedProfile?.role ??
      _client.auth.currentUser?.userMetadata?['role'] as String?;

  Future<UserModel> _loadAndValidateProfile(String userId) async {
    final profile = await fetchUserProfile(userId);
    if (!profile.isActive) {
      await _client.auth.signOut();
      throw const AccountDisabledException();
    }
    return profile;
  }

  // ── User stream ───────────────────────────────────────────
  Stream<UserModel?> get userStream async* {
    final authStream = _client.auth.onAuthStateChange;
    await for (final event in authStream) {
      if (event.session?.user != null) {
        try {
          yield await _loadAndValidateProfile(event.session!.user.id);
        } catch (_) {
          yield null;
        }
      } else {
        _cachedProfile = null;
        yield null;
      }
    }
  }

  // ── Sign up ───────────────────────────────────────────────
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    String role = AppConstants.roleStudent,
  }) async {
    final redirectTo = AppConstants.authRedirectUrl.isEmpty
        ? null
        : AppConstants.authRedirectUrl;
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'role': role},
      emailRedirectTo: redirectTo,
    );

    if (res.user == null) throw Exception('Sign up failed');

    // Insert into users table
    await _client.from('users').upsert({
      'id': res.user!.id,
      'name': name,
      'email': email,
      'role': role,
    });

    return _loadAndValidateProfile(res.user!.id);
  }

  // ── Sign in with email ────────────────────────────────────
  Future<UserModel> signInWithEmail({
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

  // ── Phone OTP ─────────────────────────────────────────────
  Future<void> sendPhoneOtp(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  Future<UserModel> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    final res = await _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
    if (res.user == null) throw Exception('OTP verification failed');

    // Upsert user profile
    await _client.from('users').upsert({
      'id': res.user!.id,
      'phone': phone,
      'role': AppConstants.roleStudent,
      'name': 'Student',
      'email': res.user!.email ?? '',
    });

    return _loadAndValidateProfile(res.user!.id);
  }

  // ── Forgot password ───────────────────────────────────────
  Future<void> resetPassword(String email) async {
    final redirectTo = AppConstants.authRedirectUrl.isEmpty
        ? null
        : AppConstants.authRedirectUrl;
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: redirectTo,
    );
  }

  // ── Sign out ──────────────────────────────────────────────
  Future<void> signOut() async {
    _cachedProfile = null;
    await _client.auth.signOut();
  }

  // ── Fetch profile ─────────────────────────────────────────
  Future<UserModel> fetchUserProfile(String userId) async {
    final data = await _client.from('users').select().eq('id', userId).single();
    final profile = UserModel.fromJson(data);
    _cachedProfile = profile;
    return profile;
  }

  // ── Update profile ────────────────────────────────────────
  Future<void> updateProfile({
    required String userId,
    String? name,
    String? avatarUrl,
    String? phone,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (phone != null) updates['phone'] = phone;

    await _client.from('users').update(updates).eq('id', userId);
  }
}

class AccountDisabledException implements Exception {
  final String message;

  const AccountDisabledException([
    this.message =
        'Your account has been disabled. Please contact the institute administrator.',
  ]);

  @override
  String toString() => message;
}

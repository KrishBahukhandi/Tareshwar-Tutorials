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

  AuthService(this._client);

  // ── State ─────────────────────────────────────────────────
  bool get isLoggedIn => _client.auth.currentSession != null;
  User? get currentAuthUser => _client.auth.currentUser;
  String? get currentRole => _client.auth.currentUser?.userMetadata?['role'] as String?;

  // ── User stream ───────────────────────────────────────────
  Stream<UserModel?> get userStream async* {
    final authStream = _client.auth.onAuthStateChange;
    await for (final event in authStream) {
      if (event.session?.user != null) {
        yield await fetchUserProfile(event.session!.user.id);
      } else {
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
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'role': role},
    );

    if (res.user == null) throw Exception('Sign up failed');

    // Insert into users table
    await _client.from('users').insert({
      'id': res.user!.id,
      'name': name,
      'email': email,
      'role': role,
    });

    return UserModel(
      id: res.user!.id,
      name: name,
      email: email,
      role: role,
      createdAt: DateTime.now(),
    );
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
    return fetchUserProfile(res.user!.id);
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

    return fetchUserProfile(res.user!.id);
  }

  // ── Forgot password ───────────────────────────────────────
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ── Sign out ──────────────────────────────────────────────
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── Fetch profile ─────────────────────────────────────────
  Future<UserModel> fetchUserProfile(String userId) async {
    final data = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .single();
    return UserModel.fromJson(data);
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

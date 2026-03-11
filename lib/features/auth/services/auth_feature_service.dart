// ─────────────────────────────────────────────────────────────
//  auth_feature_service.dart
//
//  Thin facade that bridges the feature's AuthRepository to
//  any code that prefers a service-style interface (e.g. the
//  global GoRouter redirect guard).
//
//  This keeps the router and other shared utilities decoupled
//  from the Riverpod StateNotifier.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/auth_repository.dart';
import '../presentation/providers/auth_provider.dart';

// ── Provider ──────────────────────────────────────────────────
final authFeatureServiceProvider = Provider<AuthFeatureService>((ref) {
  return AuthFeatureService(ref.watch(authRepositoryProvider));
});

// ── Service class ─────────────────────────────────────────────
class AuthFeatureService {
  final AuthRepository _repo;
  const AuthFeatureService(this._repo);

  bool get isLoggedIn   => _repo.isLoggedIn;
  String? get currentRole => _repo.currentRole;
}

// ─────────────────────────────────────────────────────────────
//  auth_user_entity.dart  –  Domain entity: authenticated user
// ─────────────────────────────────────────────────────────────

class AuthUserEntity {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;

  const AuthUserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.avatarUrl,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isStudent => role == 'student';
  bool get isTeacher => role == 'teacher';
  bool get isAdmin => role == 'admin';

  String get displayName => name.isNotEmpty ? name : (email.split('@').first);

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  AuthUserEntity copyWith({
    String? name,
    String? avatarUrl,
    String? phone,
    bool? isActive,
  }) => AuthUserEntity(
    id: id,
    name: name ?? this.name,
    email: email,
    phone: phone ?? this.phone,
    role: role,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
  );

  @override
  String toString() =>
      'AuthUserEntity(id: $id, email: $email, role: $role, isActive: $isActive)';
}

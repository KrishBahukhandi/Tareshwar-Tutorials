// ─────────────────────────────────────────────────────────────
//  auth.dart  –  Barrel export for the auth feature
// ─────────────────────────────────────────────────────────────

// Domain
export 'domain/entities/auth_user_entity.dart';
export 'domain/repositories/auth_repository.dart';

// Data
export 'data/datasources/auth_remote_datasource.dart';
export 'data/repositories/auth_repository_impl.dart';

// Presentation – Providers
export 'presentation/providers/auth_provider.dart';

// Presentation – Screens
export 'presentation/screens/splash_screen.dart';
export 'presentation/screens/onboarding_screen.dart';
export 'presentation/screens/login_screen.dart';
export 'presentation/screens/signup_screen.dart';
export 'presentation/screens/otp_screen.dart';
export 'presentation/screens/forgot_password_screen.dart';

// Presentation – Widgets
export 'presentation/widgets/auth_text_field.dart';
export 'presentation/widgets/auth_error_banner.dart';
export 'presentation/widgets/social_login_button.dart';

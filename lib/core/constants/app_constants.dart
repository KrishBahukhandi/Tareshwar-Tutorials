// ─────────────────────────────────────────────────────────────
//  app_constants.dart  –  Global app-wide constants
// ─────────────────────────────────────────────────────────────

class AppConstants {
  AppConstants._();

  // ── Supabase ──────────────────────────────────────────────
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String authRedirectUrl =
      String.fromEnvironment('AUTH_REDIRECT_URL');

  // ── Web API (Next.js on Vercel) ───────────────────────────
  static const String webApiBaseUrl =
      String.fromEnvironment('WEB_API_URL', defaultValue: 'https://tareshwar-web.vercel.app');

  // ── App Info ──────────────────────────────────────────────
  static const String appName = 'Tareshwar Tutorials';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Learn. Grow. Succeed.';

  // ── Storage Buckets ───────────────────────────────────────
  static const String videosBucket = 'videos';
  static const String lectureVideosBucket = 'lecture-videos';
  static const String pdfsBucket = 'pdfs';
  static const String notesBucket = 'notes';
  static const String doubtImagesBucket = 'doubt-images';
  static const String profileImagesBucket = 'profile-images';
  static const String thumbnailsBucket = 'thumbnails';

  // ── Roles ─────────────────────────────────────────────────
  static const String roleStudent = 'student';
  static const String roleTeacher = 'teacher';
  static const String roleAdmin = 'admin';

  // ── Pagination ────────────────────────────────────────────
  static const int pageSize = 20;

  // ── Cache Duration ────────────────────────────────────────
  static const Duration cacheDuration = Duration(minutes: 30);

  // ── SharedPreferences Keys ────────────────────────────────
  static const String keyUserRole = 'user_role';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyThemeMode = 'theme_mode';
}

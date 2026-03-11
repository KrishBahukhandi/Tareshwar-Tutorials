// ─────────────────────────────────────────────────────────────
//  app_constants.dart  –  Global app-wide constants
// ─────────────────────────────────────────────────────────────

class AppConstants {
  AppConstants._();

  // ── Supabase ──────────────────────────────────────────────
  // TODO: Replace with your actual values from:
  //   Supabase Dashboard → Settings → API
  static const String supabaseUrl     = 'https://kufmoerpdmssjrqcsvfe.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt1Zm1vZXJwZG1zc2pycWNzdmZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MTM0MDEsImV4cCI6MjA4ODE4OTQwMX0.F-V-VSN8pl6CYuMf9VMjSyFf9uekriybnWDJjwBYmrI';

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

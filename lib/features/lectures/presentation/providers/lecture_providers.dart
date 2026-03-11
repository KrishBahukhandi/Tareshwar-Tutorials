// ─────────────────────────────────────────────────────────────
//  lecture_providers.dart  –  Riverpod providers for lectures
// ─────────────────────────────────────────────────────────────
library;

export '../../../../shared/services/app_providers.dart'
    show
        watchProgressProvider,
        studentProgressMapProvider,
        chapterLecturesProvider,
        doubtsStreamProvider;

export '../../../../shared/services/course_service.dart'
    show courseServiceProvider;

export '../../../../shared/services/auth_service.dart'
    show authServiceProvider, currentUserProvider;

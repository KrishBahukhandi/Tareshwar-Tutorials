// ─────────────────────────────────────────────────────────────
//  admin_notifications_providers.dart
//  Riverpod state layer for the Admin Announcement module.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_notifications_service.dart';

export '../data/admin_notifications_service.dart'
    show AnnouncementRow, CoursePickerRow, AnnouncementStats;

// ─────────────────────────────────────────────────────────────
//  Filter state
// ─────────────────────────────────────────────────────────────
class AnnouncementFilter {
  final String? courseId;
  final String? search;
  final bool?   platformWideOnly;

  const AnnouncementFilter({
    this.courseId,
    this.search,
    this.platformWideOnly,
  });

  AnnouncementFilter copyWith({
    Object? courseId         = _sentinel,
    Object? search           = _sentinel,
    Object? platformWideOnly = _sentinel,
  }) =>
      AnnouncementFilter(
        courseId:         courseId         == _sentinel ? this.courseId         : courseId as String?,
        search:           search           == _sentinel ? this.search           : search as String?,
        platformWideOnly: platformWideOnly == _sentinel ? this.platformWideOnly : platformWideOnly as bool?,
      );

  static const _sentinel = Object();

  bool get hasActiveFilter =>
      courseId != null || (search?.isNotEmpty ?? false) || platformWideOnly != null;
}

final announcementFilterProvider =
    StateProvider<AnnouncementFilter>((ref) => const AnnouncementFilter());

// ─────────────────────────────────────────────────────────────
//  Announcements list
// ─────────────────────────────────────────────────────────────
final announcementsListProvider =
    FutureProvider.autoDispose<List<AnnouncementRow>>((ref) {
  final svc    = ref.watch(adminNotificationsServiceProvider);
  final filter = ref.watch(announcementFilterProvider);
  return svc.fetchAnnouncements(
    courseId:         filter.courseId,
    search:           filter.search,
    platformWideOnly: filter.platformWideOnly,
  );
});

// ─────────────────────────────────────────────────────────────
//  Stats
// ─────────────────────────────────────────────────────────────
final announcementStatsProvider =
    FutureProvider.autoDispose<AnnouncementStats>((ref) {
  return ref.watch(adminNotificationsServiceProvider).fetchStats();
});

// ─────────────────────────────────────────────────────────────
//  Course picker
// ─────────────────────────────────────────────────────────────
final coursePickerProvider =
    FutureProvider.autoDispose<List<CoursePickerRow>>((ref) {
  return ref.watch(adminNotificationsServiceProvider).fetchCourses();
});

// ─────────────────────────────────────────────────────────────
//  Create announcement notifier
// ─────────────────────────────────────────────────────────────
class CreateAnnouncementNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<AnnouncementRow> create({
    required String authorId,
    required String title,
    required String body,
    String?         courseId,
    bool            sendPush = true,
  }) async {
    state = const AsyncLoading();
    try {
      final row = await ref
          .read(adminNotificationsServiceProvider)
          .createAnnouncement(
            authorId: authorId,
            title:    title,
            body:     body,
            courseId: courseId,
            sendPush: sendPush,
          );
      state = const AsyncData(null);
      // Invalidate list & stats so they refresh
      ref.invalidate(announcementsListProvider);
      ref.invalidate(announcementStatsProvider);
      return row;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final createAnnouncementProvider =
    AsyncNotifierProvider<CreateAnnouncementNotifier, void>(
        CreateAnnouncementNotifier.new);

// ─────────────────────────────────────────────────────────────
//  Delete announcement notifier
// ─────────────────────────────────────────────────────────────
class DeleteAnnouncementNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> delete(String id) async {
    state = const AsyncLoading();
    try {
      await ref.read(adminNotificationsServiceProvider).deleteAnnouncement(id);
      state = const AsyncData(null);
      ref.invalidate(announcementsListProvider);
      ref.invalidate(announcementStatsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final deleteAnnouncementProvider =
    AsyncNotifierProvider<DeleteAnnouncementNotifier, void>(
        DeleteAnnouncementNotifier.new);

// ─────────────────────────────────────────────────────────────
//  Resend push notifier
// ─────────────────────────────────────────────────────────────
class ResendPushNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> resend(AnnouncementRow row) async {
    state = const AsyncLoading();
    try {
      await ref.read(adminNotificationsServiceProvider).resendPush(row);
      state = const AsyncData(null);
      ref.invalidate(announcementsListProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final resendPushProvider =
    AsyncNotifierProvider<ResendPushNotifier, void>(ResendPushNotifier.new);

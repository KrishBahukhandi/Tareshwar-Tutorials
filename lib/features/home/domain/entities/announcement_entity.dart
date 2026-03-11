// ─────────────────────────────────────────────────────────────
//  announcement_entity.dart  –  Domain entity for a banner
//  announcement shown at the top of the dashboard.
// ─────────────────────────────────────────────────────────────

class AnnouncementEntity {
  final String id;
  final String title;
  final String body;
  final String? targetId;
  final DateTime createdAt;

  const AnnouncementEntity({
    required this.id,
    required this.title,
    required this.body,
    this.targetId,
    required this.createdAt,
  });
}

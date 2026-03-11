// ─────────────────────────────────────────────────────────────
//  live_class_model.dart  –  Domain model for a live class
// ─────────────────────────────────────────────────────────────

enum LiveClassStatus { upcoming, live, ended }

class LiveClassModel {
  final String id;
  final String batchId;
  final String teacherId;
  final String title;
  final String? description;
  final String meetingLink;
  final DateTime startTime;
  final int durationMinutes;
  final bool notificationSent;
  final DateTime createdAt;

  // Joined fields (not in DB column, fetched via join)
  final String? batchName;
  final String? teacherName;
  final String? courseName;

  const LiveClassModel({
    required this.id,
    required this.batchId,
    required this.teacherId,
    required this.title,
    this.description,
    required this.meetingLink,
    required this.startTime,
    required this.durationMinutes,
    this.notificationSent = false,
    required this.createdAt,
    this.batchName,
    this.teacherName,
    this.courseName,
  });

  DateTime get endTime =>
      startTime.add(Duration(minutes: durationMinutes));

  LiveClassStatus get status {
    final now = DateTime.now();
    if (now.isBefore(startTime)) return LiveClassStatus.upcoming;
    if (now.isAfter(endTime)) return LiveClassStatus.ended;
    return LiveClassStatus.live;
  }

  bool get isLive     => status == LiveClassStatus.live;
  bool get isUpcoming => status == LiveClassStatus.upcoming;
  bool get isEnded    => status == LiveClassStatus.ended;

  /// Minutes until start (negative if already started)
  int get minutesUntilStart =>
      startTime.difference(DateTime.now()).inMinutes;

  factory LiveClassModel.fromJson(Map<String, dynamic> json) => LiveClassModel(
        id: json['id'] as String,
        batchId: json['batch_id'] as String,
        teacherId: json['teacher_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        meetingLink: json['meeting_link'] as String,
        startTime: DateTime.parse(json['start_time'] as String),
        durationMinutes: json['duration_minutes'] as int? ?? 60,
        notificationSent: json['notification_sent'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        batchName: json['batches'] != null
            ? (json['batches'] as Map<String, dynamic>)['batch_name'] as String?
            : null,
        teacherName: json['users'] != null
            ? (json['users'] as Map<String, dynamic>)['name'] as String?
            : null,
        courseName: json['batches'] != null &&
                (json['batches'] as Map<String, dynamic>)['courses'] != null
            ? ((json['batches'] as Map<String, dynamic>)['courses']
                    as Map<String, dynamic>)['title'] as String?
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'batch_id': batchId,
        'teacher_id': teacherId,
        'title': title,
        'description': description,
        'meeting_link': meetingLink,
        'start_time': startTime.toIso8601String(),
        'duration_minutes': durationMinutes,
      };

  LiveClassModel copyWith({
    String? title,
    String? description,
    String? meetingLink,
    DateTime? startTime,
    int? durationMinutes,
    bool? notificationSent,
  }) =>
      LiveClassModel(
        id: id,
        batchId: batchId,
        teacherId: teacherId,
        title: title ?? this.title,
        description: description ?? this.description,
        meetingLink: meetingLink ?? this.meetingLink,
        startTime: startTime ?? this.startTime,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        notificationSent: notificationSent ?? this.notificationSent,
        createdAt: createdAt,
        batchName: batchName,
        teacherName: teacherName,
        courseName: courseName,
      );
}

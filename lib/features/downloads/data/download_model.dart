// ─────────────────────────────────────────────────────────────
//  download_model.dart  –  Local data model for a downloaded
//  lecture video.  Persisted in SQLite via DownloadDatabase.
// ─────────────────────────────────────────────────────────────

enum DownloadStatus { queued, downloading, completed, failed, paused }

class DownloadedLecture {
  final String lectureId;
  final String studentId;      // owner – prevents cross-account access
  final String title;
  final String courseTitle;
  final int durationSeconds;
  final String localPath;      // absolute path to the .mp4 file
  final int fileSizeBytes;
  final DownloadStatus status;
  final double progress;       // 0.0 – 1.0  (only meaningful while downloading)
  final DateTime downloadedAt;

  const DownloadedLecture({
    required this.lectureId,
    required this.studentId,
    required this.title,
    required this.courseTitle,
    required this.durationSeconds,
    required this.localPath,
    required this.fileSizeBytes,
    required this.status,
    required this.progress,
    required this.downloadedAt,
  });

  // ── SQLite serialisation ────────────────────────────────────
  factory DownloadedLecture.fromMap(Map<String, dynamic> m) =>
      DownloadedLecture(
        lectureId:       m['lecture_id']       as String,
        studentId:       m['student_id']       as String,
        title:           m['title']            as String,
        courseTitle:     m['course_title']      as String? ?? '',
        durationSeconds: m['duration_seconds'] as int?    ?? 0,
        localPath:       m['local_path']        as String,
        fileSizeBytes:   m['file_size_bytes']   as int?    ?? 0,
        status: DownloadStatus.values.firstWhere(
          (s) => s.name == (m['status'] as String? ?? 'completed'),
          orElse: () => DownloadStatus.completed,
        ),
        progress:       (m['progress'] as num?)?.toDouble() ?? 1.0,
        downloadedAt:    DateTime.parse(
            m['downloaded_at'] as String? ??
                DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toMap() => {
        'lecture_id':       lectureId,
        'student_id':       studentId,
        'title':            title,
        'course_title':      courseTitle,
        'duration_seconds': durationSeconds,
        'local_path':        localPath,
        'file_size_bytes':   fileSizeBytes,
        'status':            status.name,
        'progress':          progress,
        'downloaded_at':    downloadedAt.toIso8601String(),
      };

  DownloadedLecture copyWith({
    DownloadStatus? status,
    double? progress,
    String? localPath,
    int? fileSizeBytes,
  }) =>
      DownloadedLecture(
        lectureId:       lectureId,
        studentId:       studentId,
        title:           title,
        courseTitle:     courseTitle,
        durationSeconds: durationSeconds,
        localPath:       localPath  ?? this.localPath,
        fileSizeBytes:   fileSizeBytes ?? this.fileSizeBytes,
        status:          status      ?? this.status,
        progress:        progress    ?? this.progress,
        downloadedAt:    downloadedAt,
      );

  // ── Derived helpers ──────────────────────────────────────────
  bool get isCompleted  => status == DownloadStatus.completed;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isFailed     => status == DownloadStatus.failed;

  String get formattedSize {
    if (fileSizeBytes <= 0) return '';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return s > 0 ? '${m}m ${s}s' : '${m}m';
  }
}

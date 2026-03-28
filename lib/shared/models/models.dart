// ─────────────────────────────────────────────────────────────
//  models.dart  –  All domain entity models
// ─────────────────────────────────────────────────────────────

// ── UserModel ─────────────────────────────────────────────────
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role; // 'student' | 'teacher' | 'admin'
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;

  const UserModel({
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
  bool get isAdmin   => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        role: json['role'] as String,
        avatarUrl: json['avatar_url'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'avatar_url': avatarUrl,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? name,
    String? avatarUrl,
    String? phone,
    String? role,
    bool? isActive,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}

// ── CourseModel ───────────────────────────────────────────────
class CourseModel {
  final String id;
  final String title;
  final String description;
  final String teacherId;
  final String? teacherName;
  final double price;
  final String? thumbnailUrl;
  final String? categoryTag;
  final bool isPublished;
  final int? totalLectures;
  final int? totalStudents;
  final double? rating;
  final DateTime createdAt;

  const CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.teacherId,
    this.teacherName,
    required this.price,
    this.thumbnailUrl,
    this.categoryTag,
    this.isPublished = true,
    this.totalLectures,
    this.totalStudents,
    this.rating,
    required this.createdAt,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) => CourseModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        teacherId: json['teacher_id'] as String,
        teacherName: json['teacher_name'] as String?,
        price: (json['price'] as num).toDouble(),
        thumbnailUrl: json['thumbnail_url'] as String?,
        categoryTag: json['category_tag'] as String?,
        isPublished: json['is_published'] as bool? ?? true,
        totalLectures: json['total_lectures'] as int?,
        totalStudents: json['total_students'] as int?,
        rating: (json['rating'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'teacher_id': teacherId,
        'price': price,
        'thumbnail_url': thumbnailUrl,
        'category_tag': categoryTag,
        'is_published': isPublished,
        'created_at': createdAt.toIso8601String(),
      };

  CourseModel copyWith({
    String? title,
    String? description,
    double? price,
    String? thumbnailUrl,
    String? categoryTag,
    bool? isPublished,
  }) =>
      CourseModel(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        teacherId: teacherId,
        teacherName: teacherName,
        price: price ?? this.price,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        categoryTag: categoryTag ?? this.categoryTag,
        isPublished: isPublished ?? this.isPublished,
        totalLectures: totalLectures,
        totalStudents: totalStudents,
        rating: rating,
        createdAt: createdAt,
      );
}

// ── BatchModel ────────────────────────────────────────────────
/// A cohort/batch under a Course.
/// Students enroll into batches — not directly into courses.
class BatchModel {
  final String id;
  final String courseId;
  final String? courseTitle;   // populated via join
  final String? teacherName;   // populated via join
  final String batchName;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final int maxStudents;
  final int enrolledCount;     // populated client-side
  final bool isActive;
  final DateTime createdAt;

  const BatchModel({
    required this.id,
    required this.courseId,
    this.courseTitle,
    this.teacherName,
    required this.batchName,
    this.description,
    required this.startDate,
    this.endDate,
    this.maxStudents = 50,
    this.enrolledCount = 0,
    this.isActive = true,
    required this.createdAt,
  });

  double get fillPercent =>
      maxStudents > 0 ? (enrolledCount / maxStudents).clamp(0.0, 1.0) : 0.0;

  bool get isFull => enrolledCount >= maxStudents;

  factory BatchModel.fromJson(Map<String, dynamic> json) {
    // Support joined course data: courses!course_id(title, users!teacher_id(name))
    final courseMap  = json['courses'] as Map?;
    final teacherMap = courseMap?['users'] as Map?;
    return BatchModel(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      courseTitle: (json['course_title'] ?? courseMap?['title']) as String?,
      teacherName: (json['teacher_name'] ?? teacherMap?['name']) as String?,
      batchName: (json['batch_name'] ?? json['name']) as String,
      description: json['description'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      maxStudents: json['max_students'] as int? ?? 50,
      enrolledCount: json['enrolled_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'course_id': courseId,
        'batch_name': batchName,
        'description': description,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate?.toIso8601String().substring(0, 10),
        'max_students': maxStudents,
        'is_active': isActive,
      };

  BatchModel copyWith({
    String? batchName,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    int? maxStudents,
    int? enrolledCount,
    bool? isActive,
    String? courseTitle,
  }) =>
      BatchModel(
        id: id,
        courseId: courseId,
        courseTitle: courseTitle ?? this.courseTitle,
        teacherName: teacherName,
        batchName: batchName ?? this.batchName,
        description: description ?? this.description,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        maxStudents: maxStudents ?? this.maxStudents,
        enrolledCount: enrolledCount ?? this.enrolledCount,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}

// ── EnrollmentModel ───────────────────────────────────────────
/// Students enroll in batches; this joins to course via batch.
class EnrollmentModel {
  final String id;
  final String studentId;
  final String? studentName;  // populated via join
  final String batchId;
  final String? batchName;    // populated via join
  final String? courseTitle;  // populated via join
  final DateTime enrolledAt;
  final double progressPercent;

  const EnrollmentModel({
    required this.id,
    required this.studentId,
    this.studentName,
    required this.batchId,
    this.batchName,
    this.courseTitle,
    required this.enrolledAt,
    this.progressPercent = 0.0,
  });

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) {
    final batchMap  = json['batches'] as Map?;
    final courseMap = batchMap?['courses'] as Map?;
    final userMap   = json['users'] as Map?;
    return EnrollmentModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      studentName: (json['student_name'] ?? userMap?['name']) as String?,
      batchId: json['batch_id'] as String,
      batchName: (json['batch_name'] ?? batchMap?['batch_name']) as String?,
      courseTitle: (json['course_title'] ?? courseMap?['title']) as String?,
      enrolledAt: DateTime.parse(
          json['enrolled_at'] as String? ?? DateTime.now().toIso8601String()),
      progressPercent:
          (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'batch_id': batchId,
        'enrolled_at': enrolledAt.toIso8601String(),
        'progress_percent': progressPercent,
      };
}

// ── SubjectModel ──────────────────────────────────────────────
/// A subject belongs to a batch (not directly to a course).
/// The hierarchy: Course → Batch → Subject → Chapter → Lecture
class SubjectModel {
  final String id;
  final String courseId;
  final String? batchId;   // nullable for backwards compat
  final String name;
  final int sortOrder;
  final List<ChapterModel> chapters;

  const SubjectModel({
    required this.id,
    required this.courseId,
    this.batchId,
    required this.name,
    this.sortOrder = 0,
    this.chapters = const [],
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) => SubjectModel(
        id: json['id'] as String,
        courseId: json['course_id'] as String,
        batchId: json['batch_id'] as String?,
        name: json['name'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
        chapters: (json['chapters'] as List<dynamic>?)
                ?.map((c) => ChapterModel.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
      );

  SubjectModel copyWith({
    String? name,
    int? sortOrder,
    List<ChapterModel>? chapters,
  }) =>
      SubjectModel(
        id: id,
        courseId: courseId,
        batchId: batchId,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        chapters: chapters ?? this.chapters,
      );
}

// ── ChapterModel ──────────────────────────────────────────────
class ChapterModel {
  final String id;
  final String subjectId;
  final String name;
  final int sortOrder;
  final List<LectureModel> lectures;

  const ChapterModel({
    required this.id,
    required this.subjectId,
    required this.name,
    this.sortOrder = 0,
    this.lectures = const [],
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) => ChapterModel(
        id: json['id'] as String,
        subjectId: json['subject_id'] as String,
        name: json['name'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
        lectures: (json['lectures'] as List<dynamic>?)
                ?.map((l) => LectureModel.fromJson(l as Map<String, dynamic>))
                .toList() ??
            [],
      );

  ChapterModel copyWith({
    String? name,
    int? sortOrder,
    List<LectureModel>? lectures,
  }) =>
      ChapterModel(
        id: id,
        subjectId: subjectId,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        lectures: lectures ?? this.lectures,
      );
}

// ── LectureModel ──────────────────────────────────────────────
class LectureModel {
  final String id;
  final String chapterId;
  final String title;
  final String? description;
  final String? videoUrl;
  final String? notesUrl;
  final List<LectureAttachment> attachments;
  final int? durationSeconds;
  final bool isFree;
  final int sortOrder;
  final DateTime createdAt;

  const LectureModel({
    required this.id,
    required this.chapterId,
    required this.title,
    this.description,
    this.videoUrl,
    this.notesUrl,
    this.attachments = const [],
    this.durationSeconds,
    this.isFree = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  String get formattedDuration {
    if (durationSeconds == null) return '';
    final m = durationSeconds! ~/ 60;
    final s = durationSeconds! % 60;
    return s > 0 ? '${m}m ${s}s' : '${m}m';
  }

  factory LectureModel.fromJson(Map<String, dynamic> json) => LectureModel(
        id: json['id'] as String,
        chapterId: json['chapter_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        videoUrl: json['video_url'] as String?,
        notesUrl: json['notes_url'] as String?,
        attachments: (json['attachments'] as List<dynamic>?)
                ?.map((a) =>
                    LectureAttachment.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        durationSeconds: json['duration_seconds'] as int?,
        isFree: json['is_free'] as bool? ?? false,
        sortOrder: json['sort_order'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  LectureModel copyWith({
    String? title,
    String? description,
    String? videoUrl,
    String? notesUrl,
    int? durationSeconds,
    bool? isFree,
    int? sortOrder,
  }) =>
      LectureModel(
        id: id,
        chapterId: chapterId,
        title: title ?? this.title,
        description: description ?? this.description,
        videoUrl: videoUrl ?? this.videoUrl,
        notesUrl: notesUrl ?? this.notesUrl,
        attachments: attachments,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        isFree: isFree ?? this.isFree,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
      );
}

// ── LectureProgressModel ──────────────────────────────────────
class LectureProgressModel {
  final String studentId;
  final String lectureId;
  final int watchedSeconds;
  final bool completed;
  final DateTime updatedAt;

  const LectureProgressModel({
    required this.studentId,
    required this.lectureId,
    required this.watchedSeconds,
    this.completed = false,
    required this.updatedAt,
  });

  factory LectureProgressModel.fromJson(Map<String, dynamic> json) =>
      LectureProgressModel(
        studentId: json['student_id'] as String,
        lectureId: json['lecture_id'] as String,
        watchedSeconds: json['watched_seconds'] as int? ?? 0,
        completed: json['completed'] as bool? ?? false,
        updatedAt: DateTime.parse(
            json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'lecture_id': lectureId,
        'watched_seconds': watchedSeconds,
        'completed': completed,
        'updated_at': updatedAt.toIso8601String(),
      };
}

// ── LectureAttachment ─────────────────────────────────────────
class LectureAttachment {
  final String name;
  final String url;
  final String? fileType; // pdf | doc | zip | etc.

  const LectureAttachment({
    required this.name,
    required this.url,
    this.fileType,
  });

  factory LectureAttachment.fromJson(Map<String, dynamic> json) =>
      LectureAttachment(
        name: json['name'] as String,
        url: json['url'] as String,
        fileType: json['file_type'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'file_type': fileType,
      };
}

// ── TestModel ─────────────────────────────────────────────────
class TestModel {
  final String id;
  final String chapterId;
  final String? courseId;
  final String title;
  final int durationMinutes;
  final int totalMarks;
  final double negativeMarks;
  final bool isPublished;
  final DateTime createdAt;

  const TestModel({
    required this.id,
    required this.chapterId,
    this.courseId,
    required this.title,
    required this.durationMinutes,
    required this.totalMarks,
    this.negativeMarks = 0.25,
    this.isPublished = true,
    required this.createdAt,
  });

  factory TestModel.fromJson(Map<String, dynamic> json) => TestModel(
        id: json['id'] as String,
        chapterId: json['chapter_id'] as String,
        courseId: json['course_id'] as String?,
        title: json['title'] as String,
        durationMinutes: json['duration_minutes'] as int,
        totalMarks: json['total_marks'] as int,
        negativeMarks: (json['negative_marks'] as num?)?.toDouble() ?? 0.25,
        isPublished: json['is_published'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'chapter_id': chapterId,
        'course_id': courseId,
        'title': title,
        'duration_minutes': durationMinutes,
        'total_marks': totalMarks,
        'negative_marks': negativeMarks,
        'is_published': isPublished,
        'created_at': createdAt.toIso8601String(),
      };
}

// ── QuestionModel ─────────────────────────────────────────────
class QuestionModel {
  final String id;
  final String testId;
  final String question;
  final String? questionImageUrl;
  final List<String> options;
  final int correctOptionIndex;
  final int marks;
  final String? explanation;

  const QuestionModel({
    required this.id,
    required this.testId,
    required this.question,
    this.questionImageUrl,
    required this.options,
    required this.correctOptionIndex,
    this.marks = 4,
    this.explanation,
  });

  static const int redactedAnswerIndex = -1;

  bool get hasAnswerKey => correctOptionIndex >= 0;

  factory QuestionModel.fromJson(Map<String, dynamic> json) => QuestionModel(
        id: json['id'] as String,
        testId: json['test_id'] as String,
        question: json['question'] as String,
        questionImageUrl: json['question_image_url'] as String?,
        options: List<String>.from(json['options'] as List),
        correctOptionIndex: json['correct_option_index'] as int,
        marks: json['marks'] as int? ?? 4,
        explanation: json['explanation'] as String?,
      );

  factory QuestionModel.fromStudentJson(Map<String, dynamic> json) =>
      QuestionModel(
        id: json['id'] as String,
        testId: json['test_id'] as String,
        question: json['question'] as String,
        questionImageUrl: json['question_image_url'] as String?,
        options: List<String>.from(json['options'] as List),
        correctOptionIndex: redactedAnswerIndex,
        marks: json['marks'] as int? ?? 4,
        explanation: null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'test_id': testId,
        'question': question,
        'question_image_url': questionImageUrl,
        'options': options,
        'correct_option_index': correctOptionIndex,
        'marks': marks,
        'explanation': explanation,
      };
}

// ── DoubtModel ────────────────────────────────────────────────
class DoubtModel {
  final String id;
  final String studentId;
  final String? studentName;
  final String? lectureId;
  final String question;
  final String? imageUrl;
  final String? answer;
  final String? answeredBy;
  final bool isAnswered;
  final int replyCount;
  final DateTime createdAt;

  const DoubtModel({
    required this.id,
    required this.studentId,
    this.studentName,
    this.lectureId,
    required this.question,
    this.imageUrl,
    this.answer,
    this.answeredBy,
    this.isAnswered = false,
    this.replyCount = 0,
    required this.createdAt,
  });

  factory DoubtModel.fromJson(Map<String, dynamic> json) => DoubtModel(
        id: json['id'] as String,
        studentId: json['student_id'] as String,
        studentName: json['student_name'] as String?,
        lectureId: json['lecture_id'] as String?,
        question: json['question'] as String,
        imageUrl: json['image_url'] as String?,
        answer: json['answer'] as String?,
        answeredBy: json['answered_by'] as String?,
        isAnswered: json['is_answered'] as bool? ?? false,
        replyCount: json['reply_count'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  DoubtModel copyWith({bool? isAnswered, int? replyCount, String? answer}) =>
      DoubtModel(
        id: id,
        studentId: studentId,
        studentName: studentName,
        lectureId: lectureId,
        question: question,
        imageUrl: imageUrl,
        answer: answer ?? this.answer,
        answeredBy: answeredBy,
        isAnswered: isAnswered ?? this.isAnswered,
        replyCount: replyCount ?? this.replyCount,
        createdAt: createdAt,
      );
}

// ── DoubtReplyModel ───────────────────────────────────────────
class DoubtReplyModel {
  final String id;
  final String doubtId;
  final String authorId;
  final String? authorName;
  final String role; // 'student' | 'teacher' | 'admin'
  final String body;
  final String? imageUrl;
  final DateTime createdAt;

  const DoubtReplyModel({
    required this.id,
    required this.doubtId,
    required this.authorId,
    this.authorName,
    required this.role,
    required this.body,
    this.imageUrl,
    required this.createdAt,
  });

  bool get isTeacher => role == 'teacher';
  bool get isAdmin   => role == 'admin';

  factory DoubtReplyModel.fromJson(Map<String, dynamic> json) =>
      DoubtReplyModel(
        id: json['id'] as String,
        doubtId: json['doubt_id'] as String,
        authorId: json['author_id'] as String,
        authorName: json['author_name'] as String?,
        role: json['role'] as String? ?? 'student',
        body: json['body'] as String,
        imageUrl: json['image_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'doubt_id': doubtId,
        'author_id': authorId,
        'author_name': authorName,
        'role': role,
        'body': body,
        'image_url': imageUrl,
        'created_at': createdAt.toIso8601String(),
      };
}

// ── TestAttemptModel ──────────────────────────────────────────
class TestAttemptModel {
  final String id;
  final String testId;
  final String studentId;
  final int score;
  final int totalMarks;
  final int correctAnswers;
  final int wrongAnswers;
  final int skipped;
  final int timeTakenSeconds;
  final Map<String, int> answers; // questionId → selectedOptionIndex
  final DateTime attemptedAt;

  const TestAttemptModel({
    required this.id,
    required this.testId,
    required this.studentId,
    required this.score,
    required this.totalMarks,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.skipped,
    required this.timeTakenSeconds,
    required this.answers,
    required this.attemptedAt,
  });

  double get percentage => totalMarks > 0 ? (score / totalMarks) * 100 : 0;
  String get grade {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }

  factory TestAttemptModel.fromJson(Map<String, dynamic> json) =>
      TestAttemptModel(
        id: json['id'] as String,
        testId: json['test_id'] as String,
        studentId: json['student_id'] as String,
        score: json['score'] as int,
        totalMarks: json['total_marks'] as int,
        correctAnswers: json['correct_answers'] as int,
        wrongAnswers: json['wrong_answers'] as int,
        skipped: json['skipped'] as int,
        timeTakenSeconds: json['time_taken_seconds'] as int,
        answers: Map<String, int>.from(json['answers'] as Map),
        attemptedAt: DateTime.parse(json['attempted_at'] as String),
      );
}

// ── NotificationModel ─────────────────────────────────────────
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // lecture | test | announcement
  final String? targetId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.targetId,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        type: json['type'] as String,
        targetId:
            (json['reference_id'] ?? json['target_id']) as String?,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        title: title,
        body: body,
        type: type,
        targetId: targetId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}

// ── PaymentModel ──────────────────────────────────────────────
/// Records a student's course purchase.
/// payment_status: 'completed' | 'pending' | 'failed' | 'refunded'
class PaymentModel {
  final String  id;
  final String  studentId;
  final String? studentName;
  final String  courseId;
  final String? courseTitle;
  final double  amount;
  final String  paymentStatus;
  final String? paymentMethod;
  final String? transactionId;
  final String? notes;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.studentId,
    this.studentName,
    required this.courseId,
    this.courseTitle,
    required this.amount,
    required this.paymentStatus,
    this.paymentMethod,
    this.transactionId,
    this.notes,
    required this.createdAt,
  });

  bool get isCompleted => paymentStatus == 'completed';
  bool get isPending   => paymentStatus == 'pending';
  bool get isFailed    => paymentStatus == 'failed';
  bool get isRefunded  => paymentStatus == 'refunded';

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final userMap   = json['users']   as Map?;
    final courseMap = json['courses'] as Map?;
    return PaymentModel(
      id:             json['id'] as String,
      studentId:      json['student_id'] as String,
      studentName:    (json['student_name'] ?? userMap?['name'])     as String?,
      courseId:       json['course_id'] as String,
      courseTitle:    (json['course_title'] ?? courseMap?['title'])  as String?,
      amount:         (json['amount'] as num).toDouble(),
      paymentStatus:  json['payment_status'] as String? ?? 'completed',
      paymentMethod:  json['payment_method'] as String?,
      transactionId:  json['transaction_id'] as String?,
      notes:          json['notes'] as String?,
      createdAt:      DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id':             id,
        'student_id':     studentId,
        'course_id':      courseId,
        'amount':         amount,
        'payment_status': paymentStatus,
        'payment_method': paymentMethod,
        'transaction_id': transactionId,
        'notes':          notes,
        'created_at':     createdAt.toIso8601String(),
      };

  PaymentModel copyWith({String? paymentStatus, String? notes}) =>
      PaymentModel(
        id:             id,
        studentId:      studentId,
        studentName:    studentName,
        courseId:       courseId,
        courseTitle:    courseTitle,
        amount:         amount,
        paymentStatus:  paymentStatus ?? this.paymentStatus,
        paymentMethod:  paymentMethod,
        transactionId:  transactionId,
        notes:          notes ?? this.notes,
        createdAt:      createdAt,
      );
}

// ── AnnouncementModel ─────────────────────────────────────────
/// Platform-wide or batch-scoped announcements posted by admin/teacher.
class AnnouncementModel {
  final String id;
  final String authorId;
  final String? authorName;
  final String? batchId;       // null = platform-wide
  final String? batchName;
  final String title;
  final String body;
  final DateTime createdAt;

  const AnnouncementModel({
    required this.id,
    required this.authorId,
    this.authorName,
    this.batchId,
    this.batchName,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  bool get isPlatformWide => batchId == null;

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    final userMap  = json['users'] as Map?;
    final batchMap = json['batches'] as Map?;
    return AnnouncementModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      authorName:
          (json['author_name'] ?? userMap?['name']) as String?,
      batchId: json['batch_id'] as String?,
      batchName:
          (json['batch_name'] ?? batchMap?['batch_name']) as String?,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author_id': authorId,
        'batch_id': batchId,
        'title': title,
        'body': body,
        'created_at': createdAt.toIso8601String(),
      };
}

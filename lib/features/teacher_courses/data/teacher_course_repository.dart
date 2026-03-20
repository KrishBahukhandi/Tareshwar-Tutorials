// ─────────────────────────────────────────────────────────────
//  teacher_course_repository.dart
//  All Supabase CRUD for Teacher Course Management.
//  Covers: Course, Subject, Chapter, Lecture, EnrolledStudents.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/models.dart';
import '../../../shared/services/supabase_service.dart';

final teacherCourseRepoProvider = Provider<TeacherCourseRepository>((ref) {
  return TeacherCourseRepository(ref.watch(supabaseClientProvider));
});

class TeacherCourseStats {
  final int subjectCount;
  final int chapterCount;
  final int lectureCount;
  final int batchCount;
  final int enrollmentCount;

  const TeacherCourseStats({
    required this.subjectCount,
    required this.chapterCount,
    required this.lectureCount,
    required this.batchCount,
    required this.enrollmentCount,
  });

  bool get canPublish => lectureCount > 0;
  bool get canDelete =>
      subjectCount == 0 && batchCount == 0 && enrollmentCount == 0;
}

class TeacherCourseRepository {
  final SupabaseClient _db;
  TeacherCourseRepository(this._db);

  Future<void> _requireTeacherOwnsCourse(
    String courseId,
    String teacherId,
  ) async {
    final course = await _db
        .from('courses')
        .select('teacher_id')
        .eq('id', courseId)
        .maybeSingle();
    if (course == null || course['teacher_id'] != teacherId) {
      throw StateError('You do not have permission to manage this course.');
    }
  }

  Future<String> _requireTeacherOwnsSubject(
    String subjectId,
    String teacherId,
  ) async {
    final subject = await _db
        .from('subjects')
        .select('course_id')
        .eq('id', subjectId)
        .maybeSingle();
    if (subject == null) throw StateError('Subject not found.');
    final courseId = subject['course_id'] as String;
    await _requireTeacherOwnsCourse(courseId, teacherId);
    return courseId;
  }

  Future<String> _requireTeacherOwnsChapter(
    String chapterId,
    String teacherId,
  ) async {
    final chapter = await _db
        .from('chapters')
        .select('subject_id')
        .eq('id', chapterId)
        .maybeSingle();
    if (chapter == null) throw StateError('Chapter not found.');
    final subjectId = chapter['subject_id'] as String;
    await _requireTeacherOwnsSubject(subjectId, teacherId);
    return subjectId;
  }

  Future<String> _requireTeacherOwnsLecture(
    String lectureId,
    String teacherId,
  ) async {
    final lecture = await _db
        .from('lectures')
        .select('chapter_id')
        .eq('id', lectureId)
        .maybeSingle();
    if (lecture == null) throw StateError('Lecture not found.');
    final chapterId = lecture['chapter_id'] as String;
    await _requireTeacherOwnsChapter(chapterId, teacherId);
    return chapterId;
  }

  Future<TeacherCourseStats> fetchCourseStats(
    String courseId,
    String teacherId,
  ) async {
    await _requireTeacherOwnsCourse(courseId, teacherId);

    final subjects = await _db
        .from('subjects')
        .select('id')
        .eq('course_id', courseId);
    final subjectIds = subjects.map((row) => row['id'] as String).toList();

    List<Map<String, dynamic>> chapters = const [];
    if (subjectIds.isNotEmpty) {
      chapters = await _db
          .from('chapters')
          .select('id')
          .inFilter('subject_id', subjectIds);
    }
    final chapterIds = chapters.map((row) => row['id'] as String).toList();

    List<Map<String, dynamic>> lectures = const [];
    if (chapterIds.isNotEmpty) {
      lectures = await _db
          .from('lectures')
          .select('id')
          .inFilter('chapter_id', chapterIds);
    }

    final batches = await _db
        .from('batches')
        .select('id')
        .eq('course_id', courseId);
    final batchIds = batches.map((row) => row['id'] as String).toList();

    List<Map<String, dynamic>> enrollments = const [];
    if (batchIds.isNotEmpty) {
      enrollments = await _db
          .from('enrollments')
          .select('id')
          .inFilter('batch_id', batchIds);
    }

    return TeacherCourseStats(
      subjectCount: subjects.length,
      chapterCount: chapters.length,
      lectureCount: lectures.length,
      batchCount: batches.length,
      enrollmentCount: enrollments.length,
    );
  }

  // ════════════════════════════════════════════════════════
  //  COURSES
  // ════════════════════════════════════════════════════════

  Future<List<CourseModel>> fetchMyCourses(String teacherId) async {
    final data = await _db
        .from('courses')
        .select()
        .eq('teacher_id', teacherId)
        .order('created_at', ascending: false);

    return data
        .map((j) => CourseModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<CourseModel> createCourse({
    required String teacherId,
    required String title,
    required String description,
    required double price,
    String? thumbnailUrl,
    String? categoryTag,
  }) async {
    final data = await _db
        .from('courses')
        .insert({
          'teacher_id': teacherId,
          'title': title,
          'description': description,
          'price': price,
          'thumbnail_url': thumbnailUrl,
          'category_tag': categoryTag,
          'is_published': false,
        })
        .select()
        .single();
    return CourseModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<CourseModel> updateCourse({
    required String teacherId,
    required String courseId,
    required String title,
    required String description,
    required double price,
    String? thumbnailUrl,
    String? categoryTag,
  }) async {
    await _requireTeacherOwnsCourse(courseId, teacherId);
    final data = await _db
        .from('courses')
        .update({
          'title': title,
          'description': description,
          'price': price,
          'thumbnail_url': thumbnailUrl,
          'category_tag': categoryTag,
        })
        .eq('id', courseId)
        .select()
        .single();
    return CourseModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> deleteCourse(
    String courseId, {
    required String teacherId,
  }) async {
    final stats = await fetchCourseStats(courseId, teacherId);
    if (!stats.canDelete) {
      throw StateError(
        'This course cannot be deleted because it already has content or student-linked batch data.',
      );
    }
    await _db.from('courses').delete().eq('id', courseId);
  }

  Future<void> togglePublish(
    String courseId, {
    required String teacherId,
    required bool publish,
  }) async {
    await _requireTeacherOwnsCourse(courseId, teacherId);
    if (publish) {
      final stats = await fetchCourseStats(courseId, teacherId);
      if (!stats.canPublish) {
        throw StateError(
          'Add at least one lecture before publishing this course.',
        );
      }
    }
    await _db
        .from('courses')
        .update({'is_published': publish})
        .eq('id', courseId);
  }

  // ════════════════════════════════════════════════════════
  //  SUBJECTS
  // ════════════════════════════════════════════════════════

  Future<List<SubjectModel>> fetchSubjects(
    String courseId, {
    required String teacherId,
  }) async {
    await _requireTeacherOwnsCourse(courseId, teacherId);
    final data = await _db
        .from('subjects')
        .select()
        .eq('course_id', courseId)
        .order('sort_order');
    return data
        .map(
          (j) => SubjectModel.fromJson({
            ...Map<String, dynamic>.from(j),
            'chapters': <dynamic>[],
          }),
        )
        .toList();
  }

  Future<SubjectModel> createSubject({
    required String teacherId,
    required String courseId,
    required String name,
    required int sortOrder,
  }) async {
    await _requireTeacherOwnsCourse(courseId, teacherId);
    final data = await _db
        .from('subjects')
        .insert({'course_id': courseId, 'name': name, 'sort_order': sortOrder})
        .select()
        .single();
    return SubjectModel.fromJson({
      ...Map<String, dynamic>.from(data),
      'chapters': <dynamic>[],
    });
  }

  Future<SubjectModel> updateSubject({
    required String teacherId,
    required String subjectId,
    required String name,
    required int sortOrder,
  }) async {
    await _requireTeacherOwnsSubject(subjectId, teacherId);
    final data = await _db
        .from('subjects')
        .update({'name': name, 'sort_order': sortOrder})
        .eq('id', subjectId)
        .select()
        .single();
    return SubjectModel.fromJson({
      ...Map<String, dynamic>.from(data),
      'chapters': <dynamic>[],
    });
  }

  Future<void> deleteSubject(
    String subjectId, {
    required String teacherId,
  }) async {
    await _requireTeacherOwnsSubject(subjectId, teacherId);
    final chapters = await _db
        .from('chapters')
        .select('id')
        .eq('subject_id', subjectId);
    if (chapters.isNotEmpty) {
      throw StateError(
        'Delete or move this subject’s chapters before deleting the subject.',
      );
    }
    await _db.from('subjects').delete().eq('id', subjectId);
  }

  // ════════════════════════════════════════════════════════
  //  CHAPTERS
  // ════════════════════════════════════════════════════════

  Future<List<ChapterModel>> fetchChapters(
    String subjectId, {
    required String teacherId,
  }) async {
    await _requireTeacherOwnsSubject(subjectId, teacherId);
    final data = await _db
        .from('chapters')
        .select()
        .eq('subject_id', subjectId)
        .order('sort_order');
    return data
        .map(
          (j) => ChapterModel.fromJson({
            ...Map<String, dynamic>.from(j),
            'lectures': <dynamic>[],
          }),
        )
        .toList();
  }

  Future<ChapterModel> createChapter({
    required String teacherId,
    required String subjectId,
    required String name,
    required int sortOrder,
  }) async {
    await _requireTeacherOwnsSubject(subjectId, teacherId);
    final data = await _db
        .from('chapters')
        .insert({
          'subject_id': subjectId,
          'name': name,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return ChapterModel.fromJson({
      ...Map<String, dynamic>.from(data),
      'lectures': <dynamic>[],
    });
  }

  Future<ChapterModel> updateChapter({
    required String teacherId,
    required String chapterId,
    required String name,
    required int sortOrder,
  }) async {
    await _requireTeacherOwnsChapter(chapterId, teacherId);
    final data = await _db
        .from('chapters')
        .update({'name': name, 'sort_order': sortOrder})
        .eq('id', chapterId)
        .select()
        .single();
    return ChapterModel.fromJson({
      ...Map<String, dynamic>.from(data),
      'lectures': <dynamic>[],
    });
  }

  Future<void> deleteChapter(
    String chapterId, {
    required String teacherId,
  }) async {
    await _requireTeacherOwnsChapter(chapterId, teacherId);
    final lectures = await _db
        .from('lectures')
        .select('id')
        .eq('chapter_id', chapterId);
    final tests = await _db
        .from('tests')
        .select('id')
        .eq('chapter_id', chapterId);
    if (lectures.isNotEmpty || tests.isNotEmpty) {
      throw StateError(
        'Delete this chapter’s lectures and tests before deleting the chapter.',
      );
    }
    await _db.from('chapters').delete().eq('id', chapterId);
  }

  // ════════════════════════════════════════════════════════
  //  LECTURES
  // ════════════════════════════════════════════════════════

  Future<List<LectureModel>> fetchLectures(
    String chapterId, {
    required String teacherId,
  }) async {
    await _requireTeacherOwnsChapter(chapterId, teacherId);
    final data = await _db
        .from('lectures')
        .select()
        .eq('chapter_id', chapterId)
        .order('sort_order');
    return data
        .map((j) => LectureModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<LectureModel> createLecture({
    required String teacherId,
    required String chapterId,
    required String title,
    String? description,
    String? videoUrl,
    String? notesUrl,
    int? durationSeconds,
    bool isFree = false,
    int sortOrder = 0,
  }) async {
    await _requireTeacherOwnsChapter(chapterId, teacherId);
    final data = await _db
        .from('lectures')
        .insert({
          'chapter_id': chapterId,
          'title': title,
          'description': description,
          'video_url': videoUrl,
          'notes_url': notesUrl,
          'duration_seconds': durationSeconds,
          'is_free': isFree,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return LectureModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<LectureModel> updateLecture({
    required String teacherId,
    required String lectureId,
    required String title,
    String? description,
    String? videoUrl,
    String? notesUrl,
    int? durationSeconds,
    bool isFree = false,
    int sortOrder = 0,
  }) async {
    await _requireTeacherOwnsLecture(lectureId, teacherId);
    final data = await _db
        .from('lectures')
        .update({
          'title': title,
          'description': description,
          'video_url': videoUrl,
          'notes_url': notesUrl,
          'duration_seconds': durationSeconds,
          'is_free': isFree,
          'sort_order': sortOrder,
        })
        .eq('id', lectureId)
        .select()
        .single();
    return LectureModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> deleteLecture(
    String lectureId, {
    required String teacherId,
  }) async {
    await _requireTeacherOwnsLecture(lectureId, teacherId);
    await _db.from('lectures').delete().eq('id', lectureId);
  }

  // ════════════════════════════════════════════════════════
  //  ENROLLED STUDENTS
  // ════════════════════════════════════════════════════════

  Future<List<EnrolledStudentInfo>> fetchEnrolledStudents(
    String courseId, {
    required String teacherId,
  }) async {
    await _requireTeacherOwnsCourse(courseId, teacherId);
    final data = await _db
        .from('batches')
        .select(
          'id, batch_name, enrollments(student_id, enrolled_at, users!student_id(name, email, avatar_url))',
        )
        .eq('course_id', courseId);

    final students = <EnrolledStudentInfo>[];
    for (final batch in data) {
      final batchName = batch['batch_name'] as String? ?? '';
      final enrollments = batch['enrollments'] as List<dynamic>? ?? [];
      for (final enr in enrollments) {
        final user = enr['users'] as Map<String, dynamic>?;
        students.add(
          EnrolledStudentInfo(
            studentId: enr['student_id'] as String,
            name: user?['name'] as String? ?? 'Unknown',
            email: user?['email'] as String? ?? '',
            avatarUrl: user?['avatar_url'] as String?,
            batchName: batchName,
            enrolledAt:
                DateTime.tryParse(enr['enrolled_at'] as String? ?? '') ??
                DateTime.now(),
          ),
        );
      }
    }
    return students;
  }

  // ════════════════════════════════════════════════════════
  //  FULL COURSE OUTLINE (subjects → chapters → lectures)
  // ════════════════════════════════════════════════════════

  Future<List<SubjectModel>> fetchCourseOutline(
    String courseId, {
    required String teacherId,
  }) async {
    await _requireTeacherOwnsCourse(courseId, teacherId);
    final data = await _db
        .from('subjects')
        .select('*, chapters(*, lectures(*))')
        .eq('course_id', courseId)
        .order('sort_order');
    return data
        .map((j) => SubjectModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }
}

class EnrolledStudentInfo {
  final String studentId;
  final String name;
  final String email;
  final String? avatarUrl;
  final String batchName;
  final DateTime enrolledAt;

  const EnrolledStudentInfo({
    required this.studentId,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.batchName,
    required this.enrolledAt,
  });
}

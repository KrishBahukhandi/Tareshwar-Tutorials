// ─────────────────────────────────────────────────────────────
//  teacher_course_repository.dart
//  All Supabase CRUD for Teacher Course Management.
//  Covers: Course, Subject, Chapter, Lecture, EnrolledStudents.
// ─────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/models.dart';
import '../../../shared/services/supabase_service.dart';

final teacherCourseRepoProvider =
    Provider<TeacherCourseRepository>((ref) {
  return TeacherCourseRepository(ref.watch(supabaseClientProvider));
});

class TeacherCourseRepository {
  final SupabaseClient _db;
  TeacherCourseRepository(this._db);

  // ════════════════════════════════════════════════════════
  //  COURSES
  // ════════════════════════════════════════════════════════

  /// All courses owned by [teacherId], with denormalised counts.
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
    required String courseId,
    required String title,
    required String description,
    required double price,
    String? thumbnailUrl,
    String? categoryTag,
  }) async {
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

  Future<void> deleteCourse(String courseId) async {
    await _db.from('courses').delete().eq('id', courseId);
  }

  Future<void> togglePublish(String courseId, {required bool publish}) async {
    await _db
        .from('courses')
        .update({'is_published': publish})
        .eq('id', courseId);
  }

  // ════════════════════════════════════════════════════════
  //  SUBJECTS
  // ════════════════════════════════════════════════════════

  Future<List<SubjectModel>> fetchSubjects(String courseId) async {
    final data = await _db
        .from('subjects')
        .select()
        .eq('course_id', courseId)
        .order('sort_order');
    return data
        .map((j) => SubjectModel.fromJson({
              ...Map<String, dynamic>.from(j),
              'chapters': <dynamic>[],
            }))
        .toList();
  }

  Future<SubjectModel> createSubject({
    required String courseId,
    required String name,
    required int sortOrder,
  }) async {
    final data = await _db
        .from('subjects')
        .insert({
          'course_id': courseId,
          'name': name,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return SubjectModel.fromJson({
      ...Map<String, dynamic>.from(data),
      'chapters': <dynamic>[],
    });
  }

  Future<SubjectModel> updateSubject({
    required String subjectId,
    required String name,
    required int sortOrder,
  }) async {
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

  Future<void> deleteSubject(String subjectId) async {
    await _db.from('subjects').delete().eq('id', subjectId);
  }

  // ════════════════════════════════════════════════════════
  //  CHAPTERS
  // ════════════════════════════════════════════════════════

  Future<List<ChapterModel>> fetchChapters(String subjectId) async {
    final data = await _db
        .from('chapters')
        .select()
        .eq('subject_id', subjectId)
        .order('sort_order');
    return data
        .map((j) => ChapterModel.fromJson({
              ...Map<String, dynamic>.from(j),
              'lectures': <dynamic>[],
            }))
        .toList();
  }

  Future<ChapterModel> createChapter({
    required String subjectId,
    required String name,
    required int sortOrder,
  }) async {
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
    required String chapterId,
    required String name,
    required int sortOrder,
  }) async {
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

  Future<void> deleteChapter(String chapterId) async {
    await _db.from('chapters').delete().eq('id', chapterId);
  }

  // ════════════════════════════════════════════════════════
  //  LECTURES
  // ════════════════════════════════════════════════════════

  Future<List<LectureModel>> fetchLectures(String chapterId) async {
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
    required String chapterId,
    required String title,
    String? description,
    String? videoUrl,
    String? notesUrl,
    int? durationSeconds,
    bool isFree = false,
    int sortOrder = 0,
  }) async {
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
    required String lectureId,
    required String title,
    String? description,
    String? videoUrl,
    String? notesUrl,
    int? durationSeconds,
    bool isFree = false,
    int sortOrder = 0,
  }) async {
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

  Future<void> deleteLecture(String lectureId) async {
    await _db.from('lectures').delete().eq('id', lectureId);
  }

  // ════════════════════════════════════════════════════════
  //  ENROLLED STUDENTS
  // ════════════════════════════════════════════════════════

  /// Returns list of enrolled students for a course (via batches → enrollments).
  Future<List<EnrolledStudentInfo>> fetchEnrolledStudents(
      String courseId) async {
    final data = await _db
        .from('batches')
        .select('id, batch_name, enrollments(student_id, enrolled_at, users!student_id(name, email, avatar_url))')
        .eq('course_id', courseId);

    final students = <EnrolledStudentInfo>[];
    for (final batch in data) {
      final batchName = batch['batch_name'] as String? ?? '';
      final enrollments = batch['enrollments'] as List<dynamic>? ?? [];
      for (final enr in enrollments) {
        final user = enr['users'] as Map<String, dynamic>?;
        students.add(EnrolledStudentInfo(
          studentId: enr['student_id'] as String,
          name: user?['name'] as String? ?? 'Unknown',
          email: user?['email'] as String? ?? '',
          avatarUrl: user?['avatar_url'] as String?,
          batchName: batchName,
          enrolledAt: DateTime.tryParse(
                  enr['enrolled_at'] as String? ?? '') ??
              DateTime.now(),
        ));
      }
    }
    return students;
  }

  // ════════════════════════════════════════════════════════
  //  FULL COURSE OUTLINE (subjects → chapters → lectures)
  // ════════════════════════════════════════════════════════

  Future<List<SubjectModel>> fetchCourseOutline(String courseId) async {
    final data = await _db
        .from('subjects')
        .select('*, chapters(*, lectures(*))')
        .eq('course_id', courseId)
        .order('sort_order');
    return data
        .map((j) =>
            SubjectModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────
//  Lightweight DTO for enrolled student display
// ─────────────────────────────────────────────────────────────
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

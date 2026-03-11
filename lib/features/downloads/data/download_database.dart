// ─────────────────────────────────────────────────────────────
//  download_database.dart  –  SQLite persistence layer for
//  offline lecture downloads.
//
//  Table: downloaded_lectures
//  Primary key: (lecture_id, student_id)  – one row per
//  student per lecture, so multiple accounts on the same
//  device don't see each other's downloads.
// ─────────────────────────────────────────────────────────────
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'download_model.dart';

class DownloadDatabase {
  DownloadDatabase._();
  static final DownloadDatabase instance = DownloadDatabase._();

  static Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'downloads.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS downloaded_lectures (
            lecture_id       TEXT NOT NULL,
            student_id       TEXT NOT NULL,
            title            TEXT NOT NULL,
            course_title     TEXT NOT NULL DEFAULT '',
            duration_seconds INTEGER NOT NULL DEFAULT 0,
            local_path       TEXT NOT NULL,
            file_size_bytes  INTEGER NOT NULL DEFAULT 0,
            status           TEXT NOT NULL DEFAULT 'completed',
            progress         REAL NOT NULL DEFAULT 1.0,
            downloaded_at    TEXT NOT NULL,
            PRIMARY KEY (lecture_id, student_id)
          )
        ''');
      },
    );
  }

  // ── Upsert ────────────────────────────────────────────────────
  Future<void> upsert(DownloadedLecture dl) async {
    final db = await _database;
    await db.insert(
      'downloaded_lectures',
      dl.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Fetch all for a student ───────────────────────────────────
  Future<List<DownloadedLecture>> getAllForStudent(String studentId) async {
    final db = await _database;
    final rows = await db.query(
      'downloaded_lectures',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'downloaded_at DESC',
    );
    return rows.map(DownloadedLecture.fromMap).toList();
  }

  // ── Fetch single ──────────────────────────────────────────────
  Future<DownloadedLecture?> get(
      {required String lectureId, required String studentId}) async {
    final db = await _database;
    final rows = await db.query(
      'downloaded_lectures',
      where: 'lecture_id = ? AND student_id = ?',
      whereArgs: [lectureId, studentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DownloadedLecture.fromMap(rows.first);
  }

  // ── Delete single ─────────────────────────────────────────────
  Future<void> delete(
      {required String lectureId, required String studentId}) async {
    final db = await _database;
    await db.delete(
      'downloaded_lectures',
      where: 'lecture_id = ? AND student_id = ?',
      whereArgs: [lectureId, studentId],
    );
  }

  // ── Delete all for student ────────────────────────────────────
  Future<void> deleteAllForStudent(String studentId) async {
    final db = await _database;
    await db.delete(
      'downloaded_lectures',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  // ── Total size used by a student ──────────────────────────────
  Future<int> totalSizeBytes(String studentId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT SUM(file_size_bytes) as total FROM downloaded_lectures '
      'WHERE student_id = ? AND status = ?',
      [studentId, DownloadStatus.completed.name],
    );
    return (result.first['total'] as int?) ?? 0;
  }
}

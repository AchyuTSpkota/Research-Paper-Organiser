import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/paper.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const List<String> categories = [
    'Computer Science & AI',
    'Medicine & Biology',
    'Physics & Mathematics',
    'Psychology & Social Sciences',
    'Law & Political Science',
    'Engineering & Other',
  ];

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'mypaperhub.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE papers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            authors TEXT NOT NULL DEFAULT '',
            year INTEGER NOT NULL,
            abstract TEXT NOT NULL DEFAULT '',
            keywords TEXT NOT NULL DEFAULT '',
            doi TEXT NOT NULL DEFAULT '',
            file_path TEXT NOT NULL,
            full_text TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            read_status TEXT NOT NULL DEFAULT 'unread',
            category TEXT NOT NULL DEFAULT 'Engineering & Other'
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE papers ADD COLUMN read_status TEXT NOT NULL DEFAULT 'unread'",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE papers ADD COLUMN category TEXT NOT NULL DEFAULT 'Engineering & Other'",
          );
        }
      },
    );
  }

  Future<int> insertPaper(Paper paper) async {
    final db = await database;
    return db.insert('papers', paper.toMap());
  }

  Future<List<Paper>> search(String query) async {
    final db = await database;
    final q = query.trim();
    if (q.isEmpty) {
      final rows = await db.query('papers', orderBy: 'created_at DESC');
      return rows.map(Paper.fromMap).toList();
    }
    final like = '%$q%';
    final rows = await db.query(
      'papers',
      where: 'title LIKE ? OR authors LIKE ? OR abstract LIKE ? '
          'OR keywords LIKE ? OR doi LIKE ? OR full_text LIKE ? '
          'OR category LIKE ?',
      whereArgs: [like, like, like, like, like, like, like],
      orderBy: 'created_at DESC',
    );
    return rows.map(Paper.fromMap).toList();
  }

  Future<int> deletePaper(int id) async {
    final db = await database;
    return db.delete('papers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateReadStatus(int id, String status) async {
    final db = await database;
    await db.update(
      'papers',
      {'read_status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCategory(int id, String category) async {
    final db = await database;
    await db.update(
      'papers',
      {'category': category},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns a map of category → count for the pie chart.
  Future<Map<String, int>> categoryCounts() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT category, COUNT(*) AS c FROM papers GROUP BY category',
    );
    final result = <String, int>{};
    for (final c in categories) {
      result[c] = 0;
    }
    for (final r in rows) {
      final cat = (r['category'] as String?) ?? 'Engineering & Other';
      result[cat] = (r['c'] as int?) ?? 0;
    }
    return result;
  }
}
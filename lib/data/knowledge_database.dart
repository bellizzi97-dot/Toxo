import 'package:sqlite3/sqlite3.dart';

import 'knowledge_package.dart';

class KnowledgeResult {
  const KnowledgeResult({
    required this.title,
    required this.text,
    required this.sourceTitle,
    required this.license,
    required this.attribution,
    required this.sourceUrl,
  });

  final String title;
  final String text;
  final String sourceTitle;
  final String license;
  final String attribution;
  final String sourceUrl;
}

class MemoryPreference {
  const MemoryPreference({required this.id, required this.note});

  final int id;
  final String note;
}

class KnowledgeDatabase {
  KnowledgeDatabase(this._db);

  final Database _db;

  void initialize() {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS sources (
        package_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        license TEXT NOT NULL,
        attribution TEXT NOT NULL,
        url TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS articles (
        id TEXT PRIMARY KEY,
        package_id TEXT NOT NULL REFERENCES sources(package_id),
        title TEXT NOT NULL,
        text TEXT NOT NULL,
        source_url TEXT,
        source_title TEXT,
        license TEXT,
        attribution TEXT
      )
    ''');
    final articleColumns = _db
        .select('PRAGMA table_info(articles)')
        .map((row) => row['name'] as String)
        .toSet();
    if (!articleColumns.contains('source_url')) {
      _db.execute('ALTER TABLE articles ADD COLUMN source_url TEXT');
    }
    for (final column in ['source_title', 'license', 'attribution']) {
      if (!articleColumns.contains(column)) {
        _db.execute('ALTER TABLE articles ADD COLUMN $column TEXT');
      }
    }
    _db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(
        title, text, content='articles', content_rowid='rowid'
      )
    ''');
    _db.execute('''
      CREATE TRIGGER IF NOT EXISTS articles_ai AFTER INSERT ON articles BEGIN
        INSERT INTO articles_fts(rowid, title, text)
        VALUES (new.rowid, new.title, new.text);
      END
    ''');
    _db.execute('''
      CREATE TRIGGER IF NOT EXISTS articles_ad AFTER DELETE ON articles BEGIN
        INSERT INTO articles_fts(articles_fts, rowid, title, text)
        VALUES ('delete', old.rowid, old.title, old.text);
      END
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS preferences (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        memory_enabled INTEGER NOT NULL DEFAULT 0,
        style TEXT NOT NULL DEFAULT 'cercano',
        appearance TEXT NOT NULL DEFAULT 'neural',
        visual_effects TEXT NOT NULL DEFAULT 'dynamic'
      )
    ''');
    final preferenceColumns = _db
        .select('PRAGMA table_info(preferences)')
        .map((row) => row['name'] as String)
        .toSet();
    if (!preferenceColumns.contains('appearance')) {
      _db.execute(
        "ALTER TABLE preferences ADD COLUMN appearance TEXT NOT NULL DEFAULT 'neural'",
      );
    }
    if (!preferenceColumns.contains('visual_effects')) {
      _db.execute(
        "ALTER TABLE preferences ADD COLUMN visual_effects TEXT NOT NULL DEFAULT 'dynamic'",
      );
    }
    _db.execute(
      "INSERT OR IGNORE INTO preferences(id, memory_enabled, style) "
      "VALUES (1, 0, 'cercano')",
    );
    _db.execute('''
      CREATE TABLE IF NOT EXISTS memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  int get articleCount =>
      _db.select('SELECT COUNT(*) AS count FROM articles').first['count'] as int;

  bool get memoryEnabled =>
      _db.select('SELECT memory_enabled FROM preferences WHERE id = 1')
          .first['memory_enabled'] ==
      1;

  String get style => _db.select(
        'SELECT style FROM preferences WHERE id = 1',
      ).first['style'] as String;

  String get appearance => _db.select(
        'SELECT appearance FROM preferences WHERE id = 1',
      ).first['appearance'] as String;

  String get visualEffects => _db.select(
        'SELECT visual_effects FROM preferences WHERE id = 1',
      ).first['visual_effects'] as String;

  void setMemoryEnabled(bool enabled) {
    _db.execute(
      'UPDATE preferences SET memory_enabled = ? WHERE id = 1',
      [enabled ? 1 : 0],
    );
    if (!enabled) {
      _db.execute('DELETE FROM memories');
    }
  }

  void setStyle(String value) {
    if (value != 'cercano' && value != 'breve') {
      throw ArgumentError.value(value, 'value', 'Estilo no admitido.');
    }
    _db.execute('UPDATE preferences SET style = ? WHERE id = 1', [value]);
  }

  void setAppearance(String value) {
    if (value != 'neural' && value != 'mint') {
      throw ArgumentError.value(value, 'value', 'Tema no admitido.');
    }
    _db.execute(
      'UPDATE preferences SET appearance = ? WHERE id = 1',
      [value],
    );
  }

  void setVisualEffects(String value) {
    if (value != 'dynamic' && value != 'subtle' && value != 'off') {
      throw ArgumentError.value(value, 'value', 'Intensidad no admitida.');
    }
    _db.execute(
      'UPDATE preferences SET visual_effects = ? WHERE id = 1',
      [value],
    );
  }

  void remember(String note) {
    if (!memoryEnabled) {
      throw StateError('Activa la memoria local antes de guardar preferencias.');
    }
    final cleaned = note.trim();
    if (cleaned.isEmpty || cleaned.length > 500) {
      throw ArgumentError.value(note, 'note', 'Usa entre 1 y 500 caracteres.');
    }
    _db.execute('INSERT INTO memories(note) VALUES (?)', [cleaned]);
  }

  List<MemoryPreference> get memories => _db
      .select('SELECT id, note FROM memories ORDER BY id DESC')
      .map(
        (row) => MemoryPreference(
          id: row['id'] as int,
          note: row['note'] as String,
        ),
      )
      .toList(growable: false);

  void deleteMemory(int id) {
    _db.execute('DELETE FROM memories WHERE id = ?', [id]);
  }

  void clearMemories() {
    _db.execute('DELETE FROM memories');
  }

  void importPackage(KnowledgePackage package) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'INSERT OR IGNORE INTO sources(package_id, title, license, attribution, url) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          package.packageId,
          package.sourceTitle,
          package.license,
          package.attribution,
          package.sourceUrl,
        ],
      );
      final source = _db.select(
        'SELECT title, license, attribution, url FROM sources WHERE package_id = ?',
        [package.packageId],
      ).first;
      if (source['title'] != package.sourceTitle ||
          source['license'] != package.license ||
          source['attribution'] != package.attribution ||
          source['url'] != package.sourceUrl) {
        throw const FormatException(
          'El identificador del paquete ya existe con otros metadatos.',
        );
      }
      for (final article in package.articles) {
        final existing = _db.select(
          'SELECT package_id, title, text, source_url, source_title, license, '
          'attribution FROM articles WHERE id = ?',
          [article.id],
        );
        final sameContentFromAnotherPackage =
            existing.isNotEmpty &&
            existing.first['package_id'] != package.packageId &&
            existing.first['title'] == article.title &&
            existing.first['text'] == article.text;
        if (existing.isNotEmpty &&
            !sameContentFromAnotherPackage &&
            (existing.first['title'] != article.title ||
                existing.first['text'] != article.text ||
                existing.first['source_url'] != article.sourceUrl ||
                existing.first['source_title'] != article.sourceTitle ||
                existing.first['license'] != article.license ||
                existing.first['attribution'] != article.attribution)) {
          throw FormatException(
            'El identificador de artículo "${article.id}" ya está en uso.',
          );
        }
        _db.execute(
          'INSERT OR IGNORE INTO articles'
          '(id, package_id, title, text, source_url, source_title, license, '
          'attribution) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            article.id,
            package.packageId,
            article.title,
            article.text,
            article.sourceUrl,
            article.sourceTitle,
            article.license,
            article.attribution,
          ],
        );
      }
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<KnowledgeResult> search(String query, {int limit = 5}) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((term) => term.length >= 2)
        .take(12)
        .toSet();
    if (terms.isEmpty) return const [];

    final match =
        terms.map((term) => '"${term.replaceAll('"', '""')}"').join(' OR ');
    final rows = _db.select(
      '''
      SELECT a.title, a.text, COALESCE(a.source_title, s.title) AS source_title,
             COALESCE(a.license, s.license) AS license,
             COALESCE(a.attribution, s.attribution) AS attribution,
             COALESCE(a.source_url, s.url) AS source_url
      FROM articles_fts
      JOIN articles a ON a.rowid = articles_fts.rowid
      JOIN sources s ON s.package_id = a.package_id
      WHERE articles_fts MATCH ?
      ORDER BY bm25(articles_fts)
      LIMIT ?
      ''',
      [match, limit],
    );
    return rows
        .map(
          (row) => KnowledgeResult(
            title: row['title'] as String,
            text: row['text'] as String,
            sourceTitle: row['source_title'] as String,
            license: row['license'] as String,
            attribution: row['attribution'] as String,
            sourceUrl: row['source_url'] as String,
          ),
        )
        .toList(growable: false);
  }

  void close() => _db.dispose();
}

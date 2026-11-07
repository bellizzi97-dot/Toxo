import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:toxo/data/knowledge_database.dart';
import 'package:toxo/data/knowledge_package.dart';

void main() {
  late KnowledgeDatabase database;

  setUp(() {
    database = KnowledgeDatabase(sqlite3.open(':memory:'))..initialize();
  });

  tearDown(() {
    database.close();
  });

  test('imports a package and retrieves a cited article with FTS5', () {
    database.importPackage(_package());

    final results = database.search('¿Qué sabes de volcanes?');

    expect(database.articleCount, 1);
    expect(results, hasLength(1));
    expect(results.single.title, 'Volcanes');
    expect(results.single.sourceTitle, 'Enciclopedia de prueba');
    expect(results.single.license, 'CC0-1.0');
    expect(results.single.text, contains('magma'));
  });

  test('uses article-level attribution for multi-source packages', () {
    final package = KnowledgePackage(
      packageId: 'mixed-sources',
      sourceTitle: 'Biblioteca abierta',
      license: 'CC0-1.0 y CC BY-SA 4.0',
      attribution: 'Cada artículo identifica su fuente.',
      sourceUrl: 'https://example.org/library',
      articles: const [
        KnowledgeArticle(
          id: 'wikipedia-gravity',
          title: 'Gravedad',
          text: 'La gravedad es una interacción entre cuerpos con masa.',
          sourceTitle: 'Wikipedia en español — Gravedad',
          license: 'CC BY-SA 4.0',
          attribution: 'Wikipedia contributors',
          sourceUrl: 'https://es.wikipedia.org/wiki/Gravedad?oldid=123',
        ),
      ],
    );
    database.importPackage(package);

    final result = database.search('interacción entre cuerpos').single;

    expect(result.sourceTitle, 'Wikipedia en español — Gravedad');
    expect(result.license, 'CC BY-SA 4.0');
    expect(result.attribution, 'Wikipedia contributors');
    expect(result.sourceUrl, contains('oldid=123'));
  });

  test('preserves existing attribution when identical article IDs are reused', () {
    database.importPackage(_package());
    database.importPackage(
      KnowledgePackage(
        packageId: 'updated-library',
        sourceTitle: 'Fuentes abiertas mixtas',
        license: 'CC0-1.0 y CC BY-SA 4.0',
        attribution: 'Licencia específica por artículo.',
        sourceUrl: 'https://example.org/updated',
        articles: const [
          KnowledgeArticle(
            id: 'volcanes',
            title: 'Volcanes',
            text: 'El magma puede salir a la superficie durante una erupción.',
            sourceTitle: 'Otra copia',
            license: 'CC BY-SA 4.0',
            attribution: 'Otra atribución',
            sourceUrl: 'https://example.org/volcanes',
          ),
        ],
      ),
    );

    final result = database.search('magma').single;
    expect(database.articleCount, 1);
    expect(result.sourceTitle, 'Enciclopedia de prueba');
    expect(result.license, 'CC0-1.0');
  });

  test('migrates existing article tables before importing source metadata', () {
    database.close();
    final oldDatabase = sqlite3.open(':memory:');
    oldDatabase.execute('''
      CREATE TABLE sources (
        package_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        license TEXT NOT NULL,
        attribution TEXT NOT NULL,
        url TEXT NOT NULL
      )
    ''');
    oldDatabase.execute('''
      CREATE TABLE articles (
        id TEXT PRIMARY KEY,
        package_id TEXT NOT NULL REFERENCES sources(package_id),
        title TEXT NOT NULL,
        text TEXT NOT NULL
      )
    ''');
    oldDatabase.execute('''
      CREATE TABLE preferences (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        memory_enabled INTEGER NOT NULL DEFAULT 0,
        style TEXT NOT NULL DEFAULT 'cercano'
      )
    ''');
    oldDatabase.execute(
      "INSERT INTO preferences(id, memory_enabled, style) VALUES (1, 0, 'cercano')",
    );
    database = KnowledgeDatabase(oldDatabase)..initialize();
    database.importPackage(
      KnowledgePackage(
        packageId: 'new-license',
        sourceTitle: 'Biblioteca',
        license: 'CC BY-SA 4.0',
        attribution: 'Fuente global',
        sourceUrl: 'https://example.org/library',
        articles: const [
          KnowledgeArticle(
            id: 'attributed',
            title: 'Célula',
            text: 'La célula es la unidad básica de los seres vivos.',
            sourceTitle: 'Wikipedia en español — Célula',
            license: 'CC BY-SA 4.0',
            attribution: 'Wikipedia contributors',
            sourceUrl: 'https://es.wikipedia.org/wiki/C%C3%A9lula?oldid=42',
          ),
        ],
      ),
    );

    expect(database.search('unidad básica').single.sourceUrl, contains('oldid=42'));
    expect(database.appearance, 'neural');
    expect(database.visualEffects, 'dynamic');
  });

  test('searches and returns UTF-8 accented content from the bundled library', () {
    final package = KnowledgePackage.decode(
      File('assets/packs/toxo-conocimientos-es-v3.json').readAsStringSync(),
    );
    database.importPackage(package);

    final result = database
        .search('átomos químicos')
        .firstWhere((article) => article.title == 'Átomo');

    expect(result.title, 'Átomo');
    expect(result.text, contains('químicos'));
    expect(result.sourceTitle, contains('Wikipedia en español'));
    expect(result.sourceUrl, contains('oldid='));
  });

  test('rejects a conflicting package atomically', () {
    database.importPackage(_package());

    final conflicting = KnowledgePackage(
      packageId: 'paquete-abierto',
      sourceTitle: 'Otra fuente',
      license: 'CC0-1.0',
      attribution: 'Equipo Toxo',
      sourceUrl: 'https://example.org/source',
      articles: const [
        KnowledgeArticle(
          id: 'volcanes',
          title: 'Volcanes nuevos',
          text: 'Contenido distinto.',
        ),
      ],
    );

    expect(() => database.importPackage(conflicting), throwsFormatException);
    expect(database.articleCount, 1);
    expect(database.search('magma'), hasLength(1));
  });

  test(
      'stores preferences only when memory is enabled and clears them when disabled',
      () {
    expect(
      () => database.remember('Prefiero respuestas cortas'),
      throwsStateError,
    );

    database.setMemoryEnabled(true);
    database.remember('Prefiero respuestas cortas');
    database.setStyle('breve');

    expect(database.memories.single.note, 'Prefiero respuestas cortas');
    expect(database.style, 'breve');

    database.setMemoryEnabled(false);

    expect(database.memories, isEmpty);
    expect(database.memoryEnabled, isFalse);
    expect(database.style, 'breve');
  });
}

KnowledgePackage _package() => const KnowledgePackage(
      packageId: 'paquete-abierto',
      sourceTitle: 'Enciclopedia de prueba',
      license: 'CC0-1.0',
      attribution: 'Equipo Toxo',
      sourceUrl: 'https://example.org/source',
      articles: [
        KnowledgeArticle(
          id: 'volcanes',
          title: 'Volcanes',
          text: 'El magma puede salir a la superficie durante una erupción.',
        ),
      ],
    );

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

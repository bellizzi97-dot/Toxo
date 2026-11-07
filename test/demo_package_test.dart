import 'package:flutter_test/flutter_test.dart';
import 'package:toxo/data/demo_package.dart';
import 'package:toxo/data/knowledge_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('demo knowledge is immediately searchable offline with CC0 attribution', () {
    final database = KnowledgeDatabase(sqlite3.open(':memory:'))..initialize();
    addTearDown(database.close);
    database.importPackage(demoKnowledgePackage);

    final results = database.search('¿Cómo funciona la fotosíntesis?');

    expect(demoKnowledgePackage.license, 'CC0-1.0');
    expect(results, isNotEmpty);
    expect(results.first.title, 'Fotosíntesis');
    expect(results.first.attribution, contains('Contenido original'));
  });
}

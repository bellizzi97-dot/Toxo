import 'package:flutter_test/flutter_test.dart';
import 'package:toxo/data/knowledge_package.dart';

void main() {
  group('KnowledgePackage.decode', () {
    test('decodes an attributed package and its articles', () {
      final package = KnowledgePackage.decode(_packageJson());

      expect(package.packageId, 'open-es-1');
      expect(package.license, 'CC BY-SA 4.0');
      expect(package.articles, hasLength(1));
      expect(package.articles.single.title, 'Artículo de prueba');
    });

    test('rejects sources without HTTPS URLs', () {
      expect(
        () => KnowledgePackage.decode(
          _packageJson().replaceFirst(
            'https://example.org/source',
            'http://example.org/source',
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects duplicate article identifiers', () {
      final duplicate = _packageJson().replaceFirst(
        RegExp(r'"articles":\s*\[.*?\]', dotAll: true),
        '"articles":[{"id":"art-1","title":"Uno","text":"Texto uno."},'
        '{"id":"art-1","title":"Dos","text":"Texto dos."}]',
      );

      expect(
        () => KnowledgePackage.decode(duplicate),
        throwsFormatException,
      );
    });

    test('rejects unsupported schema versions', () {
      expect(
        () => KnowledgePackage.decode(
          _packageJson().replaceFirst(
            RegExp(r'"schemaVersion"\s*:\s*1'),
            '"schemaVersion":2',
          ),
        ),
        throwsFormatException,
      );
    });
  });
}

String _packageJson() => '''
{
  "schemaVersion": 1,
  "packageId": "open-es-1",
  "source": {
    "title": "Fuente de prueba",
    "license": "CC BY-SA 4.0",
    "attribution": "Atribución de prueba",
    "url": "https://example.org/source"
  },
  "articles": [
    {
      "id": "art-1",
      "title": "Artículo de prueba",
      "text": "Texto abierto de prueba."
    }
  ]
}
''';

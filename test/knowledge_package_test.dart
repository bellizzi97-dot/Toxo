import 'dart:io';

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

    test('preserves article-specific license, attribution, and source URL', () {
      final package = KnowledgePackage.decode(
        _packageJson().replaceFirst(
          '"text": "Texto abierto de prueba."',
          '"text": "Texto abierto de prueba.",'
          '"sourceTitle": "Wikipedia en español — Prueba",'
          '"license": "CC BY-SA 4.0",'
          '"attribution": "Contribuidores de Wikipedia",'
          '"sourceUrl": "https://es.wikipedia.org/wiki/Prueba?oldid=123"',
        ),
      );

      final article = package.articles.single;
      expect(article.license, 'CC BY-SA 4.0');
      expect(article.attribution, 'Contribuidores de Wikipedia');
      expect(article.sourceUrl, contains('oldid=123'));
    });

    test('rejects insecure per-article source URLs', () {
      expect(
        () => KnowledgePackage.decode(
          _packageJson().replaceFirst(
            '"text": "Texto abierto de prueba."',
            '"text": "Texto abierto de prueba.",'
            '"sourceUrl": "http://es.wikipedia.org/wiki/Prueba"',
          ),
        ),
        throwsFormatException,
      );
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

    test('bundled library has 40 attributed entries from compatible licenses', () {
      final package = KnowledgePackage.decode(
        File('assets/packs/toxo-conocimientos-es-v2.json').readAsStringSync(),
      );

      expect(package.articles, hasLength(40));
      expect(
        package.articles.where((article) => article.license == 'CC BY-SA 4.0'),
        hasLength(25),
      );
      expect(
        package.articles.where((article) => article.license == 'CC0-1.0'),
        hasLength(15),
      );
      expect(
        package.articles
            .where((article) => article.license == 'CC BY-SA 4.0')
            .every((article) => article.sourceUrl!.contains('oldid=')),
        isTrue,
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:toxo/data/knowledge_database.dart';
import 'package:toxo/data/offline_pack_manager.dart';
import 'package:toxo/data/offline_pack_manifest.dart';
import 'package:toxo/screens/chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory supportDirectory;
  late KnowledgeDatabase database;
  late OfflinePackManager manager;
  late MockClient client;
  late Completer<void> knowledgeResponse;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp('toxo-chat-test-');
    database = KnowledgeDatabase(sqlite3.open(':memory:'))..initialize();
    final model = utf8.encode('model fixture');
    final knowledge = utf8.encode(_knowledgeJson);
    knowledgeResponse = Completer<void>();
    client = MockClient((request) async {
      if (request.url.path.endsWith('library.json')) {
        await knowledgeResponse.future;
        return http.Response.bytes(knowledge, 200);
      }
      return http.Response.bytes(model, 200);
    });
    manager = OfflinePackManager(
      manifest: OfflinePackManifest.decode(
        jsonEncode(_manifestJson(model, knowledge)),
      ),
      database: database,
      supportDirectory: supportDirectory,
      client: client,
    );
  });

  tearDown(() async {
    if (!knowledgeResponse.isCompleted) knowledgeResponse.complete();
    manager.close();
    client.close();
    database.close();
    await supportDirectory.delete(recursive: true);
  });

  testWidgets('shows download progress stages and lets the user cancel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ChatScreen(database: database, packManager: manager)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Descargar ·'));
    await tester.pumpAndSettle();
    expect(find.text('Descargar el pack offline'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Descargar'));
    await tester.pump();

    expect(find.text('Preparando la descarga…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    knowledgeResponse.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.textContaining('Descarga cancelada'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(await manager.isInstalled, isFalse);
  });
}

Map<String, Object?> _manifestJson(List<int> model, List<int> knowledge) => {
  'schemaVersion': 1,
  'packId': 'toxo-widget-test',
  'version': 1,
  'title': 'Pack de prueba',
  'model': {
    'id': 'test-model',
    'fileName': 'model.gguf',
    'url': 'https://example.test/model.gguf',
    'sizeBytes': model.length,
    'sha256': sha256.convert(model).toString(),
    'license': 'Apache-2.0',
    'licenseUrl': 'https://example.test/license',
    'attribution': 'Modelo de prueba',
    'sourceUrl': 'https://example.test/model',
  },
  'knowledge': {
    'id': 'test-knowledge',
    'fileName': 'library.json',
    'url': 'https://example.test/library.json',
    'sizeBytes': knowledge.length,
    'sha256': sha256.convert(knowledge).toString(),
    'license': 'CC0-1.0',
    'licenseUrl': 'https://example.test/license',
    'attribution': 'Contenido de prueba',
    'sourceUrl': 'https://example.test/library',
  },
};

const _knowledgeJson = '''
{
  "schemaVersion": 1,
  "packageId": "test-knowledge",
  "source": {
    "title": "Biblioteca de prueba",
    "license": "CC0-1.0",
    "attribution": "Contenido de prueba",
    "url": "https://example.test/library"
  },
  "articles": [
    {"id": "test-1", "title": "Fotosíntesis", "text": "La luz y las plantas."}
  ]
}
''';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:toxo/data/knowledge_database.dart';
import 'package:toxo/data/offline_pack_manager.dart';
import 'package:toxo/data/offline_pack_manifest.dart';
import 'package:toxo/screens/chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory supportDirectory;
  late KnowledgeDatabase database;
  late _FakePackManager manager;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp('toxo-chat-test-');
    database = KnowledgeDatabase(sqlite3.open(':memory:'))..initialize();
    manager = _FakePackManager(
      manifest: OfflinePackManifest.decode(jsonEncode(_manifestJson)),
      database: database,
      supportDirectory: supportDirectory,
    );
  });

  tearDown(() async {
    manager.close();
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

    expect(find.text('Descargando la biblioteca abierta…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Descarga cancelada'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(await manager.isInstalled, isFalse);
    expect(manager.cancelled, isTrue);
  });
}

class _FakePackManager implements OfflinePackManager {
  _FakePackManager({
    required this.manifest,
    required this.database,
    required this.supportDirectory,
  });

  @override
  final OfflinePackManifest manifest;
  @override
  final KnowledgeDatabase database;
  @override
  final Directory supportDirectory;

  final _completion = Completer<void>();
  void Function(PackProgress progress)? _onProgress;
  bool cancelled = false;

  @override
  File get modelFile => File('model-fixture.gguf');

  @override
  Future<bool> get isInstalled async => false;

  @override
  Future<void> downloadAndInstall({
    required void Function(PackProgress progress) onProgress,
  }) {
    _onProgress = onProgress;
    onProgress(
      PackProgress(
        stage: PackInstallStage.downloadingKnowledge,
        message: 'Descargando la biblioteca abierta…',
        downloadedBytes: 0,
        totalBytes: manifest.totalBytes,
      ),
    );
    return _completion.future;
  }

  @override
  void cancelDownload() {
    cancelled = true;
    _onProgress!(
      PackProgress(
        stage: PackInstallStage.failed,
        message: 'Descarga cancelada. Puedes volver a intentarlo cuando quieras.',
        downloadedBytes: 0,
        totalBytes: manifest.totalBytes,
      ),
    );
    _completion.completeError(const PackDownloadCancelled());
  }

  @override
  void close() {}
}

final _manifestJson = {
  'schemaVersion': 1,
  'packId': 'toxo-widget-test',
  'version': 1,
  'title': 'Pack de prueba',
  'model': {
    'id': 'test-model',
    'fileName': 'model.gguf',
    'url': 'https://example.test/model.gguf',
    'sizeBytes': 13,
    'sha256': sha256.convert(utf8.encode('model fixture')).toString(),
    'license': 'Apache-2.0',
    'licenseUrl': 'https://example.test/license',
    'attribution': 'Modelo de prueba',
    'sourceUrl': 'https://example.test/model',
  },
  'knowledge': {
    'id': 'test-knowledge',
    'fileName': 'library.json',
    'url': 'https://example.test/library.json',
    'sizeBytes': 1,
    'sha256': sha256.convert([1]).toString(),
    'license': 'CC0-1.0',
    'licenseUrl': 'https://example.test/license',
    'attribution': 'Contenido de prueba',
    'sourceUrl': 'https://example.test/library',
  },
};

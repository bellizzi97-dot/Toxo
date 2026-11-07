import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:toxo/data/knowledge_database.dart';
import 'package:toxo/data/offline_pack_manager.dart';
import 'package:toxo/data/offline_pack_manifest.dart';

void main() {
  late Directory supportDirectory;
  late KnowledgeDatabase database;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp('toxo-pack-test-');
    database = KnowledgeDatabase(sqlite3.open(':memory:'))..initialize();
  });

  tearDown(() async {
    database.close();
    await supportDirectory.delete(recursive: true);
  });

  test('downloads, verifies, indexes, and records the model pack', () async {
    final model = utf8.encode('small model fixture');
    final knowledge = utf8.encode(_knowledgeJson);
    final client = _clientFor(model, knowledge);
    final manager = OfflinePackManager(
      manifest: _manifest(model, knowledge),
      database: database,
      supportDirectory: supportDirectory,
      client: client,
    );
    final progress = <PackProgress>[];

    await manager.downloadAndInstall(onProgress: progress.add);

    expect(await manager.isInstalled, isTrue);
    expect(await manager.modelFile.readAsBytes(), model);
    expect(database.search('fotosíntesis'), hasLength(1));
    expect(progress.map((item) => item.stage), containsAllInOrder([
      PackInstallStage.downloadingKnowledge,
      PackInstallStage.verifyingKnowledge,
      PackInstallStage.downloadingModel,
      PackInstallStage.verifyingModel,
      PackInstallStage.installing,
      PackInstallStage.ready,
    ]));
    expect(progress.last.fraction, 1);
    client.close();
  });

  test('rejects a pack when a downloaded asset fails SHA-256 verification', () async {
    final model = utf8.encode('altered model fixture');
    final knowledge = utf8.encode(_knowledgeJson);
    final client = _clientFor(model, knowledge);
    final manager = OfflinePackManager(
      manifest: _manifest(model, knowledge, modelSha256: '0' * 64),
      database: database,
      supportDirectory: supportDirectory,
      client: client,
    );
    final progress = <PackProgress>[];

    await expectLater(
      manager.downloadAndInstall(onProgress: progress.add),
      throwsA(isA<FormatException>()),
    );

    expect(await manager.isInstalled, isFalse);
    expect(database.articleCount, 0);
    expect(progress.last.stage, PackInstallStage.failed);
    expect(progress.last.message, contains('SHA-256'));
    client.close();
  });

  test('verifies streamed bytes when a redirect reports a misleading length', () async {
    final model = utf8.encode('small model fixture');
    final knowledge = utf8.encode(_knowledgeJson);
    final client = _MisreportedLengthClient(model, knowledge);
    final manager = OfflinePackManager(
      manifest: _manifest(model, knowledge),
      database: database,
      supportDirectory: supportDirectory,
      client: client,
    );

    await manager.downloadAndInstall(onProgress: (_) {});

    expect(await manager.isInstalled, isTrue);
    expect(await manager.modelFile.readAsBytes(), model);
    expect(database.search('fotosíntesis'), hasLength(1));
    client.close();
  });

  test('reports actual versus expected bytes when a stream is truncated', () async {
    final model = utf8.encode('small model fixture');
    final knowledge = utf8.encode(_knowledgeJson);
    final client = _TruncatedKnowledgeClient(model, knowledge);
    final manager = OfflinePackManager(
      manifest: _manifest(model, knowledge),
      database: database,
      supportDirectory: supportDirectory,
      client: client,
    );
    final progress = <PackProgress>[];

    await expectLater(
      manager.downloadAndInstall(onProgress: progress.add),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('se esperaban ${knowledge.length} bytes'),
        ),
      ),
    );

    expect(progress.last.stage, PackInstallStage.failed);
    expect(progress.last.message, contains('se recibieron'));
    expect(await manager.isInstalled, isFalse);
    expect(database.articleCount, 0);
    client.close();
  });

  test('cancels the download and permits a clean retry', () async {
    final model = utf8.encode('small model fixture');
    final knowledge = utf8.encode(_knowledgeJson);
    final client = _clientFor(model, knowledge);
    final manager = OfflinePackManager(
      manifest: _manifest(model, knowledge),
      database: database,
      supportDirectory: supportDirectory,
      client: client,
    );

    await expectLater(
      manager.downloadAndInstall(
        onProgress: (progress) {
          if (progress.stage == PackInstallStage.downloadingKnowledge &&
              progress.assetBytes > 0) {
            manager.cancelDownload();
          }
        },
      ),
      throwsA(isA<PackDownloadCancelled>()),
    );
    expect(await manager.isInstalled, isFalse);

    await manager.downloadAndInstall(onProgress: (_) {});

    expect(await manager.isInstalled, isTrue);
    client.close();
  });

  test('manifest requires HTTPS sources, sizes, and SHA-256 digests', () {
    expect(
      () => OfflinePackManifest.decode(
        jsonEncode(_manifestJson(
          modelBytes: [1, 2, 3],
          knowledgeBytes: [4, 5],
          modelUrl: 'http://example.test/model.gguf',
        )),
      ),
      throwsFormatException,
    );
    expect(
      () => OfflinePackManifest.decode(
        jsonEncode(_manifestJson(
          modelBytes: [1, 2, 3],
          knowledgeBytes: [4, 5],
          modelSha256: 'invalid',
        )),
      ),
      throwsFormatException,
    );
  });
}

class _MisreportedLengthClient extends http.BaseClient {
  _MisreportedLengthClient(this.model, this.knowledge);

  final List<int> model;
  final List<int> knowledge;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isKnowledge = request.url.path.endsWith('library.json');
    final bytes = isKnowledge ? knowledge : model;
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      contentLength: bytes.length + 37,
    );
  }
}

class _TruncatedKnowledgeClient extends http.BaseClient {
  _TruncatedKnowledgeClient(this.model, this.knowledge);

  final List<int> model;
  final List<int> knowledge;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isKnowledge = request.url.path.endsWith('library.json');
    final bytes = isKnowledge ? knowledge.sublist(0, knowledge.length - 1) : model;
    return http.StreamedResponse(Stream.value(bytes), 200);
  }
}

MockClient _clientFor(List<int> model, List<int> knowledge) {
  return MockClient((request) async {
    final bytes = request.url.path.endsWith('library.json') ? knowledge : model;
    return http.Response.bytes(bytes, 200);
  });
}

OfflinePackManifest _manifest(
  List<int> model,
  List<int> knowledge, {
  String? modelSha256,
}) {
  return OfflinePackManifest.decode(
    jsonEncode(
      _manifestJson(
        modelBytes: model,
        knowledgeBytes: knowledge,
        modelSha256: modelSha256,
      ),
    ),
  );
}

Map<String, Object?> _manifestJson({
  required List<int> modelBytes,
  required List<int> knowledgeBytes,
  String? modelSha256,
  String? modelUrl,
}) {
  return {
    'schemaVersion': 1,
    'packId': 'toxo-pack-test',
    'version': 1,
    'title': 'Pack de prueba',
    'model': {
      'id': 'test-model',
      'fileName': 'model.gguf',
      'url': modelUrl ?? 'https://example.test/model.gguf',
      'sizeBytes': modelBytes.length,
      'sha256': modelSha256 ?? sha256.convert(modelBytes).toString(),
      'license': 'Apache-2.0',
      'licenseUrl': 'https://example.test/model-license',
      'attribution': 'Modelo de prueba',
      'sourceUrl': 'https://example.test/model',
    },
    'knowledge': {
      'id': 'test-knowledge',
      'fileName': 'library.json',
      'url': 'https://example.test/library.json',
      'sizeBytes': knowledgeBytes.length,
      'sha256': sha256.convert(knowledgeBytes).toString(),
      'license': 'CC0-1.0',
      'licenseUrl': 'https://example.test/knowledge-license',
      'attribution': 'Contenido de prueba',
      'sourceUrl': 'https://example.test/knowledge',
    },
  };
}

const _knowledgeJson = '''
{
  "schemaVersion": 1,
  "packageId": "test-knowledge",
  "source": {
    "title": "Biblioteca de prueba",
    "license": "CC0-1.0",
    "attribution": "Contenido de prueba",
    "url": "https://example.test/knowledge"
  },
  "articles": [
    {
      "id": "photosynthesis",
      "title": "Fotosíntesis",
      "text": "La fotosíntesis transforma luz, agua y dióxido de carbono."
    }
  ]
}
''';

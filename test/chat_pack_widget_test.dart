import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:toxo/data/knowledge_database.dart';
import 'package:toxo/data/knowledge_package.dart';
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
      _chatApp(database, manager),
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
    expect(await manager.isInstalled, isFalse);
    expect(manager.cancelled, isTrue);
  });

  testWidgets('offers pack updates only when a newer version is available', (
    tester,
  ) async {
    manager = _FakePackManager(
      manifest: OfflinePackManifest.decode(jsonEncode(_manifestJson)),
      database: database,
      supportDirectory: supportDirectory,
      hasInstalledPackValue: true,
      updateAvailable: true,
    );
    await tester.pumpWidget(
      _chatApp(database, manager),
    );
    await tester.pumpAndSettle();

    expect(find.text('Actualización del pack disponible'), findsOneWidget);
    expect(find.textContaining('Actualizar ·'), findsOneWidget);
    expect(find.textContaining('El pack se descarga una vez'), findsNothing);
  });

  testWidgets('hides the pack card after installation when no update exists', (
    tester,
  ) async {
    manager = _FakePackManager(
      manifest: OfflinePackManifest.decode(jsonEncode(_manifestJson)),
      database: database,
      supportDirectory: supportDirectory,
      installed: true,
      hasInstalledPackValue: true,
    );
    await tester.pumpWidget(
      _chatApp(database, manager),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pack offline listo'), findsNothing);
    expect(find.textContaining('Descargar ·'), findsNothing);
  });

  testWidgets('moves offline status into settings and lets users reduce visuals', (
    tester,
  ) async {
    await tester.pumpWidget(
      _chatApp(database, manager),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin conexión ·'), findsNothing);
    expect(find.byKey(const ValueKey('neural-network-backdrop')), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      const Color(0xFF071622),
    );

    await tester.tap(find.byTooltip('Preferencias'));
    await tester.pumpAndSettle();
    expect(find.text('Modo sin conexión'), findsOneWidget);
    expect(find.text('Intensidad visual'), findsOneWidget);
    await tester.tap(find.text('Sin red'));
    await tester.pumpAndSettle();
    expect(database.visualEffects, 'off');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('neural-network-backdrop')), findsNothing);

    await tester.tap(find.byTooltip('Preferencias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menta'));
    await tester.pumpAndSettle();
    expect(database.appearance, 'mint');
  });

  testWidgets('casual chat stays out of retrieval when the model is missing', (
    tester,
  ) async {
    database.importPackage(
      const KnowledgePackage(
        packageId: 'small-talk-test',
        sourceTitle: 'Prueba',
        license: 'CC0-1.0',
        attribution: 'Toxo',
        sourceUrl: 'https://example.test/library',
        articles: [
          KnowledgeArticle(
            id: 'charla',
            title: 'Charla informal',
            text: 'Una charla puede comenzar al decir que quiero conversar.',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      _chatApp(database, manager),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Quisiera charlar un poco',
    );
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('podemos charlar'), findsOneWidget);
    expect(find.text('Charla informal'), findsNothing);
    expect(
      find.textContaining('modelo local para una conversación'),
      findsOneWidget,
    );
  });

  testWidgets('factual questions show matching local sources without a model', (
    tester,
  ) async {
    database.importPackage(
      const KnowledgePackage(
        packageId: 'facts-test',
        sourceTitle: 'Biblioteca de prueba',
        license: 'CC0-1.0',
        attribution: 'Toxo',
        sourceUrl: 'https://example.test/library',
        articles: [
          KnowledgeArticle(
            id: 'fotosintesis',
            title: 'Fotosíntesis',
            text: 'Las plantas usan energía solar durante la fotosíntesis.',
            sourceTitle: 'Fuente abierta',
            license: 'CC0-1.0',
            attribution: 'Equipo Toxo',
            sourceUrl: 'https://example.test/fotosintesis',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      _chatApp(database, manager),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      '¿Qué es la fotosíntesis?',
    );
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('¡Encontré algo útil en tu biblioteca! Aquí tienes los pasajes más cercanos:'), findsOneWidget);
    expect(find.text('Fotosíntesis'), findsOneWidget);
    expect(find.textContaining('Fuente abierta'), findsOneWidget);
    expect(find.textContaining('podemos charlar'), findsNothing);
  });

  testWidgets('reduced motion keeps the neural illustration static', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ChatScreen(database: database, packManager: manager),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byKey(const ValueKey('neural-network-backdrop')),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter;
    await tester.pump(const Duration(seconds: 5));
    final after = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byKey(const ValueKey('neural-network-backdrop')),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter;

    expect(identical(before, after), isTrue);
  });
}

Widget _chatApp(KnowledgeDatabase database, OfflinePackManager manager) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: ChatScreen(database: database, packManager: manager),
    ),
  );
}

class _FakePackManager implements OfflinePackManager {
  _FakePackManager({
    required this.manifest,
    required this.database,
    required this.supportDirectory,
    this.installed = false,
    this.hasInstalledPackValue = false,
    this.updateAvailable = false,
  });

  @override
  final OfflinePackManifest manifest;
  @override
  final KnowledgeDatabase database;
  @override
  final Directory supportDirectory;
  final bool installed;
  @override
  final bool hasInstalledPackValue;
  final bool updateAvailable;

  final _completion = Completer<void>();
  void Function(PackProgress progress)? _onProgress;
  bool cancelled = false;

  @override
  File get modelFile => File('model-fixture.gguf');

  @override
  Future<bool> get isInstalled async => installed;

  @override
  Future<bool> get hasInstalledPack async => hasInstalledPackValue;

  @override
  Future<bool> get hasUpdate async => updateAvailable;

  @override
  Future<int> get bytesToDownload async => manifest.totalBytes;

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
    _completion.complete();
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

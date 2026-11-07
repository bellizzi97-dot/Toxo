import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'knowledge_database.dart';
import 'knowledge_package.dart';
import 'offline_pack_manifest.dart';

enum PackInstallStage {
  idle,
  downloadingKnowledge,
  downloadingModel,
  verifyingKnowledge,
  verifyingModel,
  installing,
  ready,
  failed,
}

class PackProgress {
  const PackProgress({
    required this.stage,
    required this.message,
    required this.downloadedBytes,
    required this.totalBytes,
    this.assetBytes = 0,
    this.assetTotalBytes = 0,
  });

  final PackInstallStage stage;
  final String message;
  final int downloadedBytes;
  final int totalBytes;
  final int assetBytes;
  final int assetTotalBytes;

  double get fraction =>
      totalBytes == 0
          ? 0
          : (downloadedBytes / totalBytes).clamp(0, 1).toDouble();
}

class OfflinePackManager {
  OfflinePackManager({
    required this.manifest,
    required this.database,
    required this.supportDirectory,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final OfflinePackManifest manifest;
  final KnowledgeDatabase database;
  final Directory supportDirectory;
  http.Client _client;
  final bool _ownsClient;
  bool _active = false;
  bool _cancelRequested = false;

  Directory get _packDirectory =>
      Directory(p.join(supportDirectory.path, 'offline_pack'));

  File get modelFile =>
      File(p.join(_packDirectory.path, manifest.model.fileName));

  File get _markerFile => File(p.join(_packDirectory.path, 'installed.json'));

  File get _previousModel =>
      File(p.join(_packDirectory.path, '${manifest.model.fileName}.previous'));

  File get _previousMarker =>
      File(p.join(_packDirectory.path, 'installed.json.previous'));

  Future<bool> get isInstalled async {
    final marker = await _readInstalledMarker();
    return marker != null &&
        await modelFile.length() == manifest.model.sizeBytes &&
        marker['version'] == manifest.version &&
        marker['modelSha256'] == manifest.model.sha256 &&
        marker['knowledgeSha256'] == manifest.knowledge.sha256;
  }

  Future<bool> get hasInstalledPack async =>
      await _readInstalledMarker() != null;

  Future<bool> get hasUpdate async {
    final marker = await _readInstalledMarker();
    final installedVersion = marker?['version'];
    return installedVersion is int && installedVersion < manifest.version;
  }

  Future<int> get bytesToDownload async =>
      manifest.knowledge.sizeBytes +
      (await _canReuseModel() ? 0 : manifest.model.sizeBytes);

  Future<bool> _canReuseModel() async {
    final marker = await _readInstalledMarker();
    if (marker == null || marker['modelSha256'] != manifest.model.sha256) {
      return false;
    }
    try {
      return await modelFile.length() == manifest.model.sizeBytes;
    } on FileSystemException {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _readInstalledMarker() async {
    if (!await modelFile.exists() || !await _markerFile.exists()) return null;
    try {
      if (await modelFile.length() == 0) return null;
      final marker = jsonDecode(await _markerFile.readAsString());
      if (marker is! Map<String, dynamic> ||
          marker['packId'] != manifest.packId ||
          marker['modelSha256'] is! String ||
          marker['knowledgeSha256'] is! String) {
        return null;
      }
      return marker;
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> downloadAndInstall({
    required void Function(PackProgress progress) onProgress,
  }) async {
    if (_active) throw StateError('Ya hay una descarga de pack en curso.');
    _active = true;
    _cancelRequested = false;
    var reuseModel = false;
    var totalDownloadBytes = manifest.totalBytes;
    var downloadedBeforeCurrent = 0;
    final knowledgePart =
        File(p.join(_packDirectory.path, '${manifest.knowledge.fileName}.part'));
    final modelPart =
        File(p.join(_packDirectory.path, '${manifest.model.fileName}.part'));
    final previousModel = _previousModel;
    final previousMarker = _previousMarker;
    final markerPart = File('${_markerFile.path}.part');
    var modelWasReplaced = false;
    var markerWasReplaced = false;
    var knowledgeImported = false;

    void report(
      PackInstallStage stage,
      String message, {
      int assetBytes = 0,
      int assetTotalBytes = 0,
      int? downloadedBytes,
    }) {
      onProgress(
        PackProgress(
          stage: stage,
          message: message,
          downloadedBytes: downloadedBytes ?? downloadedBeforeCurrent + assetBytes,
          totalBytes: totalDownloadBytes,
          assetBytes: assetBytes,
          assetTotalBytes: assetTotalBytes,
        ),
      );
    }

    try {
      reuseModel = await _canReuseModel();
      if (reuseModel) {
        try {
          await _verifyAsset(manifest.model, modelFile);
        } on FormatException {
          reuseModel = false;
        }
      }
      totalDownloadBytes =
          manifest.knowledge.sizeBytes +
          (reuseModel ? 0 : manifest.model.sizeBytes);
      await _packDirectory.create(recursive: true);
      if (await previousModel.exists()) {
        if (await modelFile.exists()) {
          await _removeIfExists(previousModel);
        } else {
          await previousModel.rename(modelFile.path);
        }
      }
      if (await previousMarker.exists()) {
        if (await _markerFile.exists()) {
          await _removeIfExists(previousMarker);
        } else {
          await previousMarker.rename(_markerFile.path);
        }
      }
      await _removeIfExists(knowledgePart);
      await _removeIfExists(modelPart);
      await _removeIfExists(markerPart);

      report(
        PackInstallStage.downloadingKnowledge,
        'Descargando la biblioteca abierta…',
      );
      await _downloadAsset(
        manifest.knowledge,
        knowledgePart,
        stage: PackInstallStage.downloadingKnowledge,
        message: 'Descargando la biblioteca abierta…',
        alreadyDownloaded: 0,
        onProgress: onProgress,
        totalBytes: totalDownloadBytes,
      );
      report(
        PackInstallStage.verifyingKnowledge,
        'Verificando integridad de la biblioteca…',
        downloadedBytes: manifest.knowledge.sizeBytes,
      );
      await _verifyAsset(manifest.knowledge, knowledgePart);
      downloadedBeforeCurrent = manifest.knowledge.sizeBytes;

      if (reuseModel) {
        report(
          PackInstallStage.verifyingModel,
          'El modelo instalado pasó la comprobación SHA-256.',
          downloadedBytes: totalDownloadBytes,
        );
      } else {
        report(
          PackInstallStage.downloadingModel,
          'Descargando el modelo local (aprox. 380 MiB)…',
        );
        await _downloadAsset(
          manifest.model,
          modelPart,
          stage: PackInstallStage.downloadingModel,
          message: 'Descargando el modelo local…',
          alreadyDownloaded: downloadedBeforeCurrent,
          onProgress: onProgress,
          totalBytes: totalDownloadBytes,
        );
        report(
          PackInstallStage.verifyingModel,
          'Verificando el modelo descargado…',
          assetBytes: manifest.model.sizeBytes,
          assetTotalBytes: manifest.model.sizeBytes,
          downloadedBytes: totalDownloadBytes,
        );
        await _verifyAsset(manifest.model, modelPart);
      }

      report(
        PackInstallStage.installing,
        'Instalando el modelo e indexando la biblioteca…',
        assetBytes: reuseModel ? 0 : manifest.model.sizeBytes,
        assetTotalBytes: reuseModel ? 0 : manifest.model.sizeBytes,
        downloadedBytes: totalDownloadBytes,
      );
      final package = KnowledgePackage.decode(await knowledgePart.readAsString());

      if (!reuseModel) {
        if (await modelFile.exists()) {
          await modelFile.rename(previousModel.path);
        }
        await modelPart.rename(modelFile.path);
        modelWasReplaced = true;
      }
      database.importPackage(package);
      knowledgeImported = true;

      await markerPart.writeAsString(
        jsonEncode({
          'packId': manifest.packId,
          'version': manifest.version,
          'modelSha256': manifest.model.sha256,
          'knowledgeSha256': manifest.knowledge.sha256,
        }),
        flush: true,
      );
      if (await _markerFile.exists()) {
        await _markerFile.rename(previousMarker.path);
      }
      await markerPart.rename(_markerFile.path);
      markerWasReplaced = true;
      await _removeIfExists(previousModel);
      await _removeIfExists(previousMarker);
      await _removeIfExists(knowledgePart);
      report(
        PackInstallStage.ready,
        '¡Listo! El modelo y la biblioteca ya están instalados para usarse sin conexión.',
        assetBytes: reuseModel ? 0 : manifest.model.sizeBytes,
        assetTotalBytes: reuseModel ? 0 : manifest.model.sizeBytes,
        downloadedBytes: totalDownloadBytes,
      );
    } on Object catch (error) {
      await _removeIfExists(knowledgePart);
      await _removeIfExists(modelPart);
      await _removeIfExists(markerPart);
      if (markerWasReplaced) await _removeIfExists(_markerFile);
      if (await previousMarker.exists()) {
        await previousMarker.rename(_markerFile.path);
      }
      if (modelWasReplaced) {
        await _removeIfExists(modelFile);
        if (await previousModel.exists()) {
          await previousModel.rename(modelFile.path);
        }
      }
      report(
        PackInstallStage.failed,
        _cancelRequested
            ? 'Descarga cancelada. Puedes volver a intentarlo cuando quieras.'
            : 'No se pudo completar el pack: $error',
      );
      if (_cancelRequested) throw const PackDownloadCancelled();
      rethrow;
    } finally {
      if (knowledgeImported) {
        await _removeIfExists(previousModel);
        await _removeIfExists(previousMarker);
      }
      _active = false;
    }
  }

  void cancelDownload() {
    if (!_active) return;
    _cancelRequested = true;
    if (_ownsClient) {
      _client.close();
      _client = http.Client();
    }
  }

  Future<void> _downloadAsset(
    PackAsset asset,
    File destination, {
    required PackInstallStage stage,
    required String message,
    required int alreadyDownloaded,
    required int totalBytes,
    required void Function(PackProgress progress) onProgress,
  }) async {
    final request = http.Request('GET', asset.url);
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>();
      throw HttpException(
        'El servidor respondió HTTP ${response.statusCode}.',
        uri: asset.url,
      );
    }
    var received = 0;
    final sink = destination.openWrite();
    try {
      await for (final chunk in response.stream) {
        if (_cancelRequested) throw const PackDownloadCancelled();
        received += chunk.length;
        if (received > asset.sizeBytes) {
          throw const FormatException(
            'La descarga superó el tamaño declarado en el manifiesto.',
          );
        }
        sink.add(chunk);
        onProgress(
          PackProgress(
            stage: stage,
            message: message,
            downloadedBytes: alreadyDownloaded + received,
            totalBytes: totalBytes,
            assetBytes: received,
            assetTotalBytes: asset.sizeBytes,
          ),
        );
      }
      if (_cancelRequested) throw const PackDownloadCancelled();
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (received != asset.sizeBytes) {
      throw FormatException(
        'La descarga de "${asset.fileName}" quedó incompleta: '
        'se recibieron $received bytes y se esperaban ${asset.sizeBytes}.',
      );
    }
  }

  Future<void> _verifyAsset(PackAsset asset, File file) async {
    final actualSize = await file.length();
    if (actualSize != asset.sizeBytes) {
      throw FormatException(
        'El archivo "${asset.fileName}" tiene $actualSize bytes; '
        'se esperaban ${asset.sizeBytes}.',
      );
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != asset.sha256) {
      throw FormatException(
        'La comprobación SHA-256 de "${asset.fileName}" falló '
        '(esperado ${asset.sha256}, recibido $digest); se descartó el archivo.',
      );
    }
  }

  Future<void> _removeIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

class PackDownloadCancelled implements Exception {
  const PackDownloadCancelled();
}

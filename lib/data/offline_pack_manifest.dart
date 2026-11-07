import 'dart:convert';

import 'package:flutter/services.dart';

class PackAsset {
  const PackAsset({
    required this.id,
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
    required this.license,
    required this.licenseUrl,
    required this.attribution,
    required this.sourceUrl,
  });

  final String id;
  final String fileName;
  final Uri url;
  final int sizeBytes;
  final String sha256;
  final String license;
  final Uri licenseUrl;
  final String attribution;
  final Uri sourceUrl;

  factory PackAsset.fromJson(Map<String, Object?> json) {
    final asset = PackAsset(
      id: _string(json, 'id'),
      fileName: _string(json, 'fileName'),
      url: _httpsUri(json, 'url'),
      sizeBytes: _integer(json, 'sizeBytes'),
      sha256: _string(json, 'sha256').toLowerCase(),
      license: _string(json, 'license'),
      licenseUrl: _httpsUri(json, 'licenseUrl'),
      attribution: _string(json, 'attribution'),
      sourceUrl: _httpsUri(json, 'sourceUrl'),
    );
    if (asset.sizeBytes <= 0 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(asset.sha256) ||
        !_safeFileName.hasMatch(asset.fileName)) {
      throw const FormatException('Metadatos de archivo del pack no válidos.');
    }
    return asset;
  }
}

class OfflinePackManifest {
  const OfflinePackManifest({
    required this.packId,
    required this.version,
    required this.title,
    required this.model,
    required this.knowledge,
  });

  final String packId;
  final int version;
  final String title;
  final PackAsset model;
  final PackAsset knowledge;

  int get totalBytes => model.sizeBytes + knowledge.sizeBytes;

  factory OfflinePackManifest.decode(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, Object?> || decoded['schemaVersion'] != 1) {
      throw const FormatException('Manifiesto de pack no compatible.');
    }
    final model = decoded['model'];
    final knowledge = decoded['knowledge'];
    if (model is! Map<String, Object?> ||
        knowledge is! Map<String, Object?>) {
      throw const FormatException('Falta el modelo o la biblioteca del pack.');
    }
    return OfflinePackManifest(
      packId: _string(decoded, 'packId'),
      version: _integer(decoded, 'version'),
      title: _string(decoded, 'title'),
      model: PackAsset.fromJson(model),
      knowledge: PackAsset.fromJson(knowledge),
    );
  }

  static Future<OfflinePackManifest> loadBundled() async {
    return OfflinePackManifest.decode(
      await rootBundle.loadString('assets/packs/android_starter_manifest.json'),
    );
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('El campo "$key" es obligatorio.');
  }
  return value.trim();
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('El campo "$key" debe ser un entero.');
  }
  return value;
}

Uri _httpsUri(Map<String, Object?> json, String key) {
  final value = Uri.tryParse(_string(json, key));
  if (value == null || value.scheme != 'https' || value.host.isEmpty) {
    throw FormatException('El campo "$key" debe ser una URL HTTPS.');
  }
  return value;
}

final _safeFileName = RegExp(r'^[a-zA-Z0-9._-]+$');

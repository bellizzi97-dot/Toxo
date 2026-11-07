import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.releaseName,
    required this.releaseNotes,
  });

  final String currentVersion;
  final String latestVersion;
  final Uri releaseUrl;
  final String releaseName;
  final String releaseNotes;

  bool get isAvailable =>
      _compareVersions(latestVersion, currentVersion) > 0;
}

class AppUpdateChecker {
  AppUpdateChecker({
    http.Client? client,
    Future<String> Function()? currentVersion,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _currentVersion =
           currentVersion ??
           (() async => (await PackageInfo.fromPlatform()).version);

  static final _latestReleaseUri = Uri.https(
    'api.github.com',
    '/repos/bellizzi97-dot/Toxo/releases/latest',
  );

  static final releasesPageUri = Uri.https(
    'github.com',
    '/bellizzi97-dot/Toxo/releases',
  );

  final http.Client _client;
  final bool _ownsClient;
  final Future<String> Function() _currentVersion;

  Future<AppUpdateInfo?> check() async {
    final currentVersion = await _currentVersion();
    _parseVersion(currentVersion);
    final response = await _client
        .get(
          _latestReleaseUri,
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'Toxo-Android-App',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw HttpException(
        'GitHub respondió HTTP ${response.statusCode} al consultar Releases.',
        uri: _latestReleaseUri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de actualización no válida.');
    }
    final tag = decoded['tag_name'];
    final releaseUrlText = decoded['html_url'];
    if (tag is! String || releaseUrlText is! String) {
      throw const FormatException(
        'La publicación no incluye versión y página de descarga.',
      );
    }
    final releaseUrl = Uri.tryParse(releaseUrlText);
    if (releaseUrl == null ||
        releaseUrl.scheme != 'https' ||
        releaseUrl.host != 'github.com' ||
        !releaseUrl.path.startsWith('/bellizzi97-dot/Toxo/releases/tag/')) {
      throw const FormatException(
        'La publicación de actualización no apunta al repositorio oficial.',
      );
    }

    final latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;
    _parseVersion(latestVersion);
    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseUrl: releaseUrl,
      releaseName: decoded['name'] is String
          ? decoded['name'] as String
          : 'Toxo $latestVersion',
      releaseNotes: decoded['body'] is String ? decoded['body'] as String : '',
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

int _compareVersions(String left, String right) {
  final leftParsed = _parseVersion(left);
  final rightParsed = _parseVersion(right);
  final leftParts = leftParsed.parts;
  final rightParts = rightParsed.parts;
  for (var index = 0; index < leftParts.length; index++) {
    final comparison = leftParts[index].compareTo(rightParts[index]);
    if (comparison != 0) return comparison;
  }
  if (leftParsed.prerelease == null) {
    return rightParsed.prerelease == null ? 0 : 1;
  }
  if (rightParsed.prerelease == null) return -1;
  return leftParsed.prerelease!.compareTo(rightParsed.prerelease!);
}

({List<int> parts, String? prerelease}) _parseVersion(String version) {
  final match = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  )
      .firstMatch(version);
  if (match == null) {
    throw FormatException('Versión de Toxo no reconocida: "$version".');
  }
  return (
    parts: [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ],
    prerelease: match.group(4),
  );
}

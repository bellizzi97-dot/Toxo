import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toxo/data/offline_pack_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled manifest hashes the exact downloadable open-knowledge asset', () async {
    final manifest = await OfflinePackManifest.loadBundled();
    final contents = await File(
      'assets/packs/toxo-conocimientos-es-v3.json',
    ).readAsString();
    final bytes = utf8.encode(contents.replaceAll('\r\n', '\n'));

    expect(manifest.model.license, 'Apache-2.0');
    expect(manifest.version, 3);
    expect(manifest.knowledge.license, contains('CC BY-SA 4.0'));
    expect(bytes.length, manifest.knowledge.sizeBytes);
    expect(sha256.convert(bytes).toString(), manifest.knowledge.sha256);
  });
}

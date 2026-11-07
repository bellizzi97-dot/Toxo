import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toxo/data/offline_pack_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled manifest hashes the exact packaged open-knowledge asset', () async {
    final manifest = await OfflinePackManifest.loadBundled();
    final bytes = await File(
      'assets/packs/toxo-conocimientos-es-v1.json',
    ).readAsBytes();

    expect(manifest.model.license, 'Apache-2.0');
    expect(manifest.knowledge.license, 'CC0-1.0');
    expect(bytes.length, manifest.knowledge.sizeBytes);
    expect(sha256.convert(bytes).toString(), manifest.knowledge.sha256);
  });
}

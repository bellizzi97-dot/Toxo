import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toxo/data/app_update_checker.dart';

void main() {
  test('finds a newer release without treating build metadata as a version', () async {
    final checker = AppUpdateChecker(
      client: MockClient((request) async {
        expect(request.url.host, 'api.github.com');
        expect(
          request.url.path,
          '/repos/bellizzi97-dot/Toxo/releases/latest',
        );
        return http.Response(
          jsonEncode({
            'tag_name': 'v0.2.0',
            'name': 'Toxo 0.2',
            'body': 'Mejoras offline.',
            'html_url':
                'https://github.com/bellizzi97-dot/Toxo/releases/tag/v0.2.0',
          }),
          200,
        );
      }),
      currentVersion: () async => '0.1.0',
    );

    final update = await checker.check();

    expect(update?.isAvailable, isTrue);
    expect(update?.latestVersion, '0.2.0');
    expect(
      update?.releaseUrl,
      Uri.parse('https://github.com/bellizzi97-dot/Toxo/releases/tag/v0.2.0'),
    );
    checker.close();
  });

  test('does not advertise a release that is not newer', () async {
    final checker = AppUpdateChecker(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'tag_name': 'v0.1.0',
            'html_url':
                'https://github.com/bellizzi97-dot/Toxo/releases/tag/v0.1.0',
          }),
          200,
        ),
      ),
      currentVersion: () async => '0.1.0+4',
    );

    expect((await checker.check())?.isAvailable, isFalse);
    checker.close();
  });

  test('does not offer a prerelease over the installed stable version', () async {
    final checker = AppUpdateChecker(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'tag_name': 'v0.2.0-rc.1',
            'html_url':
                'https://github.com/bellizzi97-dot/Toxo/releases/tag/v0.2.0-rc.1',
          }),
          200,
        ),
      ),
      currentVersion: () async => '0.2.0',
    );

    expect((await checker.check())?.isAvailable, isFalse);
    checker.close();
  });

  test('treats a repository with no published releases as no update', () async {
    final checker = AppUpdateChecker(
      client: MockClient((_) async => http.Response('', 404)),
      currentVersion: () async => '0.1.0',
    );

    expect(await checker.check(), isNull);
    checker.close();
  });

  test('rejects release URLs outside the official repository', () async {
    final checker = AppUpdateChecker(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'tag_name': 'v0.2.0',
            'html_url': 'https://example.org/download.apk',
          }),
          200,
        ),
      ),
      currentVersion: () async => '0.1.0',
    );

    expect(checker.check(), throwsFormatException);
    checker.close();
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toxo/services/toxo_api_client.dart';

void main() {
  test('posts only the question and returns the answer', () async {
    final client = ToxoApiClient(
      baseUrl: 'https://toxo.example/',
      client: MockClient((request) async {
        expect(request.url.path, '/v1/chat');
        expect(jsonDecode(request.body), {'question': '¿Qué es Toxo?'});
        return http.Response(
          jsonEncode({'answer': 'Una respuesta.'}),
          200,
        );
      }),
    );

    expect(await client.ask('  ¿Qué es Toxo?  '), 'Una respuesta.');
    client.close();
  });

  test('refuses to contact an unconfigured backend', () async {
    final client = ToxoApiClient(client: MockClient((_) async {
      fail('No se debe hacer una solicitud sin URL configurada.');
    }));

    await expectLater(
      client.ask('Hola'),
      throwsA(isA<ToxoApiException>()),
    );
    client.close();
  });

  test('sends feedback to its dedicated endpoint', () async {
    final client = ToxoApiClient(
      baseUrl: 'https://toxo.example',
      client: MockClient((request) async {
        expect(request.url.path, '/v1/feedback');
        expect(jsonDecode(request.body), {'message': 'La app me gustó'});
        return http.Response('{"ok":true}', 201);
      }),
    );

    await client.sendFeedback(' La app me gustó ');
    client.close();
  });
}

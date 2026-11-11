import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ToxoApiException implements Exception {
  const ToxoApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ToxoApiClient {
  ToxoApiClient({
    http.Client? client,
    String baseUrl = const String.fromEnvironment('TOXO_API_BASE_URL'),
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<String> ask(String question) async {
    final cleaned = question.trim();
    if (cleaned.isEmpty || cleaned.length > 4000) {
      throw const ToxoApiException(
        'La pregunta debe tener entre 1 y 4000 caracteres.',
      );
    }
    final response = await _post('/v1/chat', {'question': cleaned});
    final decoded = _decodeResponse(response);
    final answer = decoded['answer'];
    if (answer is! String || answer.trim().isEmpty) {
      throw const ToxoApiException(
        'El servidor devolvió una respuesta no válida.',
      );
    }
    return answer.trim();
  }

  Future<void> sendFeedback(String message) async {
    final cleaned = message.trim();
    if (cleaned.isEmpty || cleaned.length > 2000) {
      throw const ToxoApiException(
        'El comentario debe tener entre 1 y 2000 caracteres.',
      );
    }
    final response = await _post('/v1/feedback', {'message': cleaned});
    if (response.statusCode != 201) {
      _throwResponseError(response);
    }
  }

  Future<http.Response> _post(String path, Map<String, String> body) async {
    if (!isConfigured) {
      throw const ToxoApiException(
        'El backend todavía no está configurado para esta versión de prueba.',
      );
    }
    try {
      return await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 35));
    } on TimeoutException {
      throw const ToxoApiException(
        'El servidor tardó demasiado. Inténtalo de nuevo.',
      );
    } on http.ClientException {
      throw const ToxoApiException(
        'No se pudo conectar. Comprueba tu conexión e inténtalo de nuevo.',
      );
    } on FormatException {
      throw const ToxoApiException(
        'La dirección del backend no es válida.',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode != 200) {
      _throwResponseError(response);
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      throw const ToxoApiException(
        'El servidor devolvió una respuesta no válida.',
      );
    }
    throw const ToxoApiException(
      'El servidor devolvió una respuesta no válida.',
    );
  }

  Never _throwResponseError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        throw ToxoApiException(decoded['detail'] as String);
      }
    } on FormatException {
      // Use a generic error when the server response is not JSON.
    }
    throw const ToxoApiException(
      'El servidor no pudo completar la solicitud.',
    );
  }

  void close() => _client.close();
}

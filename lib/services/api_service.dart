import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  ApiService({String? baseUrl, http.Client? client})
    : baseUrl = (baseUrl ?? const String.fromEnvironment('API_BASE_URL'))
      .trim()
      .replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? accessToken;

  String? get configurationError {
    if (baseUrl.isEmpty) {
      return 'Backend not connected. Build the app with --dart-define=API_BASE_URL=...';
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.path.isNotEmpty && uri.path != '/') {
      return 'Backend URL is invalid. Use http://HOST:8000 or an HTTPS API URL.';
    }
    return null;
  }

  bool get isConfigured => configurationError == null;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<void> close() async => _client.close();

  Future<Map<String, dynamic>> _send(String method, String path, {
    Map<String, dynamic>? body,
  }) async {
    final error = configurationError;
    if (error != null) {
      throw ApiException(error);
    }

    final uri = Uri.parse('$baseUrl${path.startsWith('/') ? path : '/$path'}');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (accessToken != null && accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    try {
      final response = method == 'GET'
          ? await _client.get(uri, headers: headers)
          : await _client.post(
              uri,
              headers: headers,
              body: jsonEncode(body ?? <String, dynamic>{}),
            );
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _messageFromResponse(decoded, response.statusCode),
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException('The backend returned an invalid response.');
    } catch (_) {
      throw const ApiException(
        'Network error. Check the FastAPI server and your connection.',
      );
    }
  }

  String _messageFromResponse(Map<String, dynamic> body, int statusCode) {
    final detail = body['detail'] ?? body['message'] ?? body['error'];
    if (detail is String && detail.trim().isNotEmpty) return detail;
    if (statusCode == 401) return 'The email or password is incorrect.';
    if (statusCode == 409) return 'An account already exists for this email.';
    return 'The backend rejected the request. Try again.';
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:softwarep1/services/api_service.dart';

void main() {
  test('accepts a configured HTTP API URL', () {
    final service = ApiService(baseUrl: 'http://192.168.1.5:8000/');

    expect(service.isConfigured, isTrue);
    expect(service.baseUrl, 'http://192.168.1.5:8000');
    expect(service.configurationError, isNull);
  });

  test('accepts an HTTPS production API URL', () {
    final service = ApiService(baseUrl: 'https://api.example.com');

    expect(service.isConfigured, isTrue);
  });

  test('reports a missing API URL with build instructions', () {
    final service = ApiService();

    expect(service.isConfigured, isFalse);
    expect(service.configurationError, contains('--dart-define=API_BASE_URL'));
  });

  test('rejects malformed or unsupported API URLs', () {
    for (final value in ['api.example.com', 'ftp://api.example.com', 'http://']) {
      final service = ApiService(baseUrl: value);
      expect(service.isConfigured, isFalse, reason: value);
      expect(service.configurationError, contains('Backend URL is invalid'));
    }
  });
}

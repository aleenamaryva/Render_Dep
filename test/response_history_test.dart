import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softwarep1/app.dart';
import 'package:softwarep1/models/disaster_response.dart';
import 'package:softwarep1/screens/home/home_screen.dart';
import 'package:softwarep1/screens/response_history/response_history_screen.dart';
import 'package:softwarep1/services/app_session.dart';
import 'package:softwarep1/services/response_service.dart';

DisasterResponse _response({
  required SafetyStatus status,
  required DateTime timestamp,
  double latitude = 1.0,
  double longitude = 2.0,
}) {
  return DisasterResponse(
    userId: 'user-1',
    disasterId: 'disaster-1',
    status: status,
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
  );
}

void main() {
  late LocalResponseService service;

  setUp(() {
    service = LocalResponseService();
  });

  test('saves and retrieves all responses', () async {
    final response = _response(
      status: SafetyStatus.safe,
      timestamp: DateTime(2026, 10, 4, 21, 15),
    );

    await service.saveResponse(response);

    expect(service.getAllResponses(), [response]);
  });

  test('retrieves the latest response', () async {
    final older = _response(
      status: SafetyStatus.safe,
      timestamp: DateTime(2026, 10, 4, 20),
    );
    final latest = _response(
      status: SafetyStatus.needHelp,
      timestamp: DateTime(2026, 10, 4, 21),
    );

    await service.saveResponse(older);
    await service.saveResponse(latest);

    expect(service.getLatestResponse(), same(latest));
  });

  test('returns an empty history when no responses exist', () {
    expect(service.getAllResponses(), isEmpty);
    expect(service.getLatestResponse(), isNull);
  });

  test('orders responses newest first', () async {
    final oldest = _response(
      status: SafetyStatus.safe,
      timestamp: DateTime(2026, 10, 1),
    );
    final newest = _response(
      status: SafetyStatus.needHelp,
      timestamp: DateTime(2026, 10, 4),
    );

    await service.saveResponse(oldest);
    await service.saveResponse(newest);

    expect(service.getAllResponses(), [newest, oldest]);
  });

  testWidgets('response history screen renders stored responses', (tester) async {
    AppSession.responseService.clearResponseHistory();
    await AppSession.responseService.saveResponse(
      _response(
        status: SafetyStatus.needHelp,
        timestamp: DateTime(2026, 10, 4, 21, 15),
        latitude: 12.345678,
        longitude: 98.765432,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: ResponseHistoryScreen()),
    );

    expect(find.text('Response History'), findsOneWidget);
    expect(find.text('NEED_HELP'), findsOneWidget);
    expect(find.text('Date: 4 October 2026'), findsOneWidget);
    expect(find.text('Time: 9:15 PM'), findsOneWidget);
    expect(find.text('Latitude: 12.345678'), findsOneWidget);
    expect(find.text('Longitude: 98.765432'), findsOneWidget);
    AppSession.responseService.clearResponseHistory();
  });

  testWidgets('home screen displays the latest response', (tester) async {
    AppSession.responseService.clearResponseHistory();
    await AppSession.responseService.saveResponse(
      _response(
        status: SafetyStatus.safe,
        timestamp: DateTime(2026, 10, 4, 21, 15),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.profile: (_) => const SizedBox(),
          AppRoutes.responseHistory: (_) => const ResponseHistoryScreen(),
          AppRoutes.disasterAlert: (_) => const SizedBox(),
        },
        home: const HomeScreen(),
      ),
    );

    expect(find.text('Latest Response'), findsOneWidget);
    expect(find.text('Current Response: SAFE'), findsOneWidget);
    expect(find.text('Last Response: 4 October 2026, 9:15 PM'), findsOneWidget);
    AppSession.responseService.clearResponseHistory();
  });

  test('parses backend snake_case response format correctly', () {
    final parsed = DisasterResponse.fromJson({
      'user_id': 'u-123',
      'disaster_id': 'd-456',
      'response_type': 'SAFE',
      'latitude': 8.5467,
      'longitude': 76.9051,
      'submitted_at': '2026-10-12T15:36:18',
    });

    expect(parsed.userId, 'u-123');
    expect(parsed.disasterId, 'd-456');
    expect(parsed.status, SafetyStatus.safe);
    expect(parsed.latitude, 8.5467);
    expect(parsed.longitude, 76.9051);
  });
}

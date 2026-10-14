import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:softwarep1/services/location_service.dart';

class _FakeLocationGateway implements LocationGateway {
  _FakeLocationGateway({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestedPermission,
    this.currentPosition,
    this.lastKnownPosition,
    this.currentError,
  });

  bool serviceEnabled;
  LocationPermission permission;
  LocationPermission? requestedPermission;
  Position? currentPosition;
  Position? lastKnownPosition;
  Exception? currentError;
  bool requestPermissionCalled = false;
  bool getCurrentPositionCalled = false;
  bool getLastKnownPositionCalled = false;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalled = true;
    permission = requestedPermission ?? permission;
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({required LocationSettings settings}) async {
    getCurrentPositionCalled = true;
    if (currentError != null) throw currentError!;
    return currentPosition!;
  }

  @override
  Future<Position?> getLastKnownPosition() async {
    getLastKnownPositionCalled = true;
    return lastKnownPosition;
  }
}

Position _position({
  double latitude = 51.5074,
  double longitude = -0.1278,
  DateTime? timestamp,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: 8,
    altitude: 20,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    floor: null,
    isMocked: false,
    altitudeAccuracy: 1,
    headingAccuracy: 1,
  );
}

void main() {
  test('returns a clear error when location services are disabled', () async {
    final gateway = _FakeLocationGateway(serviceEnabled: false);
    final result = await DeviceLocationService(gateway: gateway).requestCurrentLocation();

    expect(result.success, isFalse);
    expect(result.message, contains('Location is turned off'));
    expect(gateway.getCurrentPositionCalled, isFalse);
  });

  test('requests permission and reports a denial', () async {
    final gateway = _FakeLocationGateway(
      permission: LocationPermission.denied,
      requestedPermission: LocationPermission.denied,
    );
    final result = await DeviceLocationService(gateway: gateway).requestCurrentLocation();

    expect(result.success, isFalse);
    expect(result.message, contains('permission was denied'));
    expect(gateway.requestPermissionCalled, isTrue);
  });

  test('reports permanently denied permission with settings guidance', () async {
    final gateway = _FakeLocationGateway(
      permission: LocationPermission.deniedForever,
    );
    final result = await DeviceLocationService(gateway: gateway).requestCurrentLocation();

    expect(result.success, isFalse);
    expect(result.message, contains('permanently denied'));
    expect(result.message, contains('Android Settings'));
  });

  test('returns the fresh GPS position', () async {
    final gateway = _FakeLocationGateway(currentPosition: _position());
    final result = await DeviceLocationService(gateway: gateway).requestCurrentLocation();

    expect(result.success, isTrue);
    expect(result.location?.latitude, 51.5074);
    expect(result.location?.longitude, -0.1278);
    expect(result.usedLastKnownLocation, isFalse);
  });

  test('uses a recent last-known position only after a fresh timeout', () async {
    final gateway = _FakeLocationGateway(
      currentError: TimeoutException('GPS timeout'),
      lastKnownPosition: _position(timestamp: DateTime.now().subtract(const Duration(minutes: 2))),
    );
    final result = await DeviceLocationService(gateway: gateway).requestCurrentLocation();

    expect(result.success, isTrue);
    expect(result.usedLastKnownLocation, isTrue);
    expect(result.location, isNotNull);
    expect(gateway.getLastKnownPositionCalled, isTrue);
  });

  test('does not succeed when GPS times out without a recent position', () async {
    final gateway = _FakeLocationGateway(
      currentError: TimeoutException('GPS timeout'),
    );
    final result = await DeviceLocationService(gateway: gateway).requestCurrentLocation();

    expect(result.success, isFalse);
    expect(result.message, contains('No recent usable location'));
  });

  test('rejects invalid coordinates instead of sending them', () async {
    final gateway = _FakeLocationGateway(currentPosition: _position(latitude: 91));
    final result = await DeviceLocationService(gateway: gateway).requestCurrentLocation();

    expect(result.success, isFalse);
    expect(result.message, contains('invalid location'));
  });
}

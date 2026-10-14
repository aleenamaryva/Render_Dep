import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location_point.dart';

abstract class LocationService {
  Future<LocationPermissionStatus> checkPermission();
  Future<LocationRequestResult> requestCurrentLocation();
  Future<bool> isNetworkAvailable();
}

enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
}

abstract class LocationGateway {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition({required LocationSettings settings});
  Future<Position?> getLastKnownPosition();
}

class GeolocatorGateway implements LocationGateway {
  @override
  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition({required LocationSettings settings}) {
    return Geolocator.getCurrentPosition(locationSettings: settings);
  }

  @override
  Future<Position?> getLastKnownPosition() => Geolocator.getLastKnownPosition();
}

class DeviceLocationService implements LocationService {
  DeviceLocationService({LocationGateway? gateway})
      : _gateway = gateway ?? GeolocatorGateway();

  static const _freshFixTimeout = Duration(seconds: 30);
  static const _lastKnownMaximumAge = Duration(minutes: 10);
  final LocationGateway _gateway;

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    if (!await _gateway.isLocationServiceEnabled()) {
      return LocationPermissionStatus.serviceDisabled;
    }
    return _permissionStatus(await _gateway.checkPermission());
  }

  @override
  Future<LocationRequestResult> requestCurrentLocation() async {
    try {
      final permissionStatus = await checkPermission();
      if (permissionStatus == LocationPermissionStatus.serviceDisabled) {
        return LocationRequestResult.failure(
          'Location is turned off. Turn on Location/GPS in Android Settings and try again.',
        );
      }

      if (permissionStatus == LocationPermissionStatus.permanentlyDenied) {
        return LocationRequestResult.failure(
          'Location permission is permanently denied. Open Android Settings, allow LifeTrace location access, and try again.',
        );
      }

      if (permissionStatus == LocationPermissionStatus.denied) {
        final requested = await _gateway.requestPermission();
        final requestedStatus = _permissionStatus(requested);
        if (requestedStatus == LocationPermissionStatus.serviceDisabled) {
          return LocationRequestResult.failure(
            'Location is turned off. Turn on Location/GPS in Android Settings and try again.',
          );
        }
        if (requestedStatus == LocationPermissionStatus.permanentlyDenied) {
          return LocationRequestResult.failure(
            'Location permission is permanently denied. Open Android Settings, allow LifeTrace location access, and try again.',
          );
        }
        if (requestedStatus != LocationPermissionStatus.granted) {
          return LocationRequestResult.failure(
            'Location permission was denied. Allow LifeTrace to use your location while using the app, then try again.',
          );
        }
      }

      try {
        final position = await _gateway.getCurrentPosition(
          settings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: _freshFixTimeout,
          ),
        );
        return _successFromPosition(position);
      } on TimeoutException {
        return await _lastKnownFallback(
          'A fresh GPS fix took too long. Try moving outdoors or checking that Location/GPS is on.',
        );
      }
    } on LocationServiceDisabledException {
      return LocationRequestResult.failure(
        'Location is turned off. Turn on Location/GPS in Android Settings and try again.',
      );
    } on PermissionDeniedException {
      return LocationRequestResult.failure(
        'Location permission was denied. Allow LifeTrace to use your location while using the app, then try again.',
      );
    } on TimeoutException {
      return LocationRequestResult.failure(
        'A fresh GPS fix took too long. Try moving outdoors or checking that Location/GPS is on.',
      );
    } on Exception catch (error) {
      return LocationRequestResult.failure(_messageForLocationError(error));
    }
  }

  Future<LocationRequestResult> _lastKnownFallback(String reason) async {
    try {
      final position = await _gateway.getLastKnownPosition();
      if (position == null || !_isUsablePosition(position)) {
        return LocationRequestResult.failure(
          '$reason No recent usable location is available. Try again with GPS enabled.',
        );
      }
      final age = DateTime.now().difference(position.timestamp).abs();
      if (age > _lastKnownMaximumAge) {
        return LocationRequestResult.failure(
          '$reason The last location is too old. Try again after GPS gets a fresh fix.',
        );
      }
      return _successFromPosition(position, usedLastKnownLocation: true);
    } on Exception catch (error) {
      return LocationRequestResult.failure(
        '$reason ${_messageForLocationError(error)}',
      );
    }
  }

  LocationRequestResult _successFromPosition(
    Position position, {
    bool usedLastKnownLocation = false,
  }) {
    if (!_isUsablePosition(position)) {
      return LocationRequestResult.failure(
        'The device returned an invalid location. Try again with GPS enabled.',
      );
    }
    return LocationRequestResult.success(
      LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
      ),
      usedLastKnownLocation: usedLastKnownLocation,
    );
  }

  bool _isUsablePosition(Position position) {
    return position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.latitude >= -90 &&
        position.latitude <= 90 &&
        position.longitude >= -180 &&
        position.longitude <= 180;
  }

  LocationPermissionStatus _permissionStatus(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.permanentlyDenied;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }

  String _messageForLocationError(Exception error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission')) {
      return 'Location permission is unavailable. Check LifeTrace location permission in Android Settings.';
    }
    if (text.contains('service') || text.contains('provider') || text.contains('location')) {
      return 'Android could not provide a location. Turn on Location/GPS, enable precise location for LifeTrace, and try again.';
    }
    return 'Android could not obtain your location. Check that Location/GPS is on and try again.';
  }

  @override
  Future<bool> isNetworkAvailable() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }
}

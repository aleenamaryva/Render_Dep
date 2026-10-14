class LocationPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class LocationRequestResult {
  final bool success;
  final LocationPoint? location;
  final String? message;
  final bool usedLastKnownLocation;

  const LocationRequestResult({
    required this.success,
    this.location,
    this.message,
    this.usedLastKnownLocation = false,
  });

  factory LocationRequestResult.success(
    LocationPoint location, {
    bool usedLastKnownLocation = false,
  }) {
    return LocationRequestResult(
      success: true,
      location: location,
      usedLastKnownLocation: usedLastKnownLocation,
    );
  }

  factory LocationRequestResult.failure(String message) {
    return LocationRequestResult(success: false, message: message);
  }
}

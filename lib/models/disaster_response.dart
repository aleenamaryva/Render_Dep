enum SafetyStatus {
  safe,
  needHelp,
  noResponse,
}

extension SafetyStatusExtension on SafetyStatus {
  String get label {
    switch (this) {
      case SafetyStatus.safe:
        return 'SAFE';
      case SafetyStatus.needHelp:
        return 'NEED_HELP';
      case SafetyStatus.noResponse:
        return 'NO_RESPONSE';
    }
  }

  String get displayName {
    switch (this) {
      case SafetyStatus.safe:
        return 'Safe';
      case SafetyStatus.needHelp:
        return 'Needs help';
      case SafetyStatus.noResponse:
        return 'No response';
    }
  }
}

class DisasterResponse {
  final String userId;
  final String disasterId;
  final SafetyStatus status;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const DisasterResponse({
    required this.userId,
    required this.disasterId,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'disasterId': disasterId,
      'status': status.name,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DisasterResponse.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] ?? json['response_type'])?.toString().toUpperCase();
    SafetyStatus status;
    if (statusRaw == 'SAFE') {
      status = SafetyStatus.safe;
    } else if (statusRaw == 'NEED_HELP' || statusRaw == 'NEEDHELP') {
      status = SafetyStatus.needHelp;
    } else {
      status = SafetyStatus.noResponse;
    }

    return DisasterResponse(
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      disasterId: json['disasterId'] as String? ?? json['disaster_id'] as String? ?? '',
      status: status,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? json['submitted_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

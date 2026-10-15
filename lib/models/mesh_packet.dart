import 'dart:convert';

class MeshPacket {
  final String packetId;
  final String userId;
  final String? citizenName;
  final String? citizenPhone;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? bloodGroup;
  final String? disasterId;
  final String responseType;
  final double latitude;
  final double longitude;
  final DateTime submittedAt;
  final int hopCount;
  final List<String> relayedBy;

  const MeshPacket({
    required this.packetId,
    required this.userId,
    this.citizenName,
    this.citizenPhone,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.bloodGroup,
    this.disasterId,
    required this.responseType,
    required this.latitude,
    required this.longitude,
    required this.submittedAt,
    this.hopCount = 0,
    this.relayedBy = const [],
  });

  MeshPacket incrementHop(String currentDeviceId) {
    return MeshPacket(
      packetId: packetId,
      userId: userId,
      citizenName: citizenName,
      citizenPhone: citizenPhone,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      bloodGroup: bloodGroup,
      disasterId: disasterId,
      responseType: responseType,
      latitude: latitude,
      longitude: longitude,
      submittedAt: submittedAt,
      hopCount: hopCount + 1,
      relayedBy: [...relayedBy, currentDeviceId],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packet_id': packetId,
      'user_id': userId,
      'citizen_name': citizenName,
      'citizen_phone': citizenPhone,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'blood_group': bloodGroup,
      'disaster_id': disasterId,
      'response_type': responseType,
      'latitude': latitude,
      'longitude': longitude,
      'submitted_at': submittedAt.toIso8601String(),
      'hop_count': hopCount,
      'relayed_by': relayedBy,
    };
  }

  factory MeshPacket.fromJson(Map<String, dynamic> json) {
    return MeshPacket(
      packetId: json['packet_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      citizenName: json['citizen_name'] as String?,
      citizenPhone: json['citizen_phone'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      bloodGroup: json['blood_group'] as String?,
      disasterId: json['disaster_id'] as String?,
      responseType: json['response_type'] as String? ?? 'NEED_HELP',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      hopCount: (json['hop_count'] as num?)?.toInt() ?? 0,
      relayedBy: (json['relayed_by'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  String toRawPayload() => jsonEncode(toJson());

  static MeshPacket? fromRawPayload(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return MeshPacket.fromJson(map);
      }
    } catch (_) {}
    return null;
  }
}

class DisasterAlert {
  final String id;
  final String type;
  final String description;
  final String location;
  final DateTime alertTime;
  final String emergencyInstructions;

  const DisasterAlert({
    required this.id,
    required this.type,
    required this.description,
    required this.location,
    required this.alertTime,
    required this.emergencyInstructions,
  });

  static DisasterAlert sample() {
    return DisasterAlert(
      id: 'disaster-001',
      type: 'Flood Warning',
      description:
          'Severe flash flooding is affecting low-lying areas near the river. Residents should prepare for rising water and avoid the affected roads.',
      location: 'Riverside District',
      alertTime: DateTime.now().subtract(const Duration(minutes: 12)),
      emergencyInstructions:
          'Move to higher ground immediately. Avoid bridges and flooded roads.',
    );
  }
}

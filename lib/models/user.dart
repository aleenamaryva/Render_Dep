class User {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String bloodGroup;
  final String? medicalInformation;

  const User({
    this.id = 'local-user',
    required this.fullName,
    required this.phoneNumber,
    this.email,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.bloodGroup,
    this.medicalInformation,
  });

  User copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    String? email,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? bloodGroup,
    String? medicalInformation,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      medicalInformation: medicalInformation ?? this.medicalInformation,
    );
  }

  List<String> validate() {
    final errors = <String>[];

    if (fullName.trim().isEmpty) {
      errors.add('Full name cannot be empty');
    }

    final phonePattern = RegExp(r'^\+?[0-9\s\-()]{7,20}$');
    if (phoneNumber.trim().isEmpty || !phonePattern.hasMatch(phoneNumber.trim())) {
      errors.add('Phone number must be valid');
    }

    if (email != null && email!.trim().isNotEmpty) {
      final emailPattern = RegExp(
        r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
      );
      if (!emailPattern.hasMatch(email!.trim())) {
        errors.add('Email must be valid if provided');
      }
    }

    if (emergencyContactName.trim().isEmpty) {
      errors.add('Emergency contact name cannot be empty');
    }

    if (emergencyContactPhone.trim().isEmpty ||
        !phonePattern.hasMatch(emergencyContactPhone.trim())) {
      errors.add('Emergency contact phone must be valid');
    }

    if (bloodGroup.trim().isEmpty) {
      errors.add('Blood group is required');
    }

    return errors;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'email': email,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'bloodGroup': bloodGroup,
      'medicalInformation': medicalInformation,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? 'local-user',
      fullName: json['fullName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      email: json['email'] as String?,
      emergencyContactName: json['emergencyContactName'] as String? ?? '',
      emergencyContactPhone: json['emergencyContactPhone'] as String? ?? '',
      bloodGroup: json['bloodGroup'] as String? ?? '',
      medicalInformation: json['medicalInformation'] as String?,
    );
  }
}

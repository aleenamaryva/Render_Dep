import 'package:flutter_test/flutter_test.dart';
import 'package:softwarep1/models/user.dart';

void main() {
  group('User validation', () {
    test('rejects empty name', () {
      final user = User(
        fullName: '',
        phoneNumber: '+1234567890',
        emergencyContactName: 'Jane',
        emergencyContactPhone: '+1987654321',
        bloodGroup: 'O+',
      );

      expect(user.validate(), contains('Full name cannot be empty'));
    });

    test('validates phone numbers', () {
      final user = User(
        fullName: 'John Doe',
        phoneNumber: 'abc',
        emergencyContactName: 'Jane',
        emergencyContactPhone: '+1987654321',
        bloodGroup: 'O+',
      );

      expect(user.validate(), contains('Phone number must be valid'));
    });

    test('allows empty or valid email', () {
      final validUser = User(
        fullName: 'John Doe',
        phoneNumber: '+1234567890',
        email: 'john@example.com',
        emergencyContactName: 'Jane',
        emergencyContactPhone: '+1987654321',
        bloodGroup: 'A+',
      );

      expect(validUser.validate(), isEmpty);
    });
  });
}

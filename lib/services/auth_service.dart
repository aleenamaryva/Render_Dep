import '../models/user.dart';
import 'api_service.dart';

abstract class AuthService {
  Future<User?> signIn({required String email, required String password});
  Future<User?> signUp({required User user, required String password});
  Future<void> signOut();
  Future<User?> restoreSession();
  User? get currentUser;
  bool get isSignedIn;
}

class AuthServiceException implements Exception {
  final String message;

  const AuthServiceException(this.message);

  @override
  String toString() => message;
}

class FastApiAuthService implements AuthService {
  FastApiAuthService({required this.api});

  final ApiService api;
  User? _currentUser;

  @override
  User? get currentUser => _currentUser;

  @override
  bool get isSignedIn => _currentUser != null && api.accessToken != null;

  @override
  Future<User?> signIn({required String email, required String password}) async {
    if (email.trim().isEmpty) {
      throw const AuthServiceException('Email is required.');
    }
    if (password.isEmpty) {
      throw const AuthServiceException('Password is required.');
    }
    try {
      final response = await api.post('/login', {
        'email': email.trim(),
        'password': password,
      });
      return _setSession(response);
    } on ApiException catch (error) {
      throw AuthServiceException(error.message);
    }
  }

  @override
  Future<User?> signUp({required User user, required String password}) async {
    final email = user.email?.trim() ?? '';
    if (email.isEmpty) {
      throw const AuthServiceException('Email is required.');
    }
    if (password.length < 6) {
      throw const AuthServiceException('Password must be at least 6 characters.');
    }
    try {
      final response = await api.post('/register', {
        'full_name': user.fullName,
        'phone_number': user.phoneNumber,
        'email': email,
        'emergency_contact_name': user.emergencyContactName,
        'emergency_contact_phone': user.emergencyContactPhone,
        'blood_group': user.bloodGroup,
        'medical_information': user.medicalInformation,
        'password': password,
      });
      return _setSession(response);
    } on ApiException catch (error) {
      throw AuthServiceException(error.message);
    }
  }

  @override
  Future<User?> restoreSession() async {
    if (api.accessToken == null) return null;
    try {
      final response = await api.get('/users/me');
      _currentUser = _userFromResponse(response);
      return _currentUser;
    } on ApiException {
      await signOut();
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (api.accessToken != null) await api.post('/logout', {});
    } on ApiException {
      // Clear local state even if the backend is unreachable.
    } finally {
      api.accessToken = null;
      _currentUser = null;
    }
  }

  User? _setSession(Map<String, dynamic> response) {
    final token = response['access_token'] ?? response['token'];
    final userData = response['user'] ?? response;
    if (token is! String || userData is! Map<String, dynamic>) {
      throw const AuthServiceException(
        'The backend returned an invalid authentication response.',
      );
    }
    api.accessToken = token;
    _currentUser = _userFromResponse(userData);
    return _currentUser;
  }

  User _userFromResponse(Map<String, dynamic> data) {
    return User(
      id: data['id']?.toString() ?? '',
      fullName: data['full_name'] as String? ?? data['fullName'] as String? ?? '',
      phoneNumber: data['phone_number'] as String? ?? data['phoneNumber'] as String? ?? '',
      email: data['email'] as String?,
      emergencyContactName: data['emergency_contact_name'] as String? ?? '',
      emergencyContactPhone: data['emergency_contact_phone'] as String? ?? '',
      bloodGroup: data['blood_group'] as String? ?? '',
      medicalInformation: data['medical_information'] as String?,
    );
  }
}

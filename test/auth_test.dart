import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softwarep1/app.dart';
import 'package:softwarep1/models/user.dart';
import 'package:softwarep1/screens/auth/login_screen.dart';
import 'package:softwarep1/services/api_service.dart';
import 'package:softwarep1/services/auth_service.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.loginResult, this.loginError});

  final User? loginResult;
  final Exception? loginError;
  bool signInCalled = false;

  @override
  User? get currentUser => loginResult;

  @override
  bool get isSignedIn => loginResult != null;

  @override
  Future<User?> signIn({required String email, required String password}) async {
    signInCalled = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (loginError != null) throw loginError!;
    return loginResult;
  }

  @override
  Future<User?> signUp({required User user, required String password}) async => user;

  @override
  Future<void> signOut() async {}

  @override
  Future<User?> restoreSession() async => loginResult;
}

User _testUser() {
  return const User(
    id: 'api-user-1',
    fullName: 'Test Citizen',
    phoneNumber: '+1234567890',
    email: 'test@example.com',
    emergencyContactName: 'Emergency Contact',
    emergencyContactPhone: '+1987654321',
    bloodGroup: 'O+',
  );
}

void main() {
  test('FastAPI auth validates empty email and password before network access', () async {
    final service = FastApiAuthService(api: ApiService());

    expect(
      () => service.signIn(email: '', password: 'password'),
      throwsA(isA<AuthServiceException>()),
    );
    expect(
      () => service.signIn(email: 'test@example.com', password: ''),
      throwsA(isA<AuthServiceException>()),
    );
  });

  test('FastAPI auth validates registration email and minimum password', () async {
    final service = FastApiAuthService(api: ApiService());

    expect(
      () => service.signUp(user: _testUser().copyWith(email: ''), password: 'password123'),
      throwsA(isA<AuthServiceException>()),
    );
    expect(
      () => service.signUp(user: _testUser(), password: '12345'),
      throwsA(isA<AuthServiceException>()),
    );
  });

  test('unconfigured backend returns a clear error instead of fake success', () async {
    final service = FastApiAuthService(api: ApiService());

    expect(
      () => service.signIn(email: 'test@example.com', password: 'password123'),
      throwsA(
        isA<AuthServiceException>().having(
          (error) => error.message,
          'message',
          contains('Backend not connected'),
        ),
      ),
    );
  });

  testWidgets('login shows loading and navigates after authentication', (tester) async {
    final fakeAuth = _FakeAuthService(loginResult: _testUser());
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authService: fakeAuth),
        routes: {
          AppRoutes.home: (_) => const Text('Home loaded'),
          AppRoutes.register: (_) => const SizedBox(),
        },
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(fakeAuth.signInCalled, isTrue);

    await tester.pumpAndSettle();
    expect(find.text('Home loaded'), findsOneWidget);
  });

  testWidgets('login shows a friendly authentication error', (tester) async {
    final fakeAuth = _FakeAuthService(
      loginError: const AuthServiceException('The email or password is incorrect.'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authService: fakeAuth),
        routes: {AppRoutes.register: (_) => const SizedBox()},
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('The email or password is incorrect.'), findsOneWidget);
  });
}

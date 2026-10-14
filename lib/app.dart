import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/disaster/disaster_alert_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/response_history/response_history_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/welcome/welcome_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const register = '/register';
  static const login = '/login';
  static const home = '/home';
  static const profile = '/profile';
  static const disasterAlert = '/disaster-alert';
  static const responseHistory = '/response-history';
}

class LifeTraceApp extends StatelessWidget {
  const LifeTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeTrace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.welcome: (_) => const WelcomeScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.profile: (_) => const ProfileScreen(),
        AppRoutes.disasterAlert: (_) => const DisasterAlertScreen(),
        AppRoutes.responseHistory: (_) => const ResponseHistoryScreen(),
      },
    );
  }
}

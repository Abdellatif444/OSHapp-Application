import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/services/auth_service.dart';
import './login_screen.dart';
import './activation_screen.dart';
import '../dashboards/admin_dashboard_screen.dart';
import '../dashboards/doctor_dashboard_screen.dart';

import '../dashboards/hse_dashboard_screen.dart';
import '../dashboards/nurse_dashboard_screen.dart';
import '../dashboards/rh_dashboard_screen.dart';
import '../dashboards/employee_dashboard_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  AuthWrapperState createState() => AuthWrapperState();
}

class AuthWrapperState extends State<AuthWrapper> {

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        switch (authService.authStatus) {
          case AuthStatus.authenticated:
            return _getDashboardForUser(authService);
          case AuthStatus.unauthenticated:
            return const LoginScreen();
          case AuthStatus.unknown:
            return const LoginScreen();
        }
      },
    );
  }

  Widget _getDashboardForUser(AuthService authService) {
    final user = authService.user;
    if (user == null) {
      // This should not happen if isAuthenticated is true, but as a safeguard:
      return const LoginScreen();
    }

    final roles = authService.roles; // normalized: e.g., ['ADMIN', 'HR']

    // Enforce activation for all non-admin users before entering dashboards
    if (!roles.contains('ADMIN') && !user.isActive) {
      return ActivationScreen(email: authService.email ?? user.email);
    }

    // Role-based navigation with a clear hierarchy.
    if (roles.contains('ADMIN')) {
      return AdminDashboardScreen(user: user);
    }
    if (roles.contains('HR')) {
      return RHDashboardScreen(user: user);
    }
    if (roles.contains('DOCTOR')) {
      return DoctorDashboardScreen(user: user);
    }
    if (roles.contains('NURSE')) {
      return NurseDashboardScreen(user: user);
    }
    if (roles.contains('HSE')) {
      return HseDashboardScreen(user: user);
    }
    if (roles.contains('EMPLOYEE')) {
      // For employees and managers, the main screen manages the bottom navigation.
      return EmployeeDashboardScreen(user: user);
    }

    // Fallback to login screen if no recognizable role is found.
    return const LoginScreen();
  }
}  

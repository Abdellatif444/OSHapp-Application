import 'package:flutter/material.dart';

class RoleBasedNavigator {
  static void navigateToDashboard(BuildContext context, String? role) {
    switch (role?.toUpperCase()) {
      case 'ADMIN':
        Navigator.pushReplacementNamed(context, '/admin_home');
        break;
      case 'RH':
      case 'HR':
        Navigator.pushReplacementNamed(context, '/rh_home');
        break;
      case 'INFIRMIER':
      case 'NURSE':
        Navigator.pushReplacementNamed(context, '/nurse_home');
        break;
      case 'MEDECIN':
      case 'DOCTOR':
        Navigator.pushReplacementNamed(context, '/doctor_home');
        break;
      case 'HSE':
        Navigator.pushReplacementNamed(context, '/hse_home');
        break;
      case 'EMPLOYEE':
      default:
        Navigator.pushReplacementNamed(context, '/employee_home');
        break;
    }
  }
} 
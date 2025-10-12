import 'package:flutter/foundation.dart';
import 'package:oshapp/shared/models/employee.dart';

@immutable
class User {
  final String id;
  final String username;
  final String email;
  final List<String> roles;
  final bool isActive;
  final bool enabled;
  final Employee? employee;
  final int? n1Id;
  final int? n2Id;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.roles,
    required this.isActive,
    required this.enabled,
    this.employee,
    this.n1Id,
    this.n2Id,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Handles both nested (from login) and direct user data structures.
    final userData = json['user'] ?? json;

    // Parse roles from the determined user data.
    final rolesData = userData['roles'];
    List<String> roles = [];
    if (rolesData != null && rolesData is List) {
      roles = List<String>.from(rolesData.map((r) => r.toString()));
    }

    int? _parseManagerId(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      if (value is Map<String, dynamic>) {
        // Try common keys
        final dynamic direct = value['id'];
        if (direct is int) return direct;
        if (direct is num) return direct.toInt();
        if (direct is String) {
          final p = int.tryParse(direct);
          if (p != null) return p;
        }
        // Sometimes a nested user object may contain an employee sub-object
        final emp = value['employee'];
        if (emp is Map<String, dynamic>) {
          final dynId = emp['id'];
          if (dynId is int) return dynId;
          if (dynId is num) return dynId.toInt();
          if (dynId is String) return int.tryParse(dynId);
        }
      }
      return null;
    }

    return User(
      id: userData['id']?.toString() ?? '',
      username: userData['username']?.toString() ?? '',
      email: userData['email']?.toString() ?? '',
      roles: roles,
      isActive: userData['active'] ?? false,
      enabled: userData['enabled'] ?? false,
      employee: userData['employee'] != null
          ? Employee.fromJson(userData['employee'])
          : null,
      n1Id: _parseManagerId(userData['n1'] ?? userData['n1Id']),
      n2Id: _parseManagerId(userData['n2'] ?? userData['n2Id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'roles': roles,
      'active': isActive,
      'enabled': enabled,
      'employee': employee?.toJson(),
      // Emit as IDs for consistency with backend DTOs
      'n1': n1Id,
      'n2': n2Id,
      'n1Id': n1Id,
      'n2Id': n2Id,
    };
  }

  static String _normalizeRoleName(String role) {
    var name = role.trim().toUpperCase();
    if (name.startsWith('ROLE_')) {
      name = name.substring(5);
    }
    if (name == 'RH') name = 'HR';
    if (name == 'INFIRMIER') name = 'NURSE';
    if (name == 'MEDECIN') name = 'DOCTOR';
    return name;
  }

  bool hasRole(String role) {
    final target = _normalizeRoleName(role);
    return roles.any((r) => _normalizeRoleName(r) == target);
  }

  factory User.empty() {
    return const User(
      id: '',
      username: '',
      email: '',
      roles: [],
      isActive: false,
      enabled: false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

import 'package:meta/meta.dart';

@immutable
class Role {
  final int id;
  final String name;
  final Set<String> permissions;

  const Role({required this.id, required this.name, required this.permissions});

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as int,
      name: json['name'] as String,
      permissions: Set<String>.from(json['permissions'] ?? []),
    );
  }

  static const List<Role> allRoles = [
    Role(id: 1, name: 'EMPLOYEE', permissions: <String>{}),
    Role(id: 2, name: 'HR', permissions: <String>{}),
    Role(id: 3, name: 'NURSE', permissions: <String>{}),
    Role(id: 4, name: 'DOCTOR', permissions: <String>{}),
    Role(id: 5, name: 'HSE', permissions: <String>{}),
    Role(id: 6, name: 'ADMIN', permissions: <String>{}),
  ];

  static Role fromString(String roleName) {
    // Normalize backend roles like 'ROLE_ADMIN' to 'ADMIN',
    // and map French labels to English equivalents (e.g., RH->HR, INFIRMIER->NURSE, MEDECIN->DOCTOR)
    var name = roleName.trim().toUpperCase();
    if (name.startsWith('ROLE_')) {
      name = name.substring(5);
    }
    if (name == 'RH') {
      name = 'HR';
    }
    if (name == 'INFIRMIER') {
      name = 'NURSE';
    }
    if (name == 'MEDECIN') {
      name = 'DOCTOR';
    }
    return allRoles.firstWhere(
      (role) => role.name == name,
      orElse: () => throw ArgumentError('Unknown role: $roleName'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'permissions': permissions.toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Role && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
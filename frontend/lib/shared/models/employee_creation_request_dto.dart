import 'package:flutter/foundation.dart';

@immutable
class EmployeeCreationRequestDTO {
  // Core fields required by backend EmployeeCreationRequestDTO
  final int? userId;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? position; // maps directly to backend 'position'
  final String? department;
  final DateTime? hireDate; // LocalDate on backend
  final DateTime? dateOfBirth; // LocalDate on backend
  final int? manager1Id; // employee IDs
  final int? manager2Id; // employee IDs
  final String? cin;
  final String? cnss;
  final String? phoneNumber;
  final String? placeOfBirth;
  final String? address;
  final String? nationality;
  final String? city;
  final String? zipCode;
  final String? country;
  final String? gender; // HOMME | FEMME

  // Backward-compatibility (legacy fields sometimes used in older code paths)
  final String? id;
  final String? jobTitle; // alias for position
  final List<int>? roleIds; // ignored by backend in this DTO
  final String? managerId; // alias for manager1Id (string form)

  const EmployeeCreationRequestDTO({
    this.userId,
    this.firstName,
    this.lastName,
    this.email,
    this.position,
    this.department,
    this.hireDate,
    this.dateOfBirth,
    this.manager1Id,
    this.manager2Id,
    this.cin,
    this.cnss,
    this.phoneNumber,
    this.placeOfBirth,
    this.address,
    this.nationality,
    this.city,
    this.zipCode,
    this.country,
    this.gender,
    // legacy/optional
    this.id,
    this.jobTitle,
    this.roleIds,
    this.managerId,
  });

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String? _formatDate(DateTime? d) {
    if (d == null) return null;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'userId': userId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      // Prefer explicit 'position'; fallback to legacy 'jobTitle'
      'position': position ?? jobTitle,
      'department': department,
      'hireDate': _formatDate(hireDate),
      'dateOfBirth': _formatDate(dateOfBirth),
      'manager1Id': manager1Id ?? _parseInt(managerId),
      'manager2Id': manager2Id,
      'cin': cin,
      'cnss': cnss,
      'phoneNumber': phoneNumber,
      'placeOfBirth': placeOfBirth,
      'address': address,
      'nationality': nationality,
      'city': city,
      'zipCode': zipCode,
      'country': country,
      'gender': gender,
    };
    map.removeWhere((key, value) => value == null);
    return map;
  }
}

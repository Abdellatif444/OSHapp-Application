import 'package:flutter/foundation.dart';

@immutable
class Employee {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? cin;
  final DateTime? hireDate;
  final String? jobTitle;
  final String? email;
  final String? address;
  final String? phoneNumber;
  final String? cnssNumber;
  final String? maritalStatus;
  final int? childrenCount;
  final DateTime? birthDate;
  final String? birthPlace;
  final String? department;
  final String? city;
  final String? zipCode;
  final String? country;
  final String? gender;
  final bool profileCompleted;
  final String? profilePicture;
  final Employee? manager;
  final List<String>? roles;

  const Employee({
    required this.id,
    this.firstName,
    this.lastName,
    this.cin,
    this.hireDate,
    this.jobTitle,
    this.email,
    this.address,
    this.phoneNumber,
    this.cnssNumber,
    this.maritalStatus,
    this.childrenCount,
    this.birthDate,
    this.birthPlace,
    this.department,
    this.city,
    this.zipCode,
    this.country,
    this.gender,
    this.profileCompleted = false,
    this.profilePicture,
    this.manager,
    this.roles,
  });

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();

  String get initials {
    final f = firstName?.isNotEmpty == true ? firstName![0] : '';
    final l = lastName?.isNotEmpty == true ? lastName![0] : '';
    return '$f$l'.toUpperCase();
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    // Helper to extract non-nullable fields and throw a clear error if missing.
    T getRequiredField<T>(String key) {
      if (json.containsKey(key) && json[key] != null) {
        // Handle case where backend sends int for id but we expect String
        if (T == String && json[key] is int) {
          return json[key].toString() as T;
        }
        return json[key] as T;
      }
      throw FormatException('Missing required field "$key" in Employee JSON.');
    }

    // Handle date parsing.
    DateTime? parseNullableDate(String key) {
      final value = json[key];
      if (value != null && value is String) {
        return DateTime.parse(value);
      }
      return null;
    }

    // Pre-resolve potential manager node once
    final dynamic mgrNode = json['manager'] ?? json['manager1'];
    // Parse roles if present as an array of strings
    List<String>? parseRoles() {
      final r = json['roles'];
      if (r is List) {
        return r.map((e) => e.toString()).toList();
      }
      return null;
    }

    return Employee(
      id: getRequiredField<dynamic>('id').toString(),
      // Make these fields nullable to handle incomplete profiles
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      cin: json['cin'] as String?,
      jobTitle: (json['jobTitle'] ?? json['position']) as String?,
      email: json['email'] as String?,
      hireDate: parseNullableDate('hireDate'),
      gender: json['gender'] as String?,
      profileCompleted: json['profileCompleted'] as bool? ?? false,

      // Nullable fields
      address: json['address'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      cnssNumber: (json['cnss'] ?? json['cnssNumber']) as String?,
      maritalStatus: json['maritalStatus'] as String?,
      childrenCount: json['childrenCount'] as int?,
      birthDate: parseNullableDate('birthDate'),
      birthPlace: json['birthPlace'] as String?,
      department: json['department'] as String?,
      city: json['city'] as String?,
      zipCode: json['zipCode'] as String?,
      country: json['country'] as String?,
      profilePicture: json['profilePicture'] as String?,
      // Only parse manager if it's a nested object; ignore if it's an ID or unsupported type
      manager: (mgrNode is Map<String, dynamic>)
          ? Employee.fromJson(mgrNode as Map<String, dynamic>)
          : null,
      roles: parseRoles(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'cin': cin,
      'hireDate': hireDate?.toIso8601String(),
      'jobTitle': jobTitle,
      'email': email,
      'address': address,
      'phoneNumber': phoneNumber,
      'cnss': cnssNumber,
      'maritalStatus': maritalStatus,
      'childrenCount': childrenCount,
      'birthDate': birthDate?.toIso8601String(),
      'birthPlace': birthPlace,
      'department': department,
      'city': city,
      'zipCode': zipCode,
      'country': country,
      'gender': gender,
      'profileCompleted': profileCompleted,
      'profilePicture': profilePicture,
      'manager': manager?.toJson(),
      if (roles != null) 'roles': roles,
    };
  }
}

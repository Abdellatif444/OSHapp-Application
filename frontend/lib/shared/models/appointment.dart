import 'package:flutter/material.dart';
import 'package:oshapp/shared/models/user.dart';
import 'package:oshapp/shared/config/status_styles.dart';

// Represents the detailed Appointment object received from the backend (AppointmentResponseDTO)
class Appointment {
  final int id;
  final int employeeId;
  final String employeeName;
  final String employeeEmail;
  final String? cancellationReason;
  final User? nurse;
  final User? doctor;
  final String type;
  final String status;
  final String? visitMode;
  final DateTime? requestedDateEmployee;
  final DateTime? proposedDate;
  final DateTime? appointmentDate;
  final String? motif;
  final String? reason;
  final String? notes;
  final String? location;
  final bool obligatory;
  final User? createdBy;
  final User? updatedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // OSHapp Workflow Fields
  final String? priority;
  final List<String>? preferredTimeSlots;
  final bool? flexibleSchedule;
  final List<String>? notificationChannels;
  final String? workflowStep;
  final String? comments;

  // Medical visit planning fields
  final String? medicalInstructions;
  final String? medicalServicePhone;

  // Formatted display fields from backend
  final String? statusDisplay;
  final String? typeDisplay;
  final String? typeShortDisplay;
  final String? visitModeDisplay;
  final String? statusUiDisplay;
  final String? statusUiDisplayForNurse;
  final String? statusUiCategory;

  // Action flags from backend based on user role and appointment status
  final bool canConfirm;
  final bool canCancel;
  final bool canPropose;
  final bool canComment;

  Appointment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeEmail,
    this.cancellationReason,
    this.nurse,
    this.doctor,
    required this.type,
    required this.status,
    this.visitMode,
    required this.requestedDateEmployee,
    this.proposedDate,
    this.appointmentDate,
    required this.motif,
    required this.reason,
    required this.notes,
    required this.location,
    required this.obligatory,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    this.updatedAt,
    this.priority,
    this.preferredTimeSlots,
    this.flexibleSchedule,
    this.notificationChannels,
    this.workflowStep,
    this.comments,
    // Medical visit planning fields
    this.medicalInstructions,
    this.medicalServicePhone,
    // Formatted display fields from backend
    this.statusDisplay,
    this.typeDisplay,
    this.typeShortDisplay,
    this.visitModeDisplay,
    this.statusUiDisplay,
    this.statusUiDisplayForNurse,
    this.statusUiCategory,
    // Action flags from backend
    this.canConfirm = false,
    this.canCancel = false,
    this.canPropose = false,
    this.canComment = false,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    int? safeParseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    DateTime? safeParseDateTime(dynamic value) {
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    // Fallback mapping: some backend flows (e.g., obligatory planning)
    // provide the planned date under 'scheduledTime'. Use it as a fallback
    // for deadline (requestedDateEmployee) and appointmentDate when missing.
    final DateTime? _scheduledTime = safeParseDateTime(json['scheduledTime']);

    final appointmentId = safeParseInt(json['id']);
    // Extract nested employee summary if present
    final Map<String, dynamic>? employeeJson =
        (json['employee'] is Map<String, dynamic>)
            ? (json['employee'] as Map<String, dynamic>)
            : null;
    final int? employeeIdValue = safeParseInt(json['employeeId']) ??
        (employeeJson != null ? safeParseInt(employeeJson['id']) : null);

    if (appointmentId == null) {
      throw ArgumentError(
          'Appointment ID is missing or invalid: ${json['id']}');
    }
    if (employeeIdValue == null) {
      throw ArgumentError(
          'Employee ID is missing or invalid for appointment: ${json['id']}');
    }

    // Normalize comments to plain text: if backend returns a list of comment objects,
    // pick the latest one's 'comment' text. Otherwise, stringify gracefully.
    final dynamic _commentsRaw = json['comments'];
    String? _commentsText;
    if (_commentsRaw == null) {
      _commentsText = null;
    } else if (_commentsRaw is String) {
      _commentsText = _commentsRaw;
    } else if (_commentsRaw is List) {
      if (_commentsRaw.isEmpty) {
        _commentsText = null;
      } else {
        final last = _commentsRaw.last;
        if (last is Map && last['comment'] != null) {
          _commentsText = last['comment']?.toString();
        } else {
          _commentsText = _commentsRaw.map((e) {
            if (e is Map && e['comment'] != null)
              return e['comment'].toString();
            return e.toString();
          }).join(', ');
        }
      }
    } else if (_commentsRaw is Map) {
      _commentsText = (_commentsRaw['comment'] ?? _commentsRaw).toString();
    } else {
      _commentsText = _commentsRaw.toString();
    }

    return Appointment(
      id: appointmentId,
      employeeId: employeeIdValue,
      employeeName: (() {
        final dynamic top = json['employeeName'];
        if (top is String && top.trim().isNotEmpty) return top;
        // Backend EmployeeSummaryDTO only has id and fullName
        final e = employeeJson;
        if (e != null) {
          final fullName = e['fullName']?.toString();
          if (fullName != null && fullName.trim().isNotEmpty) return fullName;
        }
        // Fallback to createdBy name if available
        final createdBy = json['createdBy'];
        if (createdBy is Map<String, dynamic>) {
          final createdByName = createdBy['fullName']?.toString() ?? 
                                createdBy['firstName']?.toString() ?? 
                                createdBy['username']?.toString();
          if (createdByName != null && createdByName.trim().isNotEmpty) return createdByName;
        }
        return 'N/A';
      })(),
      employeeEmail: (() {
        final dynamic top = json['employeeEmail'];
        if (top is String && top.trim().isNotEmpty) return top;
        // EmployeeSummaryDTO doesn't include email, try createdBy
        final createdBy = json['createdBy'];
        if (createdBy is Map<String, dynamic>) {
          final email = createdBy['email']?.toString();
          if (email != null && email.trim().isNotEmpty) return email;
        }
        // Try employee summary if it has email (though spec says it doesn't)
        final e = employeeJson;
        if (e != null) {
          final email = e['email']?.toString();
          if (email != null && email.trim().isNotEmpty) return email;
        }
        return 'N/A';
      })(),
      cancellationReason:
          json['cancellationReason'] ?? 'Aucune raison d\'annulation',
      nurse: json['nurse'] != null ? User.fromJson(json['nurse']) : null,
      doctor: json['doctor'] != null ? User.fromJson(json['doctor']) : null,
      type: (json['type'] is List
              ? (json['type'] as List).join(', ')
              : json['type']) ??
          'UNKNOWN',
      status: (json['status'] is List
              ? (json['status'] as List).join(', ')
              : json['status']) ??
          'UNKNOWN',
      visitMode: json['visitMode']?.toString(),
      requestedDateEmployee:
          safeParseDateTime(json['requestedDateEmployee']) ?? _scheduledTime,
      proposedDate: safeParseDateTime(json['proposedDate']),
      appointmentDate:
          safeParseDateTime(json['appointmentDate']) ?? _scheduledTime,
      motif: json['motif'] is List
          ? (json['motif'] as List).join(', ')
          : json['motif'],
      reason: json['reason'] is List
          ? (json['reason'] as List).join(', ')
          : json['reason'],
      notes: json['notes'] is List
          ? (json['notes'] as List).join(', ')
          : json['notes'],
      location: json['location'] is List
          ? (json['location'] as List).join(', ')
          : json['location'],
      obligatory: json['obligatory'] ?? false,
      createdBy:
          json['createdBy'] != null ? User.fromJson(json['createdBy']) : null,
      updatedBy:
          json['updatedBy'] != null ? User.fromJson(json['updatedBy']) : null,
      createdAt: safeParseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: safeParseDateTime(json['updatedAt']),
      priority: json['priority'] is List
          ? (json['priority'] as List).join(', ')
          : json['priority'],
      preferredTimeSlots: json['preferredTimeSlots'] != null
          ? List<String>.from(json['preferredTimeSlots'])
          : null,
      flexibleSchedule: json['flexibleSchedule'],
      notificationChannels: json['notificationChannels'] != null
          ? List<String>.from(json['notificationChannels'])
          : null,
      workflowStep: json['workflowStep'] is List
          ? (json['workflowStep'] as List).join(', ')
          : json['workflowStep'],
      comments: _commentsText,
      // Parse medical visit planning fields
      medicalInstructions: json['medicalInstructions']?.toString(),
      medicalServicePhone: json['medicalServicePhone']?.toString(),
      // Parse formatted display fields from backend
      statusDisplay: json['statusDisplay'],
      typeDisplay: json['typeDisplay'],
      typeShortDisplay: json['typeShortDisplay'],
      visitModeDisplay: json['visitModeDisplay'],
      statusUiDisplay: json['statusUiDisplay'],
      statusUiDisplayForNurse: json['statusUiDisplayForNurse'],
      statusUiCategory: json['statusUiCategory'],
      // Parse action flags from backend (default to false if not present)
      canConfirm: json['canConfirm'] ?? false,
      canCancel: json['canCancel'] ?? false,
      canPropose: json['canPropose'] ?? false,
      canComment: json['canComment'] ?? false,
    );
  }

  // Getter for backward compatibility
  String get appointmentType => type;

  Color get statusColor => StatusStyle.colorFor(statusUiCategory);

  // Getters for backward compatibility
  String get employee => employeeName;
  String? get employeeManager1 => null; // TODO: Add manager info from backend
  String? get employeeManager2 => null; // TODO: Add manager info from backend

  // Professional alias for the requested date (used as deadline in UI when applicable)
  DateTime? get deadline => requestedDateEmployee;
}

class AppointmentRequest {
  final int employeeId;
  final String? motif;
  final String? notes;
  final String requestedDateEmployee;
  final String? visitMode;
  final String type;

  AppointmentRequest({
    required this.employeeId,
    this.motif,
    this.notes,
    required this.requestedDateEmployee,
    this.visitMode,
    this.type = 'SPONTANEOUS', // Employee-initiated requests are spontaneous visits
  });

  Map<String, dynamic> toJson() {
    return {
      'motif': motif,
      'notes': notes,
      'type': type,
      'requestedDateEmployee': requestedDateEmployee,
      'visitMode': visitMode,
      'employeeId': employeeId,
    }..removeWhere((key, value) => value == null);
  }
}

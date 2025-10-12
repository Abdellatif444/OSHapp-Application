class StatsDTO {
  final int totalAppointments;
  final int pendingRequests;
  final int confirmedAppointments;
  final int completedVisits;
  final int pendingCount;
  final int proposedCount;
  final int todayCount;
  final int rescheduledCount;

  StatsDTO({
    required this.totalAppointments,
    required this.pendingRequests,
    required this.confirmedAppointments,
    required this.completedVisits,
    required this.pendingCount,
    required this.proposedCount,
    required this.todayCount,
    required this.rescheduledCount,
  });

  factory StatsDTO.fromJson(Map<String, dynamic> json) {
    return StatsDTO(
      totalAppointments: json['totalAppointments'] ?? 0,
      pendingRequests: json['pendingRequests'] ?? 0,
      confirmedAppointments: json['confirmedAppointments'] ?? 0,
      completedVisits: json['completedVisits'] ?? 0,
      pendingCount: json['pendingCount'] ?? 0,
      proposedCount: json['proposedCount'] ?? 0,
      todayCount: json['todayCount'] ?? 0,
      rescheduledCount: json['rescheduledCount'] ?? 0,
    );
  }
}

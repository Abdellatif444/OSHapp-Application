class Stats {
  // Fields for Medical Dashboards
  final int pendingCount;
  final int confirmedCount;
  final int completedCount;
  final int proposedCount;
  final int totalAppointments;

  // Fields for HSE Dashboard
  final int totalIncidents;
  final int totalAccidents;
  final int riskAnalyses;
  final int completedTasks;

  Stats({
    // Medical
    this.pendingCount = 0,
    this.confirmedCount = 0,
    this.completedCount = 0,
    this.proposedCount = 0,
    this.totalAppointments = 0,
    // HSE
    this.totalIncidents = 0,
    this.totalAccidents = 0,
    this.riskAnalyses = 0,
    this.completedTasks = 0,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return Stats(
      // Medical (support multiple backend key variants)
      pendingCount: toInt(json['pendingCount'] ?? json['pendingAppointments'] ?? json['pending'] ?? 0),
      confirmedCount: toInt(json['confirmedCount'] ?? json['confirmedAppointments'] ?? json['confirmed'] ?? 0),
      completedCount: toInt(json['completedCount'] ?? json['completedConsultations'] ?? json['completedAppointments'] ?? json['completed'] ?? 0),
      proposedCount: toInt(
        json['proposedCount'] ??
        json['proposedAppointments'] ??
        json['proposed'] ??
        json['proposed_visits'] ??
        json['proposees'] ??
        json['proposées'] ?? 0,
      ),
      totalAppointments: toInt(
        json['totalAppointments'] ??
        json['totalRequests'] ??
        json['appointmentsTotal'] ??
        json['total_visits'] ??
        json['total'] ?? 0,
      ),
      // HSE
      totalIncidents: toInt(json['totalIncidents']),
      totalAccidents: toInt(json['totalAccidents']),
      riskAnalyses: toInt(json['riskAnalyses']),
      completedTasks: toInt(json['completedTasks']),
    );
  }
}

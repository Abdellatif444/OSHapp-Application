class MedicalCertificate {
  final int id;
  final String employeeName;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;

  MedicalCertificate({
    required this.id,
    required this.employeeName,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
  });

  factory MedicalCertificate.fromJson(Map<String, dynamic> json) {
    return MedicalCertificate(
      id: json['id'],
      employeeName: json['employeeName'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      reason: json['reason'],
      status: json['status'],
    );
  }
}

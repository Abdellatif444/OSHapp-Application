class UploadedMedicalCertificate {
  final int id;
  final int? employeeId;
  final String? employeeName;
  final String? certificateType;
  final DateTime issueDate;
  final DateTime? expirationDate;
  final String? filePath;
  final String? doctorName;
  final String? comments;

  UploadedMedicalCertificate({
    required this.id,
    required this.issueDate,
    this.employeeId,
    this.employeeName,
    this.certificateType,
    this.expirationDate,
    this.filePath,
    this.doctorName,
    this.comments,
  });

  factory UploadedMedicalCertificate.fromJson(Map<String, dynamic> json) {
    return UploadedMedicalCertificate(
      id: (json['id'] as num).toInt(),
      employeeId: json['employeeId'] == null ? null : (json['employeeId'] as num).toInt(),
      employeeName: json['employeeName'] as String?,
      certificateType: json['certificateType'] as String?,
      issueDate: DateTime.parse(json['issueDate'] as String),
      expirationDate: json['expirationDate'] != null && (json['expirationDate'] as String).isNotEmpty
          ? DateTime.tryParse(json['expirationDate'] as String)
          : null,
      filePath: json['filePath'] as String?,
      doctorName: json['doctorName'] as String?,
      comments: json['comments'] as String?,
    );
  }
}

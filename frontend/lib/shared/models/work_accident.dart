class WorkAccident {
  final int id;
  final String employeeName;
  final DateTime accidentDate;
  final String description;
  final String status;

  WorkAccident({
    required this.id,
    required this.employeeName,
    required this.accidentDate,
    required this.description,
    required this.status,
  });

  factory WorkAccident.fromJson(Map<String, dynamic> json) {
    return WorkAccident(
      id: json['id'],
      employeeName: json['employeeName'],
      accidentDate: DateTime.parse(json['accidentDate']),
      description: json['description'],
      status: json['status'],
    );
  }
}

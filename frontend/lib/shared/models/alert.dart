class Alert {
  final String id;
  final String title;
  final String description;
  final String date;
  final String severity;
  final String link;

  Alert({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.severity,
    required this.link,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      date: json['date']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
    );
  }
}

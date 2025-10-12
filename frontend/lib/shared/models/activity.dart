class Activity {
  final String id;
  final String title;
  final String description;
  final String timestamp;
  final String type;
  final String? link;

  Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
    this.link, // Make link optional
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      timestamp: json['timestamp']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      link: json['link']?.toString(), // Safely cast to nullable String
    );
  }
}

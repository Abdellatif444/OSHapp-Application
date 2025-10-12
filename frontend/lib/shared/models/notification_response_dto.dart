class NotificationResponseDTO {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  bool isRead;

  NotificationResponseDTO({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

 factory NotificationResponseDTO.fromJson(Map<String, dynamic> json) {
    return NotificationResponseDTO(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['read'] ?? false,
    );
  }
}

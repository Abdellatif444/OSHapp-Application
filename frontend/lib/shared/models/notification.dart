class AppNotification {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool read;
  final String? relatedEntityType;
  final int? relatedEntityId;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    this.relatedEntityType,
    this.relatedEntityId,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
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

    final notificationId = safeParseInt(json['id']);
    if (notificationId == null) {
      throw ArgumentError('Notification ID is missing or invalid: ${json['id']}');
    }

    return AppNotification(
      id: notificationId,
      title: json['title'] ?? 'Sans titre',
      message: json['message'] ?? 'Pas de message.',
      type: json['type'] ?? 'GENERAL',
      read: json['read'] ?? false,
      relatedEntityType: json['relatedEntityType'],
      relatedEntityId: safeParseInt(json['relatedEntityId']),
      createdAt: safeParseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'read': read,
      'relatedEntityType': relatedEntityType,
      'relatedEntityId': relatedEntityId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get typeDisplay {
    switch (type) {
      case 'APPOINTMENT':
        return 'Rendez-vous';
      case 'EMERGENCY':
        return 'Urgence';
      case 'SYSTEM':
        return 'Système';
      case 'GENERAL':
        return 'Général';
      default:
        return type;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inMinutes < 5;
  }
} 
import 'package:oshapp/shared/models/employee.dart';
import 'package:oshapp/shared/models/appointment.dart';
import 'package:oshapp/shared/models/stats.dart';

import 'package:oshapp/shared/models/notification.dart';
import 'package:oshapp/shared/services/logger_service.dart';

class NurseDashboardData {
  final Employee employee;
  final Stats stats;
  final List<Appointment> pendingAppointments;
  final List<Appointment> todayAppointments;
  final int unreadNotifications;
  final List<AppNotification> notifications;
  final Map<String, int> visitTypeCounts;

  NurseDashboardData({
    required this.employee,
    required this.stats,
    required this.pendingAppointments,
    required this.todayAppointments,
    required this.unreadNotifications,
    required this.notifications,
    required this.visitTypeCounts,
  });

  factory NurseDashboardData.fromJson(Map<String, dynamic> json) {
    var notificationList = json['notifications'] as List? ?? [];
    List<AppNotification> notifications = notificationList.map((i) => AppNotification.fromJson(i)).toList();

    // Safely parse appointment lists: skip corrupted items but log them.
    List<Appointment> _parseAppointments(String fieldName) {
      final raw = json[fieldName] as List? ?? [];
      final result = <Appointment>[];
      for (final item in raw) {
        try {
          result.add(Appointment.fromJson(item));
        } catch (e) {
          LoggerService.warning('Skipping corrupted appointment in ' + fieldName + ': ' + e.toString());
        }
      }
      return result;
    }

    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final Map<String, dynamic> vtcRaw = (json['visitTypeCounts'] as Map?)?.cast<String, dynamic>() ?? const {};
    final Map<String, int> visitTypeCounts = {
      'reprise': toInt(vtcRaw['reprise']),
      'embauche': toInt(vtcRaw['embauche']),
      'spontane': toInt(vtcRaw['spontane']),
      'periodique': toInt(vtcRaw['periodique']),
      'surveillance': toInt(vtcRaw['surveillance']),
      'appel_medecin': toInt(vtcRaw['appel_medecin']),
    };

    return NurseDashboardData(
      employee: Employee.fromJson(json['employee']),
      stats: Stats.fromJson(json['stats']),
      pendingAppointments: _parseAppointments('pendingAppointments'),
      todayAppointments: _parseAppointments('todayAppointments'),
      unreadNotifications: json['unreadNotifications'] ?? 0,
      notifications: notifications,
      visitTypeCounts: visitTypeCounts,
    );
  }
}

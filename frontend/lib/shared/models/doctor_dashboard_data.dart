import 'package:oshapp/shared/models/alert.dart';
import 'package:oshapp/shared/models/activity.dart';

class DoctorStats {
  final int pendingCount;
  final int confirmedCount;
  final int completedCount;

  DoctorStats({
    required this.pendingCount,
    required this.confirmedCount,
    required this.completedCount,
  });

  factory DoctorStats.fromJson(Map<String, dynamic> json) {
    return DoctorStats(
      pendingCount: json['pendingCount']?.toInt() ?? 0,
      confirmedCount: json['confirmedCount']?.toInt() ?? 0,
      completedCount: json['completedCount']?.toInt() ?? 0,
    );
  }
}

class DoctorDashboardData {
  final DoctorStats stats;
  final List<Alert> alerts;
  final List<Activity> activities;
  final int unreadNotifications;

  DoctorDashboardData({
    required this.stats,
    required this.alerts,
    required this.activities,
    required this.unreadNotifications,
  });

  factory DoctorDashboardData.fromJson(Map<String, dynamic> json) {
    var alertList = json['alerts'] as List? ?? [];
    var activityList = json['activities'] as List? ?? [];

    return DoctorDashboardData(
      stats: DoctorStats.fromJson(json['stats'] ?? {}),
      alerts: alertList.map((i) => Alert.fromJson(i)).toList(),
      activities: activityList.map((i) => Activity.fromJson(i)).toList(),
      unreadNotifications: json['unreadNotifications']?.toInt() ?? 0,
    );
  }
}

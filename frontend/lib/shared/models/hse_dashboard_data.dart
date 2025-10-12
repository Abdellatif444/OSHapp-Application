import 'package:oshapp/shared/models/activity.dart';
import 'package:oshapp/shared/models/alert.dart';
import 'package:oshapp/shared/models/stats.dart';

class HseDashboardData {
  final Stats stats;
  final List<Alert> alerts;
  final List<Activity> activities;

  HseDashboardData({
    required this.stats,
    required this.alerts,
    required this.activities,
  });

  factory HseDashboardData.fromJson(Map<String, dynamic> json) {
    return HseDashboardData(
      stats: Stats.fromJson(json['stats'] ?? {}),
      alerts: (json['alerts'] as List?)
              ?.map((item) => Alert.fromJson(item))
              .toList() ??
          [],
      activities: (json['activities'] as List?)
              ?.map((item) => Activity.fromJson(item))
              .toList() ??
          [],
    );
  }
}

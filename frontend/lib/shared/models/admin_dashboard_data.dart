class AdminDashboardData {
  final int totalUsers;
  final int activeUsers;
  final int totalRoles;
  final int recentLogins;
  final int inactiveUsers;
  final int awaitingVerificationUsers;

  AdminDashboardData({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalRoles,
    required this.recentLogins,
    required this.inactiveUsers,
    required this.awaitingVerificationUsers,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    return AdminDashboardData(
      totalUsers: json['totalUsers'] ?? 0,
      activeUsers: json['activeUsers'] ?? 0,
      totalRoles: json['totalRoles'] ?? 0,
      recentLogins: json['recentLogins'] ?? 0,
      inactiveUsers: json['inactiveUsers'] ?? 0,
      awaitingVerificationUsers: json['awaitingVerificationUsers'] ?? 0,
    );
  }
}

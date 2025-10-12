package com.oshapp.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class AdminDashboardData {
    private long totalUsers;
    private long activeUsers;
    private long totalRoles;
    private long recentLogins; // Example stat
    private long inactiveUsers;
    private long awaitingVerificationUsers;
}

package com.oshapp.backend.service;

import com.oshapp.backend.dto.ActivityDTO;
import com.oshapp.backend.dto.AlertDTO;

import java.util.List;
import java.util.Map;

public interface StatisticsService {
    Map<String, Object> getAdminDashboardStatistics();
    Map<String, Object> getRhDashboardStatistics();
    List<AlertDTO> getRhDashboardAlerts();
    List<ActivityDTO> getRhDashboardActivities();
}

package com.oshapp.backend.controller;

import com.oshapp.backend.service.StatisticsService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.oshapp.backend.dto.ActivityDTO;
import com.oshapp.backend.dto.AlertDTO;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/statistics")
public class StatisticsController {

    @Autowired
    private StatisticsService statisticsService;

    @GetMapping("/admin")
    @PreAuthorize("hasRole('ROLE_ADMIN')")
    public ResponseEntity<Map<String, Object>> getAdminDashboardStatistics() {
        Map<String, Object> stats = statisticsService.getAdminDashboardStatistics();
        return ResponseEntity.ok(stats);
    }

    @GetMapping("/rh")
    @PreAuthorize("hasRole('ROLE_RH')")
    public ResponseEntity<Map<String, Object>> getRhDashboardStatistics() {
        Map<String, Object> stats = statisticsService.getRhDashboardStatistics();
        return ResponseEntity.ok(stats);
    }

    @GetMapping("/rh/alerts")
    @PreAuthorize("hasRole('ROLE_RH')")
    public ResponseEntity<List<AlertDTO>> getRhDashboardAlerts() {
        List<AlertDTO> alerts = statisticsService.getRhDashboardAlerts();
        return ResponseEntity.ok(alerts);
    }

    @GetMapping("/rh/activities")
    @PreAuthorize("hasRole('ROLE_RH')")
    public ResponseEntity<List<ActivityDTO>> getRhDashboardActivities() {
        List<ActivityDTO> activities = statisticsService.getRhDashboardActivities();
        return ResponseEntity.ok(activities);
    }
}

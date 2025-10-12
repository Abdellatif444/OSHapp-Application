package com.oshapp.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.Map;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class NurseDashboardDTO {
    private EmployeeProfileDTO employee;
    private StatsDTO stats;
        private List<AppointmentResponseDTO> pendingAppointments;
        private List<AppointmentResponseDTO> todayAppointments;
    private int unreadNotifications;
    private List<NotificationResponseDTO> notifications;
    private Map<String, Long> visitTypeCounts;
}

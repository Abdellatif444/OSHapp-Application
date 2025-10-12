package com.oshapp.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class DoctorDashboardDTO {
    private StatsDTO stats;
    private List<AlertDTO> alerts;
    private List<ActivityDTO> activities;
    private int unreadNotifications;
}
